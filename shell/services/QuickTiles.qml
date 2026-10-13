pragma Singleton

import QtQuick
import Quickshell
import qs.core

// The Control view's quick tiles. Each tile is one long-lived object whose
// properties bind to their own source, so a change (the recording timer, the
// Wi-Fi name) updates that one property; nothing is rebuilt. The view lists
// tiles by id and looks the object up, so its delegates live as long as it does.
//
// Which tiles and sliders show, and in what order: Config.control.layout (ids;
// sliders are slider:<name>). Everything else is hidden and can be added back in
// the view's edit mode. Each tile is full (icon, title, state), medium (icon,
// title) or icon only (Config.control.sizes, else tileStyle); sliders always
// take a whole row.
Singleton {
    id: root

    // Every tile and slider, in the order hidden ones are offered
    readonly property list<string> ids: ["wifi", "bluetooth", "warp", "dnd", "game", "nightlight", "caffeine", "mic", "dark", "streamer", "record", "screenshot", "keyboard", "battery", "slider:volume", "slider:mic", "slider:brightness"]
    readonly property list<string> layout: Config.control.layout.length > 0 ? Array.from(Config.control.layout) : Array.from(Config.control.tiles).concat(["slider:volume", "slider:mic", "slider:brightness"])
    // Items without hardware (no Bluetooth adapter, no DDC monitor) are left out of both lists
    readonly property list<string> shown: layout.filter(id => ids.includes(id) && byId[id].available)
    readonly property list<string> hidden: ids.filter(id => !shown.includes(id) && byId[id].available)

    function tile(id) {
        return byId[id] ?? null;
    }
    function isSlider(id) {
        return id.startsWith("slider:");
    }
    // Smallest to largest; the edit badge and the grid button step through them
    readonly property var sizes: [
        { id: "icon", name: "Icon" },
        { id: "medium", name: "Medium" },
        { id: "full", name: "Full" }
    ]
    function size(id) {
        if (isSlider(id))
            return "slider";
        const s = Config.control.sizes[id] ?? Config.control.tileStyle;
        return sizes.some(z => z.id === s) ? s : "full";    // a hand-edited value it does not know
    }
    function nextSize(s) {
        return sizes[(sizes.findIndex(z => z.id === s) + 1) % sizes.length].id;
    }
    function setSize(id, s) {
        const next = Object.assign({}, Config.control.sizes);
        next[id] = s;
        Config.control.sizes = next;
    }
    // The grid button: every tile to one size
    function setAllSizes(s) {
        Config.control.tileStyle = s;
        Config.control.sizes = {};
    }
    // Writes keep unavailable items where they were, so a missing adapter
    // does not drop its tile from the saved layout
    function save(list) {
        const kept = layout.filter(id => ids.includes(id) && !byId[id].available && !list.includes(id));
        Config.control.layout = list.concat(kept);
    }
    function show(id) {
        if (!shown.includes(id))
            save(shown.concat([id]));
    }
    function hide(id) {
        save(shown.filter(t => t !== id));
    }
    function setOrder(list) {
        save(list);
    }

    // `detail`: the Control view's page for a right-click (wifi, bluetooth, warp,
    // nightlight, audio); otherwise right-click opens `settings` in the settings app
    component Tile: QtObject {
        property string icon
        property string title
        property string subtitle
        property bool active: false
        property bool available: true
        property string detail
        property string settings
        property var run: () => {}
    }
    // A slider row: `value` 0..1, `set(v)`, and what its icon and right-click do
    component SliderItem: QtObject {
        property string icon
        property string title
        property real value
        property bool available: true
        property var set: v => {}
        property var iconClick: () => {}
        property var rightClick: () => {}
    }

    readonly property var byId: ({ wifi: wifi, bluetooth: bluetooth, warp: warp, dnd: dnd, game: game, nightlight: nightlight, caffeine: caffeine, mic: mic, dark: dark, streamer: streamer, record: record, screenshot: screenshot, keyboard: keyboard, battery: battery, "slider:volume": volumeSlider, "slider:mic": micSlider, "slider:brightness": brightnessSlider })

    property Tile wifi: Tile {
        icon: Network.icon
        title: Network.hasWifi ? "Wi-Fi" : "Network"
        subtitle: Network.name
        active: Network.hasWifi ? Network.wifiEnabled : Network.connected
        detail: "wifi"
        run: () => Network.hasWifi ? Network.toggleWifi() : UiState.controlDetail = "wifi"
    }
    property Tile bluetooth: Tile {
        icon: BluetoothState.icon
        title: "Bluetooth"
        subtitle: BluetoothState.name
        active: BluetoothState.enabled
        available: BluetoothState.available
        detail: "bluetooth"
        run: () => BluetoothState.toggle()
    }
    // Only with warp-cli installed (Warp.qml)
    property Tile warp: Tile {
        icon: Warp.icon
        title: "WARP"
        subtitle: Warp.summary
        active: Warp.connected
        available: Warp.available
        detail: "warp"
        run: () => Warp.registered ? Warp.toggle() : UiState.controlDetail = "warp"
    }
    property Tile dnd: Tile {
        icon: "do_not_disturb_on"
        title: "Do not disturb"
        subtitle: Notifs.dnd ? "On" : "Off"
        active: Notifs.dnd
        settings: "modes"
        run: () => Notifs.toggleDnd()
    }
    property Tile game: Tile {
        icon: "sports_esports"
        title: "Game mode"
        subtitle: GameMode.active ? "On" : "Auto"
        active: GameMode.active
        settings: "modes"
        run: () => GameMode.toggle()
    }
    property Tile nightlight: Tile {
        icon: "nightlight"
        title: "Night light"
        subtitle: NightLight.active ? NightLight.temperature + " K" : "Off"
        active: NightLight.active
        detail: "nightlight"
        run: () => NightLight.toggle()
    }
    property Tile caffeine: Tile {
        icon: "coffee"
        title: "Keep awake"
        subtitle: UiState.caffeine ? "On" : "Off"
        active: UiState.caffeine
        settings: "desktop"
        run: () => UiState.caffeine = !UiState.caffeine
    }
    property Tile mic: Tile {
        icon: Audio.micIcon
        title: "Microphone"
        subtitle: Audio.micMuted ? "Muted" : "On"
        active: !Audio.micMuted
        detail: "audio"
        run: () => Audio.toggleMicMute()
    }
    property Tile dark: Tile {
        icon: Config.theme.mode === "dark" ? "dark_mode" : "light_mode"
        title: "Dark mode"
        subtitle: Config.theme.mode === "dark" ? "On" : "Off"
        active: Config.theme.mode === "dark"
        settings: "wallpaper"
        run: () => Wallpaper.toggleLightDark()
    }
    property Tile streamer: Tile {
        icon: "cast"
        title: "Streamer mode"
        subtitle: Streamer.active ? (Streamer.auto && !Config.streamer.enabled ? "On · sharing" : "On") : "Off"
        active: Streamer.active
        settings: "modes"
        run: () => Streamer.toggle()
    }
    property Tile record: Tile {
        icon: Recorder.active ? "stop_circle" : "screen_record"
        title: "Record"
        subtitle: Recorder.active ? Recorder.elapsedText : "Region"
        active: Recorder.active
        settings: "capture"
        run: () => Recorder.active ? Recorder.stop() : Capture.start("record")
    }
    property Tile screenshot: Tile {
        icon: "screenshot_region"
        title: "Screenshot"
        subtitle: "Region"
        settings: "capture"
        run: () => Capture.start("shot")
    }
    property Tile keyboard: Tile {
        icon: "keyboard"
        title: "Keyboard"
        subtitle: UiState.osk ? "On" : "Off"
        active: UiState.osk
        settings: "desktop"
        run: () => UiState.osk = !UiState.osk
    }

    // Laptops whose battery has a charge limit (Battery.qml): toggles it
    property Tile battery: Tile {
        icon: Battery.icon
        title: "Battery bypass"
        subtitle: (Battery.limitEnabled ? "On" : "Off") + " · " + Battery.percent + "%"
        active: Battery.limitEnabled
        available: Battery.available && Battery.limitSupported
        settings: "power"
        run: () => Battery.toggleLimit()
    }

    property SliderItem volumeSlider: SliderItem {
        icon: Audio.icon
        title: "Volume"
        value: Audio.volume
        set: v => Audio.setVolume(v)
        iconClick: () => Audio.toggleMute()
        rightClick: () => UiState.open("mixer")
    }
    property SliderItem micSlider: SliderItem {
        icon: Audio.micIcon
        title: "Microphone level"
        value: Audio.micVolume
        set: v => Audio.setMicVolume(v)
        iconClick: () => Audio.toggleMicMute()
        rightClick: () => UiState.controlDetail = "audio"
    }
    property SliderItem brightnessSlider: SliderItem {
        icon: "light_mode"
        title: "Brightness"
        value: Brightness.value
        available: Brightness.available
        set: v => Brightness.set(v)
    }
}
