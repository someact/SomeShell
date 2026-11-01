import QtQuick
import qs.core

PressButton {
    id: root
    property string icon
    property real iconSize: 20
    property color iconColor: active ? Theme.fgPrimary : Theme.fgIsland
    // Round when off, a squircle when on
    activeRadius: Math.round(Math.min(width, height) * 0.32)

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        fill: 1
        color: root.iconColor
    }
}
