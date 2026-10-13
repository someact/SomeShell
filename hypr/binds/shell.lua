-- Shell actions: the global shortcut the shell registers under appid
-- "someshell", plus an optional CLI fallback that runs only while the shell is
-- not running (crashed, restarting, or killed by hand).

local scripts = HYPR_DIR .. "/scripts"

local ocr = "grim -g \"$(slurp $SLURP_ARGS)\" /tmp/ocr_image.png && "
    .. "tesseract /tmp/ocr_image.png stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | paste -sd+) | wl-copy; "
    .. "rm -f /tmp/ocr_image.png"

SHELL_ACTIONS = {
    search           = { name = "searchToggleRelease", fallback = "pkill fuzzel || fuzzel" },
    superKey         = { name = "superKey" },
    overview         = { name = "overviewToggle" },
    clipboard        = { name = "clipboardToggle",
                         fallback = "pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy" },
    emoji            = { name = "emojiToggle", fallback = "pkill fuzzel || " .. scripts .. "/fuzzel-emoji.sh copy" },
    sidebar          = { name = "controlToggle" },
    cheatsheet       = { name = "keysToggle" },
    osk              = { name = "oskToggle" },
    media            = { name = "mediaToggle" },
    overlay          = { name = "overlayToggle" },
    session          = { name = "powerToggle", fallback = "pkill wlogout || wlogout -p layer-shell" },
    bar              = { name = "islandHideToggle" },
    wallpaper        = { name = "wallpaperToggle" },
    wallpaperRandom  = { name = "wallpaperRandom" },
    lightDark        = { name = "toggleLightDark" },
    regionScreenshot = { name = "regionScreenshot",
                         fallback = "pidof slurp || hyprshot --freeze --clipboard-only --mode region --silent" },
    regionSearch     = { name = "regionSearch", fallback = "pidof slurp || " .. scripts .. "/snip_to_search.sh" },
    regionOcr        = { name = "regionOcr", fallback = "pidof slurp || " .. ocr },
    screenTranslate  = { name = "screenTranslate" },
    regionRecord     = { name = "regionRecord", fallback = scripts .. "/record.sh" },
    screenRecord     = { name = "screenRecord", fallback = scripts .. "/record.sh --fullscreen" },
    screenRecordSound = { name = "screenRecordSound", fallback = scripts .. "/record.sh --fullscreen --sound" },
}

-- Shell commands that are not global shortcuts
SHELL_COMMANDS = {
    restart  = "killall qs quickshell; qs -c someshell &",
    settings = "qs -c someshell ipc call settings open",
}

-- The shell is up while its island layer exists (one per screen, also in game
-- mode). Checked in Lua, so a key press starts no process unless the shell is down.
local function shell_alive()
    return #hl.get_layers({ namespace = "someshell:island" }) > 0
end

-- Bind `keys` to a shell action. `opts` are normal hl.bind options; the
-- description is attached only to the first bind so cheatsheets list it once.
function shell_bind(keys, action, opts)
    local a = SHELL_ACTIONS[action]
    assert(a, "unknown shell action: " .. action)
    opts = opts or {}
    if a.name then
        hl.bind(keys, hl.dsp.global("someshell:" .. a.name), opts)
        if a.fallback then
            local quiet = {}
            for k, v in pairs(opts) do
                if k ~= "description" then quiet[k] = v end
            end
            local fallback = a.fallback
            hl.bind(keys, function()
                if not shell_alive() then hl.dispatch(hl.dsp.exec_cmd(fallback)) end
            end, quiet)
        end
    elseif a.fallback then
        hl.bind(keys, hl.dsp.exec_cmd(a.fallback), opts)
    end
end

function shell_command(name)
    return SHELL_COMMANDS[name]
end
