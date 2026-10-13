-- Autostart. Runs once when Hyprland starts, not on config reload.

hl.on("hyprland.start", function()
    -- Desktop shell (island, pills, dock, wallpaper, notifications, polkit agent)
    hl.exec_cmd(HYPR_DIR .. "/scripts/shell.sh")

    -- Session plumbing
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Clipboard history (the shell watches the clipboard for its own list)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- Your own autostart entries (settings app, Autostart page)
    for _, entry in ipairs(setting("autostart", {})) do
        if type(entry) == "table" and entry.enabled ~= false and type(entry.command) == "string" and entry.command ~= "" then
            hl.exec_cmd(entry.command)
        end
    end
end)
