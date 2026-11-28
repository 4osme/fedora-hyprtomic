# Self-built Hyprland RPMs

Fedora 45 does not provide the Hyprland stack this image needs. `lock.yml`
pins every source tarball and every vendored spec; `build.sh` builds the RPM
set and a local repository that the image installs from.

## Layout

| Path | Purpose |
|---|---|
| `lock.yml` | Lock file: spec origin commit, versions, source URLs + SHA256, build order |
| `build.sh` | Verify lock, fetch sources, `rpmbuild` in order, `createrepo_c` |
| `update-lock.sh` | Rewrite the SHA256 fields after bumping versions/specs |
| `specs/<name>/` | Vendored `.spec` files and patches (from wayblue's `hyprlandRPM`) |
| `out/` | Build output (gitignored): RPMs + `repodata/` + `.complete` |

## Building

The build must run inside Fedora 45: the specs use `%autorelease`,
`%autochangelog` and Fedora macros, and the binary RPMS must match the image's
glibc.

```bash
podman run --rm -v "$PWD:/work:Z" -w /work fedora:45 \
  bash packages/hyprland/build.sh
```

The script installs `rpm-build`/`rpmautospec` tooling plus the build deps of
each spec, then produces `out/`. `out/.complete` records the `lock.yml` sha256
so a cache restore that does not match the lock is discarded instead of used.

### Local image build

`files/` is bind-mounted at `/tmp/files` while BlueBuild runs the dnf module,
so the RPMs are installed but never committed to an image layer. To build the
image locally:

```bash
rm -rf files/dnf/hyprland-rpms
cp -a packages/hyprland/out files/dnf/hyprland-rpms
```

`files/dnf/hyprland-local.repo` points dnf at `file:///tmp/files/dnf/hyprland-rpms`.

## CI

The `hyprland-rpms` job in `.github/workflows/build.yml` runs in `fedora:45`
and caches `out/` under a key derived from `lock.yml`, `build.sh` and
`specs/**`. On a miss it rebuilds; either way it uploads the RPMs and the image
job downloads them into `files/dnf/hyprland-rpms/`. The base image contains no
third-party COPR repository for this stack.

## Updating a package

1. Edit the package's `version`, source `url`/`name` and the vendored spec
   (and patch set) in `lock.yml` / `specs/`.
2. Run `packages/hyprland/update-lock.sh` (needs PyYAML; run it in the
   `fedora:45` container if the host lacks it). It downloads new sources into
   `~/.cache/hyprtomic/hyprland-sources` and rewrites the hashes in place.
3. Rebuild. A failing compile usually means the other packages need the same
   upstream commit set (Hyprland's libraries are released in lockstep).

`hyprland` is built from a git snapshot as `hyprland-git`, which `Provides` and
`Conflicts: hyprland`, matching the wayblue packaging.