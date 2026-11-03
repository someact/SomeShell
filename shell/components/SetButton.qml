import QtQuick
import qs.core

// A rounded button in the settings window: outlined, or filled with ink
// (`primary`) for the main action. Pressing inverts it.
//   SetButton { text: "Apply"; primary: true; onClicked: ... }
Item {
    id: root

    property string text
    property string icon
    property bool primary: false
    property bool enabled: true
    readonly property var c: Theme.paper
    readonly property bool filled: primary !== mouse.pressed
    signal clicked

    implicitWidth: row.implicitWidth + 32
    implicitHeight: 38
    opacity: enabled ? 1 : 0.35
    activeFocusOnTab: enabled
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.filled ? root.c.fg : mouse.containsMouse && root.enabled ? root.c.raised : "transparent"
        border.width: 1
        border.color: root.filled || root.activeFocus ? root.c.fg : root.c.line
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 18
            color: root.filled ? root.c.bg : root.c.fg
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            face: Theme.font.regular
            color: root.filled ? root.c.bg : root.c.fg
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
