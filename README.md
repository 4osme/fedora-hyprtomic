# fedora-hyprtomic &nbsp; [![bluebuild build badge](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml)

A personal Fedora Atomic desktop image built around **DMS (Dux Modular
Shell)**, with the GUI stack running natively on the host instead of in an Arch
distrobox container. It builds on the official minimal
`quay.io/fedora-ostree-desktops/base-atomic:45` instead of wayblue, so the
Hyprland stack is compiled from pinned sources in this repository.

- **Host** — Fedora Atomic base, self-built Hyprland/SDDM, DMS + quickshell,
  fcitx5 + Sweet IME, dfiles, native Mission Center, and a JIS-patched
  Sunshine build.
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
| `packages/hyprland/**` | Pinned Hyprland stack sources, specs and `build.sh` (see below) |
| `files/system/**` | Files copied to `/` (skel, systemd units, PAM, SDDM theme overlay, ujust) |
| `files/scripts/**` | Build-time scripts (Sweet IME, Sunshine source build, SDDM theme, finalize) |
| `files/dnf/**` | COPR repo files; `hyprland-rpms/` is populated by CI (gitignored) |
| `scripts/check.sh` | Linux/WSL checks that do not need a container build |
| `docs/design/**` | Layer/design decisions (tracked) |
| `AGENTS.md` | Architecture notes, conventions and change rules |

## Hyprland stack (self-built)

Fedora 45 does not ship a usable Hyprland stack: `hyprutils`, `hyprgraphics`,
`hyprlang` and `hyprcursor` are too old, and `aquamarine`, `hyprwire`,
`hyprtoolkit`, `xdg-desktop-portal-hyprland` and `hyprpolkitagent` are missing
entirely. `packages/hyprland/` therefore vendors the wayblue specs and pins
every source URL and SHA256 in `lock.yml`.

`build.sh` verifies the lock, fetches the sources, runs `rpmbuild` in dependency
order and creates a local RPM repository in `packages/hyprland/out/`. The image
installs from that repository through `files/dnf/hyprland-local.repo`;
`files/` is bind-mounted (not copied) during the build, so the RPMs never
become an image layer.

The `hyprland-rpms` CI job restores a cache keyed on `lock.yml`, `build.sh` and
`specs/**`, rebuilds only on a miss, and uploads the RPMs as an artifact for
the image job. To build locally:

```bash
podman run --rm -v "$PWD:/work:Z" -w /work fedora:45 bash packages/hyprland/build.sh
rm -rf files/dnf/hyprland-rpms
cp -a packages/hyprland/out files/dnf/hyprland-rpms
```

To bump a package, edit its entry and vendored spec, then run
`packages/hyprland/update-lock.sh` to refresh the hashes.

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
files registered in `~/.config/hyprtomic-user/home/`).

## User configuration (USR)

```bash
ujust user-config-init                # create ~/.config/hyprtomic-user (git repo)
ujust user-config-register ~/.config/hypr/user.lua  # copy and git add an existing file
ujust user-config-apply               # link tracked regular files under home/{.config,.local}
ujust user-config-status              # check for drift
ujust prune=1 user-config-apply       # drop links the repository removed
ujust user-config-update              # git pull --ff-only, then apply
```

### Wayland input methods

Sweet IME works with its system dictionary out of the box. To enable neural
conversion, open **Sweet IME Settings** (`sweet-settings`) and download a
model for your user account. When upgrading from Mozkey, replace its entry
with Sweet IME (`sweetime`) in `fcitx5-configtool`.

Hyprland prefers the Wayland backend for Qt and leaves Qt and GTK free to
select their native input contexts. X11 clients can use `XMODIFIERS=@im=fcitx`.
The session exports its environment before starting the DMS target so tray
actions and launcher entries inherit the same defaults as terminal commands.
After updating an existing `hyprland.lua`, log out and back in: reloading the
compositor does not change the environment of running applications.

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
  It also routes `xdg-open` in that box through the host. To select Chrome
  from a box named `work`, run `xdg-settings set default-web-browser
  work-google-chrome.desktop` on the host after the first refresh. Use
  `xdg-mime query default x-scheme-handler/https` to check the association.
- `ujust distrobox-host-dbus <container>` (or `all`) points the container at the
  host system bus via `/run/host/run/dbus/system_bus_socket`. This is required
  for Bluetooth passkeys in containerised Chrome and for `bluetoothctl`/`nmcli`
  inside the container. Running apps must be restarted afterwards.

### Zsh completion and suggestions

The shipped `.zshrc` supports Antidote for completions, history suggestions,
and syntax highlighting on both the host and Distrobox. Without Antidote it
falls back to the Fedora plugins where available.

After updating the image, back up any custom `~/.zshrc` and copy the two Zsh
files from `/etc/skel` (or merge the changes if you manage them yourself).
Install Antidote once per home directory; a Distrobox that shares the host's
home does not need its own copy. A container with a separate home needs the
two files and Antidote in that home.

```bash
cp /etc/skel/.zshrc /etc/skel/.zsh_plugins.txt "$HOME/"
git clone --depth=1 https://github.com/mattmc3/antidote.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
```

Open a new Zsh session. The first Antidote load downloads the listed plugins
with Git. Completion caches are kept separate for each container and Zsh
version.

## Audio

Chrome in a minimal Arch distrobox needs `libpulse` inside the container to
connect to the host's PipeWire PulseAudio socket. The Arch `google-chrome`
package does not pull it in. From the host, install the client library and
check the connection (replace `application` with your container name):

```bash
distrobox enter -n application -- sudo pacman -S --needed libpulse
distrobox enter -n application -- pactl info
```

`pactl info` should report `PulseAudio (on PipeWire …)`. Fully quit Chrome
(including any background processes), then reopen it. Do not start a separate
PulseAudio or PipeWire server inside the container.

PipeWire/WirePlumber defaults follow the nixos-dotfiles tuning: 48 kHz clock
with a 2048-sample quantum, no suspend timeout on hardware sinks, and USB audio
power saving disabled. On `main-desktop` the HDMI-1/LG TV sink can become the
default when a display is hot-plugged; if that output has no speakers, pick the
intended one with `pactl list short sinks` and
`ujust audio-default-sink <name>` (e.g. the S-W4 USB sink or a Bluetooth
headset).

## Flatpak fonts

Flatpak 1.18 and newer expose the host fonts to a sandbox only through
`/run/host/font-dirs.xml`, whose `<remap-dir>` entries point at the host font
directories plus the caches the host fontconfig wrote for them (mounted
read-only at `/run/host/fonts-cache`). Chromium and Electron apps ship their
own fontconfig with a different cache format, so it finds no usable cache
there and the host fonts stay invisible: Latin still renders from the
runtime's own fonts, but CJK text becomes tofu.

`/usr/libexec/hyprtomic/flatpak-fonts` writes a per-app
`~/.var/app/<id>/config/fontconfig/fonts.conf` with plain `<dir>` entries for
`/run/host/fonts`, `/run/host/local-fonts`, `/run/host/user-fonts` and
`/run/host/user-fonts-legacy`, so the bundled fontconfig scans the host fonts
itself and writes its own cache. Apps that already carry their own
`fonts.conf` are left untouched.

It runs automatically at session start. To re-apply it (for example after
installing a new Chromium/Electron app):

```bash
ujust fix-flatpak-fonts
```

Restart the affected apps afterwards. Apps that use the runtime's fontconfig
(Firefox and most GTK/Qt apps) are not affected.

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
