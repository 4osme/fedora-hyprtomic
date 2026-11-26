# Third-party notices / 引用元クレジット

This image adapts work from other projects. Each retains its own license.

## Design references

| Source | License | Used for |
|---|---|---|
| [oameye/atomic-hyprland](https://github.com/oameye/atomic-hyprland) | (per upstream repo) | The `sync-skel-config` ujust design (`/etc/skel` + rsync, `overwrite=1` manifest replace & prune) in `files/system/usr/share/ublue-os/just/60-custom.just` |

## Packages installed from Fedora / COPR

These are installed as RPMs by `recipes/recipe.yml`; all rights remain with the
upstream authors. See the package metadata for the exact license of each.

| Source | License | Used for |
|---|---|---|
| [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) | GPL-3.0 | SDDM login theme (pinned revision + HyprTomic overlay) |
| [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) + HyprTomic JIS patches | GPL-3.0-or-later (Sunshine), MIT (libvirtualhid backend) | game streaming host, built from source with the JIS key patches |
| [Dux Modular Shell](https://github.com/duxlabs-dev/dux-shell) (`duxlabs/dms`, `duxlabs/dux-repo`) | MIT | shell, quickshell, matugen, dgop, dsearch, dcal, dfiles |
| [Mozkey IbG](https://github.com/kazormia296/mozkey-ibg) (Fedora RPM) | BSD-3-Clause AND Apache-2.0 AND LGPL-2.1-or-later AND MIT | Japanese IME engine (fcitx5) |
| ghostty (`duxlabs/dux-repo`) | per upstream | terminal |
| Bibata cursor theme, JetBrains Mono NF fonts (`ririko66z/dots-hyprland`) | per upstream | cursor / terminal font |
| Papirus, adw-gtk3, Noto, Roboto and the remaining Fedora packages | per upstream | desktop foundation |

## Dotfiles vendored into `/etc/skel`

| Path in `/etc/skel` | Source | License |
|---|---|---|
| `.config/hypr/` (hyprland.lua, hyprlock, hypridle, quadgrid.lua, scripts) | the user's own dotfiles | none (self-authored) |
| `.local/share/backgrounds/wallpaper.jpg` | personal asset | none (personal) |
| `.config/gtk-3.0/gtk.css`, `.config/gtk-4.0/gtk.css` | adapted from the previous matugen GTK templates | per the original matugen upstream |

## Build-time references

- [BlueBuild](https://blue-build.org/) image pipeline & [ublue-os](https://universal-blue.org/) just/system plumbing
- [wayblueorg/hyprlandRPM](https://github.com/wayblueorg/hyprlandRPM) — spec files vendored under `packages/hyprland/specs/` for the self-built Hyprland RPMs
- The Hyprland stack sources pinned in `packages/hyprland/lock.yml` retain their upstream licenses (BSD-3-Clause for Hyprland and its libraries, MIT for glaze, and so on); see each spec's `License:` field
