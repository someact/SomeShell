import QtQuick
import qs.core

// A control panel tile: icon, name and state. Outlined when off, filled with
// the accent (and rounder) when on. `more` shows an arrow that opens the
// tile's own page; a right click does the same.
//   Tile { icon: "wifi"; label: "Internet"; sub: "Ethernet"; active: true; more: true }
Item {
    id: root

    property string icon
    property string label
    property string sub
    property bool active: false
    property bool more: false
    property bool enabled: true
    // Extra content (a slider, a number), placed freely inside the tile's
    // padding; `reserveBottom` / `reserveRight` keep the text clear of it
    default property alias extra: slot.data
    property real reserveBottom: 0
    property real reserveRight: 0

    readonly property color fg: mouse.pressed ? Theme.ink.bg : root.active ? Theme.ink.onAccent : Theme.ink.fg
    readonly property color subColor: mouse.pressed ? Theme.ink.bg : root.active ? Theme.ink.onAccent : Theme.ink.mute

    signal clicked
    signal opened

    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: root.active ? 26 : 16
        color: mouse.pressed ? Theme.ink.fg : root.active ? Theme.ink.accent : mouse.containsMouse ? Theme.ink.raised : "transparent"
        border.width: root.active || mouse.pressed ? 0 : 1
        border.color: Theme.ink.line
        Behavior on radius {
            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
        }
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton && root.more ? root.opened() : root.clicked()
    }

    Icon {
        x: 14
        y: 13
        name: root.icon
        filled: root.active
        size: 22
        color: root.fg
    }

    // Arrow to the tile's page
    Rectangle {
        visible: root.more
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        width: 30
        height: 30
        radius: 15
        color: arrow.containsMouse ? Qt.alpha(root.fg, 0.14) : "transparent"
        Icon {
            anchors.centerIn: parent
            name: "chevron_right"
            size: 20
            color: root.fg
        }
        MouseArea {
            id: arrow
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.bottomMargin: 14 + root.reserveBottom
        anchors.rightMargin: 14 + root.reserveRight
        spacing: 1

        Txt {
            width: parent.width
            text: root.label
            face: Theme.font.medium
            color: root.fg
        }
        Txt {
            width: parent.width
            visible: text !== ""
            text: root.sub
            caps: true
            color: root.subColor
        }
    }

    Item {
        id: slot
        anchors.fill: parent
        anchors.margins: 14
    }
}
