-- Keyboard, mouse, touchpad, gestures and pen tablets.

hl.config({
    input = {
        -- More layouts come from the settings window (e.g. "us,th"); Super+Space switches
        kb_layout = "us",
        kb_options = "grp:win_space_toggle",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,
        off_window_axis_events = 2,

        -- Ignored without a touchpad
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = false,
            clickfinger_behavior = true, -- two fingers = right click, three = middle
            scroll_factor = 0.7,
        },
    },
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_create_new = true,
    },
})

-- Touchpad gestures; they never fire without a touchpad.
if setting("touchpad.gestures", true) then
    local function overview() hl.dispatch(hl.dsp.global("someshell:overview")) end
    hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 4, direction = "up", action = overview })
end

-- Pen tablets and other devices, from the settings window (hypr.json
-- "devices": a list of hl.device tables with a `name`). Nothing is hardcoded
-- here, so a tablet on another machine needs no edit of this file.
for _, device in ipairs(setting("devices", {})) do
    if type(device) == "table" and type(device.name) == "string" then
        hl.device(device)
    end
end
