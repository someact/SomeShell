-- Keybind changes from the settings app (~/.config/someshell/keybinds.json):
--   overrides: { ["SUPER + V"] = { keys = "SUPER + B" } }  or  { disabled = true }
--   custom:    [ { keys, command, description, enabled } ]
--
-- keybinds.lua stays a 1:1 port. While it runs, hl.bind is wrapped so a
-- remapped combo binds to its new keys and a disabled one is skipped; every
-- bind of that combo follows (press and release halves alike). UserBinds.finish()
-- then restores hl.bind and adds the custom binds plus the key-recording submap.
-- A bad entry is skipped and listed in USER_BINDS_ERRORS instead of breaking the config.

local data, err = JSON.read(SOMESHELL_DIR .. "/keybinds.json")
data = type(data) == "table" and data or {}
USER_BINDS_ERRORS = {}
if err and err ~= "missing" then table.insert(USER_BINDS_ERRORS, "keybinds.json: " .. err) end

local MODS = { SUPER = "SUPER", WIN = "SUPER", MOD4 = "SUPER", LOGO = "SUPER", CTRL = "CTRL", CONTROL = "CTRL", ALT = "ALT", MOD1 = "ALT", SHIFT = "SHIFT" }
local ORDER = { "SUPER", "CTRL", "ALT", "SHIFT" }

-- "ctrl + Super + t" -> "SUPER + CTRL + t": modifiers in a fixed order, key lowercased.
-- Same rule as shell/settings/KeybindStore.qml, so both sides agree on identity.
function normalize_keys(keys)
    local parts = {}
    for part in tostring(keys):gmatch("[^+]+") do
        parts[#parts + 1] = part:match("^%s*(.-)%s*$")
    end
    local key = table.remove(parts) or ""
    local have = {}
    for _, p in ipairs(parts) do
        local m = MODS[p:upper()]
        if m then have[m] = true end
    end
    local out = {}
    for _, m in ipairs(ORDER) do
        if have[m] then out[#out + 1] = m end
    end
    out[#out + 1] = key:lower()
    return table.concat(out, " + ")
end

local overrides = {}
for k, v in pairs(type(data.overrides) == "table" and data.overrides or {}) do
    if type(v) == "table" then overrides[normalize_keys(k)] = v end
end

local bind = hl.bind
hl.bind = function(keys, dsp, opts)
    local o = overrides[normalize_keys(keys)]
    if o then
        if o.disabled then return nil end
        if type(o.keys) == "string" and o.keys ~= "" then
            local ok, res = pcall(bind, o.keys, dsp, opts)
            if ok then return res end
            table.insert(USER_BINDS_ERRORS, keys .. " -> " .. o.keys .. ": " .. tostring(res))
        end
    end
    return bind(keys, dsp, opts)
end

UserBinds = {}

function UserBinds.finish()
    hl.bind = bind
    for _, b in ipairs(type(data.custom) == "table" and data.custom or {}) do
        if type(b) == "table" and b.enabled ~= false and type(b.keys) == "string" and type(b.command) == "string" and b.command ~= "" then
            local desc = (type(b.description) == "string" and b.description ~= "") and b.description or b.command
            local ok, res = pcall(bind, b.keys, hl.dsp.exec_cmd(b.command), { description = "Custom: " .. desc })
            if not ok then table.insert(USER_BINDS_ERRORS, b.keys .. ": " .. tostring(res)) end
        end
    end

    -- The settings app enters this submap while recording a shortcut, so combos
    -- that are already bound reach it instead of firing. It leaves on its own;
    -- CTRL + ALT + Escape is the way out if it ever cannot.
    hl.define_submap("someshell-record", function()
        bind("CTRL + ALT + Escape", hl.dsp.submap("reset"))
    end)
end
