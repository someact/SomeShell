-- Games: tearing allowed (lowest latency), no effects, marked as "game" content
-- so direct scanout and adaptive sync can work. The same list, as Lua
-- patterns, tells game mode (modes/gamemode.lua) what a game is.

local function game(match)
    hl.window_rule({ match = match, immediate = true, no_anim = true, no_shadow = true, content = "game", idle_inhibit = "fullscreen" })
end

game({ class = "^(steam_app_).*" })                                  -- Steam, Proton and native
game({ class = "^(gamescope)$" })
game({ class = "^(genshinimpact\\.exe|starrail\\.exe|zenlesszonezero\\.exe|client-win64-shipping\\.exe|bh3\\.exe)$" })
game({ class = "^(Minecraft).*" })
game({ title = "^(Minecraft).*" })
game({ class = "^(sober|org\\.vinegarhq\\.Sober)$" })               -- Roblox
-- Other Wine games: the title ends in .exe
hl.window_rule({ match = { title = ".*\\.exe" }, immediate = true })

GAME_CLASS_PATTERNS = {
    "^steam_app_", "^gamescope$",
    "^genshinimpact%.exe$", "^starrail%.exe$", "^zenlesszonezero%.exe$", "^client%-win64%-shipping%.exe$", "^bh3%.exe$",
    "^minecraft", "^sober$", "^org%.vinegarhq%.sober$",
}
GAME_TITLE_PATTERNS = { "^minecraft", "%.exe$" }
-- Never games, even fullscreen
NOT_GAME_CLASS_PATTERNS = { "clipstudio", "blender", "krita" }
