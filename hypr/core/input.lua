-- Keyboard, mouse, touchpad and pen tablet.

hl.config({
    input = {
        -- Add layouts in hypr.json (hyprland.input.kb_layout, e.g. "us,th");
        -- install.sh keeps the ones the machine already used. SUPER+Space switches
        kb_layout = "us",
        kb_options = "grp:win_space_toggle",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,
        off_window_axis_events = 2,

        -- Laptops; ignored without a touchpad. Settings → Hyprland → Touchpad
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = false,
            clickfinger_behavior = true,  -- two-finger click = right, three = middle
            scroll_factor = 0.7,
        },
    },
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true,
    },
})

-- Touchpad gestures (hypr.json touchpad.gestures, on by default). Without a
-- touchpad they never fire.
if setting("touchpad.gestures", true) then
    local function overview() hl.dispatch(hl.dsp.global("someshell:overviewToggle")) end
    hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen" })
    hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 4, direction = "up", action = overview })
    hl.gesture({ fingers = 4, direction = "down", action = overview })
end

-- UGTablet 10" pen (254 x 158.75 mm, 16:10) on a 16:9 monitor; the rule only
-- matches that tablet.
-- The active area is trimmed to 254 x 142.9 mm and centred vertically so the
-- pen keeps the screen's aspect ratio: circles stay circles in Clip Studio and Krita.
hl.device({
    name = "ugtablet-10-inch-pentablet-pen",
    active_area_size = { 254, 142.9 },
    active_area_position = { 0, 7.9 },
})
