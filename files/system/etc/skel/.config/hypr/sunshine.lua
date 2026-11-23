-- Sunshine streaming layout (SKEL).
--
-- Sunshine is a manual service: `sunshine-session start` creates the HEADLESS-1
-- virtual output, writes the session marker and restarts the user unit. While a
-- profile marker exists this file moves the captured output to 0x0 and disables
-- the physical outputs so the stream does not render to a 4K panel.
--
-- Machine-specific rules (workspace assignments, window rules, HDMI names) live
-- in ~/.config/hypr/host.lua, which is loaded after this file.

local sunshineRuntime = os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000"
local function marker(name)
    local file = io.open(sunshineRuntime .. "/sunshine-hypr-display/" .. name, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local profile1080 = marker("1080p.active")
local profileNative = marker("native.active")
local sessionActive = marker("session.active")

local function sunshineConfig(key)
    local path = (os.getenv("HOME") or "") .. "/.config/sunshine/sunshine.conf"
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local value = nil
    for line in file:lines() do
        local match = line:match("^%s*" .. key .. "%s*=%s*(%S+)")
        if match then
            value = match
        end
    end
    file:close()
    return value
end

-- Disable every output except the one Sunshine captures. The live monitor list
-- covers whatever DMS named the outputs; a fixed fallback would be wrong on a
-- different machine.
local function disablePhysicalOutputs(output)
    local ok, list = pcall(function()
        return hl.get_monitors and hl.get_monitors({ all = true }) or {}
    end)
    if not ok or type(list) ~= "table" then
        return
    end
    for _, monitor in ipairs(list) do
        local name = monitor.name
        if name and name ~= output and not name:find("^HEADLESS%-") then
            hl.monitor({ output = name, disabled = true })
        end
    end
end

local function applySunshineLayout(mode)
    local output = sunshineConfig("output_name") or "HEADLESS-1"
    if output == "" then
        output = "HEADLESS-1"
    end
    if output:find("^HEADLESS%-") then
        mode = "1920x1080@60"
    end
    hl.monitor({ output = output, mode = mode, position = "0x0", scale = 1.0, transform = 0 })
    disablePhysicalOutputs(output)
end

if profile1080 then
    applySunshineLayout("1920x1080@60")
    for i = 1, 8 do
        hl.workspace_rule({ workspace = tostring(i), layout = "dwindle" })
    end
    hl.layout.register("sunshine-stream-refresh", { recalculate = function() end })
elseif profileNative then
    applySunshineLayout("preferred")
elseif sessionActive then
    -- `sunshine-session start` owns the physical layout for the whole session:
    -- a client connect/disconnect must not bring the 4K panel back.
    applySunshineLayout("preferred")
else
    -- No session and no client: keep the virtual output alive (Sunshine probes
    -- it) and park it far to the right so DMS outputs.lua keeps the real layout.
    local output = sunshineConfig("output_name") or "HEADLESS-1"
    if output:find("^HEADLESS%-") then
        hl.monitor({ output = output, mode = "1920x1080@60", position = "10000x0", scale = 1.0, transform = 0 })
    end
end

-- Also handles a stream started at SDDM before this Hyprland session exists.
-- hypr-stream-display.py takes a per-instance lock, so reloads do not duplicate
-- the watcher.
local watcher = 'python3 "$HOME/.config/sunshine/hypr-stream-display.py" watch'
hl.on("hyprland.start", function()
    hl.exec_cmd(watcher)
end)
hl.exec_cmd(watcher)
