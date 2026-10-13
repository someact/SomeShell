import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Control → right-click Quick Share: visibility, the transfer waiting for an
// answer, files to send with the devices that can take them, and this
// session's transfers.
Column {
    id: root

    spacing: 10

    function kindIcon(kind) {
        return kind === "laptop" ? "laptop_mac" : kind === "tablet" ? "tablet_android" : "devices";
    }

    Item {
        width: parent.width
        height: 34
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            Label {
                text: "Quick Share"
                font.weight: Theme.font.weightTitle
            }
            Label {
                text: QuickShare.enabled ? "Nearby devices can send to this PC" : "Off: this PC cannot be found"
                color: QuickShare.enabled ? Theme.accentIsland : Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }
        PillSwitch {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: QuickShare.enabled
            onToggled: QuickShare.toggle()
        }
    }

    // Phones look for receivers over Bluetooth; without it only the same Wi-Fi works
    Item {
        visible: BluetoothState.available && !BluetoothState.enabled
        width: parent.width
        height: 32
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - btOn.width - 32
            text: "Bluetooth is off: your phone may not find this PC"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Chip {
            id: btOn
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Turn on"
            onClicked: BluetoothState.toggle()
        }
    }

    // The firewall drops what a phone sends here
    Rectangle {
        visible: QuickShare.blocked !== "" && QuickShare.enabled
        width: parent.width
        height: fw.implicitHeight + 16
        radius: Theme.radius.normal
        color: Theme.islandRaised
        Column {
            id: fw
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - 24 - copy.width - 8
            spacing: 2
            Label {
                width: parent.width
                text: "The firewall (" + QuickShare.blocked + ") blocks phones from sending here"
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
            }
            Label {
                width: parent.width
                text: "Run once in a terminal:  " + QuickShare.unblock
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
        Chip {
            id: copy
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Copy"
            onClicked: Quickshell.execDetached(["wl-copy", "--", QuickShare.unblock])
        }
    }

    // Waiting for an answer
    Rectangle {
        readonly property var t: QuickShare.pending
        visible: t !== null
        width: parent.width
        height: 58
        radius: Theme.radius.normal
        color: Theme.islandRaised
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            width: parent.width - 28 - answers.width - 10
            Label {
                width: parent.width
                text: (parent.parent.t?.device ?? "") + " wants to send " + QuickShare.describe(parent.parent.t)
                font.weight: Theme.font.weightTitle
            }
            Label {
                width: parent.width
                text: "PIN " + (parent.parent.t?.pin ?? "") + (parent.parent.t?.total > 0 ? " · " + QuickShare.size(parent.parent.t.total) : "")
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }
        Row {
            id: answers
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                text: "Decline"
                onClicked: QuickShare.reject(parent.parent.t.id)
            }
            Chip {
                text: "Accept"
                primary: true
                onClicked: QuickShare.accept(parent.parent.t.id)
            }
        }
    }

    // Send
    Item {
        width: parent.width
        height: 30
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - sendButtons.width - 32
            text: QuickShare.outbox.length === 0 ? "Send files to a nearby device" : QuickShare.outbox.length === 1 ? QuickShare.outbox[0].split("/").pop() : QuickShare.outbox.length + " files: " + QuickShare.outbox.map(f => f.split("/").pop()).join(", ")
            color: QuickShare.outbox.length === 0 ? Theme.fgIslandDim : Theme.fgIsland
            font.pixelSize: Theme.font.small
        }
        Row {
            id: sendButtons
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                visible: QuickShare.outbox.length > 0
                text: "Clear"
                onClicked: QuickShare.clearOutbox()
            }
            Chip {
                text: QuickShare.outbox.length > 0 ? "Add…" : "Choose files…"
                onClicked: QuickShare.pick()
            }
        }
    }
    Column {
        visible: QuickShare.outbox.length > 0
        width: parent.width
        spacing: 2
        Label {
            x: 12
            height: 24
            width: parent.width - 24
            text: QuickShare.devices.length > 0 ? "Send to" : "Looking for devices… open Quick Share on the phone and make it visible"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Repeater {
            model: QuickShare.devices
            DetailRow {
                required property var modelData
                icon: root.kindIcon(modelData.kind)
                title: modelData.name
                subtitle: "Click to send"
                onClicked: QuickShare.sendTo(modelData)
            }
        }
    }

    // This session's transfers
    Column {
        visible: QuickShare.transfers.length > 0
        width: parent.width
        spacing: 2
        Label {
            x: 12
            height: 24
            text: "Transfers"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Repeater {
            model: QuickShare.transfers.slice(0, 5)
            DetailRow {
                id: row
                required property var modelData
                readonly property bool live: !QuickShare.isOver(modelData.state)
                readonly property bool openable: QuickShare.hasFiles(modelData)
                icon: modelData.direction === "in" ? "download" : "upload_file"
                title: QuickShare.describe(modelData) + (modelData.direction === "in" ? " from " : " to ") + modelData.device
                subtitle: (openable ? "Click to open · " : "") + QuickShare.stateText(modelData) + (modelData.state === "receiving" || modelData.state === "sending" ? " · " + Math.round(QuickShare.progress(modelData) * 100) + "%" : "") + (modelData.total > 0 ? " · " + QuickShare.size(modelData.total) : "")
                current: live
                busy: modelData.state === "connecting"
                // Running: cancel. Received files: click opens, the button shows them in the folder
                action: live ? "close" : openable ? "folder_open" : ""
                onActionClicked: live ? QuickShare.cancel(modelData.id) : QuickShare.reveal(modelData)
                onClicked: {
                    if (openable) {
                        QuickShare.open(modelData);
                        UiState.close();
                    }
                }
            }
        }
    }

    // A small text button
    component Chip: PressButton {
        id: chip
        property string text
        property bool primary: false
        width: chipLabel.implicitWidth + 24
        height: 28
        color: primary ? Theme.accentIsland : Theme.islandRaisedHover
        hoverColor: primary ? Qt.lighter(Theme.accentIsland, 1.1) : Qt.lighter(Theme.islandRaisedHover, 1.3)
        Label {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            font.pixelSize: Theme.font.small
            font.weight: Theme.font.weightTitle
            color: chip.primary ? Theme.fgAccentIsland : Theme.fgIsland
        }
    }
}
