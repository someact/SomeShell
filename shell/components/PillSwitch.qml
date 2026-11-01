import QtQuick
import qs.core

// On/off switch for island pages: a pill track with a springing knob.
Item {
    id: root

    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accentIsland : Theme.islandRaisedHover
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }
    Rectangle {
        property real size: root.checked ? root.height - 6 : root.height - 10
        width: size
        height: size
        radius: size / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - size - 3 : 5
        color: root.checked ? Theme.fgAccentIsland : Theme.fgIslandDim
        Behavior on x {
            Spring { preset: "snappy" }
        }
        Behavior on size {
            Spring { preset: "snappy" }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
