# fedora-hyprtomic &nbsp; [![bluebuild build badge](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml)

A personal Fedora Atomic (wayblue) desktop image built around **DMS (Dux
Modular Shell)**, with the GUI stack running natively on the host instead of in
an Arch distrobox container.

- **Host** — Fedora Atomic base, Hyprland/SDDM, DMS + quickshell, fcitx5 +
  Mozkey IbG, dfiles, native Mission Center, and a JIS-patched Sunshine build.
- **SKEL** — environment defaults baked into `/etc/skel` and synced into
  `$HOME` with `ujust sync-skel-config`.
- **USR** — the user's own git repository, symlinked into `$HOME` with
  `ujust user-config-apply` (see `docs/design/`).
- **HOST** — machine-specific rpm-ostree state (layered packages, kargs, COPRs)
  in a separate manifest, applied with `ujust machine-apply`.

The Arch GUI container has been removed: Hyprland, DMS, the IME, the file
manager and the streaming stack all run on the Fedora Atomic host.

## Repository layout

| Path | Purpose |
|---|---|
| `recipes/recipe.yml` | Host image (packages, COPRs, firstboot services, default flatpaks) |
| `files/system/**` | Files copied to `/` (skel, systemd units, PAM, SDDM theme overlay, ujust) |
| `files/scripts/**` | Build-time scripts (Mozkey RPM, Sunshine source build, SDDM theme, finalize) |
| `scripts/check.sh` | Linux/WSL checks that do not need a container build |
| `docs/design/**` | Layer/design decisions (tracked) |
| `AGENTS.md` | Architecture notes, conventions and change rules |

## Installation

> [!WARNING]
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/j7b3y/fedora-hyprtomic:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/j7b3y/fedora-hyprtomic:latest
  ```
- Reboot again to complete the installation.

## First boot

```bash
ujust sync-skel-config                # copy /etc/skel into $HOME (skips existing files)
ujust overwrite=1 sync-skel-config    # replace managed files, prune removed ones, then re-login
```

The SKEL layer never touches files owned by the user repository
(`~/.config/hypr/user.lua`, `workspaces.lua`, `host.lua`, `local.conf`, and
anything under `~/.config/hyprtomic-user/home/`).

## User configuration (USR)

```bash
ujust user-config-init                # create ~/.config/hyprtomic-user (git repo)
ujust user-config-apply               # symlink home/ into $HOME
ujust user-config-status              # check for drift
ujust prune=1 user-config-apply       # drop links the repository removed
ujust user-config-update              # git pull --ff-only, then apply
```

## Machine state (HOST)

The rpm-ostree layer lives in a separate manifest
(`~/.config/hyprtomic-machine/machine.json`):

```bash
ujust machine-init                    # create an empty manifest (git init)
ujust machine-export                  # seed it from this machine
ujust machine-apply                   # COPRs, packages, kargs, Flatpaks, user units
ujust dry_run=1 machine-apply         # preview
```

Packages and kernel arguments are only ever **added**; removal stays manual.

## Sunshine streaming

Sunshine is built from the pinned upstream release with the JIS key patches and
is started manually (it is not enabled at login):

```bash
sunshine-session start                # HEADLESS-1 1080p60 + Sunshine unit
sunshine-session status
sunshine-session stop                 # stop and restore DMS' monitor layout
```

The streaming layout lives in `~/.config/hypr/sunshine.lua`; machine-specific
rules belong in `~/.config/hypr/host.lua`.

## Distrobox integration

GUI apps installed inside a distrobox are registered with the host launcher
(DMS) automatically:

- `hyprtomic-distrobox-apps.service` polls running containers every 15 seconds.
  When the set of visible `.desktop` files changes (package installed/removed,
  entry hidden, app deleted), it re-exports the entries and removes stale ones.
  Stopped containers keep their entries, so they can still be launched on
  demand. Only files marked `X-HyprTomic-Container=<name>` are pruned.
- `ujust refresh-distrobox-apps` triggers a scan immediately.
- `ujust distrobox-app-hooks <container>` installs an apt/pacman/apk hook for
  instant refresh after a package transaction (dnf is covered by the watcher).
- `ujust distrobox-host-dbus <container>` (or `all`) points the container at the
  host system bus via `/run/host/run/dbus/system_bus_socket`. This is required
  for Bluetooth passkeys in containerised Chrome and for `bluetoothctl`/`nmcli`
  inside the container. Running apps must be restarted afterwards.

## Audio

PipeWire/WirePlumber defaults follow the nixos-dotfiles tuning: 48 kHz clock
with a 2048-sample quantum, no suspend timeout on hardware sinks, and USB audio
power saving disabled. On `main-desktop` the HDMI-1/LG TV sink can become the
default when a display is hot-plugged; if that output has no speakers, pick the
intended one with `pactl list short sinks` and
`ujust audio-default-sink <name>` (e.g. the S-W4 USB sink or a Bluetooth
headset).

## Ghostty

The shipped config sets `mouse-reporting = false` so right-click always stays
local to Ghostty: even inside mouse-capturing TUIs (OpenCode, vim, lazygit) it
opens the terminal's native context menu instead of being consumed by the app
(which only partially selects the line). This also keeps it from competing with
DMS's desktop right-click handler. `mouse-shift-capture = never` additionally
prevents a TUI from overriding shift-selection via `XTSHIFTESCAPE`. For TUIs
that genuinely need the mouse, `Ctrl+Shift+M` toggles reporting back on for the
current surface; press again to restore the default.

As defence in depth, the USR scaffold also ships `home/.config/opencode/cli.json`
with `"mouse": false`, so OpenCode does not request mouse capture in the first
place. OpenCode hot-reloads this file while running.

## Checks

```bash
bash scripts/check.sh                 # CRLF, YAML, shellcheck, Python, Lua, just
```

The same script runs in the `lint` GitHub Actions workflow.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s
[cosign](https://github.com/sigstore/cosign). Download `cosign.pub` from this repo
and run:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
```
