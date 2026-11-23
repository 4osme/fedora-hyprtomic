#!/usr/bin/env bash
# Build Sunshine with the JIS keyboard patches and install it to /usr.
#
# Upstream has not merged the JIS key mapping yet (LizardByte/Sunshine#5542,
# LizardByte/libvirtualhid#101), so the image rebuilds the release the patches
# were tested against (v2026.914.233613, commit 63d35f70) with:
#
#   0001  uinput path honours SS_KBE_FLAG_NON_NORMALIZED
#   0002  Wayland layout validation is retried instead of cached
#   0003  libvirtualhid uhid backend maps JIS keys by physical position
#
# The patches are installed by the files module at
# /usr/share/hyprtomic/sunshine/patches. CUDA is disabled: this is a wlr/KMS
# host, not an NVIDIA frame-buffer capture host.
set -oue pipefail

commit="63d35f702ee9e362e43263742981836ec0710384"
patches="/usr/share/hyprtomic/sunshine/patches"
src="/var/tmp/sunshine"
build="/var/tmp/sunshine-build"

echo "==> Sunshine: installing build dependencies"
dnf install -y --setopt=install_weak_deps=False \
    cmake ninja-build gcc gcc-c++ git nodejs npm \
    python3 python3-pip python3-jinja2 \
    appstream glslc libappstream-glib desktop-file-utils \
    libcap-devel libcurl-devel libdrm-devel libevdev-devel libva-devel \
    libX11-devel libxcb-devel libXcursor-devel libXfixes-devel libXi-devel \
    libXinerama-devel libXrandr-devel libXtst-devel \
    mesa-libGL-devel mesa-libgbm-devel libgudev-devel \
    miniupnpc-devel numactl-devel opus-devel pulseaudio-libs-devel \
    openssl-devel pipewire-devel qt6-qtbase-devel qt6-qtsvg-devel \
    vulkan-loader-devel systemd-udev wget which xz libatomic

echo "==> Sunshine: fetching ${commit}"
rm -rf "$src" "$build"
git clone https://github.com/LizardByte/Sunshine.git "$src"
git -C "$src" checkout "$commit"
git -C "$src" submodule update --init --recursive

echo "==> Sunshine: applying JIS patches"
git -C "$src" apply "${patches}/0001-sunshine-non-normalized-key-flag.patch"
git -C "$src" apply "${patches}/0002-sunshine-wayland-retry.patch"
git -C "$src/third-party/libvirtualhid" apply \
    "${patches}/0003-libvirtualhid-jis-keyboard-mapping.patch"

echo "==> Sunshine: configuring"
cmake -B "$build" -G Ninja -S "$src" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_DOCS=OFF \
    -DBUILD_WERROR=OFF \
    -DSUNSHINE_ASSETS_DIR=/usr/share/sunshine \
    -DSUNSHINE_EXECUTABLE_PATH=/usr/bin/sunshine \
    -DSUNSHINE_ENABLE_DRM=ON \
    -DSUNSHINE_ENABLE_KWIN=ON \
    -DSUNSHINE_ENABLE_PORTAL=ON \
    -DSUNSHINE_ENABLE_WAYLAND=ON \
    -DSUNSHINE_ENABLE_X11=ON \
    -DSUNSHINE_ENABLE_CUDA=OFF \
    -DSUNSHINE_PUBLISHER_NAME=HyprTomic \
    -DSUNSHINE_PUBLISHER_WEBSITE=https://github.com/j7b3y/fedora-hyprtomic \
    -DSUNSHINE_PUBLISHER_ISSUE_URL=https://github.com/j7b3y/fedora-hyprtomic/issues

echo "==> Sunshine: building"
ninja -C "$build"

echo "==> Sunshine: installing"
ninja -C "$build" install

# KMS capture needs these; wlr capture works without them. OSTree keeps the
# security.capability xattr, so the binary keeps the caps across updates.
if command -v setcap >/dev/null 2>&1; then
    setcap cap_sys_admin,cap_sys_nice+p /usr/bin/sunshine
fi

# The upstream unit is enabled with graphical-session.target; HyprTomic starts
# Sunshine on demand from `sunshine-session start`, so replace it.
install -Dm644 /usr/share/hyprtomic/sunshine/sunshine.service \
    /usr/lib/systemd/user/sunshine.service

echo "==> Sunshine: cleaning build tree"
rm -rf "$src" "$build" /root/.npm /root/.cache
# Build dependencies stay in the image. `dnf remove` also drops runtime
# packages that depend on them (the first CI run lost ghostty, flatpak,
# file-roller, xdg-utils and libadwaita), and /var/cache/libdnf5 is a build
# cache mount (`rm: Device or resource busy`). Pruning them safely needs a
# separate build stage.

echo "==> Sunshine: done"
