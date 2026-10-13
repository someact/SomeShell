import QtQuick
import qs.core
import qs.components
import qs.services

// The island's side slot (Config.island.dual): recording and microphone /
// screen-share use, kept in view beside media, a notification or the OSD
// instead of replacing them. A small raised pill at the island's right end;
// clicking it stops the recording, or opens Control when nothing records.
Rectangle {
    id: root

    property bool live: true    // false under a fullscreen window: the pulse stops
    readonly property bool hovered: area.containsMouse   // the island does not peek while the pointer is here

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 22
    radius: height / 2
    color: area.containsMouse ? Theme.islandRaisedHover : Theme.islandRaised

    Row {
        id: row
        anchors.centerIn: parent
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
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Recorder.active ? Recorder.stop() : UiState.open("control")
    }
}
