import QtQuick
import qs.core

// An on/off switch in the desktop's paper and ink (the settings window).
//   Switch { checked: Desktop.dock.enabled; onToggled: on => Desktop.dock.enabled = on }
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    readonly property var c: Theme.paper
    signal toggled(bool on)

    implicitWidth: 46
    implicitHeight: 26
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Keys.onSpacePressed: if (enabled) toggled(!checked)
    Keys.onReturnPressed: if (enabled) toggled(!checked)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.c.fg : mouse.containsMouse ? root.c.raised : "transparent"
        border.width: 1
        border.color: root.checked ? root.c.fg : root.activeFocus ? root.c.fg : root.c.line
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
    Rectangle {
        width: parent.height - 8
        height: width
        radius: width / 2
        y: 4
        x: root.checked ? parent.width - width - 4 : 4
        color: root.checked ? root.c.bg : root.c.mute
        Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Motion.easing } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
