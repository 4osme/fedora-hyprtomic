-- Hyprland Configuration (Lua)
-- hyprland.conf からの移行版。~/.config/hypr/hyprland.lua が存在すると
-- .conf より優先される (戻すにはこのファイルへのリンクを外すだけ)。
-- デフォルトレイアウトは標準 dwindle。カスタムレイアウト quadgrid (layouts/quadgrid.lua)
-- は登録のみ行い、適用は workspace_rule に委ねる。
--
-- このファイルはイメージ (SKEL) の既定値。ユーザー設定は末尾で読み込む:
--   ~/.config/hypr/dms/*.lua          (DMS が生成) colors / outputs / layout /
--                                     input / binds / binds-user / windowrules
--                                     (cursor は SKEL 側の指定を優先)
--   ~/.config/hypr/workspaces.lua     (任意) ワークスペース割当
--   ~/.config/hypr/sunshine.lua       (SKEL) Sunshine ストリーミング用レイアウト
--   ~/.config/hypr/host.lua           (任意) マシン固有
--   ~/.config/hypr/user.lua           (任意) 最後に読み込み、何でも上書きできる
--   ~/.config/hypr/local.conf         (旧形式) return { monitor_primary = "DP-1" }
-- local.conf / user.lua / host.lua / workspaces.lua は /etc/skel に同梱しない
-- (sync-skel-config の overwrite=1 同期で上書きされないよう)。
--
-- 配色と透明度は DMS の設定 (Settings → Wallpaper & colors) に一本化する。
-- このファイルには色・透明度の値を書かない: 書くと DMS が生成する
-- dms/colors.lua や dms/layout.lua の値を上書きし、GUI アプリ間で
-- 配色がずれる (例: 端末は DMS の色、バーは Hyprland の既定色)。

-- Monitor - auto detect (host.lua / user.lua で上書き可能)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})

-- Variables
local terminal    = "ghostty"
local fileManager = "dfiles"
local menu        = "dms ipc call launcher toggle"
local mainMod     = "SUPER"

-- Machine-specific overrides: ~/.config/hypr/local.conf (loaded when present).
local _HOME = os.getenv("HOME") or ""
local function _exists(p)
    local f = io.open(p, "r")
    if f then io.close(f); return true end
    return false
end
-- Load a Lua fragment if it exists; report failures as a notification instead
-- of aborting the whole config.
local function _dofile(path)
    if not _exists(path) then
        return
    end
    local ok = pcall(dofile, path)
    if not ok then
        hl.notification.create({ text = "hypr: failed to load " .. path, duration = 5000 })
    end
end
-- Load a DMS fragment (DMS writes them into ~/.config/hypr/dms/).
--
-- require() is used on purpose:
--   - Hyprland tracks required files, so when DMS rewrites a fragment
--     (wallpaper change, theme switch) the compositor reloads the config
--     automatically and the new colors/opacity are applied.
--   - DMS looks for `require("dms.<name>")` lines to decide whether a
--     fragment is already included, so it does not append a second one.
--
-- The file may not exist yet (DMS creates the fragments when it starts),
-- so the existence check keeps the config loadable on a fresh session.
local function _dms(name)
    local path = _HOME .. "/.config/hypr/dms/" .. name .. ".lua"
    if not _exists(path) then
        return
    end
    local ok = pcall(require, "dms." .. name)
    if not ok then
        hl.notification.create({ text = "hypr: failed to load dms/" .. name .. ".lua", duration = 5000 })
    end
end
-- Bind a key, dropping any bind that is already registered for it.
-- Hyprland runs every bind registered for a key combo, so a DMS stock bind
-- and a bind from this file for the same combo would both fire. Unbinding
-- first keeps this file (and user.lua) authoritative.
local function _bind(key, dispatcher, opts)
    hl.unbind(key)
    hl.bind(key, dispatcher, opts)
end
local localCfg = {}
if _exists(_HOME .. "/.config/hypr/local.conf") then
    local ok, cfg = pcall(dofile, _HOME .. "/.config/hypr/local.conf")
    if ok and type(cfg) == "table" then
        localCfg = cfg
    else
        hl.notification.create({ text = "hypr: ~/.config/hypr/local.conf failed to load; using defaults", duration = 5000 })
    end
end
-- Empty = no monitor pinning. A legacy local.conf `monitor_primary` still
-- pins that output; new configs should set monitors in host.lua/user.lua.
local monitorPrimary = localCfg.monitor_primary or ""
if monitorPrimary ~= "" then
    hl.monitor({
        output   = monitorPrimary,
        mode     = "preferred",
        position = "auto",
        scale    = 1.0,
    })
end

-- カスタムレイアウト登録 (適用は local.conf の workspace_rule で指定。
-- ~/.config/hypr/layouts が無い場合は skip)
local quadgridOk, quadgrid = pcall(require, "layouts.quadgrid")
if not quadgridOk then
    quadgrid = nil
end

-- Environment
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "36")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- IME: fcitx5 + Mozkey run on the host (the image ships them), so GTK/Qt apps
-- reach the IME through these variables.
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")

-- Autostart
-- DMS (bar / launcher / control center / notifications / power menu / OSD)
-- runs as the dms.service user unit, bound to hyprland-session.target by the
-- image. Start the target after exporting the environment so DMS can see
-- WAYLAND_DISPLAY. IME (fcitx5) starts from its XDG autostart entry.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("/usr/libexec/hyprtomic/seed-dms-wallpaper")
    hl.exec_cmd("systemctl --user start graphical-session.target")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME GTK_IM_MODULE QT_IM_MODULE XMODIFIERS")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 36")
    hl.exec_cmd("sleep 2 && dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

-- General
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        -- 枠の配色 (general.col) は DMS の dms/colors.lua が設定する。
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    -- マウスドラッグのしきい値 (px)。0 (既定) だと SUPER+クリックの僅かな
    -- 動きでもドラッグ扱いになり、quadgrid のドロップ配置が誤発火する。
    -- 10px 動かすまでドラッグを開始しない。
    binds = {
        drag_threshold = 10,
    },

    -- Group (tabs) - integrated with terminal window
    group = {
        -- 枠・グループバーの配色 (group.col / groupbar.col) は
        -- DMS の dms/colors.lua が設定する。
        -- auto_group=false: chrome 等の自動グループ参加を防止
        auto_group = false,
        groupbar = {
            enabled   = true,
            font_size = 10,
            height    = 24,
            gradients = true,
            blur      = true,
            -- groupbar.col (背景) は DMS の dms/colors.lua が設定する。
            -- text_color は Hyprland の既定 (白) のままにする。
            indicator_height    = 2,
            rounding            = 4,
            gradient_rounding   = 4,
        },
    },

    -- Decoration
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = true,
            popups  = false,
            -- Blur の強さ (size / passes) とウィンドウの不透明度
            -- (active_opacity / inactive_opacity) は DMS の dms/layout.lua
            -- が設定する (Settings → System & integrations → Hyprland)。
            -- ここでは手動で指定しない。
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        middle_click_paste   = false,
        disable_autoreload   = true,
        render_unfocused_fps = 10,
    },

    cursor = {
        no_hardware_cursors = false,
    },

    render = {
        new_render_scheduling = true,
    },

    -- Input
    input = {
        kb_layout          = "jp",
        kb_options         = "caps:none",
        repeat_delay       = 800,
        numlock_by_default = true,
        follow_mouse       = 1,
        sensitivity        = 0.2,
        touchpad = {
            natural_scroll = false,
            scroll_factor  = 1.5,
        },
    },
})

-- Animations
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- DMS keybinds (Settings → Keyboard shortcuts で管理されるファイル)
-- 先に読み込み、このファイル側のバインド (_bind) が上書きする。
-- 同じキーに 2 つ登録されると Hyprland は両方を実行するため、
-- _bind() は hl.unbind() を先に行う。
_dms("binds")
_dms("binds-user")

-- Keybindings
_bind(mainMod .. " + S", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland"), { desc = "キーバインドを確認" })
_bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { desc = "ターミナルを開く (単体)" })
_bind(mainMod .. " + X", hl.dsp.window.close(), { desc = "アクティブウィンドウを閉じる" })
_bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { desc = "ファイルマネージャを開く" })
-- タイル窓を float 化すると直前のタイルサイズがそのまま採用され画面をほぼ覆ってしまう
-- (windowrule の max_size は togglefloating では再評価されず効かない実測済み) ため、
-- float 化した直後に限り明示的に上限までリサイズしてセンタリングする
_bind(mainMod .. " + F", function()
    local w = hl.get_active_window()
    local wasFloating = w and w.floating
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if not w or wasFloating then
        return
    end
    local mon = w.monitor
    if not mon then
        return
    end
    local maxW = mon.width / mon.scale * 0.25
    local maxH = mon.height / mon.scale * 0.25
    if w.size.x > maxW or w.size.y > maxH then
        hl.dispatch(hl.dsp.window.resize({ x = math.min(w.size.x, maxW), y = math.min(w.size.y, maxH), relative = false }))
        hl.dispatch(hl.dsp.window.center())
    end
end, { desc = "フローティング切り替え" })
_bind("SUPER + Alt_L", hl.dsp.exec_cmd("dms ipc call widget toggle launcherButton"), { desc = "アプリランチャを開く" })
_bind(mainMod .. " + P", hl.dsp.window.pseudo(), { desc = "Pseudo モード切り替え (dwindle)" })
_bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { desc = "スプリット方向切り替え (dwindle)" })
_bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { desc = "画面ロック" })
_bind(mainMod .. " + C", hl.dsp.exec_cmd("flatpak run org.mozilla.firefox"), { desc = "Firefox を開く" })
_bind(mainMod .. " + M", hl.dsp.exec_cmd("mission-center"), { desc = "プロセス / パフォーマンス" })
_bind(mainMod .. " + B", hl.dsp.exec_cmd("flatpak run com.bitwarden.desktop"), { desc = "Bitwarden を開く" })

-- Focus
_bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { desc = "フォーカス移動: 左" })
_bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { desc = "フォーカス移動: 右" })
_bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { desc = "フォーカス移動: 上" })
_bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { desc = "フォーカス移動: 下" })

-- Move window (quadgrid 上では隣接セルへ移動。先客が居れば縮小して同居)
local function moveWindowAction(dir)
    if quadgrid then
        return quadgrid.move_or_swap(dir)
    end
    return hl.dsp.window.move({ direction = dir })
end
_bind(mainMod .. " + SHIFT + left",  moveWindowAction("left"),  { desc = "ウィンドウ移動: 左" })
_bind(mainMod .. " + SHIFT + right", moveWindowAction("right"), { desc = "ウィンドウ移動: 右" })
_bind(mainMod .. " + SHIFT + up",    moveWindowAction("up"),    { desc = "ウィンドウ移動: 上" })
_bind(mainMod .. " + SHIFT + down",  moveWindowAction("down"),  { desc = "ウィンドウ移動: 下" })

-- Utilities
_bind(mainMod .. " + Escape", hl.dsp.exec_cmd("rofi -show window"), { desc = "ウィンドウスイッチャ (rofi)" })
_bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("dms screenshot"),
    { desc = "領域スクリーンショット (保存 + コピー)" })
_bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("dms screenshot --no-clipboard"),
    { desc = "領域スクリーンショット (保存のみ)" })
_bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("dms color pick"), { desc = "カラーピッカー" })
_bind(mainMod .. " + DELETE", hl.dsp.exec_cmd("dms ipc call powermenu toggle"), { desc = "電源メニュー" })
_bind(mainMod .. " + A", hl.dsp.exec_cmd("dms ipc call control-center toggle"), { desc = "コントロールセンター" })
_bind(mainMod .. " + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"), { desc = "クリップボード履歴" })

-- Ghostty ネイティブタブを使用 (Ctrl+Shift+T/Q/←/→ は Ghostty が処理)

-- Workspaces
for i = 1, 10 do
    local key = i % 10 -- 10 は 0 キー
    _bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }),
        { desc = "ワークスペース " .. i .. " へ" })
    _bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }),
        { desc = "ウィンドウをワークスペース " .. i .. " に移動" })
end

-- Workspace scroll
_bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース (スクロール)" })
_bind(mainMod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }), { desc = "前のワークスペース (スクロール)" })
_bind(mainMod .. " + bracketleft",  hl.dsp.focus({ workspace = "e-1" }), { desc = "前のワークスペース" })
_bind(mainMod .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース" })
_bind(mainMod .. " + TAB",          hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース (Tab)" })

-- Disable noisy keys
_bind("Caps_Lock", hl.dsp.no_op(), { desc = "Caps Lock 無効化" })
_bind("Insert",    hl.dsp.no_op(), { desc = "Insert キー無効化" })

-- Resize (repeat)
_bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -20, y = 0,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 左 -20px" })
_bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 20,  y = 0,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 右 +20px" })
_bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 上 -20px" })
_bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 下 +20px" })

-- Mouse bindings
_bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "マウスドラッグでウィンドウリサイズ" })
if quadgrid then
    -- quadgrid: 押下でウィンドウのドラッグを開始し、解放後 (release follow-up) に
    -- ドロップ先のセルへ配置。先客の居るセルなら入れ替え、別モニタへのドロップは
    -- C++ 側のワークスペース移動に従う (詳細は layouts/quadgrid.lua)。
    -- ※ 押下用 (dispatcher) と解放用 (drag フラグ) の 2 bind に分けると、
    --    押下を消費した bind が解放用 bind を shadow して発火しない
    _bind(mainMod .. " + mouse:272", quadgrid.on_drag, { mouse = true, desc = "quadgrid: ドラッグ&ドロップでセル移動" })
else
    _bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "マウスドラッグでウィンドウ移動" })
end

-- Locked bindings - work on lock screen
_bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true, desc = "音量を上げる" })
_bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, desc = "音量を下げる" })
_bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true, desc = "出力ミュート切り替え" })
_bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true, desc = "マイクミュート切り替え" })
_bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/bright.sh 5%+"),
    { locked = true, repeating = true, desc = "画面輝度を上げる" })
_bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/bright.sh 5%-"),
    { locked = true, repeating = true, desc = "画面輝度を下げる" })

_bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, desc = "次の曲" })
_bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "再生/一時停止" })
_bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "再生/一時停止" })
_bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, desc = "前の曲" })

-- Window rules
-- 透明度 (opacity) はアプリごとに指定しない: ウィンドウ全体の不透明度は
-- DMS の dms/layout.lua (decoration.active_opacity / inactive_opacity) が
-- 設定する。アプリごとに値を変えると GUI アプリ間で見た目がずれる。
hl.window_rule({
    name  = "float-utils",
    match = { class = "^(authentication-agent|Rustdesk|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|Blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name  = "float-qt5ct-shotcut",
    match = { initial_class = "^(qt5ct|org.shotcut.Shotcut)$" },
    float = true,
})

hl.window_rule({
    name  = "float-steam",
    match = { initial_class = "^(steam)$" },
    float = true,
})

hl.window_rule({
    name   = "float-portals",
    match  = { initial_class = ".*-desktop-portal-.*" },
    float  = true,
    center = true,
})

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name   = "float-satty",
    match  = { class = "com.gabm.satty" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.7)",
    center = true,
})

hl.window_rule({
    name    = "float-missioncenter",
    match   = { class = "io.missioncenter.MissionCenter" },
    float   = true,
    size    = "(monitor_w*0.5) (monitor_h*0.6)",
    center  = true,
})

hl.window_rule({
    name    = "float-gtk",
    match   = { class = "xdg-desktop-portal-gtk" },
    float   = true,
    size    = "(monitor_w*0.5) (monitor_h*0.6)",
    center  = true,
})

hl.window_rule({
    name           = "pip-float",
    match          = { title = "^(Picture-in-Picture|ピクチャー イン ピクチャー)$" },
    float          = true,
    pin            = true,
    suppress_event = "float",
})

hl.window_rule({
    name           = "float-waydroid",
    match          = { class = "Waydroid" },
    float          = true,
    center         = true,
    suppress_event = "activate activatefocus",
})

hl.window_rule({
    name  = "float-wine-proton",
    match = { class = "^(steam_app_.*|.*\\.exe)$" },
    float = true,
})

-- Layer rules (DMS namespaces: https://duxlabs.dev/docs/dms/layers)
hl.layer_rule({ name = "bar",                       match = { namespace = "dms:bar" },                      blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "control-center",            match = { namespace = "dms:control-center" },           blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "notification-popup",        match = { namespace = "dms:notification-popup" },       blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "notification-center",       match = { namespace = "dms:notification-center-popout" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "notification-modal",        match = { namespace = "dms:notification-center-modal" }, blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "spotlight",                 match = { namespace = "dms:spotlight" },                blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "dash",                      match = { namespace = "dms:dash" },                     blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "clipboard",                 match = { namespace = "dms:clipboard" },                blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "settings",                  match = { namespace = "dms:settings" },                 blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "power-menu",                match = { namespace = "dms:power-menu" },               blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "osd",                       match = { namespace = "dms:osd" },                      blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "tooltip",                   match = { namespace = "dms:tooltip" },                  blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "rofi",                      match = { namespace = "rofi" },                         blur = true,  ignore_alpha = 0.2 })

-- DMS fragments, loaded last so they can override anything above.
-- DMS regenerates its own files; only host.lua / user.lua / local.conf
-- are meant to be edited (and git-managed).
--
-- colors  : 枠・グループバーなどの配色 (Settings → Wallpaper & colors)
-- outputs : モニタ構成 (Settings → Displays)
-- layout  : ウィンドウ不透明度・Blur 強度・角丸・gaps (Settings → Hyprland)
-- input   : ポインタ / キーボード設定 (Settings → Input)
-- windowrules : ウィンドウルール (Settings → Applications → Window rules)
--
-- dms/cursor.lua だけは読み込まない: カーソルは SKEL 側 (Bibata) と
-- dconf / GTK の設定で揃える。取り込むと DMS 既定 (Adwaita) が env を
-- 上書きし、コンポジタと GTK アプリと X11 アプリでカーソルがずれる。
_dms("colors")
_dms("outputs")
_dms("layout")
_dms("input")
_dms("windowrules")

-- User / machine fragments, loaded last so they can override anything above.
_dofile(_HOME .. "/.config/hypr/workspaces.lua")
_dofile(_HOME .. "/.config/hypr/sunshine.lua")
_dofile(_HOME .. "/.config/hypr/host.lua")
_dofile(_HOME .. "/.config/hypr/user.lua")
