import QtQuick
import qs.core

// One row of a list on the island: icon, title, a small caption, and
// anything on the right (a tag, a switch, a slider). A hairline below.
//   ListRow { icon: "wifi"; title: "Home"; sub: "Saved"; onClicked: ... }
Item {
    id: root

    property string icon
    property bool iconFilled: false
    property string title
    property string sub
    property bool clickable: true
    property bool line: true
    default property alias trailing: right.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked

    // Keyboard (Open.qml)
    readonly property bool kbNav: clickable
    function kbClick() { clicked(); }
    function kbAlt() { rightClicked(); }

    implicitHeight: 52
    width: parent?.width ?? 400

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 1
        radius: 10
        color: root.clickable && mouse.containsMouse ? Theme.ink.raised : "transparent"
    }
    KeyRing {
        target: root
        anchors.bottomMargin: -2
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.clickable
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    Icon {
        id: glyph
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        filled: root.iconFilled
        color: Theme.ink.fg
    }
    Column {
        anchors.left: glyph.right
        anchors.leftMargin: 14
        anchors.right: right.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        Txt {
            width: parent.width
            text: root.title
        }
        Txt {
            width: parent.width
            visible: text !== ""
            text: root.sub
            caps: true
            color: Theme.ink.mute
        }
    }
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
    Rectangle {
        visible: root.line
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.ink.line
    }
}
