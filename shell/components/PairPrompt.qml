import QtQuick
import qs.core
import qs.services

// A device asking to pair (Share.pairs): its name, the code to compare with
// the one on its screen, Pair / Cancel. On the Bluetooth page and the Share
// page.
Column {
    id: root

    readonly property var ask: Share.pairs[0] ?? null

    visible: ask !== null
    width: parent?.width ?? 500
    spacing: 12

    Row {
        width: parent.width
        spacing: 16
        Rectangle {
            width: 56
            height: 56
            radius: Theme.shape.small
            color: Theme.ink.raised
            Icon {
                anchors.centerIn: parent
                name: "phonelink_ring"
                size: 26
                color: Theme.ink.fg
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 72
            spacing: 2
            Txt {
                width: parent.width
                text: "Pair with " + (root.ask?.peer ?? "")
                face: Theme.font.medium
            }
            Txt {
                width: parent.width
                text: root.ask?.passkey ? "Is this code on its screen too?" : "It asks to connect"
                caps: true
                color: Theme.ink.mute
            }
        }
    }
    Digits {
        visible: (root.ask?.passkey ?? "") !== ""
        text: (root.ask?.passkey ?? "").replace(/(\d{3})(\d{3})/, "$1 $2")
        size: Theme.font.headline
    }
    Row {
        spacing: 8
        Chip {
            icon: "link"
            label: "Pair"
            active: true
            onClicked: Share.answer(root.ask.id, true)
        }
        Chip {
            icon: "close"
            label: "Cancel"
            onClicked: Share.answer(root.ask.id, false)
        }
    }
}
