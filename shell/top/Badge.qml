import QtQuick
import Quickshell.Hyprland
import qs.core
import qs.components

// The workspace on this monitor, by its number (shared by every monitor,
// Super+1..0). Scroll to go to the previous or next number; a click opens
// the overview.
Rectangle {
    id: root

    property var monitor
    readonly property int id: monitor?.activeWorkspace?.id ?? 1
    readonly property int slot: id > 0 ? id : 0

    width: 34
    height: 34
    radius: 17
    color: Theme.ink.bg

    Digits {
        anchors.centerIn: parent
        text: root.slot > 0 ? String(root.slot) : "S"
        size: 16
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openOverview()
        onWheel: wheel => Hyprland.dispatch(`hl.dsp.focus({ workspace = workspace_step(${wheel.angleDelta.y > 0 ? -1 : 1}) })`)
    }
}
