-- Autostart: runs once when Hyprland starts, not on a config reload.
-- SOMESHELL_NO_AUTOSTART=1 skips it (testing the config in a nested Hyprland).
if os.getenv("SOMESHELL_NO_AUTOSTART") then return end

hl.on("hyprland.start", function()
    hl.exec_cmd(SCRIPTS .. "/shell.sh")

    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    -- Idle times from the settings window (generated/hypridle.conf), else the defaults
    local idle = HYPR_DIR .. "/generated/hypridle.conf"
    if file_exists(idle) then
        hl.exec_cmd("hypridle -c " .. idle)
    else
        hl.exec_cmd("hypridle")
    end

    -- logind would shut down on the power key: the session takes it (keybinds.lua locks instead)
    hl.exec_cmd("systemd-inhibit --what=handle-power-key --who=SomeShell --why='The power key locks the screen' --mode=block sleep infinity")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

    -- Clipboard history for /clip
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    hl.exec_cmd("hyprctl setcursor " .. setting("cursor.theme", "Bibata-Modern-Classic") .. " " .. setting("cursor.size", 24))

    -- The user's own entries (settings window)
    for _, entry in ipairs(setting("autostart", {})) do
        if type(entry) == "table" and entry.enabled ~= false and type(entry.command) == "string" and entry.command ~= "" then
            hl.exec_cmd(entry.command)
        end
    end
end)
