-- Focus follows the mouse after a workspace switch.
--
-- Hyprland gives a workspace back the window that last had focus there, even
-- when the mouse rests on another window; keys then go to a window you are
-- not looking at until the mouse moves. After every workspace change this
-- focuses the window under the mouse instead (floating and pinned windows
-- first, since they are on top). With the mouse over no window, Hyprland's
-- choice stays.

local function vec(v)
    if type(v) == "table" then return v.x or v[1] or 0, v.y or v[2] or 0 end
    return 0, 0
end

local function under(w, cx, cy)
    if w.hidden or w.mapped == false then return false end
    local x, y = vec(w.at)
    local wd, ht = vec(w.size)
    return cx >= x and cx < x + wd and cy >= y and cy < y + ht
end

function window_under_cursor()
    local c = hl.get_cursor_pos()
    if not c then return nil end
    local monitor = hl.get_monitor_at_cursor()
    if not monitor then return nil end

    local candidates = {}
    local function add(list, floating)
        for _, w in ipairs(list or {}) do
            if (w.floating or w.pinned) == floating then candidates[#candidates + 1] = w end
        end
    end
    -- An open special workspace (scratchpad) covers the normal one
    local special = hl.get_active_special_workspace(monitor.name)
    if special then
        add(hl.get_workspace_windows(special.id), true)
        add(hl.get_workspace_windows(special.id), false)
    else
        local ws = hl.get_active_workspace(monitor.name)
        if not ws then return nil end
        local list = hl.get_workspace_windows(ws.id) or {}
        for _, w in ipairs(hl.get_windows() or {}) do
            if w.pinned then list[#list + 1] = w end
        end
        add(list, true)
        add(list, false)
    end

    for _, w in ipairs(candidates) do
        if under(w, c.x, c.y) then return w end
    end
    return nil
end

local function focus_under_cursor()
    local w = window_under_cursor()
    if w and not w.active then
        -- Focusing a window normally moves the mouse to its centre; the mouse
        -- is already on it, so keep it exactly where it is
        local no_warps = hl.get_config("cursor:no_warps")
        hl.config({ cursor = { no_warps = true } })
        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
        hl.config({ cursor = { no_warps = no_warps == true } })
    end
end

hl.on("workspace.active", focus_under_cursor)
hl.on("workspace.special_active", focus_under_cursor)
