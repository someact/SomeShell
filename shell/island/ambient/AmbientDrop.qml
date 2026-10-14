import QtQuick
import qs.core
import qs.components

// The island as a drop target, while something is dragged over it or the top
// edge beside it: what the drag carries, and that it goes to the shelf.
Item {
    id: root

    property var info: ({ icon: "move_to_inbox", text: "" })   // Shelf.describe(drag)
    property bool live: true

    implicitWidth: Math.max(340, row.implicitWidth + 40)
    implicitHeight: 76

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        ShapeIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.info.icon
            size: 24
            active: true
            shape: "cookie9Sided"
            shapeColor: Theme.accentIsland
            activeIconColor: Theme.fgOnIslandFill
            // A slow breathe says "let go here"
            SequentialAnimation on scale {
                running: root.live
                loops: Animation.Infinite
                NumberAnimation { to: 1.08; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label {
                text: "Drop to keep it on the shelf"
                font.weight: Theme.font.weightTitle
            }
            Label {
                visible: root.info.text !== ""
                width: Math.min(implicitWidth, 260)
                text: root.info.text
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }
    }
}
