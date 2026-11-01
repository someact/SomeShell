import QtQuick
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// Control → right-click Bluetooth: paired devices and, while this page is open,
// discovery of new ones. Click connects or disconnects; a new device pairs
// (trusted, then connected); the trailing button forgets a paired one.
Column {
    id: root

    spacing: 6

    readonly property var adapter: BluetoothState.adapter
    readonly property var devices: {
        // Unnamed devices around (BlueZ names them after their address) are noise
        const list = Bluetooth.devices.values.filter(d => d.paired || (d.name !== "" && d.name.replace(/-/g, ":") !== d.address));
        return list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
    }
    readonly property var paired: devices.filter(d => d.paired)
    readonly property var found: devices.filter(d => !d.paired)

    Component.onCompleted: if (adapter?.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false
    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.adapter.enabled)
                root.adapter.discovering = true;
        }
    }

    function iconFor(d) {
        const i = d.icon ?? "";
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio"))
            return "speaker";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("phone"))
            return "smartphone";
        if (i.includes("gaming") || i.includes("joystick"))
            return "sports_esports";
        if (i.includes("computer"))
            return "computer";
        return "bluetooth";
    }
    function stateText(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + " %" : "");
        return d.paired ? "Paired" : "Click to pair";
    }
    function activate(d) {
        if (d.connected)
            d.disconnect();
        else if (d.paired)
            d.connect();
        else {
            d.trusted = true;
            d.pair();
        }
    }

    Item {
        width: parent.width
        height: 34
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            text: root.adapter?.discovering ? "Bluetooth · searching…" : "Bluetooth"
            font.styleName: Theme.font.styleTitle
        }
        PillSwitch {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: BluetoothState.enabled
            onToggled: BluetoothState.toggle()
        }
    }

    Flickable {
        visible: BluetoothState.enabled
        width: parent.width
        height: Math.min(list.implicitHeight, 320)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 2

            Repeater {
                model: root.paired
                Device {}
            }
            Label {
                visible: root.found.length > 0
                x: 12
                height: 28
                text: "Available"
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
            Repeater {
                model: root.found
                Device {}
            }
        }
    }

    Label {
        visible: BluetoothState.enabled && root.devices.length === 0
        x: 12
        text: "No devices yet"
        color: Theme.fgIslandDim
        font.pixelSize: Theme.font.small
    }

    component Device: DetailRow {
        id: row
        required property var modelData
        icon: root.iconFor(modelData)
        title: modelData.name || modelData.address
        subtitle: root.stateText(modelData)
        current: modelData.connected
        busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
        action: modelData.paired ? "delete" : ""
        onClicked: root.activate(modelData)
        onActionClicked: modelData.forget()
        // A device paired from here connects once pairing finishes
        Connections {
            target: row.modelData
            function onPairedChanged() {
                if (row.modelData.paired && !row.modelData.connected)
                    row.modelData.connect();
            }
        }
    }
}
