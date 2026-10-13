import QtQuick
import qs.core

// Phone-style quick toggle tile: icon, title and optional subtitle; the icon
// alone (`compact`); or icon and title on up to two lines (`titleOnly`, for a
// narrow tile).
PressButton {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool compact: false
    property bool titleOnly: false
    property color activeFg: Theme.fgPrimary

    implicitWidth: 170
    implicitHeight: 52
    // Off: a pill. On: a squircle (Material 3 Expressive tiles)
    radius: height / 2
    activeRadius: Theme.radius.normal
    color: Theme.islandRaised
    activeColor: Theme.primary

    Icon {
        visible: root.compact
        anchors.centerIn: parent
        name: root.icon
        size: 22
        fill: root.active ? 1 : 0
        color: root.active ? root.activeFg : Theme.fgIsland
    }

    Row {
        visible: !root.compact
        anchors.fill: parent
        anchors.leftMargin: root.titleOnly ? 12 : 14
        anchors.rightMargin: root.titleOnly ? 8 : 10
        spacing: root.titleOnly ? 8 : 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 22
            fill: root.active ? 1 : 0
            color: root.active ? root.activeFg : Theme.fgIsland
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - parent.spacing
            Label {
                width: parent.width
                text: root.title
                font.weight: Theme.font.weightTitle
                color: root.active ? root.activeFg : Theme.fgIsland
                // Narrow tile: "Do not / disturb" on two lines instead of cut off
                wrapMode: root.titleOnly ? Text.WordWrap : Text.NoWrap
                maximumLineCount: root.titleOnly ? 2 : 1
                lineHeight: root.titleOnly ? 0.9 : 1
                font.pixelSize: root.titleOnly ? Theme.font.normal - 1 : Theme.font.normal
            }
            Label {
                width: parent.width
                visible: text !== "" && !root.titleOnly
                text: root.subtitle
                font.pixelSize: Theme.font.small
                color: root.active ? root.activeFg : Theme.fgIslandDim
                opacity: 0.85
            }
        }
    }
}
