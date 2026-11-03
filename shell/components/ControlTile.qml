import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// One control tile of any kind, at any of its sizes ("1x1", "2x1", "2x2").
// Wide tiles show more: Sound and Brightness get a slider at 2x1 and a big
// number at 2x2. `held` is a long press (it starts quick edit).
Item {
    id: root

    property string kind
    property string size: "1x1"
    readonly property bool wide: size !== "1x1"
    readonly property bool big: size === "2x2"
    signal held

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: ({
            net: net, bt: bt, sound: sound, night: night, dnd: dnd, awake: awake, game: game,
            brightness: brightness, shot: shot, record: record,
            dark: dark, mic: mic, picker: picker, clipboard: clipboard, wallpaper: wallpaper, preset: preset, lock: lock, share: share
        })[root.kind] ?? null
    }
    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onHeld() { root.held(); }
    }

    Component {
        id: net
        Tile {
            icon: Network.icon
            label: "Internet"
            sub: Network.label
            active: Network.online
            more: true
            onClicked: Network.hasWifi ? Network.setWifi(!Network.wifiOn) : Ui.detail = "net"
            onOpened: Ui.detail = "net"
        }
    }
    Component {
        id: bt
        Tile {
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
    }
    Component {
        id: sound
        Tile {
            icon: Audio.muted ? "volume_off" : Audio.volume > 0.5 ? "volume_up" : "volume_down"
            label: "Sound"
            sub: root.big ? Audio.name(Audio.sink)
                : Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%" + (root.wide ? "  ·  " + Audio.name(Audio.sink) : "")
            more: true
            onClicked: Audio.toggleMute()
            onOpened: Ui.detail = "sound"
            // 2x2: the slider along the bottom; 2x1: on the right (like Brightness)
            reserveBottom: root.big ? 34 : 0
            reserveRight: root.size === "2x1" ? 184 : 0

            Digits {
                visible: root.big
                anchors.right: parent.right
                anchors.rightMargin: 34
                anchors.top: parent.top
                anchors.topMargin: -4
                text: String(Math.round(Audio.volume * 100))
                size: 52
                color: Theme.ink.fg
            }
            BarSlider {
                visible: root.wide
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.big ? 0 : 4
                width: root.big ? parent.width : 170
                height: root.big ? 24 : 16
                bars: root.big ? 32 : 20
                value: Math.min(1, Audio.volume)
                fill: Audio.muted ? Theme.ink.mute : Theme.ink.fg
                onMoved: v => Audio.setVolume(v)
            }
        }
    }
    Component {
        id: brightness
        Tile {
            icon: "light_mode"
            label: "Brightness"
            sub: !Brightness.available ? "Not available"
                : root.size === "2x1" ? Brightness.value + "%  ·  " + Brightness.label
                : root.big ? Brightness.label : Brightness.value + "%"
            enabled: Brightness.available
            reserveRight: root.size === "2x1" ? 184 : 0
            reserveBottom: root.big ? 34 : 0
            Digits {
                visible: root.big && Brightness.available
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -4
                text: String(Brightness.value)
                size: 52
                color: Theme.ink.fg
            }
            BarSlider {
                visible: root.wide && Brightness.available
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.big ? 0 : 4
                width: root.big ? parent.width : 170
                height: root.big ? 24 : 16
                bars: root.big ? 32 : 20
                value: Brightness.value / 100
                onMoved: v => Brightness.set(v * 100)
            }
        }
    }
    Component {
        id: night
        Tile {
            icon: "nightlight"
            label: "Night light"
            sub: NightLight.on ? NightLight.temperature + " K" : Config.nightLight.auto ? "From " + Config.nightLight.from : "Off"
            active: NightLight.on
            more: true
            onClicked: NightLight.toggle()
            onOpened: Ui.detail = "night"
        }
    }
    Component {
        id: dnd
        Tile {
            icon: "do_not_disturb_on"
            label: "Do not disturb"
            sub: Notifications.dnd ? "On" : "Off"
            active: Notifications.dnd
            onClicked: Notifications.dnd = !Notifications.dnd
        }
    }
    Component {
        id: awake
        Tile {
            icon: "coffee"
            label: "Keep awake"
            sub: KeepAwake.on ? "On" : "Off"
            active: KeepAwake.on
            onClicked: KeepAwake.toggle()
        }
    }
    Component {
        id: game
        Tile {
            icon: "sports_esports"
            label: "Game mode"
            sub: GameMode.active ? "On" : "Auto"
            active: GameMode.active
            onClicked: GameMode.toggle()
        }
    }
    Component {
        id: shot
        Tile {
            icon: "screenshot_region"
            label: "Screenshot"
            sub: "Region"
            onClicked: Capture.start("shot")
        }
    }
    Component {
        id: record
        Tile {
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

    // New with quick edit
    Component {
        id: dark
        Tile {
            icon: Theme.dark ? "dark_mode" : "light_mode"
            label: "Dark mode"
            sub: Theme.dark ? "On" : "Off"
            active: Theme.dark
            onClicked: Config.theme.mode = Theme.dark ? "light" : "dark"
        }
    }
    Component {
        id: mic
        Tile {
            icon: Audio.micMuted ? "mic_off" : "mic"
            label: "Microphone"
            sub: !Audio.source ? "No microphone" : Audio.micMuted ? "Off" : "On"
            active: !!Audio.source && !Audio.micMuted
            enabled: !!Audio.source
            onClicked: Audio.toggleMic()
        }
    }
    Component {
        id: picker
        Tile {
            icon: "colorize"
            label: "Color picker"
            sub: "Copies the color"
            onClicked: {
                Ui.close();
                Quickshell.execDetached(["sh", "-c", "sleep 0.4; hyprpicker -a"]);
            }
        }
    }
    Component {
        id: clipboard
        Tile {
            icon: "content_paste"
            label: "Clipboard"
            sub: "Super+V"
            onClicked: Ui.openPage("clipboard")
        }
    }
    Component {
        id: wallpaper
        Tile {
            icon: "shuffle"
            label: "Wallpaper"
            sub: "Random"
            more: true
            onClicked: Wallpapers.random()
            onOpened: Ui.edit("wallpaper")
        }
    }
    Component {
        id: preset
        Tile {
            icon: "dashboard_customize"
            label: "Preset"
            sub: Desktop.preset || "None"
            more: true
            onClicked: Ui.openPage("search", false, "/preset ")
            onOpened: Ui.edit("presets")
        }
    }
    Component {
        id: lock
        Tile {
            icon: "lock"
            label: "Lock"
            sub: "Lock the screen"
            onClicked: {
                Ui.close();
                Quickshell.execDetached(["loginctl", "lock-session"]);
            }
        }
    }
    // Quick Share: a click turns receiving on or off; the arrow (and a right
    // click, Shift+Enter) opens the Quick Share page
    Component {
        id: share
        Tile {
            icon: "share"
            label: "Quick Share"
            active: Share.alive && Share.receiving
            sub: !Share.adapter ? "No Bluetooth"
                : !Share.installed ? "Not installed"
                : Jobs.list.some(j => j.kind === "send" || j.kind === "receive") ? "Sharing…"
                : Share.receiving ? "Receiving on" : "Receiving off"
            enabled: Share.adapter && Share.installed
            more: true
            onClicked: Share.toggleReceive()
            onOpened: Share.openPage()
        }
    }
}
