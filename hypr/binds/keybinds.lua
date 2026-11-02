-- Every keybind. The same keys as v1. Descriptions ("Group: Action") feed the
-- keybind list in the shell; extra binds for the same action have none.
-- Number keys bind by key code, so they work on any layout (US, Thai...).

require("binds.shell")

local NUMBER_CODES = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 } -- 1..9, 0
local KEYPAD_CODES = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 } -- keypad 1..9, 0

--##! Shell
shell_bind("SUPER + Tab", "overview", { description = "Shell: Overview" })
shell_bind("SUPER + N", "control", { description = "Shell: Control panel" })
shell_bind("SUPER + Slash", "keys", { description = "Shell: Keybind list" })
shell_bind("SUPER + K", "osk", { description = "Shell: On-screen keyboard" })
shell_bind("SUPER + M", "media", { description = "Shell: Media" })
shell_bind("SUPER + G", "overlay", { description = "Shell: Game overlay" })
shell_bind("CTRL + ALT + Delete", "power", { description = "Shell: Power" })
shell_bind("SUPER + J", "islandHide", { description = "Shell: Hide the island" })
shell_bind("CTRL + SUPER + T", "wallpaper", { description = "Shell: Change wallpaper" })
shell_bind("CTRL + SUPER + ALT + T", "wallpaperRandom", { description = "Shell: Random wallpaper" })
shell_bind("CTRL + SUPER + SHIFT + D", "lightDark", { description = "Shell: Light or dark" })
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd(SHELL_RESTART), { description = "Shell: Restart" })
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open " .. HYPR_DIR .. "/binds/keybinds.lua"), { description = "Shell: Edit keybinds" })

shell_bind("XF86MonBrightnessUp", "brightnessUp", { locked = true, repeating = true })
shell_bind("XF86MonBrightnessDown", "brightnessDown", { locked = true, repeating = true })
-- Volume through the shell (it shows the level); raising unmutes
shell_bind("XF86AudioRaiseVolume", "volumeUp", { locked = true, repeating = true })
shell_bind("XF86AudioLowerVolume", "volumeDown", { locked = true, repeating = true })

-- Power key (logind leaves it to us, autostart.lua): lock and screens off;
-- with a screen off, turn them on (any key already wakes them, so this
-- press must not turn them off again right away)
local screens_off_by_key = false
hl.bind("XF86PowerOff", function()
    local any_off = false
    for _, m in ipairs(hl.get_monitors()) do
        if not m.dpms_status then any_off = true end
    end
    if any_off or screens_off_by_key then
        hl.dispatch(hl.dsp.dpms({ action = "enable" }))
        screens_off_by_key = false
        return
    end
    screens_off_by_key = true
    hl.dispatch(hl.dsp.exec_cmd("loginctl lock-session; sleep 1; hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'"))
end, { locked = true })

--##! Utilities
shell_bind("SUPER + V", "clipboard", { description = "Utilities: Clipboard history" })
shell_bind("SUPER + Period", "emoji", { description = "Utilities: Emoji" })
shell_bind("SUPER + SHIFT + S", "screenshot", { description = "Utilities: Screenshot a region" })
shell_bind("SUPER + SHIFT + A", "lens", { description = "Utilities: Search a region (Google Lens)" })
shell_bind("SUPER + SHIFT + X", "ocr", { description = "Utilities: Copy text from a region" })
shell_bind("SUPER + SHIFT + T", "translate", { description = "Utilities: Translate a region" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick a color" })

--# Recording
shell_bind("SUPER + SHIFT + R", "recordRegion", { locked = true, description = "Utilities: Record a region" })
shell_bind("SUPER + ALT + R", "recordRegion", { locked = true })
shell_bind("CTRL + ALT + R", "recordScreen", { locked = true, description = "Utilities: Record the screen" })
shell_bind("SUPER + SHIFT + ALT + R", "recordScreenSound", { locked = true, description = "Utilities: Record the screen with sound" })

--# Full screenshot of the focused monitor
local grimMonitor = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(grimMonitor .. " - | wl-copy"), { locked = true, description = "Utilities: Screenshot to clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(
    "d=\"$(xdg-user-dir PICTURES)/Screenshots\" && mkdir -p \"$d\" && f=\"$d/Screenshot_$(LC_ALL=C date '+%Y-%m-%d_%H.%M.%S').png\" && "
    .. grimMonitor .. " \"$f\" && wl-copy < \"$f\""
), { locked = true, description = "Utilities: Screenshot to clipboard and file" })

--##! Screen
local function zoom(delta)
    local z = hl.get_config("cursor:zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
hl.bind("SUPER + Minus", function() zoom(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoom(0.3) end, { repeating = true, description = "Screen: Zoom in" })
hl.bind("SUPER + code:82", function() zoom(-0.3) end, { repeating = true }) -- keypad -
hl.bind("SUPER + code:86", function() zoom(0.3) end, { repeating = true })  -- keypad +

--##! Media
local nextTrack = "playerctl next"
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(nextTrack), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(nextTrack), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:276", hl.dsp.exec_cmd(nextTrack))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play or pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
shell_bind("SUPER + SHIFT + M", "mute", { locked = true, description = "Media: Mute" })
shell_bind("XF86AudioMute", "mute", { locked = true })
shell_bind("SUPER + ALT + M", "micMute", { locked = true, description = "Media: Mute the microphone" })
shell_bind("ALT + XF86AudioMute", "micMute", { locked = true })
shell_bind("XF86AudioMicMute", "micMute", { locked = true })

--##! Window
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

local arrows = { "Left", "Right", "Up", "Down" }
local dirs = { "l", "r", "u", "d" }
for i = 1, 4 do
    hl.bind("SUPER + " .. arrows[i], hl.dsp.focus({ direction = dirs[i] }), { description = "Window: Focus " .. arrows[i]:lower() })
    hl.bind("SUPER + SHIFT + " .. arrows[i], hl.dsp.window.move({ direction = dirs[i] }), { description = "Window: Move " .. arrows[i]:lower() })
end
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + BracketRight", hl.dsp.focus({ direction = "r" }))

hl.bind("ALT + F4", function()
    hl.exec_cmd("notify-send 'Close with Super+Q' 'Alt+F4 is passed on to the app (for Windows VMs)' -a Hyprland")
end, { non_consuming = true })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Force close (click a window)" })

hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true, description = "Window: Narrower split" })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true, description = "Window: Wider split" })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float or tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Window: Tell the app it is fullscreen" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin on every workspace" })
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))

