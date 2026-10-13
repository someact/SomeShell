-- SomeShell: Hyprland entry point.
--
-- Load order is fixed and every setting has exactly one home, so nothing
-- silently overrides anything else. Machine-written files load last:
--   generated/colors.lua    matugen (wallpaper colors)
--   generated/monitors.lua  install.sh and the settings app's Displays page (per machine)
--   core/settings.lua       settings app choices (~/.config/someshell/hypr.json)

require("lib.util")
require("user")

require("core.env")
require("core.input")
require("core.look")
require("core.motion")
require("core.misc")

require("rules.windows")
require("rules.media")
require("rules.art")
require("rules.gaming")
require("rules.layers")
require("core.liquidglass")

require("binds.user")      -- keybinds.json: remaps apply while keybinds.lua binds
require("binds.keybinds")
UserBinds.finish()
require("modes.gamemode")
require("core.execs")

if not require_optional("generated.colors") then
    require("core.colors_default")
end
-- Any output the monitors file does not name: its fastest mode, so a new machine
-- does not start at 60 Hz on a high-refresh panel.
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })
require_optional("generated.monitors")
require("core.settings")
