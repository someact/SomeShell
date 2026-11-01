-- Gaps, borders, rounding, blur and shadows. The only file that sets them.
-- Windows match the island: rounded corners, a thin border in the wallpaper's
-- color on the focused window (generated/colors.lua), small gaps, no dimming.
-- Blur stays available for the few shell surfaces that ask for it; windows
-- are opaque (rules/windows.lua), so they never pay for it.

-- Kept in a table so game mode can turn effects off and back on.
LOOK = {
    blur = {
        enabled = true,
        xray = false,
        new_optimizations = true,
        size = 4,
        passes = 2,
        noise = 0.02,
        contrast = 0.9,
        vibrancy = 0.2,
        popups = false,
    },
    shadow = {
        enabled = true,
        range = 18,
        offset = { 0, 3 },
        render_power = 3,
        color = "rgba(0000002a)",
    },
    animations = true,
}

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 6,
        gaps_workspaces = 50,
        border_size = 2,
        resize_on_border = true,
        allow_tearing = true, -- for the `immediate` game rules
        snap = {
            enabled = true,
            window_gap = 6,
            monitor_gap = 6,
            respect_gaps = true,
        },
    },
    decoration = {
        rounding = 16,
        rounding_power = 2.5,
        active_opacity = 1,
        inactive_opacity = 1,
        dim_inactive = false,
        dim_special = 0.25,
        blur = LOOK.blur,
        shadow = LOOK.shadow,
    },
})
