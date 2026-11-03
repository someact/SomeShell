-- General window rules: dialogs, small utilities, picture-in-picture.
-- App-specific rules are in apps.lua and games.lua.

-- Windows are opaque: skip blur for them entirely
hl.window_rule({ match = { class = ".*" }, no_blur = true })

-- Only floating windows cast a shadow
hl.window_rule({ match = { float = 0 }, no_shadow = true })

-- File pickers and save prompts float in the middle
for _, title in ipairs({
    "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$",
    "^(Library)(.*)$", "^(File Upload)(.*)$", "^(.*)(wants to save)$", "^(.*)(wants to open)$",
}) do
    hl.window_rule({ match = { title = title }, float = true, center = true })
end
hl.window_rule({ match = { class = "^(org\\.freedesktop\\.impl\\.portal\\.desktop\\.kde)$" }, float = true, size = { "(monitor_w*0.6)", "(monitor_h*0.65)" } })

-- Small utility windows
for _, class in ipairs({ "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|pavucontrol-qt)$", "^(nm-connection-editor)$" }) do
    hl.window_rule({ match = { class = class }, float = true, center = true, size = { "(monitor_w*0.45)", "(monitor_h*0.45)" } })
end
for _, class in ipairs({ ".*plasmawindowed.*", "^(kcm_.*)$", ".*bluedevilwizard" }) do
    hl.window_rule({ match = { class = class }, float = true })
end

-- The settings window
hl.window_rule({ match = { title = "^(SomeShell Settings)$" }, float = true, center = true, size = { 1080, 740 } })

-- Picture-in-picture: small, pinned, bottom right, keeps its shape
hl.window_rule({
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    move = { "(monitor_w*0.73)", "(monitor_h*0.72)" },
    size = { "(monitor_w*0.25)", "(monitor_h*0.25)" },
})

-- "X is sharing your screen" bar: pinned at the bottom centre
hl.window_rule({
    match = { title = ".*is sharing (a window|your screen).*" },
    float = true,
    pin = true,
    move = { "(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)" },
})

-- Dolphin's copy progress window out of the way
hl.window_rule({ match = { title = "^(Copying — Dolphin)$" }, move = { 40, 80 } })

-- Scratchpad (Super+S) sits further in from the edges
hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })
