import QtQuick
import qs.core

// One row of the settings window: a label (and an optional short hint) on
// the left, the control on the right, a hairline below.
//   SetRow { label: "Mode"; IconChoice { ... } }
Item {
    id: root

    property string label
    property string hint
    default property alias control: slot.data
    readonly property var c: Theme.paper

    width: parent ? parent.width : 400
    implicitHeight: Math.max(60, texts.implicitHeight + 24, slot.childrenRect.height + 22)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Txt {
            width: parent.width
            text: root.label
            face: Theme.font.regular
            color: root.c.fg
        }
        Txt {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            size: Theme.font.small
            color: root.c.mute
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.c.line
    }
}
