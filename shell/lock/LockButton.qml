import QtQuick
import qs.core
import qs.components

// A round outlined button on the lock page (the player). `on` fills it with
// ink; pressing inverts it.
Item {
    id: root
    property real u: 10
    property string icon
    property bool on: false
    signal clicked

    readonly property var c: Theme.paper
    readonly property bool filled: on !== mouse.pressed
    width: 2.4 * u
    height: width

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.filled ? root.c.fg : mouse.containsMouse ? root.c.raised : "transparent"
        border.width: 1
        border.color: root.filled ? root.c.fg : root.c.line
    }
    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: Math.round(1.3 * root.u)
        filled: true
        color: root.filled ? root.c.bg : root.c.fg
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
