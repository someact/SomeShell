import QtQuick
import qs.core
import qs.components
import qs.services

// The island's side slot, a small raised pill at the island's right end:
// - recording and microphone / screen-share use (Config.island.dual), kept in
//   view beside media, a notification or the OSD instead of replacing them;
//   a click stops the recording, or opens Control when nothing records
// - the shelf (things dropped on the island): how many wait there; a click
//   opens it
Rectangle {
    id: root

    property bool live: true        // false under a fullscreen window: the pulse stops
    property bool showState: true   // the island shows recording / privacy here (Island.sideState)
    readonly property bool hovered: stateArea.containsMouse || shelfArea.containsMouse   // the island does not peek while the pointer is here

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 22
    radius: height / 2
    color: hovered ? Theme.islandRaisedHover : Theme.islandRaised

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Row {
            id: stateRow
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showState
            spacing: 6

            PulseDot {
                anchors.verticalCenter: parent.verticalCenter
                live: root.live
                size: 7
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Recorder.active
                mono: true
                text: Recorder.elapsedText
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Privacy.screenSharing
                name: "screen_share"
                size: 14
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Privacy.micActive
                name: "mic"
                size: 14
            }

            MouseArea {
                id: stateArea
                // Covers the state part only, with the pill's padding
                x: -8
                y: -6
                width: stateRow.width + 13
                height: stateRow.height + 12
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Recorder.active ? Recorder.stop() : UiState.open("control")
            }
        }

        Row {
            id: shelfRow
            anchors.verticalCenter: parent.verticalCenter
            visible: Shelf.count > 0
            spacing: 4

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "shelves"
                size: 14
                color: Theme.accentIsland
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Shelf.count
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
            }

            MouseArea {
                id: shelfArea
                x: -6
                y: -6
                width: shelfRow.width + 14
                height: shelfRow.height + 12
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.open("shelf")
            }
        }
    }
}
