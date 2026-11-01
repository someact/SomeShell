import QtQuick
import qs.core

// A pressable area on the island. Hover shows a raised fill; pressing
// inverts it (ink and paper swap), the one motion for "you pressed this".
// Content goes inside and can read `fg` for its color.
//   Tap { onClicked: ...; Icon { anchors.centerIn: parent; name: "close"; color: parent.fg } }
Item {
    id: root

    default property alias content: inner.data
    property real radius: Theme.shape.small
    property bool active: false        // turned on: filled with the accent
    property bool outlined: false
    property bool highlighted: false   // chosen with the keyboard
    property bool enabled: true
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property color fg: pressed ? Theme.ink.bg : active ? Theme.ink.onAccent : Theme.ink.fg

    signal clicked
    signal rightClicked

    implicitWidth: 34
    implicitHeight: 34
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.pressed ? Theme.ink.fg
            : root.active ? Theme.ink.accent
            : root.hovered || root.highlighted ? Theme.ink.raised : "transparent"
        border.width: root.outlined && !root.active && !root.pressed ? 1 : 0
        border.color: Theme.ink.line
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
