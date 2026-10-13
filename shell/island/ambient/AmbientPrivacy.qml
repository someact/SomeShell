import QtQuick
import qs.core
import qs.components
import qs.services

// Screen share / mic in use: a red dot that is hard to miss.
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
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Privacy.screenSharing
            name: "screen_share"
            size: 17
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Privacy.micActive
            name: "mic"
            size: 17
        }
    }
}
