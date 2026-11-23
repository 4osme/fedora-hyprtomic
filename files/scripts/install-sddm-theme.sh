#!/usr/bin/env bash
# Install the sddm-astronaut theme at a pinned upstream revision, with the
# HyprTomic overlay (custom palette, login wallpaper, fingerprint status line).
set -oue pipefail

rev="abb3163c724935af888ba5ea9ac0c4f22afd8048"
sha256="3e7ccde7158b336bb7ea6c69a18cefe27a9c82d6c04c4bef03b5b1519d6ae11c"
url="https://github.com/Keyitdev/sddm-astronaut-theme/archive/${rev}.tar.gz"

theme=/usr/share/sddm/themes/sddm-astronaut-theme
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> SDDM theme: fetching ${rev}"
curl -fsSL --retry 3 -o "$tmp/theme.tar.gz" "$url"
printf '%s  %s\n' "$sha256" "$tmp/theme.tar.gz" | sha256sum -c -
tar -xzf "$tmp/theme.tar.gz" -C "$tmp"

srcdir="$tmp/sddm-astronaut-theme-${rev}"
[ -d "$srcdir" ] || srcdir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -n1)"

echo "==> SDDM theme: installing"
rm -rf "$theme"
mkdir -p "$theme"
cp -a "$srcdir/." "$theme/"

# HyprTomic overlay. theme.conf goes to Themes/custom.conf because the upstream
# metadata.desktop selects that path; the two Components files add the
# fingerprint status line to the login form.
install -Dm644 /usr/share/hyprtomic/sddm/theme.conf "$theme/Themes/custom.conf"
sed -i 's|^ConfigFile=.*|ConfigFile=Themes/custom.conf|' "$theme/metadata.desktop"
install -Dm644 /usr/share/hyprtomic/sddm/Components/FingerprintStatus.qml \
    "$theme/Components/FingerprintStatus.qml"
install -Dm644 /usr/share/hyprtomic/sddm/Components/LoginForm.qml \
    "$theme/Components/LoginForm.qml"

# Default wallpaper: theme.conf references Backgrounds/wallpaper.jpg.
install -Dm644 /usr/share/hyprtomic/sddm/wallpaper.jpg \
    "$theme/Backgrounds/wallpaper.jpg"

systemctl enable sddm
