//@ pragma UseQApplication
// SomeShell: the island shell. Started by hypr/scripts/shell.sh (qs -c someshell).
// UseQApplication: tray menus are platform menus.
import QtQuick
import Quickshell
import "top"
import "wallpaper"
import "capture"
import "edit"
import "overview"
import "lock"
import "settings"
import qs.core
import qs.services

ShellRoot {
    // Services that must run from the start: the notification server, the
    // night light schedule, the battery alerts and the lock (it locks again
    // after a crash while locked), the Android slot check for the power page, and
    // keep awake (Always, or a session's, holds its idle block from the start),
    // the displays (the touch screen and pen follow the built-in panel) and
    // touch (devices and the last input kind)
    Component.onCompleted: {
        KeepAwake.on;
        Notifications.dnd;
        NightLight.on;
        Battery.available;
        Locker.locked;
        DualBoot.available;
        Auth.registered;
        Displays.saved;
        Touch.hasTouch;
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

    // Touch screen edges, only while a touch screen exists, on its monitor
    // (every monitor when it maps to none in particular)
    LazyLoader {
        active: Touch.hasTouch
        Variants {
            model: Quickshell.screens.filter(s => !Touch.monitor || s.name === Touch.monitor)
            TouchEdges {}
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

    // The overview, only while open, on one monitor
    LazyLoader {
        active: Ui.overview
        Overview {}
    }

    // The capture picker, only while picking
    LazyLoader {
        active: Capture.picking
        Variants {
            model: Quickshell.screens
            Picker {}
        }
    }

    // The lock screen, only while locked (or previewed)
    LazyLoader {
        active: Locker.shown
        Lock {}
    }

    // The settings window, only while open
    LazyLoader {
        active: Ui.settings
        SettingsWindow {}
    }

    Shortcuts {}
    Ipc {}
}
