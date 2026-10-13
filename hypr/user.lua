-- User choices: the defaults below, overridden by the settings app (hypr.json,
-- see the end of this file).

-- Apps
local pick = HYPR_DIR .. "/scripts/launch_first_available.sh"
terminal       = "kitty -1"
fileManager    = "dolphin"
browser        = "zen-browser"
codeEditor     = first_available({ "code", "codium", "zeditor", "antigravity", "kate" })
textEditor     = pick .. " 'kate' 'gnome-text-editor' 'emacs'"
officeSoftware = pick .. " 'wps' 'onlyoffice-desktopeditors' 'libreoffice'"
volumeMixer    = pick .. " 'pavucontrol-qt' 'pavucontrol'"
taskManager    = "kitty -1 btop"

-- SUPER+1..0 address workspaces inside groups of this size.
workspaceGroupSize = 10

-- Glass: translucent terminals, chat and editors with frosted blur.
-- false = every window opaque, blur only on shell surfaces (your current look).
glass = false
-- Fast glass (with glass = true): window blur samples only the wallpaper, so it
-- is cached instead of redone whenever something behind a window changes. Tiled
-- windows look the same; a floating glass window over another window shows the
-- wallpaper behind it instead of that window.
fastGlass = false

-- Liquid glass (hyprglass plugin, see core/liquidglass.lua): refraction and an
-- edge light on the island, pills, dock and keyboard. Build it once with
-- scripts/hyprglass.sh. Presets: pomme (Apple-like), clear, subtle, glass, high_contrast.
liquidGlass = false
liquidGlassPreset = "pomme"
liquidGlassWindows = false   -- also on translucent windows (with glass = true)

-- Game mode: turn off blur, shadows and animations while a game is fullscreen.
gameModeAuto = true

-- Settings app overrides (Appearance, Modes and Apps pages)
glass = setting("glass", glass)
fastGlass = setting("fastGlass", fastGlass)
liquidGlass = setting("liquidGlass", liquidGlass)
liquidGlassPreset = setting("liquidGlassPreset", liquidGlassPreset)
liquidGlassWindows = setting("liquidGlassWindows", liquidGlassWindows)
gameModeAuto = setting("gameModeAuto", gameModeAuto)
for _, name in ipairs({ "terminal", "fileManager", "browser", "codeEditor", "textEditor", "officeSoftware", "volumeMixer", "taskManager" }) do
    _G[name] = setting("apps." .. name, _G[name])
end
