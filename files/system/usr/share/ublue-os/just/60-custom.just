# HyprTomic ujust recipes.
# Loaded by ublue-os-just's justfile via `import "/usr/share/ublue-os/just/60-custom.just"`.

# just overrides must come *before* the recipe name:
#   ujust overwrite=1 sync-skel-config
#   ujust dry_run=1 user-config-apply
overwrite := "0"
dry_run := "0"
prune := "0"

# --- GUI container (Arch distrobox; the shell + GUI helpers live there) ---

# Create and initialize the GUI container (safe to re-run).
gui-container-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell init
    /usr/bin/hyprtomic-gui-shell status

# Recreate the GUI container from the latest published image.
gui-container-update:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell update
    /usr/bin/hyprtomic-gui-shell status

# Recreate the GUI container from scratch (same as update, explicit).
gui-container-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell reset
    /usr/bin/hyprtomic-gui-shell status

# Show whether the GUI container exists.
gui-container-status:
    @/usr/bin/hyprtomic-gui-shell status

# --- Fonts ---

# Fix CJK rendering in Chromium/Electron flatpaks: flatpak >= 1.18 exposes the
# host fonts only through caches their bundled fontconfig cannot read, so every
# host font disappears (Japanese renders as tofu). Writes a per-app
# ~/.var/app/<id>/config/fontconfig/fonts.conf; restart the affected apps
# afterwards. Also run automatically on session start.
fix-flatpak-fonts:
    @/usr/bin/hyprtomic-flatpak-fonts

# Re-register the .desktop files of the other distrobox containers with the
# host application dirs, so the quickshell launcher lists them (the launcher
# groups them by container). Removes entries whose source app or container
# disappeared and refreshes the mirrored icons. Also runs as the
# hyprtomic-distrobox-apps.service user unit, which follows containers that
# start after login; use this to force a pass.
refresh-distrobox-apps:
    @/usr/bin/hyprtomic-distrobox-apps

# --- Dotfiles (SKEL layer) ---

# Sync the baked /etc/skel into $HOME (oameye/atomic-hyprland-style).
# Pass overwrite=1 to replace managed files from the shipped skel and prune
# files that previous overwrite runs synced but the image has since removed.
# Leave the default to only copy files that don't yet exist.
# Files owned by the hyprtomic-user repository are never touched.
# Example:
#   ujust sync-skel-config                # safe -- skips files that exist
#   ujust overwrite=1 sync-skel-config    # replace managed files from skel
[doc("Sync the baked /etc/skel into $HOME, skipping paths owned by the USR layer.")]
sync-skel-config:
    #!/usr/bin/env bash
    set -euo pipefail

    user_dir="${HYPRTOMIC_USER_DIR:-$HOME/.config/hyprtomic-user}"
    state_dir="$HOME/.local/state/hyprtomic"
    manifest_file="${state_dir}/skel-manifest"
    new_manifest="$(mktemp)"
    exclude_file="$(mktemp)"
    trap 'rm -f "$new_manifest" "$exclude_file"' EXIT

    # Paths the USR layer owns (symlinked by user-config-apply) and paths that
    # are always user-owned. rsync patterns are anchored at the transfer root.
    {
        if [ -d "$user_dir/home" ]; then
            (cd "$user_dir/home" && find . -mindepth 1 ! -type d -printf '/%P\n')
        fi
        printf '%s\n' \
            '/.config/hypr/user.lua' \
            '/.config/hypr/workspaces.lua' \
            '/.config/hypr/local.conf' \
            '/.config/hypr/host.lua'
    } | LC_ALL=C sort -u >"$exclude_file"

    if [ "{{ overwrite }}" = "1" ]; then
        install -d "$state_dir"
        find /etc/skel -mindepth 1 ! -type d -printf '%P\n' | LC_ALL=C sort >"$new_manifest"

        # Prune files we synced on a previous overwrite run that the image has
        # since removed. Only runs when a manifest from a prior overwrite exists:
        # we never speculatively delete on a first run, because /etc/skel paths
        # like .local/share are shared with non-skel data (podman storage, user
        # app data, etc.) and a blind rm -rf would destroy unrelated files.
        if [ -f "$manifest_file" ]; then
            while IFS= read -r relpath; do
                if [ -z "$relpath" ]; then
                    continue
                fi
                if grep -qxF "/$relpath" "$exclude_file"; then
                    continue
                fi
                target="$HOME/$relpath"
                rm -f "$target"

                parent="$(dirname "$target")"
                while [ "$parent" != "$HOME" ]; do
                    rmdir "$parent" 2>/dev/null || break
                    parent="$(dirname "$parent")"
                done
            done < <(comm -23 "$manifest_file" "$new_manifest")
            echo "Replacing managed dotfiles from /etc/skel and pruning removed files ..."
        else
            echo "Replacing managed dotfiles from /etc/skel (first overwrite -- seeding manifest, no prune) ..."
        fi

        rsync -av --exclude-from="$exclude_file" /etc/skel/ "$HOME/"
        cp "$new_manifest" "$manifest_file"
    else
        echo "Syncing /etc/skel into \$HOME (skipping files that already exist) ..."
        rsync -av --ignore-existing --exclude-from="$exclude_file" /etc/skel/ "$HOME/"
    fi
    echo
    echo "Done. Run 'hyprctl reload' or log out/in to apply."

