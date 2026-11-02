-- Shell actions. Each is a global shortcut the shell registers under the app
-- id "someshell" (someshell:<name>). While the shell is not running (crashed,
-- restarting, being rebuilt) a few actions fall back to a plain tool.

local ocr = "f=$(mktemp --tmpdir=\"${XDG_RUNTIME_DIR:-/tmp}\" someshell-ocr.XXXXXX.png) && grim -g \"$(slurp)\" \"$f\" && "
    .. "tesseract \"$f\" stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | paste -sd+) | wl-copy; rm -f \"$f\""

local FALLBACK = {
    island          = "pkill fuzzel || fuzzel",
    clipboard       = "pkill fuzzel || cliphist list | fuzzel --dmenu | cliphist decode | wl-copy",
    power           = "pkill wlogout || wlogout -p layer-shell",
    screenshot      = "pidof slurp || grim -g \"$(slurp)\" - | wl-copy",
    ocr             = "pidof slurp || " .. ocr,
    screenshotScreen = "d=\"$(xdg-user-dir PICTURES)/Screenshots\" && mkdir -p \"$d\" && f=\"$d/Screenshot_$(LC_ALL=C date '+%Y-%m-%d_%H.%M.%S').png\" && "
        .. "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" \"$f\" && wl-copy < \"$f\"",
    brightnessUp    = "brightnessctl s 5%+",
    brightnessDown  = "brightnessctl s 5%-",
    volumeUp        = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.5",
    volumeDown      = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    mute            = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    micMute         = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
}

-- The shell is up while its island layer exists. Checked in Lua, so a key
-- press starts no process when the shell is running.
local function shell_alive()
    return #hl.get_layers({ namespace = "someshell:island" }) > 0
end

function shell_action(name)
    if shell_alive() then
        hl.dispatch(hl.dsp.global("someshell:" .. name))
    elseif FALLBACK[name] then
        hl.dispatch(hl.dsp.exec_cmd(FALLBACK[name]))
    end
end

-- Bind `keys` to a shell action; `opts` are normal hl.bind options.
function shell_bind(keys, name, opts)
    hl.bind(keys, function() shell_action(name) end, opts or {})
end

-- Super tap opens the island. Super alone, pressed and released within
-- 450 ms: Hyprland does not report the release after a combo (Super+1,
-- Super+drag), and the timer covers a long hold. Both binds are
-- non-consuming, so apps always see Super go down and come back up
-- (v1 swallowed them, which left apps like Blender with a stuck Super).
local tap = { id = 0, armed = false }
local function super_down()
    tap.id = tap.id + 1
    local id = tap.id
    tap.armed = true
    hl.timer(function() if tap.id == id then tap.armed = false end end, { timeout = 450, type = "oneshot" })
end
local function super_up()
    if tap.armed then
        tap.armed = false
        shell_action("island")
    end
end
for _, key in ipairs({ "SUPER_L", "SUPER_R" }) do
    hl.bind(key, super_down, { ignore_mods = true, transparent = true, non_consuming = true })
    hl.bind("SUPER + " .. key, super_up, { release = true, non_consuming = true, description = "Shell: Open the island" })
end

SHELL_RESTART = "qs kill -c someshell; " .. SCRIPTS .. "/shell.sh"
SHELL_SETTINGS = "qs -c someshell ipc call settings open"
