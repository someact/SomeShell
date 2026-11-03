import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// The tray tab in the top right corner: app tray icons, then the status:
// keyboard layout, network, Bluetooth and battery. A status shows only where
// the hardware is there. Clicks open the matching island page.
Item {
    id: root

    property var window
    // Inside the dock: no tab of its own (the dock is the background)
    property bool plain: false

    implicitWidth: row.implicitWidth + (plain ? 16 : 34)
    implicitHeight: Theme.shape.band

    Rectangle {
        visible: !root.plain
        anchors.fill: parent
        color: Theme.ink.bg
        bottomLeftRadius: Theme.shape.restRadius
    }
    // Ear where the tab meets the top edge
    Shape {
        visible: !root.plain
        readonly property real e: Theme.shape.ear
        x: -e
        width: e
        height: e
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.ink.bg
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: Theme.shape.ear; y: 0 }
            PathLine { x: Theme.shape.ear; y: Theme.shape.ear }
            PathCubic { x: 0; y: 0; control1X: Theme.shape.ear; control1Y: Theme.shape.ear * 0.4477; control2X: Theme.shape.ear * 0.5523; control2Y: 0 }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 2
        spacing: 12

        Repeater {
            model: SystemTray.items

            Item {
                id: entry
                required property var modelData
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (event.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const p = entry.mapToItem(null, 0, entry.height + 8);
                                item.display(root.window, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                }
            }
        }

        // Keyboard layout: a click switches to the next one
        Tap {
            id: layoutTap
            anchors.verticalCenter: parent.verticalCenter
            visible: Keyboard.code !== ""
            implicitWidth: layoutText.implicitWidth + 12
            implicitHeight: 28
            onClicked: Keyboard.next()
            Txt {
                id: layoutText
                anchors.centerIn: parent
                text: Keyboard.code
                caps: true
                color: layoutTap.pressed ? layoutTap.fg : layoutTap.hovered ? Theme.ink.fg : Theme.ink.mute
            }
        }

        // Network: Ethernet, Wi-Fi with signal bars, searching, off
        Tap {
            id: netTap
            anchors.verticalCenter: parent.verticalCenter
            visible: Network.wired !== null || Network.hasWifi
            implicitWidth: 28
            implicitHeight: 28
            onClicked: root.openDetail("net")
            Icon {
                anchors.centerIn: parent
                size: 18
                filled: true
                color: netTap.fg
                name: {
                    if (Network.wiredUp)
                        return "lan";
                    const w = Network.activeWifi;
                    if (w) {
                        const s = w.signalStrength;
                        return s < 0.25 ? "network_wifi_1_bar" : s < 0.5 ? "network_wifi_2_bar" : s < 0.75 ? "network_wifi_3_bar" : "signal_wifi_4_bar";
                    }
                    return Network.hasWifi && Network.wifiOn ? "wifi_find" : "wifi_off";
                }
            }
        }

        // Bluetooth: only while on; shows when a device is connected
        Tap {
            id: btTap
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property bool connected: adapter?.devices.values.some(d => d.connected) ?? false
            anchors.verticalCenter: parent.verticalCenter
            visible: adapter?.enabled ?? false
            implicitWidth: 28
            implicitHeight: 28
            onClicked: root.openDetail("bt")
            Icon {
                anchors.centerIn: parent
                size: 18
                filled: true
                color: btTap.fg
                name: btTap.connected ? "bluetooth_connected" : "bluetooth"
            }
        }

        // Battery: icon and percentage; the error color when low. A click
        // opens the System page (power draw, time left)
        Tap {
            id: batTap
            anchors.verticalCenter: parent.verticalCenter
            visible: Battery.available || Battery.testing
            implicitWidth: batRow.implicitWidth + 12
            implicitHeight: 28
            onClicked: Ui.openPage("system")
        Row {
            id: batRow
            anchors.centerIn: parent
            spacing: 2
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                filled: true
                rotation: 90
                name: Battery.icon
                color: batTap.pressed ? batTap.fg : Battery.low ? Theme.ink.error : Theme.ink.fg
            }
            Digits {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.percent + "%"
                size: Theme.font.small
                color: batTap.pressed ? batTap.fg : Battery.low ? Theme.ink.error : Theme.ink.fg
            }
        }
        }
    }

    function openDetail(name) {
        Ui.openPage("control");
        Ui.detail = name;
    }
}
