-- Layout, focus, render and cursor settings.

hl.config({
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- Adaptive sync only for fullscreen apps (games); the desktop stays at a
        -- fixed refresh rate so the cursor and animations never judder.
        vrr = 2,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        -- A window opened over a fullscreen one takes it out of fullscreen
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        initial_workspace_tracking = false,
        focus_on_activate = true,
    },

    render = {
        -- Direct scanout only for windows that say they are games (fewer NVIDIA glitches)
        direct_scanout = 2,
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true,
        -- Switching to the workspace you are on does nothing (no jump back)
        workspace_back_and_forth = false,
    },

    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
        hotspot_padding = 1,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})
