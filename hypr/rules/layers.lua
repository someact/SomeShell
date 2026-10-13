-- Layer surfaces: shell panels, launchers, pickers.

-- Blur on layers samples only the wallpaper: cheaper and steady while windows move
hl.layer_rule({ match = { namespace = ".*" }, xray = true })

-- Instant tools
for _, ns in ipairs({ "selection", "hyprpicker", "noanim", "gtk4-layer-shell" }) do
    hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end

-- CLI fallbacks used when the shell is not running (fuzzel, wlogout)
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })

-- The shell animates its own surfaces (springs), and blurs exactly the
-- notch/pill shapes itself through ext-background-effect, so no layer blur here.
-- No xray either: the glass frosts the real windows behind it, not just the
-- wallpaper (with xray a window behind the island showed wallpaper through it).
for _, ns in ipairs({ "someshell:island", "someshell:pill", "someshell:wallpaper", "someshell:dock", "someshell:overview", "someshell:capture", "someshell:overlay", "someshell:widgets", "someshell:osk", "someshell:lockpreview" }) do
    hl.layer_rule({ match = { namespace = ns }, no_anim = true, xray = false })
end
-- Streamer mode: notification peeks live here and never reach a screen share or recording
hl.layer_rule({ match = { namespace = "someshell:private" }, no_anim = true, no_screen_share = true })
