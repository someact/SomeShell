-- Small helpers shared by every other module. Loaded first by hyprland.lua.

HOME = os.getenv("HOME")
HYPR_DIR = HOME .. "/.config/hypr"

function file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

-- require() a module only if its file exists. Used for machine-written files
-- (generated/*, monitors.lua) that may not exist on a fresh install.
function require_optional(name)
    if package.searchpath(name, package.path) then
        require(name)
        return true
    end
    return false
end

-- Absolute workspace id for slot `i` (1..10) inside the current group of
-- `workspaceGroupSize` workspaces, so SUPER+1 on workspace 13 goes to 11.
function workspace_in_group(i)
    local curr = hl.get_active_workspace().id
    return math.floor((curr - 1) / workspaceGroupSize) * workspaceGroupSize + i
end

-- Case-insensitive "does `s` match any Lua pattern in `patterns`".
function matches_any(s, patterns)
    if s == nil or s == "" then return false end
    s = string.lower(s)
    for _, p in ipairs(patterns) do
        if string.find(s, p) then return true end
    end
    return false
end

JSON = require("lib.json")
SOMESHELL_DIR = (os.getenv("XDG_CONFIG_HOME") or HOME .. "/.config") .. "/someshell"

-- Choices made in the settings app (~/.config/someshell/hypr.json). The file only
-- holds what was changed there, so the repo defaults apply to everything else.
-- A broken file is ignored (SETTINGS_ERROR says why) rather than breaking the config.
SETTINGS, SETTINGS_ERROR = JSON.read(SOMESHELL_DIR .. "/hypr.json")
if SETTINGS_ERROR == "missing" then SETTINGS_ERROR = nil end
SETTINGS = type(SETTINGS) == "table" and SETTINGS or {}

-- setting("apps.terminal", "kitty"): the hypr.json value at a dotted path, or
-- `default` when unset (empty strings count as unset)
function setting(path, default)
    local v = SETTINGS
    for part in path:gmatch("[^.]+") do
        if type(v) ~= "table" then return default end
        v = v[part]
    end
    if v == nil or v == "" then return default end
    return v
end
