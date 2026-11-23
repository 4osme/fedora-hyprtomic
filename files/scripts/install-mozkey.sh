#!/usr/bin/env bash
# Install Mozkey IbG (Mozc-based fcitx5 Japanese IME) from the upstream Fedora
# RPM.
#
# Mozkey is not packaged in Fedora and there is no COPR for it. Upstream builds
# an x86_64 RPM for Fedora on every release, containing the Fcitx5 frontend and
# the bundled Zenz runtime (llama-server + GGUF model), so this downloads a
# pinned release and verifies it against a checksum we recorded from the
# release's SHA256SUMS.
#
# Updating: bump `version` and `sha256` together. The release is marked
# pre-release upstream (Mozkey only ships experimental builds right now).
set -oue pipefail

version="0.11.0"
sha256="7c453fd2a210fab913936bd66fad6ea1df348d3f08c67f8ae9a34ce7733e5d53"

rpm="mozkey-ibg-${version}-1.x86_64.rpm"
base="https://github.com/kazormia296/mozkey-ibg/releases/download/v${version}"

work="$(mktemp -d /var/tmp/mozkey.XXXXXX)"
trap 'rm -rf "$work"' EXIT

echo "==> Mozkey IbG: fetching ${rpm}"
curl -fsSL --retry 3 -o "${work}/${rpm}" "${base}/${rpm}"
printf '%s  %s\n' "${sha256}" "${rpm}" >"${work}/${rpm}.sha256"
( cd "${work}" && sha256sum -c "${rpm}.sha256" )

echo "==> Mozkey IbG: installing"
dnf install -y "${work}/${rpm}"

rm -f "${work}/${rpm}" "${work}/${rpm}.sha256"
echo "==> Mozkey IbG: done"
