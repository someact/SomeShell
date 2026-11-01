-- Game mode: while a game is the focused fullscreen window, blur, shadows and
-- animations are off so the compositor does as little as possible. Everything
-- comes back as soon as the game loses focus or leaves fullscreen.
--
-- Runs inside Hyprland, driven by its own events (no polling). From anywhere:
--   hyprctl eval 'GameMode.toggle()'   force on or off
--   hyprctl eval 'GameMode.auto()'     back to automatic
--   hyprctl repl 'return GameMode.active'
-- The shell hears changes as a `custom>>someshell_gamemode,<0|1>` event and
-- may pass gamemoded's client PIDs with GameMode.set_clients({ ... }).

GameMode = { active = false, forced = nil, clients = {} }

local function is_game(w)
    if w == nil or matches_any(w.class, NOT_GAME_CLASS_PATTERNS) then return false end
    if GameMode.clients[w.pid] then return true end
    if (w.fullscreen or 0) < 2 then return false end
    return next(GameMode.clients) ~= nil
        or w.content_type == "game"
        or matches_any(w.class, GAME_CLASS_PATTERNS)
        or matches_any(w.title, GAME_TITLE_PATTERNS)
end

local function apply(on)
    if on == GameMode.active then return end
    GameMode.active = on
    hl.dispatch(hl.dsp.event("someshell_gamemode," .. (on and "1" or "0")))
    hl.config({
        decoration = {
            blur = { enabled = not on and LOOK.blur.enabled },
            shadow = { enabled = not on and LOOK.shadow.enabled },
        },
        animations = { enabled = not on and LOOK.animations },
    })
end

local function evaluate()
    if GameMode.forced ~= nil then
        apply(GameMode.forced)
    elseif GAME_MODE_AUTO then
        apply(is_game(hl.get_active_window()))
    end
end

function GameMode.toggle()
    GameMode.forced = not GameMode.active
    evaluate()
    return GameMode.active
end

function GameMode.auto()
    GameMode.forced = nil
    evaluate()
    return GameMode.active
end

-- pids: the full list of gamemoded clients, sent again on every change
function GameMode.set_clients(pids)
    GameMode.clients = {}
    for _, pid in ipairs(pids or {}) do GameMode.clients[pid] = true end
    evaluate()
    return GameMode.active
end

for _, event in ipairs({ "window.fullscreen", "window.active", "window.destroy", "workspace.active" }) do
    hl.on(event, evaluate)
end
-- A reload restarts this file with game mode off and sends no event, so the
-- shell rereads GameMode.active after `configreloaded`. Dispatching from this
-- handler would crash `Hyprland --verify-config`, which runs it too.
hl.on("config.reloaded", evaluate)
