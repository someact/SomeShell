import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.services

// The session lock (ext-session-lock-v1) on every screen, plus the same screen
// in an ordinary overlay window for previewing. Surfaces exist only while
// locked; everything here is idle otherwise.
Scope {
    WlSessionLock {
        id: sessionLock
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface
            color: "transparent"
            LockSurface {
                anchors.fill: parent
                hasFocus: surface.screen?.name === Hyprland.focusedMonitor?.name
            }
        }
    }

    // Preview: no session lock, no PAM; Esc or Enter closes it
    LazyLoader {
        active: Lock.preview

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.namespace: "someshell:lockpreview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            LockSurface {
                anchors.fill: parent
            }
        }
    }
}
