#!/usr/bin/env bash
set -euo pipefail

version=v0.9.1
archive=SweetIME-Linux-x86_64.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

curl -fsSL --retry 3 -o "$archive" \
    "https://github.com/frost-1256/sweet-ime/releases/download/$version/$archive"
echo "e747c5e2060a9e1e623525679c780eb6f8ebc00a6ab0ecebd5272068e533368c  $archive" | sha256sum -c -
tar -xzf "$archive"
bash sweet-ime-linux-x86_64/install.sh --prefix /usr --addon-dir /usr/lib64/fcitx5
