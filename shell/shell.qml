//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// SomeShell shell. Run with `qs -c someshell`; hypr/scripts/shell.sh starts it
// with the EGL vendor pinned on NVIDIA-only machines.
// One island, two corner pills and a dock per monitor, a wallpaper layer,
// global shortcuts and IPC. Every panel inside the island, the overview, the
// region selector, the game overlay, the private peek, desktop widgets, the
// on-screen keyboard and the lock screen are loaded on demand.

import QtQuick
import Quickshell
import qs.services
import "island"
import "corners"
import "wallpaper"
import "dock"
import "overview"
import "capture"
import "overlay"
import "lock"
import "widgets"
import "osk"

ShellRoot {
    Variants {
        model: Quickshell.screens
        WallpaperLayer {}
    }
    Variants {
        model: Quickshell.screens
        DesktopWidgets {}
    }
    Variants {
        model: Quickshell.screens
        Pills {}
    }
    Variants {
        model: Quickshell.screens
        Dock {}
    }
    Variants {
        model: Quickshell.screens
        Island {}
    }

    Overview {}
    RegionSelector {}
    GameOverlay {}
    PrivatePeek {}
    Osk {}
    LockScreen {}

    Shortcuts {}
    Ipc {}

    // Services that act on their own (not only when a panel reads them)
    Component.onCompleted: {
        Schedule.check();
        GameClients.pids;
    }
}