--# Send to workspace 1..10 on this monitor
for i = 1, 10 do
    local send = function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_slot(i), follow = false }))
    end
    hl.bind("SUPER + ALT + code:" .. NUMBER_CODES[i], send, { description = "Window: Send to workspace " .. i })
    hl.bind("SUPER + ALT + code:" .. KEYPAD_CODES[i], send)
end

--# Send to the workspace left or right
for _, keys in ipairs({ "SUPER + SHIFT + mouse_down", "SUPER + ALT + mouse_down", "SUPER + SHIFT + Page_Up", "SUPER + ALT + Page_Up", "CTRL + SUPER + SHIFT + Left" }) do
    hl.bind(keys, hl.dsp.window.move({ workspace = "r-1" }), keys == "SUPER + SHIFT + Page_Up" and { description = "Window: Send to the workspace on the left" } or {})
end
for _, keys in ipairs({ "SUPER + SHIFT + mouse_up", "SUPER + ALT + mouse_up", "SUPER + SHIFT + Page_Down", "SUPER + ALT + Page_Down", "CTRL + SUPER + SHIFT + Right" }) do
    hl.bind(keys, hl.dsp.window.move({ workspace = "r+1" }), keys == "SUPER + SHIFT + Page_Down" and { description = "Window: Send to the workspace on the right" } or {})
end

hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to the scratchpad" })

--##! Workspace
for i = 1, 10 do
    local go = function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_slot(i) }))
    end
    hl.bind("SUPER + code:" .. NUMBER_CODES[i], go, { description = "Workspace: Go to " .. i })
    hl.bind("SUPER + code:" .. KEYPAD_CODES[i], go)
end

hl.bind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Left" })
hl.bind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Right" })
hl.bind("CTRL + SUPER + ALT + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + SUPER + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("CTRL + SUPER + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + mouse_up", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("CTRL + SUPER + BracketLeft", hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + BracketRight", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL + SUPER + Up", hl.dsp.focus({ workspace = "r-5" }))
hl.bind("CTRL + SUPER + Down", hl.dsp.focus({ workspace = "r+5" }))

--## Scratchpad
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Scratchpad" })
hl.bind("CTRL + SUPER + S", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special("special"))

--##! Virtual machines: Super+Alt+F1 passes every key to the VM until pressed again
hl.define_submap("virtual-machine", function()
    hl.bind("SUPER + ALT + F1", function()
        if hl.get_current_submap() == "virtual-machine" then
            hl.exec_cmd("notify-send 'Keybinds back on' 'Left the virtual machine mode' -a Hyprland")
            hl.dispatch(hl.dsp.submap("reset"))
        else
            hl.exec_cmd("notify-send 'Keybinds off' 'Every key goes to the virtual machine. Super+Alt+F1 to leave' -a Hyprland")
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true })
end)

--##! Test notifications
hl.bind("SUPER + ALT + F11", hl.dsp.exec_cmd("notify-send 'Test notification' 'With an action button' -a Hyprland -A 'open=Open' -t 6000"))
hl.bind("SUPER + ALT + F12", hl.dsp.exec_cmd("notify-send 'Test notification' \"With an image from Pictures\" -a 'Hyprland' -h \"string:image-path:$(find ~/Pictures -type f -name '*.jpg' | shuf -n 1)\" -t 6000"))
hl.bind("SUPER + ALT + Equal", hl.dsp.exec_cmd("notify-send 'Urgent notification' 'This one stays' -u critical -a Hyprland"))

--##! Session
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })
hl.bind("CTRL + SHIFT + ALT + SUPER + Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"), { description = "Session: Shut down" })

--##! Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(APPS.terminal), { description = "App: Terminal" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(APPS.terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(APPS.terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(APPS.fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(APPS.browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(APPS.codeEditor), { description = "App: Code editor" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(APPS.textEditor), { description = "App: Text editor" })
hl.bind("CTRL + SUPER + SHIFT + ALT + W", hl.dsp.exec_cmd(APPS.office), { description = "App: Office" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(APPS.volumeMixer), { description = "App: Volume mixer" })
hl.bind("SUPER + I", hl.dsp.exec_cmd(SHELL_SETTINGS), { description = "App: Settings" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(SHELL_SETTINGS))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(APPS.taskManager), { description = "App: Task manager" })
