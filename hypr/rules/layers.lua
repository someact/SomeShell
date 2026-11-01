-- Layer surfaces: the shell and other tools.

-- The shell animates its own surfaces, so Hyprland must not animate them too
hl.layer_rule({ match = { namespace = "^(someshell:.*)$" }, no_anim = true })
-- Streamer mode: what goes on this layer never reaches a screen share or recording
hl.layer_rule({ match = { namespace = "^(someshell:private)$" }, no_screen_share = true })

-- Pickers appear at once
for _, ns in ipairs({ "selection", "hyprpicker", "noanim" }) do
    hl.layer_rule({ match = { namespace = "^(" .. ns .. ")$" }, no_anim = true })
end

-- Fallbacks used while the shell is down
hl.layer_rule({ match = { namespace = "^(launcher)$" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(logout_dialog)$" }, blur = true })
