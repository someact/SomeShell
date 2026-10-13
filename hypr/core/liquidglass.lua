-- Liquid glass: the hyprglass plugin adds refraction, an edge light and a soft
-- lens to the shell's glass (island, corner pills, dock, on-screen keyboard).
-- Optional (`liquidGlass` in user.lua / Settings > Appearance). Build it first:
--   ~/.config/hypr/scripts/hyprglass.sh
-- The plugin is bound to one Hyprland build, so only the file built for this
-- version is loaded.
--
-- hl.plugin.load() is declarative: it must run on EVERY config load while the
-- plugin is wanted. Hyprland loads what is declared and not loaded yet, then
-- reloads the config; a plugin no longer declared gets unloaded. (Skipping the
-- call once the plugin was loaded made it unload/load/reload forever until
-- Hyprland crashed.) With the switch off it is simply not declared.
--
-- Cost measured on the RTX 3060: no visible change in GPU use, Hyprland CPU or
-- power (within the noise of a playing video); ~40 MB more VRAM for its buffers.
-- It re-samples the background only when something behind a surface changes
-- (at most 30 times a second), otherwise it reuses the last frame.

LIQUID_GLASS_PLUGIN = HOME .. "/.local/share/someshell/plugins/hyprglass-" .. hl.version() .. ".so"

if liquidGlass and file_exists(LIQUID_GLASS_PLUGIN) then
    hl.plugin.load(LIQUID_GLASS_PLUGIN)
end

local hg = hl.plugin.hyprglass
if hg then
    hg.config({
        default_theme = "dark",
        default_preset = liquidGlassPreset,
        -- Glass exactly where the shell asks for blur (ext-background-effect),
        -- shaped like that region (fit_shape: hypr/plugins/hyprglass-fit-shape.patch)
        layers = { enabled = true, mask_mode = "region", fit_shape = 1 },
    })
    -- One glass shape per surface only: fit_shape reads one rounded box from the
    -- region. The overlay and desktop widgets hold several cards, so they keep
    -- Hyprland's plain blur.
    for _, ns in ipairs({ "someshell:island", "someshell:pill", "someshell:dock", "someshell:osk" }) do
        hg.layer(ns, { mask_mode = "region" })
    end
    -- Windows stay as they are (their own blur) unless asked for
    if not liquidGlassWindows then
        hl.window_rule({ match = { class = ".*" }, tag = "+hyprglass_disabled" })
    end
end
