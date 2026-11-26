#!/usr/bin/env bash
set -oue pipefail
chmod +x /usr/libexec/hyprtomic/setup-zsh.sh
chmod +x /usr/libexec/hyprtomic/setup-groups.sh
chmod +x /usr/libexec/hyprtomic/user-config
chmod +x /usr/libexec/hyprtomic/machine-config
chmod +x /usr/libexec/hyprtomic/seed-dms-wallpaper
chmod +x /usr/libexec/hyprtomic/pam-fingerprint-gate
chmod +x /usr/libexec/hyprtomic/distrobox-apps
chmod +x /usr/libexec/hyprtomic/distrobox-app-hooks
chmod +x /usr/libexec/hyprtomic/distrobox-host-dbus
# skel helpers invoked directly by the user / Hyprland
chmod +x /etc/skel/.local/bin/sunshine-session
chmod +x /etc/skel/.config/sunshine/hypr-stream-display.py
# Legacy: wayblue baked its own hyprland.conf into /etc/skel. HyprTomic
# dotfiles bring their own (lua) config, so drop any stale file from images
# built on the old base to avoid ambiguity.
rm -f /etc/skel/.config/hypr/hyprland.conf

# DMS must start inside the compositor session, not at login: dms.service has
# Requisite=graphical-session.target. Bind it to hyprland-session.target, which
# Hyprland >= 0.57 ships and starts after exporting the environment (the skel
# config also starts the target, so older Hyprland works too).
if [ -f /usr/lib/systemd/user/dms.service ]; then
  install -d /usr/lib/systemd/user/hyprland-session.target.wants
  ln -sf /usr/lib/systemd/user/dms.service \
    /usr/lib/systemd/user/hyprland-session.target.wants/dms.service
else
  echo "finalize: dms.service not found, skipping hyprland-session.target binding" >&2
fi
# compile the baked dconf system db (files/etc/dconf/db/hyprtomic.d)
dconf update
