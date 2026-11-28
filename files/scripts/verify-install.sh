#!/usr/bin/env bash
# Fail the image build loudly if a component the desktop depends on was
# silently skipped by dnf's skip-unavailable (COPR churn, renamed package,
# a missing self-built RPM, ...). A missing compositor must never produce a
# "successful" image.
set -oue pipefail

missing=()

require_pkg() {
    rpm -q "$1" >/dev/null 2>&1 || missing+=("package:$1")
}

require_file() {
    [[ -e $1 ]] || missing+=("file:$1")
}

# Self-built Hyprland stack (packages/hyprland).
require_pkg hyprland-git
require_pkg hyprlock
require_pkg hypridle
require_pkg hyprpolkitagent
require_pkg hyprland-qt-support
require_pkg xdg-desktop-portal-hyprland
require_file /usr/share/wayland-sessions/hyprland.desktop
require_file /usr/share/xdg-desktop-portal/portals/hyprland.portal

# Display manager (base-atomic ships none).
require_pkg sddm
require_pkg sddm-themes
require_pkg sddm-wayland-generic
require_pkg weston # greeter display server (no Xorg in the image)
require_file /usr/lib/systemd/system/sddm.service
# The recipe's systemd module (which runs after this script) enables the unit;
# `systemctl enable` itself fails the build if the unit is missing.

# Shell / launcher / IME.
require_pkg dms
require_pkg quickshell
require_pkg fcitx5
require_file /usr/lib64/fcitx5/sweetime.so
require_file /usr/lib64/fcitx5/sweetui.so
require_file /usr/share/fcitx5/inputmethod/sweetime.conf
require_file /usr/share/sweet-ime/system.dict
require_file /usr/bin/sweet-zenz-pack
require_file /usr/share/sweet-ime/get-zenz.sh
require_file /usr/bin/sweet-settings
require_pkg ublue-os-just
require_file /usr/share/ublue-os/just/60-custom.just

# Streaming host (JIS-patched source build).
require_file /usr/bin/sunshine

# Xwayland path used by the compositor and DMS.
require_pkg xwayland-satellite

if ((${#missing[@]})); then
    printf 'verify-install: missing required component(s):\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

echo "verify-install: desktop components present"