# --- User configuration (USR layer) ---

# Create the user configuration repository (~/.config/hyprtomic-user).
[doc("Create the user configuration repository (~/.config/hyprtomic-user).")]
user-config-init:
    @/usr/libexec/hyprtomic/user-config init

# Show link differences between the repository and $HOME.
[doc("Show link differences between the repository and $HOME.")]
user-config-status:
    @/usr/libexec/hyprtomic/user-config status

# Symlink ~/.config/hyprtomic-user/home into $HOME.
# Pass dry_run=1 to preview, prune=1 to drop links the repository removed.
[doc("Symlink ~/.config/hyprtomic-user/home into $HOME (dry_run=1, prune=1).")]
user-config-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    args=()
    if [ "{{ dry_run }}" = "1" ]; then
        args+=(--dry-run)
    fi
    if [ "{{ prune }}" = "1" ]; then
        args+=(--prune)
    fi
    /usr/libexec/hyprtomic/user-config apply "${args[@]}"

# git pull --ff-only, then apply.
[doc("git pull --ff-only in the user repository, then apply the links.")]
user-config-update:
    @/usr/libexec/hyprtomic/user-config update

# --- Machine state (HOST layer, rpm-ostree) ---

# Create an empty machine manifest (~/.config/hyprtomic-machine/machine.json).
[doc("Create an empty machine manifest (~/.config/hyprtomic-machine/machine.json).")]
machine-init:
    @/usr/libexec/hyprtomic/machine-config init

# Show manifest entries that are not applied yet.
[doc("Show machine manifest entries that are not applied yet.")]
machine-status:
    @/usr/libexec/hyprtomic/machine-config status

# Enable COPRs, layer packages, append kargs, install Flatpaks, enable units.
# Pass dry_run=1 to preview. Packages and kargs are only ever added.
[doc("Apply COPRs, layered packages, kargs, Flatpaks and user units (dry_run=1).")]
machine-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    args=()
    if [ "{{ dry_run }}" = "1" ]; then
        args+=(--dry-run)
    fi
    /usr/libexec/hyprtomic/machine-config apply "${args[@]}"

# Rewrite hosts.<hostname> from the current machine state.
[doc("Rewrite hosts.<hostname> in the machine manifest from this machine.")]
machine-export:
    @/usr/libexec/hyprtomic/machine-config export

# --- SDDM login screen ---

# Replace the SDDM login-screen wallpaper. Copies the astronaut theme to a
# private name under /usr/local (=/var/usrlocal host state: survives updates)
# and selects it via /etc/sddm.conf.d/zz-wallpaper.conf (sorts after the
# baked zz-theme.conf). Undo: delete both paths and restart sddm.
[doc("Replace the SDDM login-screen wallpaper (path=<image>).")]
login-wallpaper path:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{ path }}"
    [ -f "$src" ] || { echo "no such file: $src"; exit 1; }
    dest=/usr/local/share/sddm/themes/hyprtomic-login
    [ -d "$dest" ] || sudo cp -a /usr/share/sddm/themes/sddm-astronaut-theme "$dest"
    sudo install -Dm644 "$src" "$dest/Backgrounds/wallpaper.jpg"
    printf '[Theme]\nCurrent=hyprtomic-login\n' | sudo tee /etc/sddm.conf.d/zz-wallpaper.conf >/dev/null
    sudo systemctl restart sddm || true
    echo "login wallpaper updated"
