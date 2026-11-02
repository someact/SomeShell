import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// 02 Control. Tiles in a 4-column grid; a tile's arrow (or a right click)
// opens its own page: Internet, Bluetooth, Sound, Night light. The layout is
// fixed for now; editing it (sizes, order) comes with edit mode in step 6.
Item {
    id: root

    readonly property int cell: 180
    readonly property int row: 100
    readonly property int gap: 10
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

    implicitWidth: 4 * cell + 3 * gap
    // The backlight may have been changed by another tool since
    Component.onCompleted: Brightness.refresh()
    implicitHeight: Ui.detail ? detailLoader.implicitHeight : grid.height

    function span(c, r) {
        return { w: c * cell + (c - 1) * gap, h: r * row + (r - 1) * gap };
    }

    // The grid: positions are (column, row, columns wide, rows tall)
    Item {
        id: grid
        visible: !Ui.detail
        width: parent.width
        height: 4 * root.row + 3 * root.gap

        Tile {
            x: 0; y: 0
            width: root.span(2, 1).w; height: root.row
            icon: Network.icon
            label: "Internet"
            sub: Network.label
            active: Network.online
            more: true
            onClicked: Network.hasWifi ? Network.setWifi(!Network.wifiOn) : Ui.detail = "net"
            onOpened: Ui.detail = "net"
        }
        Tile {
            x: root.span(2, 1).w + root.gap; y: 0
            width: root.span(2, 1).w; height: root.row
            icon: root.adapter?.enabled ? "bluetooth" : "bluetooth_disabled"
            label: "Bluetooth"
            sub: !root.adapter ? "No adapter" : !root.adapter.enabled ? "Off"
                : root.btConnected.length ? root.btConnected.map(d => d.name).join(", ") : "On"
            active: root.adapter?.enabled ?? false
            enabled: root.adapter !== null
            more: true
            onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            onOpened: Ui.detail = "bt"
        }

        // Sound: 2 x 2 with the volume
        Tile {
            x: 0; y: root.row + root.gap
            width: root.span(2, 2).w; height: root.span(2, 2).h
            icon: Audio.muted ? "volume_off" : Audio.volume > 0.5 ? "volume_up" : "volume_down"
            label: "Sound"
            sub: Audio.name(Audio.sink)
            more: true
            onClicked: Audio.toggleMute()
            onOpened: Ui.detail = "sound"
            reserveBottom: 34

            Digits {
                anchors.right: parent.right
                anchors.rightMargin: 34
                anchors.top: parent.top
                anchors.topMargin: -4
                text: String(Math.round(Audio.volume * 100))
                size: 52
                color: Theme.ink.fg
            }
            BarSlider {
                width: parent.width
                anchors.bottom: parent.bottom
                value: Math.min(1, Audio.volume)
                fill: Audio.muted ? Theme.ink.mute : Theme.ink.fg
                onMoved: v => Audio.setVolume(v)
            }
        }
        Tile {
            x: 2 * (root.cell + root.gap); y: root.row + root.gap
            width: root.cell; height: root.row
            icon: "nightlight"
            label: "Night light"
            sub: NightLight.on ? NightLight.temperature + " K" : Config.nightLight.auto ? "From " + Config.nightLight.from : "Off"
            active: NightLight.on
            more: true
            onClicked: NightLight.toggle()
            onOpened: Ui.detail = "night"
        }
        Tile {
            x: 3 * (root.cell + root.gap); y: root.row + root.gap
            width: root.cell; height: root.row
            icon: "do_not_disturb_on"
            label: "Do not disturb"
            sub: Notifications.dnd ? "On" : "Off"
            active: Notifications.dnd
            onClicked: Notifications.dnd = !Notifications.dnd
        }
        Tile {
            x: 2 * (root.cell + root.gap); y: 2 * (root.row + root.gap)
            width: root.cell; height: root.row
            icon: "coffee"
            label: "Keep awake"
            sub: KeepAwake.on ? "On" : "Off"
            active: KeepAwake.on
            onClicked: KeepAwake.toggle()
        }
        Tile {
            x: 3 * (root.cell + root.gap); y: 2 * (root.row + root.gap)
            width: root.cell; height: root.row
            icon: "sports_esports"
            label: "Game mode"
            sub: GameMode.active ? "On" : "Auto"
            active: GameMode.active
            onClicked: GameMode.toggle()
        }

        // Brightness: 2 x 1 with a slider
        Tile {
            x: 0; y: 3 * (root.row + root.gap)
            width: root.span(2, 1).w; height: root.row
            icon: "light_mode"
            label: "Brightness"
            sub: Brightness.available ? Brightness.value + "%  ·  " + Brightness.label : "Not available"
            enabled: Brightness.available
            reserveRight: 184
            BarSlider {
                visible: Brightness.available
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: 170
                height: 16
                bars: 20
                value: Brightness.value / 100
                onMoved: v => Brightness.set(v * 100)
            }
        }
        Tile {
            x: 2 * (root.cell + root.gap); y: 3 * (root.row + root.gap)
            width: root.cell; height: root.row
            icon: "screenshot_region"
            label: "Screenshot"
            sub: "Region"
            onClicked: Capture.start("shot")
        }
        Tile {
            x: 3 * (root.cell + root.gap); y: 3 * (root.row + root.gap)
            width: root.cell; height: root.row
            icon: "screen_record"
            label: "Record"
            sub: Recorder.recording ? "Stop" : "Screen"
            active: Recorder.recording
            onClicked: {
                Ui.close();
                Recorder.toggle(false);
            }
        }
    }

    // A tile's own page
    Loader {
        id: detailLoader
        visible: !!Ui.detail
        width: parent.width
        source: Ui.detail ? "control/" + ({ net: "NetworkDetail", bt: "BluetoothDetail", sound: "SoundDetail", night: "NightDetail" })[Ui.detail] + ".qml" : ""
    }
}
