-- SomeShell: Hyprland entry point.
--
-- Every setting lives in exactly one file, loaded in this order, so nothing
-- silently overrides anything else. Machine-written files come last:
--   generated/colors.lua    matugen, from the wallpaper
--   generated/monitors.lua  the settings window (per machine)
--   core/settings.lua       options changed in the settings window (hypr.json)

require("lib.util")
require("apps")

require("core.env")
require("core.input")
require("core.look")
require("core.motion")
require("core.misc")

require("rules.windows")
require("rules.apps")
require("rules.games")
require("rules.layers")

require("binds.keybinds")
require("modes.gamemode")
require("core.autostart")

if not require_optional("generated.colors") then
    require("core.colors_default")
end
-- Outputs the monitors file does not name get their fastest mode, so a new
-- machine does not start at 60 Hz on a high-refresh panel.
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })
require_optional("generated.monitors")
require("core.settings")
