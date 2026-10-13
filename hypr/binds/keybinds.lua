-- Keybinds, ported 1:1 from the ii config (hyprland/keybinds.lua + custom/keybinds.lua).
-- Changes vs. ii:
--   * shell binds go through shell_bind() (binds/shell.lua): global shortcut + CLI fallback
--   * SUPER+ALT+number also binds raw keycodes, so it works on the Thai layout
--   * SUPER+ALT+Page_Down/Up use the canonical key names
--   * touchpad gestures live in core/input.lua; removed: the edit-custom-keybinds
--     shortcut now opens this file
-- Description strings feed the cheatsheet; keep the "Group: Action" format.

require("binds.shell")

--##! Shell
shell_bind("SUPER + SUPER_L", "search", { description = "Shell: Toggle search" })
shell_bind("SUPER + SUPER_R", "search")
shell_bind("SUPER_L", "superKey", { ignore_mods = true, transparent = true })
shell_bind("SUPER_R", "superKey", { ignore_mods = true, transparent = true })
shell_bind("SUPER_L", "superKey", { ignore_mods = true, transparent = true, release = true })
shell_bind("SUPER_R", "superKey", { ignore_mods = true, transparent = true, release = true })
shell_bind("SUPER + Tab", "overview", { description = "Shell: Toggle overview" })
shell_bind("SUPER + N", "sidebar", { description = "Shell: Toggle right sidebar" })
shell_bind("SUPER + Slash", "cheatsheet", { description = "Shell: Toggle cheatsheet" })
shell_bind("SUPER + K", "osk", { description = "Shell: Toggle on-screen keyboard" })
shell_bind("SUPER + M", "media", { description = "Shell: Toggle media controls" })
shell_bind("SUPER + G", "overlay", { description = "Shell: Toggle widget overlay" })
shell_bind("CTRL + ALT + Delete", "session", { description = "Shell: Toggle session menu" })
shell_bind("SUPER + J", "bar", { description = "Shell: Toggle bar" })
shell_bind("CTRL + SUPER + T", "wallpaper", { description = "Shell: Change wallpaper" })
shell_bind("CTRL + SUPER + ALT + T", "wallpaperRandom", { description = "Shell: Random wallpaper" })
shell_bind("CTRL + SUPER + SHIFT + D", "lightDark", { description = "Shell: Toggle light/dark mode" })
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd(shell_command("restart")), { description = "Shell: Restart widgets" })
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open " .. HYPR_DIR .. "/binds/keybinds.lua"), { description = "Shell: Edit keybinds" })

local qsIpcCall = "qs -c someshell ipc call"
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(qsIpcCall .. " brightness increment || brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qsIpcCall .. " brightness decrement || brightnessctl s 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"), { locked = true, repeating = true })

--##! Utilities
shell_bind("SUPER + V", "clipboard", { description = "Utilities: Clipboard history >> clipboard" })
shell_bind("SUPER + Period", "emoji", { description = "Utilities: Emoji >> clipboard" })
shell_bind("SUPER + SHIFT + S", "regionScreenshot", { description = "Utilities: Screen snip" })
shell_bind("SUPER + SHIFT + A", "regionSearch", { description = "Utilities: Google Lens" })
shell_bind("SUPER + SHIFT + X", "regionOcr", { description = "Utilities: Character recognition >> clipboard" })
shell_bind("SUPER + SHIFT + T", "screenTranslate", { description = "Utilities: Translate screen content" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick color #RRGGBB >> clipboard" })

--# Recording
shell_bind("SUPER + SHIFT + R", "regionRecord", { locked = true, description = "Utilities: Record region (no sound)" })
shell_bind("SUPER + ALT + R", "regionRecord", { locked = true })
shell_bind("CTRL + ALT + R", "screenRecord", { locked = true })
shell_bind("SUPER + SHIFT + ALT + R", "screenRecordSound", { locked = true, description = "Utilities: Record screen (with sound)" })

--# Fullscreen screenshot
local grimMonitor = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(grimMonitor .. " - | wl-copy"), { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(
    "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && " ..
    grimMonitor .. " $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
), { locked = true, non_consuming = true, description = "Utilities: Screenshot >> clipboard & file" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(grimMonitor .. " - | wl-copy"), { locked = true, non_consuming = true })

--##! Screen
--# Zoom, clamped to 1.0 .. 3.0
local function zoom(delta)
    local z = hl.get_config("cursor:zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
hl.bind("SUPER + Minus", function() zoom(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoom(0.3) end, { repeating = true, description = "Screen: Zoom in" })
hl.bind("SUPER + code:82", function() zoom(-0.3) end, { repeating = true }) -- keypad -
hl.bind("SUPER + code:86", function() zoom(0.3) end, { repeating = true })  -- keypad +

--##! Media
local mediaNext = "playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(mediaNext), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(mediaNext), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:276", hl.dsp.exec_cmd(mediaNext))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play/pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true, description = "Media: Toggle mute" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true, description = "Media: Toggle mic" })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

--##! Window
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

local arrows = { "Left", "Right", "Up", "Down" }
local dirs = { "l", "r", "u", "d" }
for i = 1, 4 do
    hl.bind("SUPER + " .. arrows[i], hl.dsp.focus({ direction = dirs[i] }), { description = "Window: Focus " .. arrows[i] })
    hl.bind("SUPER + SHIFT + " .. arrows[i], hl.dsp.window.move({ direction = dirs[i] }), { description = "Window: Move " .. arrows[i] })
end
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + BracketRight", hl.dsp.focus({ direction = "r" }))

hl.bind("ALT + F4", function()
    hl.exec_cmd("notify-send \"Wrong close keybind\" \"Super+Q to close. Use Alt+F4 for Windows VMs\" -a Hyprland")
end, { non_consuming = true })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Forcefully zap a window" })

hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Window: Fullscreen spoof" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin" })
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))

