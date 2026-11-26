#!/usr/bin/env bash
#
# Build the pinned Hyprland RPM set for fedora-hyprtomic.
#
# Inputs are read exclusively from lock.yml. The build is meant to run as root
# inside a Fedora 45 container (the GitHub Actions job uses fedora:45):
#
#   podman run --rm -v "$PWD:/work:Z" -w /work fedora:45 \
#       bash packages/hyprland/build.sh
#
# Output:
#   packages/hyprland/out/         RPMs + repodata, suitable as a file:// dnf repo
#   packages/hyprland/out/.complete
#
# The GitHub workflow copies out/ to files/dnf/hyprland-rpms/ before the
# BlueBuild action runs; the recipe consumes it through
# files/dnf/hyprland-local.repo (bind-mounted at /tmp/files during the build,
# so the RPMs never become an image layer).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lock=${LOCK:-$here/lock.yml}
out=${OUT:-$here/out}
work=${WORK:-$(mktemp -d)}
keep_work=${KEEP_WORK:-0}

cleanup() {
    if [[ $keep_work == 1 ]]; then
        echo "keeping work directory: $work" >&2
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT

if [[ $(id -u) -ne 0 ]]; then
    echo "build.sh must run as root (use the fedora:45 container shown above)" >&2
    exit 1
fi

if [[ ! -f $lock ]]; then
    echo "missing lock file: $lock" >&2
    exit 1
fi

echo "==> installing build tooling"
dnf install -y --setopt=install_weak_deps=False \
    createrepo_c dnf-plugins-core git gzip jq python3-pyyaml \
    redhat-rpm-config rpmautospec rpm-build rpmdevtools spectool tar xz zstd

export HOME=$work/home
mkdir -p "$HOME"
rpmdev-setuptree
topdir=$HOME/rpmbuild

build_id=$(python3 - "$lock" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest()[:12])
PY
)
echo "==> lock build id: $build_id"

# Emit one shell-quoted record per package, in build order.
# Fields: name, rpm, version, spec, spec_sha256, local_paths..., sources...
python3 - "$lock" "$here" >"$work/plan.json" <<'PY'
import hashlib, json, os, sys, yaml

lock_path, root = sys.argv[1], sys.argv[2]
with open(lock_path, encoding='utf-8') as fh:
    lock = yaml.safe_load(fh)

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

plan = []
for pkg in lock['packages']:
    spec = os.path.join(root, pkg['spec'])
    if not os.path.exists(spec):
        sys.exit(f"missing spec: {spec}")
    actual = sha256(spec)
    if actual != pkg['spec_sha256']:
        sys.exit(
            f"spec hash mismatch for {pkg['name']}:\n"
            f"  lock: {pkg['spec_sha256']}\n"
            f"  file: {actual}\n"
            "run packages/hyprland/update-lock.sh after editing a spec"
        )

    local = []
    for item in pkg.get('local', []):
        path = os.path.join(root, item['path'])
        if not os.path.exists(path):
            sys.exit(f"missing local file: {path}")
        actual = sha256(path)
        if actual != item['sha256']:
            sys.exit(f"hash mismatch for {path}: lock={item['sha256']} file={actual}")
        local.append({'path': path, 'name': os.path.basename(path)})

    sources = []
    for item in pkg['sources']:
        sources.append({
            'name': item['name'],
            'url': item['url'],
            'sha256': item['sha256'],
        })

    plan.append({
        'name': pkg['name'],
        'rpm': pkg['rpm'],
        'version': pkg['version'],
        'spec': spec,
        'local': local,
        'sources': sources,
    })

json.dump(plan, sys.stdout)
PY

mkdir -p "$out"
# Start from a clean tree: a stale .complete next to partial output would make
# the CI cache look valid after a failed local build.
rm -rf "$out"
mkdir -p "$out"

package_count=$(jq length "$work/plan.json")
index=0

while [[ $index -lt $package_count ]]; do
    pkg_name=$(jq -r ".[$index].name" "$work/plan.json")
    spec=$(jq -r ".[$index].spec" "$work/plan.json")
    index=$((index + 1))

    echo "==> [$index/$package_count] $pkg_name"

    # Stage the spec and any local sources (patches, macros).
    cp -f "$spec" "$topdir/SPECS/"
    while IFS=$'\t' read -r src_name src_path; do
        [[ -n $src_name ]] || continue
        cp -f "$src_path" "$topdir/SOURCES/$src_name"
    done < <(jq -r ".[$index-1].local[] | [.name, .path] | @tsv" "$work/plan.json")

    # Fetch and verify upstream sources.
    while IFS=$'\t' read -r src_name src_url src_sha; do
        [[ -n $src_name ]] || continue
        dest=$topdir/SOURCES/$src_name
        if [[ ! -f $dest ]]; then
            tmp=$work/$src_name.part
            echo "    fetching $src_name"
            curl -fL --retry 5 --retry-delay 2 --connect-timeout 30 -o "$tmp" "$src_url"
            mv "$tmp" "$dest"
        fi
        actual=$(sha256sum "$dest" | cut -d' ' -f1)
        if [[ $actual != "$src_sha" ]]; then
            echo "sha256 mismatch for $src_name" >&2
            echo "  lock: $src_sha" >&2
            echo "  file: $actual" >&2
            exit 1
        fi
    done < <(jq -r ".[$index-1].sources[] | [.name, .url, .sha256] | @tsv" "$work/plan.json")

    # Resolve BuildRequires against Fedora plus everything built so far.
    dnf builddep -y --setopt=install_weak_deps=False "$topdir/SPECS/$(basename "$spec")"

    rpmbuild -bb --define "_topdir $topdir" "$topdir/SPECS/$(basename "$spec")"

    # Make the just-built libs/devel packages visible to later builddeps.
    # hyprland-git-uwsm is skipped: it hard-Requires uwsm, which Fedora 45 does
    # not package, and the image does not use uwsm.
    mapfile -t built < <(find "$topdir/RPMS" -name '*.rpm' \
        ! -name '*-debuginfo-*' ! -name '*-debugsource-*' ! -name 'hyprland-git-uwsm-*' | sort)
    if [[ ${#built[@]} -eq 0 ]]; then
        echo "no RPMs produced for $pkg_name" >&2
        exit 1
    fi
    dnf install -y --nogpgcheck --setopt=install_weak_deps=False "${built[@]}"

    # Keep runtime packages for the image repo; devel/debug stay in the
    # disposable build root only. hyprland-git-uwsm is excluded: it would pull
    # uwsm (not packaged in F45) through hyprland-git's Recommends.
    find "$topdir/RPMS" -name '*.rpm' \
        ! -name '*-debuginfo-*' ! -name '*-debugsource-*' ! -name '*-devel-*' \
        ! -name 'hyprland-git-uwsm-*' \
        -exec cp -f {} "$out/" \;

    rm -rf "$topdir/BUILD" "$topdir/BUILDROOT" "$topdir/RPMS" \
        "$topdir/SRPMS" "$topdir/SOURCES"/*.tar.gz "$topdir/SOURCES"/*.tar.xz
done

echo "==> indexing local repo"
createrepo_c --quiet "$out"

# Marker used by the workflow: an out/ without it is treated as an incomplete
# cache entry and rebuilt.
{
    printf 'build_id=%s\n' "$build_id"
    printf 'fedora=45\n'
    printf 'packages=%s\n' "$package_count"
} >"$out/.complete"

echo "==> done: $(find "$out" -name '*.rpm' | wc -l) RPMs in $out"
ls -1 "$out"/*.rpm