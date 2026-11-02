import QtQuick
import Quickshell.Networking as QsNet
import qs.core
import qs.components
import qs.services

// Internet: the wired connection, Wi-Fi networks (click to join; a new
// secured one asks for its password here), and the DNS servers.
Column {
    id: root

    property string asking: ""   // network asking for a password
    property bool editingDns: false

    spacing: 6
    Component.onCompleted: Network.refresh()

    BackRow {
        title: "Internet"
        Tap {
            visible: Network.hasWifi
            width: 96
            height: 34
            outlined: true
            active: Network.wifiOn
            onClicked: Network.setWifi(!Network.wifiOn)
            Txt {
                anchors.centerIn: parent
                text: Network.wifiOn ? "Wi-Fi on" : "Wi-Fi off"
                caps: true
                color: parent.fg
            }
        }
    }

    ListRow {
        visible: Network.wired !== null
        icon: "settings_ethernet"
        title: "Ethernet"
        sub: Network.wired ? (Network.wiredUp ? Network.wired.name + "  ·  connected" : "Not plugged in") : ""
        clickable: false
        Tag {
            visible: Network.wiredUp
            text: "Connected"
        }
    }

    Repeater {
        model: Network.wifiOn ? Network.networks.slice(0, 6) : []

        Column {
            id: net
            required property var modelData
            width: root.width
            readonly property bool secured: modelData.security !== QsNet.WifiSecurityType.Open

            ListRow {
                icon: net.secured ? "wifi_lock" : "wifi"
                title: net.modelData.name
                sub: net.modelData.connected ? "Connected" : net.modelData.known ? "Saved" : net.secured ? "Secured" : "Open"
                onClicked: {
                    if (net.modelData.connected)
                        net.modelData.disconnect();
                    else if (net.modelData.known || !net.secured)
                        Network.join(net.modelData, "");
                    else
                        root.asking = net.modelData.name;
                }
                onRightClicked: if (net.modelData.known) net.modelData.forget()

                Tag {
                    visible: net.modelData.connected
                    text: "Connected"
                }
                // Signal as four bars
                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 3
                            height: 4 + index * 3
                            anchors.bottom: parent.bottom
                            radius: 1
                            color: net.modelData.signalStrength > index * 0.25 ? Theme.ink.fg : Theme.ink.line
                        }
                    }
                }
            }
            Row {
                visible: root.asking === net.modelData.name
                spacing: 8
                leftPadding: 46
                bottomPadding: 8
                Field {
                    id: pass
                    width: 260
                    placeholder: "Password for " + net.modelData.name
                    secret: true
                    onVisibleChanged: if (visible) focusField()
                    onAccepted: text => {
                        Network.join(net.modelData, text);
                        root.asking = "";
                    }
                }
                Tap {
                    width: 80
                    height: 34
                    active: true
                    onClicked: {
                        Network.join(net.modelData, pass.text);
                        root.asking = "";
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: "Join"
                        caps: true
                        color: parent.fg
                    }
                }
            }
        }
    }

    ListRow {
        visible: Network.hasWifi && Network.wifiOn && Network.networks.length === 0
        icon: "wifi_find"
        title: "Looking for networks"
        clickable: false
    }

    ListRow {
        icon: "dns"
        title: "DNS"
        sub: Network.connectionName ? Network.dns + "  ·  " + Network.connectionName : "No connection"
        clickable: false
        line: false
        Tap {
            visible: !root.editingDns && Network.connectionName !== ""
            width: 70
            height: 34
            outlined: true
            onClicked: {
                root.editingDns = true;
                dnsField.focusField();
            }
            Txt {
                anchors.centerIn: parent
                text: "Edit"
                caps: true
                color: parent.fg
            }
        }
        Field {
            id: dnsField
            visible: root.editingDns
            width: 240
            placeholder: "1.1.1.1 1.0.0.1 (empty = automatic)"
            onAccepted: text => {
                Network.setDns(text);
                root.editingDns = false;
            }
        }
    }
}
