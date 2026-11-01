//@ pragma UseQApplication
// SomeShell: the island shell. Started by hypr/scripts/shell.sh (qs -c someshell).
// UseQApplication: tray menus are platform menus.
import QtQuick
import Quickshell
import "top"
import "wallpaper"

ShellRoot {
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
