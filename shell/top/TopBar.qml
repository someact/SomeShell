import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core

// One window per monitor along the top edge: the workspace badge, the tray
// tab and the island (only on the monitor the island is on). The window is
// tall enough for the open island but only its shapes take the pointer, and
// it takes the keyboard only while the island is open here.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool islandHere: Ui.monitor === "" || Ui.monitor === monitor?.name

    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Math.round(modelData.height * 0.8)
    exclusiveZone: Theme.shape.band + (island.floating ? Theme.shape.floatGap : 0)
    color: "transparent"

    WlrLayershell.namespace: "someshell:island"
    WlrLayershell.layer: WlrLayer.Top
    // Keyboard only while open here; never Exclusive, or the focus grab
    // below could not clear on an outside click
    WlrLayershell.keyboardFocus: islandHere && Ui.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        Region { item: badge }
        Region { item: tray }
        Region { item: island.hitArea }
    }

    // A click outside the open island closes it
    HyprlandFocusGrab {
        windows: [win]
        active: win.islandHere && Ui.open
        onCleared: Ui.close()
    }

    Badge {
        id: badge
        monitor: win.monitor
        x: 16
        y: (Theme.shape.band - height) / 2
    }

    Tray {
        id: tray
        window: win
        anchors.right: parent.right
        visible: win.islandHere
    }

    Island {
        id: island
        here: win.islandHere
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
