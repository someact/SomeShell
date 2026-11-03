import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// Bluetooth: on/off, scan, devices (click: connect, disconnect or pair;
// right click: forget), and this computer's name as others see it. While
// the page is open it scans, and this computer is visible and pairable (the
// Quick Share helper; a phone's pairing code is asked here).
Column {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    // Connected first, then devices just found (a phone to pair must not
    // fall below the list's end behind paired keyboards), then paired ones
    function rank(d) {
        return d.connected ? 0 : !d.paired ? 1 : 2;
    }
    // Nameless devices found nearby (shown by their address) are left out
    readonly property var devices: (adapter?.devices.values ?? []).slice()
        .filter(d => d.paired || (d.name && d.name !== d.address.replace(/:/g, "-")))
        .sort((a, b) => (rank(a) - rank(b)) || a.name.localeCompare(b.name))

    // Scanning and visible while open (Share counts the pages: on a page
    // switch the new one is made before the old one goes)
    Component.onCompleted: Share.setVisible(true)
    Component.onDestruction: Share.setVisible(false)
    property bool renaming: false

    spacing: 6

    BackRow {
        title: "Bluetooth"
        Tap {
            visible: root.adapter?.enabled ?? false
            width: 96
            height: 34
            outlined: true
            active: root.adapter?.discovering ?? false
            onClicked: root.adapter.discovering = !root.adapter.discovering
            Txt {
                anchors.centerIn: parent
                text: root.adapter?.discovering ? "Scanning" : "Scan"
                caps: true
                color: parent.fg
            }
        }
        Tap {
            width: 70
            height: 34
            outlined: true
            active: root.adapter?.enabled ?? false
            enabled: root.adapter !== null
            onClicked: root.adapter.enabled = !root.adapter.enabled
            Txt {
                anchors.centerIn: parent
                text: root.adapter?.enabled ? "On" : "Off"
                caps: true
                color: parent.fg
            }
        }
    }

    PairPrompt {
        width: root.width
    }

    Repeater {
        model: root.adapter?.enabled ? root.devices.slice(0, 7) : []

        ListRow {
            required property var modelData
            icon: modelData.icon?.includes("headset") || modelData.icon?.includes("headphone") ? "headphones"
                : modelData.icon?.includes("mouse") ? "mouse" : modelData.icon?.includes("keyboard") ? "keyboard"
                : modelData.icon?.includes("phone") ? "smartphone" : modelData.icon?.includes("audio") ? "speaker" : "bluetooth"
            title: modelData.name
            // Two devices with one name (a keyboard paired on two channels):
            // the end of the address tells them apart
            readonly property bool twin: root.devices.filter(d => d.name === modelData.name).length > 1
            sub: (modelData.pairing ? "Pairing…" : modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Found nearby")
                + (twin ? "  ·  " + modelData.address.slice(-5) : "")
            onClicked: modelData.connected ? modelData.disconnect() : modelData.paired ? modelData.connect() : modelData.pair()
            onRightClicked: if (modelData.paired) modelData.forget()

            Txt {
                visible: modelData.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(modelData.battery * 100) + "%"
                caps: true
                color: Theme.ink.mute
            }
            Tag {
                visible: modelData.connected
                text: "Connected"
            }
        }
    }

    ListRow {
        visible: (root.adapter?.enabled ?? false) && root.devices.length === 0
        icon: "bluetooth_searching"
        title: root.adapter?.discovering ? "Looking for devices" : "No devices yet"
        sub: root.adapter?.discovering ? "" : "Scan to find one"
        clickable: false
    }

    ListRow {
        visible: root.adapter !== null
        icon: "computer"
        title: "This computer"
        sub: (root.adapter?.name ?? "") + (Share.discoverable ? "  ·  visible now" : "")
        clickable: false
        line: false
        Tap {
            visible: !root.renaming
            width: 84
            height: 34
            outlined: true
            onClicked: {
                root.renaming = true;
                nameField.text = root.adapter.name;
                nameField.focusField();
            }
            Txt {
                anchors.centerIn: parent
                text: "Rename"
                caps: true
                color: parent.fg
            }
        }
        Field {
            id: nameField
            visible: root.renaming
            width: 220
            placeholder: "Name others see"
            onAccepted: text => {
                if (text.trim())
                    Quickshell.execDetached(["bluetoothctl", "system-alias", text.trim()]);
                root.renaming = false;
            }
        }
    }
}
