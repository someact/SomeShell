import QtQuick
import Quickshell.Networking as QsNet
import qs.core
import qs.components
import qs.services

// Internet: the wired connection, Wi-Fi networks (click to join; a new
// secured one asks for its password, or username and password for an
// enterprise network, here; right-click a saved one for Edit and Forget),
// and the DNS servers.
Column {
    id: root

    property string asking: ""   // network showing its login form
    property string menuFor: ""  // saved network showing Edit and Forget
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
            readonly property bool secured: !Network.open(modelData)
            readonly property bool eap: Network.enterprise(modelData)
            readonly property bool joiningThis: Network.joining === modelData.name
            readonly property bool failed: Network.errorFor === modelData.name && Network.joinError !== ""
            readonly property bool menuOpen: root.menuFor === modelData.name
            readonly property bool formOpen: root.asking === modelData.name

            function askLogin() {
                root.menuFor = "";
                root.asking = modelData.name;
            }
            function submit() {
                if (pass.text === "" || (eap && user.text === ""))
                    return;
                Network.join(modelData, user.text, pass.text);
                pass.text = "";
            }
            // Close the form once joined
            Connections {
                target: Network
                function onJoiningChanged() {
                    if (Network.joining === "" && root.asking === net.modelData.name && Network.errorFor !== net.modelData.name)
                        root.asking = "";
                }
            }

            ListRow {
                icon: net.secured ? "wifi_lock" : "wifi"
                title: net.modelData.name
                sub: net.joiningThis ? "Connecting…"
                    : net.modelData.connected ? "Connected"
                    : net.modelData.known ? "Saved"
                    : net.eap ? "Secured  ·  username and password"
                    : net.secured ? "Secured" : "Open"
                onClicked: {
                    if (net.menuOpen) {
                        root.menuFor = "";
                    } else if (net.modelData.connected) {
                        net.modelData.disconnect();
                    } else if (net.modelData.known || !net.secured) {
                        Network.connect(net.modelData);
                    } else {
                        net.askLogin();
                    }
                }
                // A saved network: Edit or Forget, each its own button
                onRightClicked: if (net.modelData.known) root.menuFor = net.menuOpen ? "" : net.modelData.name

                Tap {
                    visible: net.menuOpen
                    width: 64
                    height: 30
                    outlined: true
                    onClicked: net.askLogin()
                    Txt {
                        anchors.centerIn: parent
                        text: "Edit"
                        caps: true
                        color: parent.fg
                    }
                }
                Tap {
                    visible: net.menuOpen
                    width: 76
                    height: 30
                    outlined: true
                    onClicked: {
                        root.menuFor = "";
                        net.modelData.forget();
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: "Forget"
                        caps: true
                        color: parent.pressed ? parent.fg : Theme.ink.error
                    }
                }
                Tag {
                    visible: net.modelData.connected && !net.menuOpen
                    text: "Connected"
                }
                // Signal as four bars
                Row {
                    visible: !net.menuOpen
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

            // The login: a password, or a username and password (enterprise)
            Row {
                visible: net.formOpen
                spacing: 8
                leftPadding: 46
                bottomPadding: net.failed ? 2 : 8
                Field {
                    id: user
                    visible: net.eap
                    width: 190
                    placeholder: "Username"
                    onVisibleChanged: if (visible && net.formOpen) focusField()
                    onAccepted: pass.focusField()
                }
                Field {
                    id: pass
                    width: net.eap ? 190 : 260
                    placeholder: "Password"
                    secret: true
                    onVisibleChanged: if (visible && !net.eap) focusField()
                    onAccepted: net.submit()
                }
                Tap {
                    width: 80
                    height: 34
                    active: !net.joiningThis
                    enabled: !net.joiningThis
                    onClicked: net.submit()
                    Txt {
                        anchors.centerIn: parent
                        text: net.joiningThis ? "…" : net.modelData.known ? "Save" : "Join"
                        caps: true
                        color: parent.fg
                    }
                }
            }
            Txt {
                visible: net.formOpen && net.failed
                leftPadding: 46
                bottomPadding: 8
                text: "Could not connect: " + Network.joinError
                color: Theme.ink.error
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
