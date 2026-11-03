import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The lock: Wayland's session lock with a LockPage on every monitor. While
// `Locker.preview` the same page shows in an ordinary overlay window instead
// (nothing is locked; Esc closes it). Loaded only while shown (shell.qml).
Scope {
    WlSessionLock {
        locked: Locker.locked

        WlSessionLockSurface {
            color: "black"
            LockPage {
                anchors.fill: parent
            }
        }
    }

    Variants {
        model: Locker.preview ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "someshell:lockpreview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockPage {
                anchors.fill: parent
            }
        }
    }
}
