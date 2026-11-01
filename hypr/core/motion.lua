-- Window, layer and workspace animations. Things that appear or move use
-- springs (mass 1; stiffness = (2*pi/response)^2, dampening = 4*pi*ratio/response),
-- things that leave use a short accelerating curve so closing feels instant.
--   smooth  response 0.40, no bounce: moving, workspaces
--   snappy  response 0.35, slight settle: opening
hl.curve("smooth", { type = "spring", mass = 1, stiffness = 246.74, dampening = 31.42 })
hl.curve("snappy", { type = "spring", mass = 1, stiffness = 322.27, dampening = 30.52 })

hl.curve("decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })

hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.5, spring = "snappy", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2,   bezier = "accel",  style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, spring = "smooth", style = "slide" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3,   bezier = "decel" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2,   bezier = "decel" })
hl.animation({ leaf = "border",      enabled = true, speed = 6,   bezier = "decel" })

-- Layers: the shell animates its own surfaces (rules/layers.lua turns these
-- off for it); these are for other tools such as pickers and launchers.
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   spring = "snappy", style = "popin 93%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2.4, bezier = "accel",  style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.7, bezier = "accel" })

hl.animation({ leaf = "workspaces",          enabled = true, speed = 5,   spring = "smooth", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 4,   spring = "snappy", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "accel",  style = "slidevert" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "decel" })
