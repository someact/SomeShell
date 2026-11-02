//@ pragma UseQApplication
// SomeShell: the island shell. Started by hypr/scripts/shell.sh (qs -c someshell).
// UseQApplication: tray menus are platform menus.
import QtQuick
import Quickshell
import "top"
import "wallpaper"
import "capture"
import "edit"
import qs.core
import qs.services

ShellRoot {
    // Services that must run from the start: the notification server, the
    // night light schedule and the battery alerts
    Component.onCompleted: {
        Notifications.dnd;
        NightLight.on;
        Battery.available;
    }

    Variants {
        model: Quickshell.screens
        WallpaperWindow {}
    }

    Variants {
        model: Quickshell.screens
        TopBar {}
    }

    // The separate dock (Notch and Plain styles), only while it is on
    LazyLoader {
        active: Desktop.dock.enabled && Desktop.style !== "dock"
        Variants {
            model: Quickshell.screens
            Dock {}
        }
    }

    // Edit mode, only while editing
    LazyLoader {
        active: Ui.editing
        Variants {
            model: Quickshell.screens
            EditWindow {}
        }
    }

    // The capture picker, only while picking
    LazyLoader {
        active: Capture.picking
        Variants {
            model: Quickshell.screens
            Picker {}
        }
    }

    Shortcuts {}
    Ipc {}
}
