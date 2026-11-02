//@ pragma UseQApplication
// SomeShell: the island shell. Started by hypr/scripts/shell.sh (qs -c someshell).
// UseQApplication: tray menus are platform menus.
import QtQuick
import Quickshell
import "top"
import "wallpaper"
import qs.services

ShellRoot {
    // Services that must run from the start: the notification server and the
    // night light schedule
    Component.onCompleted: {
        Notifications.dnd;
        NightLight.on;
    }

    Variants {
        model: Quickshell.screens
        WallpaperWindow {}
    }

    Variants {
        model: Quickshell.screens
        TopBar {}
    }

    Shortcuts {}
    Ipc {}
}
