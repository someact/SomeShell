import QtQuick
import qs.core
import qs.components

// A row on a Control detail page or the mixer: icon, title, subtitle, and an
// optional trailing action button. `current` marks the connected / selected one.
PressButton {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool current: false
    property bool busy: false
    property string action                // trailing button icon (e.g. "delete")
    signal actionClicked

    width: parent ? parent.width : 400
    height: subtitle !== "" ? 50 : 42
    radius: Theme.radius.normal
    color: root.current ? Theme.islandRaised : "transparent"

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        spacing: 12

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 22
            fill: 1
            color: root.current ? Theme.accentIsland : Theme.fgIsland
            // The pulse drives its own value, so the icon is fully back once busy ends
            property real pulse: 1
            opacity: root.busy ? pulse : 1
            SequentialAnimation on pulse {
                running: root.busy
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - (actionButton.visible ? actionButton.width + 12 : 0)
            Label {
                width: parent.width
                text: root.title
                font.styleName: root.current ? Theme.font.styleTitle : Theme.font.style
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: root.current ? Theme.accentIsland : Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }
        IconButton {
            id: actionButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.action !== ""
            width: 32
            height: 32
            iconSize: 18
            icon: root.action
            iconColor: Theme.fgIslandDim
            onClicked: root.actionClicked()
        }
    }
}
