import QtQuick
import Quickshell.Networking as NM
import qs.core
import qs.components
import qs.services

// Control → right-click Network: wired links, and with Wi-Fi hardware the
// networks around (scanning only while this page is open). Click connects or
// disconnects; a secured network asks for its password inline.
Column {
    id: root

    spacing: 6

    readonly property var wiredDevices: Network.devices.filter(d => d.type === NM.DeviceType.Wired)
    readonly property var networks: {
        const list = Network.wifi?.networks.values.slice() ?? [];
        return list.filter(n => n.name !== "").sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    property var asking: null             // network waiting for a password
    property string error: ""

    Component.onCompleted: if (Network.wifi) Network.wifi.scannerEnabled = true
    Component.onDestruction: if (Network.wifi) Network.wifi.scannerEnabled = false

    function signalIcon(s) {
        return s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    function secured(n) {
        return n.security !== NM.WifiSecurityType.Open && n.security !== NM.WifiSecurityType.Owe;
    }
    function activate(n) {
        error = "";
        if (n.connected)
            n.disconnect();
        else if (n.known || !secured(n))
            n.connect();
        else {
            asking = n;
            Qt.callLater(() => pass.focusInput());
        }
    }

    // Esc leaves the password field first
    function handleKey(event) {
        if (asking && event.key === Qt.Key_Escape) {
            asking = null;
            return true;
        }
        return false;
    }

    Repeater {
        model: root.wiredDevices
        DetailRow {
            required property var modelData
            icon: "lan"
            title: "Ethernet"
            subtitle: modelData.connected ? "Connected" + (modelData.linkSpeed > 0 ? " · " + modelData.linkSpeed + " Mb/s" : "") : modelData.hasLink ? "Cable in, not connected" : "No cable"
            current: modelData.connected
        }
    }

    Item {
        visible: Network.hasWifi
        width: parent.width
        height: 34
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            text: "Wi-Fi"
            font.styleName: Theme.font.styleTitle
        }
        PillSwitch {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: Network.wifiEnabled
            onToggled: Network.toggleWifi()
        }
    }

    Label {
        visible: !Network.hasWifi
        x: 12
        text: "No Wi-Fi hardware"
        color: Theme.fgIslandDim
        font.pixelSize: Theme.font.small
    }
    Label {
        visible: Network.hasWifi && Network.wifiEnabled && root.networks.length === 0
        x: 12
        text: "Searching…"
        color: Theme.fgIslandDim
        font.pixelSize: Theme.font.small
    }

    Flickable {
        visible: Network.hasWifi && Network.wifiEnabled && root.networks.length > 0
        width: parent.width
        height: Math.min(list.implicitHeight, 300)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 2
            Repeater {
                model: root.networks
                DetailRow {
                    id: row
                    required property var modelData
                    icon: root.signalIcon(modelData.signalStrength)
                    title: modelData.name
                    subtitle: modelData.stateChanging ? "Connecting…" : modelData.connected ? "Connected" : modelData.known ? "Saved" : root.secured(modelData) ? "Secured" : "Open"
                    current: modelData.connected
                    busy: modelData.stateChanging
                    action: modelData.known ? "delete" : ""
                    onClicked: root.activate(modelData)
                    onActionClicked: modelData.forget()
                    Connections {
                        target: row.modelData
                        function onConnectionFailed(reason) {
                            root.error = row.modelData.name + ": " + NM.ConnectionFailReason.toString(reason);
                        }
                    }
                }
            }
        }
    }

    // Password for a new secured network
    SearchField {
        id: pass
        visible: root.asking !== null
        width: parent.width
        icon: "key"
        placeholder: root.asking ? "Password for " + root.asking.name : ""
        echoMode: TextInput.Password
        keyHandler: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.asking.connectWithPsk(pass.text);
                pass.text = "";
                root.asking = null;
                return true;
            }
            if (event.key === Qt.Key_Escape) {
                root.asking = null;
                return true;
            }
            return false;
        }
    }

    Label {
        visible: root.error !== ""
        x: 12
        width: parent.width - 24
        text: root.error
        color: Theme.error
        font.pixelSize: Theme.font.small
    }
}
