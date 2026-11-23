#!/usr/bin/env bash
# Repository checks that do not need a container build.
#
# Run from WSL/Linux (or CI) before pushing:
#   bash scripts/check.sh
#
# This catches YAML/Lua/Python/shell syntax errors and CRLF in the files that
# are executed inside the image (shell scripts, patch files, skel helpers).
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

fail=0
warn() { echo "WARN  $*" >&2; }
err() { echo "FAIL  $*" >&2; fail=1; }

echo "==> CRLF check (scripts and patches must be LF)"
crlf_targets=(
    files/scripts
    files/system/usr/libexec/hyprtomic
    files/system/etc/skel/.local/bin
    files/system/etc/skel/.config/sunshine
    files/system/usr/share/hyprtomic/sunshine/patches
)
for target in "${crlf_targets[@]}"; do
    [ -e "$target" ] || continue
    if grep -rIl $'\r' "$target" >/dev/null 2>&1; then
        err "CRLF found under $target"
        grep -rIl $'\r' "$target" >&2 || true
    fi
done

echo "==> YAML"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
    python3 - <<'PY'
import sys
import yaml

for path in ("recipes/recipe.yml",):
    with open(path, encoding="utf-8") as handle:
        yaml.safe_load(handle)
    print(f"ok    {path}")
PY
    [ $? -eq 0 ] || fail=1
else
    warn "python3 + PyYAML not available; skipping YAML"
fi

echo "==> shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning -s bash files/scripts/*.sh || fail=1
    shellcheck -S warning -s bash \
        files/system/usr/libexec/hyprtomic/user-config \
        files/system/usr/libexec/hyprtomic/machine-config \
        files/system/usr/libexec/hyprtomic/seed-dms-wallpaper || fail=1
    shellcheck -S warning -s bash \
        files/system/usr/libexec/hyprtomic/setup-*.sh || fail=1
    shellcheck -S warning -s sh \
        files/system/usr/libexec/hyprtomic/pam-fingerprint-gate || fail=1
else
    warn "shellcheck not installed; skipping"
fi

echo "==> Python syntax"
if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import pathlib
import sys

paths = [
    pathlib.Path("files/system/etc/skel/.config/sunshine/hypr-stream-display.py"),
    pathlib.Path("files/system/etc/skel/.local/bin/sunshine-session"),
]
failed = False
for path in paths:
    try:
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
        print(f"ok    {path}")
    except SyntaxError as error:
        print(f"FAIL  {path}: {error}", file=sys.stderr)
        failed = True
sys.exit(1 if failed else 0)
PY
    [ $? -eq 0 ] || fail=1
else
    warn "python3 not available; skipping Python syntax"
fi

echo "==> Lua syntax"
luac_bin=""
for candidate in luac luac5.4 luac5.3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        luac_bin="$candidate"
        break
    fi
done
if [ -n "$luac_bin" ]; then
    while IFS= read -r file; do
        "$luac_bin" -p "$file" || fail=1
        echo "ok    $file"
    done < <(find files/system/etc/skel/.config/hypr -name '*.lua' -type f)
else
    warn "luac not installed; skipping Lua"
fi

echo "==> justfile"
if command -v just >/dev/null 2>&1; then
    # Parse the file with `--list`; `--fmt --check` output differs between just
    # versions, so formatting stays a local/CI-editor concern.
    just --unstable \
        --justfile files/system/usr/share/ublue-os/just/60-custom.just \
        --list >/dev/null || fail=1
    echo "ok    60-custom.just"
else
    warn "just not installed; skipping justfile"
fi

if [ "$fail" -ne 0 ]; then
    echo
    echo "checks failed" >&2
    exit 1
fi

echo
echo "all checks passed"
