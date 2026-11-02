import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core

// One window per monitor along the top edge: the workspace badge, the tray
// tab and the island (only on the monitor the island is on). The window is
// tall enough for the open island but only its shapes take the pointer, and
// it takes the keyboard only while the island is open here.
// Dock style: the window sits on the bottom edge instead, and one floating
// bar holds the badge, the apps, the island (growing upward) and the tray.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool islandHere: Ui.monitor === "" || Ui.monitor === monitor?.name
    readonly property bool docked: Desktop.style === "dock"

    screen: modelData
    anchors.top: !docked
    anchors.bottom: docked
    anchors.left: true
    anchors.right: true
    implicitHeight: Math.round(modelData.height * 0.8)
    exclusiveZone: docked ? dockBar.height + 2 * Theme.shape.floatGap
        : Theme.shape.band + (island.floating ? Theme.shape.floatGap : 0)
    color: "transparent"

    WlrLayershell.namespace: "someshell:island"
    WlrLayershell.layer: WlrLayer.Top
    // Keyboard only while open here; never Exclusive, or the focus grab
    // below could not clear on an outside click
    WlrLayershell.keyboardFocus: islandHere && Ui.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        Region { item: win.docked ? dockBar : badge }
        Region { item: win.docked ? null : tray }
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
        visible: !win.docked
        monitor: win.monitor
        x: 16
        y: (Theme.shape.band - height) / 2
    }

    Tray {
        id: tray
        window: win
        anchors.right: parent.right
        visible: win.islandHere && !win.docked
    }

    // Dock style: badge, apps, room for the resting island, tray
    Rectangle {
        id: dockBar
        visible: win.docked
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.shape.floatGap
        width: dockRow.implicitWidth + 16
        height: 54
        radius: height / 2
        color: Theme.ink.bg

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 8
            Badge {
                anchors.verticalCenter: parent.verticalCenter
                monitor: win.monitor
            }
            DockApps {
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                id: islandSlot
                width: win.islandHere ? island.restWidth : 0
                height: 1
            }
            Tray {
                anchors.verticalCenter: parent.verticalCenter
                visible: win.islandHere
                window: win
                plain: true
            }
        }
    }

    Island {
        id: island
        here: win.islandHere
        shellScreen: win.modelData
        // Centred on the screen. Docked: centred on its slot in the bar, resting
        // in the middle of the bar's height and growing upward (kept on
        // screen); open, a panel in the middle just above the dock.
        // x is computed, never anchored: an anchor that is later released
        // leaves x stuck and drops this binding. The screen's width is used,
        // as the window's own width reads as its default here.
        x: !win.docked || Ui.open ? (win.modelData.width - width) / 2
            : Math.max(8, Math.min(win.modelData.width - width - 8, dockBar.x + dockRow.x + islandSlot.x + islandSlot.width / 2 - width / 2))
        bottomLine: Ui.open ? dockBar.y - Theme.shape.floatGap
            : dockBar.y + dockBar.height - (dockBar.height - restHeight) / 2
    }
}
