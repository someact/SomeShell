-- Default apps. The settings window overrides any of them (hypr.json "apps").

APPS = {
    terminal    = "kitty -1",
    fileManager = "dolphin",
    browser     = first_available({ "zen-browser", "firefox", "chromium" }),
    codeEditor  = first_available({ "code", "codium", "zeditor", "kate" }),
    textEditor  = first_available({ "kate", "gnome-text-editor", "mousepad" }),
    volumeMixer = first_available({ "pavucontrol-qt", "pavucontrol" }),
    office      = first_available({ "wps", "onlyoffice-desktopeditors", "libreoffice" }),
    taskManager = "kitty -1 btop",
}

for name, default in pairs(APPS) do
    APPS[name] = setting("apps." .. name, default)
end

-- Game mode: effects off while a game is the focused fullscreen window.
GAME_MODE_AUTO = setting("gameModeAuto", true)
