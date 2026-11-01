-- Helpers shared by every other file. Loaded first.

HOME = os.getenv("HOME")
CONFIG_HOME = os.getenv("XDG_CONFIG_HOME") or HOME .. "/.config"
HYPR_DIR = CONFIG_HOME .. "/hypr"
SOMESHELL_DIR = CONFIG_HOME .. "/someshell"
SCRIPTS = HYPR_DIR .. "/scripts"

JSON = require("lib.json")

function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

-- require() a module only when its file exists (machine-written files).
function require_optional(name)
    if package.searchpath(name, package.path) then
        require(name)
        return true
    end
    return false
end

-- The first of `names` found in $PATH, else the first name. Reads the
-- directories itself, so loading the config starts no process.
function first_available(names)
    for _, name in ipairs(names) do
        local cmd = name:match("^(%S+)")
        for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
            if file_exists(dir .. "/" .. cmd) then return name end
        end
    end
    return names[1]
end

-- Case-insensitive: does `s` match any Lua pattern in `patterns`?
function matches_any(s, patterns)
    if s == nil or s == "" then return false end
    s = s:lower()
    for _, p in ipairs(patterns) do
        if s:find(p) then return true end
    end
    return false
end

-- Choices from the settings window (~/.config/someshell/hypr.json). It holds
-- only what was changed, so the defaults in these files cover the rest. A
-- broken file is ignored (SETTINGS_ERROR says why) instead of breaking Hyprland.
SETTINGS, SETTINGS_ERROR = JSON.read(SOMESHELL_DIR .. "/hypr.json")
if SETTINGS_ERROR == "missing" then SETTINGS_ERROR = nil end
if type(SETTINGS) ~= "table" then SETTINGS = {} end

-- setting("apps.terminal", "kitty"): the value at a dotted path, or `default`
-- when it is unset (an empty string counts as unset).
function setting(path, default)
    local v = SETTINGS
    for part in path:gmatch("[^.]+") do
        if type(v) ~= "table" then return default end
        v = v[part]
    end
    if v == nil or v == "" then return default end
    return v
end

-- Monitors from left to right (then top to bottom). Workspace numbers come in
-- groups of 10 per monitor in this order: the left one has 1-10, the next 11-20.
function monitors_in_order()
    local list = hl.get_monitors() or {}
    local function pos(m)
        local p = m.position
        if type(p) == "table" then return p.x or p[1] or 0, p.y or p[2] or 0 end
        return 0, 0
    end
    table.sort(list, function(a, b)
        local ax, ay = pos(a)
        local bx, by = pos(b)
        if ax ~= bx then return ax < bx end
        return ay < by
    end)
    return list
end

-- Workspace id for slot `i` (1..10) on the focused monitor.
function workspace_slot(i)
    local active = hl.get_active_monitor()
    local group = 0
    if active then
        for index, m in ipairs(monitors_in_order()) do
            if m.name == active.name then group = index - 1 break end
        end
    end
    return group * 10 + i
end
