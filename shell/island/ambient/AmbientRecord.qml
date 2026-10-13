import QtQuick
import qs.core
import qs.components
import qs.services

// Screen recording: pulsing red dot, elapsed time and a stop button.
// Clicking anywhere on the island stops the recording (see Island.qml).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    property bool live: true    // false under a fullscreen window: the pulse stops

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        PulseDot {
            anchors.verticalCenter: parent.verticalCenter
            live: root.live
            size: 9
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            text: Recorder.elapsedText
            font.weight: Theme.font.weightTitle
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Recorder.sound
            name: "volume_up"
            size: 16
            color: Theme.fgIslandDim
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: Theme.islandRaised
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 2
                color: Theme.fgIsland
            }
        }
    }
}
