#!/usr/bin/env bash
#
# Refresh the sha256 fields in lock.yml after a version/spec change.
#
# This never guesses new versions: edit lock.yml first (bump "version", the
# source "url"/"name", and the vendored spec), then run this script to pin the
# new artifacts. Run it on a machine with PyYAML (or in the fedora:45 build
# container) because the lock is YAML.
#
#   packages/hyprland/update-lock.sh
#
# Re-running with unchanged inputs is a no-op apart from rewriting the hashes.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lock=${LOCK:-$here/lock.yml}
cache=${HYPRLAND_SOURCE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/hyprtomic/hyprland-sources}

mkdir -p "$cache"

python3 - "$lock" "$here" "$cache" <<'PY'
import hashlib
import os
import re
import sys
import urllib.request

import yaml

lock_path, root, cache = sys.argv[1], sys.argv[2], sys.argv[3]

with open(lock_path, encoding='utf-8') as fh:
    lock = yaml.safe_load(fh)

lines = open(lock_path, encoding='utf-8').read().splitlines(keepends=True)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def fetch(url, name):
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        tmp = path + '.part'
        print(f'  fetching {name}')
        urllib.request.urlretrieve(url, tmp)
        os.replace(tmp, path)
    return sha256_file(path)


def replace_sha_after(block_start, marker, new_sha):
    """Replace the first sha256: line after `marker` within this block."""
    for i in range(block_start, len(lines)):
        text = lines[i]
        if i > block_start and re.match(r'^  - name: ', text):
            break
        if marker in text:
            if re.match(r'^\s+spec_sha256: [0-9a-f]{64}\s*$', text):
                indent = re.match(r'^(\s+)', text).group(1)
                lines[i] = f'{indent}spec_sha256: {new_sha}\n'
                return True
            for j in range(i + 1, len(lines)):
                if re.match(r'^\s+sha256: [0-9a-f]{64}\s*$', lines[j]):
                    indent = re.match(r'^(\s+)', lines[j]).group(1)
                    lines[j] = f'{indent}sha256: {new_sha}\n'
                    return True
                if re.match(r'^\s+- (name|path):', lines[j]):
                    break
            break
    return False


# Locate each package block by its "- name:" marker. There is exactly one
# package block per name, and source/local entries nest below it.
for pkg in lock['packages']:
    start = None
    for i, text in enumerate(lines):
        if re.match(rf'^  - name: {re.escape(pkg["name"])}\s*$', text):
            start = i
            break
    if start is None:
        sys.exit(f'cannot find package block for {pkg["name"]} in {lock_path}')

    spec_path = os.path.join(root, pkg['spec'])
    new_spec_sha = sha256_file(spec_path)
    if not replace_sha_after(start, 'spec_sha256:', new_spec_sha):
        sys.exit(f'cannot find spec_sha256 for {pkg["name"]}')
    if new_spec_sha != pkg['spec_sha256']:
        print(f'{pkg["name"]}: spec {pkg["spec_sha256"][:12]} -> {new_spec_sha[:12]}')

    for item in pkg.get('local', []):
        path = os.path.join(root, item['path'])
        new_sha = sha256_file(path)
        if not replace_sha_after(start, f'path: {item["path"]}', new_sha):
            sys.exit(f'cannot find local entry {item["path"]} for {pkg["name"]}')
        if new_sha != item['sha256']:
            print(f'{pkg["name"]}: local {item["path"]} {item["sha256"][:12]} -> {new_sha[:12]}')

    for item in pkg['sources']:
        new_sha = fetch(item['url'], item['name'])
        if not replace_sha_after(start, f'name: {item["name"]}', new_sha):
            sys.exit(f'cannot find source entry {item["name"]} for {pkg["name"]}')
        if new_sha != item['sha256']:
            print(f'{pkg["name"]}: source {item["name"]} {item["sha256"][:12]} -> {new_sha[:12]}')

with open(lock_path, 'w', encoding='utf-8') as fh:
    fh.writelines(lines)
print(f'updated {lock_path}')
PY