--# Send to workspace N of the current group (number row, raw keycodes for the Thai layout, keypad)
local numberCodes = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
local keypadCodes = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
-- On the US layout the key-name bind and its code: bind both fire for one press;
-- run the action once, or the second move takes the window that got focus next.
local function once_per_press(fn)
    local busy = false
    return function()
        if busy then return end
        busy = true
        hl.timer(function() busy = false end, { timeout = 50, type = "oneshot" })
        fn()
    end
end
for i = 1, 10 do
    local send = once_per_press(function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end)
    hl.bind("SUPER + ALT + " .. (i % 10), send, { description = "Window: Send to workspace " .. i })
    hl.bind("SUPER + ALT + code:" .. numberCodes[i], send)
    hl.bind("SUPER + ALT + code:" .. keypadCodes[i], send)
end

--# Send to the workspace left/right
hl.bind("SUPER + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("SUPER + SHIFT + mouse_up", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("SUPER + ALT + mouse_down", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("SUPER + ALT + mouse_up", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Window: Send to workspace left" })
hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Window: Send to workspace right" })
hl.bind("SUPER + ALT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("SUPER + ALT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("CTRL + SUPER + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + SHIFT + Left", hl.dsp.window.move({ workspace = "r-1" }))

hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to scratchpad" })

--##! Workspace
for i = 1, 10 do
    local go = once_per_press(function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end)
    hl.bind("SUPER + " .. (i % 10), go, { description = "Workspace: Focus " .. i })
    hl.bind("SUPER + code:" .. numberCodes[i], go)
    hl.bind("SUPER + code:" .. keypadCodes[i], go)
end

hl.bind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Focus left" })
hl.bind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Focus right" })
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
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle scratchpad" })
hl.bind("CTRL + SUPER + S", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special("special"))

--##! Virtual machines: SUPER+ALT+F1 passes every key through to the VM
hl.define_submap("virtual-machine", function()
    hl.bind("SUPER + ALT + F1", function()
        local current = hl.get_current_submap()
        if current == "virtual-machine" then
            hl.dispatch(hl.dsp.exec_cmd("notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("reset"))
        elseif current == "" then
            hl.dispatch(hl.dsp.exec_cmd("notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. hit SUPER+ALT+F1 to escape' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true })
end)

--##! Testing notifications
hl.bind("SUPER + ALT + F11", hl.dsp.exec_cmd(
    "bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | shuf -n 1); ACTION=$(notify-send \"Test notification with body image\" \"This notification should contain your user account <b>image</b> and <a href=\\\"https://discord.com/app\\\">Discord</a> <b>icon</b>. Oh and here is a random image in your Pictures folder: <img src=\\\"$RANDOM_IMAGE\\\" alt=\\\"Testing image\\\"/>\" -a \"Hyprland\" -p -h \"string:image-path:/var/lib/AccountsService/icons/$USER\" -t 6000 -i \"discord\" -A \"openImage=Profile image\" -A \"action2=Open the random image\" -A \"action3=Useless button\"); [[ $ACTION == *openImage ]] && xdg-open \"/var/lib/AccountsService/icons/$USER\"; [[ $ACTION == *action2 ]] && xdg-open \"$RANDOM_IMAGE\"'"))
hl.bind("SUPER + ALT + F12", hl.dsp.exec_cmd(
    "bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | shuf -n 1); ACTION=$(notify-send \"Test notification\" \"This notification should contain a random image in your <b>Pictures</b> folder and <a href=\\\"https://discord.com/app\\\">Discord</a> <b>icon</b>.\n<i>Flick right to dismiss!</i>\" -a \"Discord (fake)\" -p -h \"string:image-path:$RANDOM_IMAGE\" -t 6000 -i \"discord\" -A \"openImage=Profile image\" -A \"action2=Useless button\"); [[ $ACTION == *openImage ]] && xdg-open \"/var/lib/AccountsService/icons/$USER\"'"))
hl.bind("SUPER + ALT + Equal", hl.dsp.exec_cmd("notify-send 'Urgent notification' 'Ah hell no' -u critical -a 'Hyprland keybind'"))

--##! Session
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })
hl.bind("CTRL + SHIFT + ALT + SUPER + Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"), { description = "Session: Shut down" })

--##! Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind("CTRL + SUPER + SHIFT + ALT + W", hl.dsp.exec_cmd(officeSoftware), { description = "App: Office software" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })
hl.bind("SUPER + I", hl.dsp.exec_cmd(shell_command("settings")), { description = "App: Settings app" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(shell_command("settings")))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskManager), { description = "App: Task manager" })
