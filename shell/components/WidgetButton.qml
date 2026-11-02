import QtQuick
import qs.core

// A round icon button for desktop widgets, in the desktop colors (Tap is the
// island's). Hover shows a soft fill; pressing inverts it.
//   WidgetButton { icon: "skip_next"; size: 40; onClicked: ... }
Item {
    id: root

    property string icon
    property bool filled: false
    property real size: 36
    property bool live: true
    property var c: Theme.paper
    signal clicked

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? root.c.fg : root.filled ? root.c.accent : mouse.containsMouse ? root.c.raised : "transparent"
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }
    Icon {
        anchors.centerIn: parent
        name: root.icon
        filled: true
        size: Math.round(root.size * 0.55)
        color: mouse.pressed ? root.c.bg : root.filled ? root.c.onAccent : root.c.fg
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.live
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
