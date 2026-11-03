import QtQuick
import qs.core
import qs.components
import qs.services

// Quick Share (services/Share.qml): an incoming file to accept or decline,
// or the devices to send to (after Share on the Drop page, or from the
// control tile). A phone must be paired first (the Bluetooth page).
Item {
    id: root

    readonly property var incoming: Share.offers[0] ?? null
    readonly property var pending: Share.pending

    implicitWidth: 560
    implicitHeight: col.implicitHeight

    function size(b) {
        const u = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) {
            b /= 1000;
            i++;
        }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i];
    }

    // The devices again whenever the page opens (pairing may have changed),
    // and phones on the network while it is open
    Component.onCompleted: {
        Share.refresh();
        Share.setScan(true);
    }
    Component.onDestruction: Share.setScan(false)

    Column {
        id: col
        width: root.width
        spacing: 14

        // A device asking to pair
        PairPrompt {
            width: parent.width
        }

        // Incoming: who, what, Accept / Decline
        Column {
            visible: root.incoming !== null && Share.pairs.length === 0
            width: parent.width
            spacing: 14
            Row {
                width: parent.width
                spacing: 16
                Rectangle {
                    width: 60
                    height: 60
                    radius: Theme.shape.small
                    color: Theme.ink.raised
                    Icon {
                        anchors.centerIn: parent
                        name: "download"
                        size: 28
                        color: Theme.ink.fg
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 76
                    spacing: 4
                    Txt {
                        width: parent.width
                        text: root.incoming?.name ?? ""
                        size: Theme.font.body
                        face: Theme.font.medium
                    }
                    Txt {
                        width: parent.width
                        text: (root.incoming?.peer ?? "") + " wants to send this  ·  " + root.size(root.incoming?.size ?? 0)
                            + (root.incoming?.pin ? "  ·  PIN " + root.incoming.pin : "")
                            + (root.incoming?.via === "quick" ? "  ·  Wi-Fi" : "  ·  Bluetooth")
                            + (Share.offers.length > 1 ? "  ·  " + (Share.offers.length - 1) + " more" : "")
                        caps: true
                        color: Theme.ink.mute
                    }
                }
            }
            Row {
                spacing: 8
                Chip {
                    icon: "check"
                    label: "Accept"
                    active: true
                    onClicked: Share.answer(root.incoming.id, true)
                }
                Chip {
                    icon: "close"
                    label: "Decline"
                    onClicked: Share.answer(root.incoming.id, false)
                }
            }
        }

        // Sending: what goes, then the devices
        Txt {
            visible: root.incoming === null && Share.pairs.length === 0
            width: parent.width
            text: !root.pending ? "Drop files on the island to share them"
                : root.pending.url ? "Send the link  ·  " + root.pending.url
                : root.pending.files.length === 1 ? "Send " + root.pending.files[0].split("/").pop()
                : "Send " + root.pending.files.length + " files"
            caps: true
            color: Theme.ink.mute
        }
        Column {
            visible: root.incoming === null && Share.pairs.length === 0
            width: parent.width
            Repeater {
                model: Share.targets
                ListRow {
                    required property var modelData
                    icon: modelData.icon
                    title: modelData.name
                    sub: modelData.sub
                    clickable: root.pending !== null
                    onClicked: Share.sendTo(modelData)
                    Icon {
                        visible: root.pending !== null
                        anchors.verticalCenter: parent.verticalCenter
                        name: "send"
                        size: 20
                        color: Theme.ink.mute
                    }
                }
            }
        }
        // Quick Share phones show up here once found on the network
        Txt {
            visible: root.incoming === null && Share.pairs.length === 0 && root.pending !== null && Share.quick && Share.nearby.length === 0 && Share.targets.length > 0
            width: parent.width
            text: "Looking for phones on the network: on the phone, Quick Share visible to Everyone, same Wi-Fi"
            wrapMode: Text.Wrap
            maximumLineCount: 2
            color: Theme.ink.mute
        }

        // No phone yet: where to pair one
        Row {
            visible: root.incoming === null && Share.pairs.length === 0 && Share.targets.length === 0
            width: parent.width
            spacing: 14
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - pairChip.width - 14
                text: !Share.installed ? "The Quick Share helper is not installed (share/install.sh)."
                    : !Share.ready ? "Starting…"
                    : Share.quick ? "Looking on the network. On the phone: Quick Share visible to Everyone, same Wi-Fi. Or pair it by Bluetooth."
                    : "No paired phone or computer yet. Pair one, then share."
                wrapMode: Text.Wrap
                maximumLineCount: 2
                color: Theme.ink.mute
            }
            Chip {
                id: pairChip
                anchors.verticalCenter: parent.verticalCenter
                icon: "bluetooth"
                label: "Bluetooth"
                onClicked: {
                    Ui.openPage("control");
                    Ui.detail = "bt";
                }
            }
        }
    }
}
