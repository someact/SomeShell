-- Game mode: while a game is the focused fullscreen window, turn off blur,
-- shadows and animations so the compositor does as little work as possible.
-- Everything is restored as soon as focus leaves the game or it exits fullscreen.
--
-- gamemoded clients also count: the shell watches gamemoded's D-Bus signals
-- (no polling) and hands over the registered PIDs with GameMode.set_clients().
-- A focused window owned by one of them is a game even when windowed, and any
-- fullscreen window is while a client is registered (Proton PIDs may differ).
--
-- Runs inside Hyprland (no extra process). Manual control from anywhere:
--   hyprctl eval 'GameMode.toggle()'   force on/off
--   hyprctl eval 'GameMode.auto()'     back to automatic
--   hyprctl eval 'GameMode.overlay(true)'  blur on for the game overlay (the shell does this)
--   hyprctl repl 'return GameMode.active'
-- The shell follows changes through a socket2 `custom` event, see apply().

GameMode = { active = false, forced = nil, clients = {}, overlay_open = false }

local function is_game(w)
    if w == nil or matches_any(w.class, NOT_GAME_CLASS_PATTERNS) then return false end
    if GameMode.clients[w.pid] then return true end
    if (w.fullscreen or 0) < 2 then return false end
    return next(GameMode.clients) ~= nil
        or w.content_type == "game"
        or matches_any(w.class, GAME_CLASS_PATTERNS)
        or matches_any(w.title, GAME_TITLE_PATTERNS)
end

-- Tell the shell (socket2 `custom>>someshell_gamemode,1`) so it never has to poll
local function announce()
    hl.dispatch(hl.dsp.event("someshell_gamemode," .. (GameMode.active and "1" or "0")))
end

local function apply(on)
    if on == GameMode.active then return end
    GameMode.active = on
    announce()
    if on then
        hl.config({
            decoration = { blur = { enabled = GameMode.overlay_open and look.blur.enabled }, shadow = { enabled = false } },
            animations = { enabled = false },
        })
    else
        hl.config({
            decoration = { blur = { enabled = look.blur.enabled }, shadow = { enabled = look.shadow.enabled } },
            animations = { enabled = look.animations ~= false },
        })
    end
end

local function evaluate()
    if GameMode.forced ~= nil then
        apply(GameMode.forced)
    elseif gameModeAuto then
        apply(is_game(hl.get_active_window()))
    end
end

function GameMode.toggle()
    GameMode.forced = not GameMode.active
    evaluate()
    return GameMode.active
end

-- pids: list of gamemoded client PIDs (the shell sends the full list on every change)
function GameMode.set_clients(pids)
    GameMode.clients = {}
    for _, pid in ipairs(pids or {}) do GameMode.clients[pid] = true end
    evaluate()
    return GameMode.active
end

-- The Super+G overlay frosts its cards over the game: blur comes back while it
-- is open (only the shell's cards ask for it; the game itself is opaque).
function GameMode.overlay(open)
    GameMode.overlay_open = open == true
    if GameMode.active then
        hl.config({ decoration = { blur = { enabled = GameMode.overlay_open and look.blur.enabled } } })
    end
    return GameMode.overlay_open
end

function GameMode.auto()
    GameMode.forced = nil
    evaluate()
    return GameMode.active
end

for _, event in ipairs({ "window.fullscreen", "window.active", "window.destroy", "workspace.active" }) do
    hl.on(event, evaluate)
end
-- A reload starts this file again with game mode off (a forced mode is
-- dropped), so the shell is told the state even when nothing changed here;
-- otherwise it would keep showing the mode from before the reload.
hl.on("config.reloaded", function()
    evaluate()
    announce()
end)
