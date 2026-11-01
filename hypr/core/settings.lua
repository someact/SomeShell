-- Hyprland options changed in the settings window (hypr.json "hyprland": a
-- partial hl.config table). Loaded last, so it wins over the defaults in core/.

local opts = SETTINGS.hyprland
if type(opts) ~= "table" or next(opts) == nil then return end

hl.config(opts)

-- Game mode restores effects from LOOK when a game closes; keep it in step
local d = opts.decoration or {}
if type(d.blur) == "table" and d.blur.enabled ~= nil then LOOK.blur.enabled = d.blur.enabled end
if type(d.shadow) == "table" and d.shadow.enabled ~= nil then LOOK.shadow.enabled = d.shadow.enabled end
if type(opts.animations) == "table" and opts.animations.enabled ~= nil then LOOK.animations = opts.animations.enabled end
