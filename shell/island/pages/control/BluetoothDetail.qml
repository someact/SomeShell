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
    // Connected first, then paired ones by name, then devices found nearby in
    // the order they turned up: a new one joins at the end, so rows never
    // move under a finger while scanning (the list scrolls, so a phone to
    // pair is never cut off)
    function rank(d) {
        return d.connected ? 0 : d.paired ? 1 : 2;
    }
    // Nameless devices found nearby (shown by their address) are left out.
    // The sort is stable: found ones keep bluez's order (first seen first)
    readonly property var devices: (adapter?.devices.values ?? []).slice()
        .filter(d => d.paired || (d.name && d.name !== d.address.replace(/:/g, "-")))
        .sort((a, b) => (rank(a) - rank(b)) || (rank(a) < 2 ? a.name.localeCompare(b.name) : 0))

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

    // Every device, six rows tall at most, then it scrolls (a finger drags it;
    // the keyboard mark scrolls it too). A paired device's ⋯ (or a right
    // click, a long press, Shift+Enter) shows Connect / Disconnect and Forget,
    // so forgetting never needs a second mouse button.
    property string menuFor: ""  // address of the device showing its actions
    onDevicesChanged: if (menuFor && !devices.some(d => d.address === menuFor && d.paired)) menuFor = ""

    Flickable {
        id: list
        width: root.width
        height: Math.min(rows.implicitHeight, 52 * 6)
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            width: list.width

            Repeater {
                model: root.adapter?.enabled ? root.devices : []

                ListRow {
                    id: row
                    required property var modelData
                    readonly property bool menuOpen: root.menuFor === modelData.address
                    function toggleMenu() {
                        if (modelData.paired)
                            root.menuFor = menuOpen ? "" : modelData.address;
                    }
                    icon: modelData.icon?.includes("headset") || modelData.icon?.includes("headphone") ? "headphones"
                        : modelData.icon?.includes("mouse") ? "mouse" : modelData.icon?.includes("keyboard") ? "keyboard"
                        : modelData.icon?.includes("phone") ? "smartphone" : modelData.icon?.includes("audio") ? "speaker" : "bluetooth"
                    title: modelData.name
                    // Two devices with one name (a keyboard paired on two channels):
                    // the end of the address tells them apart
                    readonly property bool twin: root.devices.filter(d => d.name === modelData.name).length > 1
                    sub: (modelData.pairing ? "Pairing…  ·  tap to stop" : modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Found nearby  ·  tap to pair")
                        + (twin ? "  ·  " + modelData.address.slice(-5) : "")
                    onClicked: {
                        if (menuOpen)
                            root.menuFor = "";
                        else if (modelData.pairing)
                            modelData.cancelPair();
                        else if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.paired)
                            modelData.connect();
                        else
                            modelData.pair();
                    }
                    onRightClicked: toggleMenu()

                    Txt {
                        visible: row.modelData.batteryAvailable && !row.menuOpen
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(row.modelData.battery * 100) + "%"
                        caps: true
                        color: Theme.ink.mute
                    }
                    Tag {
                        visible: row.modelData.connected && !row.menuOpen
                        text: "Connected"
                    }
                    Tap {
                        visible: row.menuOpen
                        width: 112
                        height: 34
                        outlined: true
                        onClicked: {
                            root.menuFor = "";
                            row.modelData.connected ? row.modelData.disconnect() : row.modelData.connect();
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: row.modelData.connected ? "Disconnect" : "Connect"
                            caps: true
                            color: parent.fg
                        }
                    }
                    Tap {
                        visible: row.menuOpen
                        width: 84
                        height: 34
                        outlined: true
                        onClicked: {
                            root.menuFor = "";
                            row.modelData.forget();
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: "Forget"
                            caps: true
                            color: parent.pressed ? parent.fg : Theme.ink.error
                        }
                    }
                    // ⋯ / ×: big enough for a finger
                    Tap {
                        visible: row.modelData.paired
                        width: 40
                        height: 40
                        onClicked: row.toggleMenu()
                        Icon {
                            anchors.centerIn: parent
                            name: row.menuOpen ? "close" : "more_horiz"
                            color: parent.fg
                        }
                    }
                }
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
