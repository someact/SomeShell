import QtQuick
import qs.core
import qs.components
import qs.services

// Something from another app is dragged over the island: it grows a little
// and says what it holds. A drop opens the Drop page.
Item {
    id: root

    implicitWidth: row.implicitWidth + 64
    implicitHeight: Theme.shape.band + 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "move_to_inbox"
            filled: true
            size: 22
            color: Theme.ink.accent
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: "Drop"
            caps: true
            face: Theme.font.bold
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: "·  " + Drop.label
            caps: true
            color: Theme.ink.mute
        }
    }
}
