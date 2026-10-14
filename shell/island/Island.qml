import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services
import "ambient"
import "views"

// The island: one top-layer window per monitor. Collapsed it shows the most
// important ambient state, plus a side slot for recording and microphone /
// screen-share use while something else has the main place (Config.island.dual);
// expanded it hosts one view at a time. The notch
// shape springs to the size of whatever it holds, and the content follows a
// beat later, so shape and content move as one reaction.
//
// The window is larger than the notch; `mask` passes clicks outside the notch
// through, and the compositor blurs only the notch (BackgroundEffect).
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    readonly property bool isFocusedScreen: (Hyprland.focusedMonitor?.name ?? modelData.name) === modelData.name
    readonly property bool open: UiState.expanded && isFocusedScreen
    // Hover peek: a view shown without keyboard focus (see the hover section)
    readonly property bool peek: UiState.peeking && !UiState.expanded && UiState.peekScreen === modelData.name
    readonly property bool shown: open || peek

    // Ambient priority: polkit → Quick Share asking → notification → OSD → Quick Share
    // progress → recording → privacy → game dot → media → clock
    // (in streamer mode notification peeks go to the private layer, see PrivatePeek.qml).
    // With the side slot on, recording and privacy let media keep the main place
    // and show in the slot instead (never in game mode, where the island is a nub).
    readonly property string persistent: Recorder.active ? "record" : Privacy.active ? "privacy" : ""
    readonly property bool mediaShown: Media.active && Config.island.showMedia
    readonly property string ambient: {
        if (Polkit.active)
            return "polkit";
        if (QuickShare.pending)
            return "share";
        if (Notifs.peeked && !Streamer.active)
            return "notif";
        if (Osd.visible)
            return "osd";
        if (QuickShare.current && !GameMode.active)
            return "share";
        if (persistent !== "" && (!Config.island.dual || !mediaShown || GameMode.active))
            return persistent;
        if (GameMode.active)
            return "dot";
        if (mediaShown)
            return "media";
        return "clock";
    }
    // The side slot: only beside content that would otherwise hide the state
    readonly property bool side: Config.island.dual && persistent !== "" && (ambient === "notif" || ambient === "osd" || ambient === "media" || ambient === "share")
    readonly property real sideGap: 10
    readonly property real sideWidth: sideLoader.item ? sideLoader.item.implicitWidth + sideGap : 0

    // Styles: notch hangs from the edge; floating and satellites are a free pill
    // level with the corner pills (satellites also pulls the pills to its sides)
    readonly property bool floating: Config.island.style !== "notch"
    readonly property real topGap: floating ? 3 : 0
    readonly property real ear: floating ? 0 : 12
    readonly property real pad: 18
    readonly property real minCollapsedWidth: 160
    readonly property bool showTabs: UiState.mainViews.includes(UiState.view)

    readonly property real targetWidth: {
        if (shown && viewLoader.item)
            return viewLoader.item.implicitWidth + pad * 2;
        const a = ambientLoader.item;
        if (ambient === "dot")
            return a?.implicitWidth ?? 24;
        return Math.max(minCollapsedWidth, (a?.implicitWidth ?? 60) + 32) + sideWidth;
    }
    readonly property real targetHeight: {
        if (shown && viewLoader.item)
            return (showTabs ? tabs.height + 10 : 0) + viewLoader.item.implicitHeight + pad * 2 - 4;
        const a = ambientLoader.item;
        if (ambient === "dot")
            return a?.implicitHeight ?? 6;
        const h = Math.max(Theme.barHeight, a?.implicitHeight ?? Theme.barHeight);
        return win.floating ? h - 6 : h;
    }

    WlrLayershell.namespace: "someshell:island"
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive at first so typing straight after Super lands in search; OnDemand
    // once the focus grab holds, because an exclusive layer keeps the keyboard
    // and Hyprland never clears the grab on a click outside
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : grab.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
    anchors.top: true
    exclusiveZone: UiState.hidden ? 0 : Theme.barHeight
    implicitWidth: 1000
    implicitHeight: 720
    color: "transparent"

    mask: Region {
        item: notch
        Region { item: hotStrip }
    }

    // Compositor frost behind the notch. Region corners are whole-pixel steps, so
    // the region stays 1 px inside the anti-aliased shape (the rim covers that
    // pixel); the notch's top edge is the screen edge and needs no inset. The
    // concave ears get a few strips that stay inside their curve.
    Region {
        id: blurArea
        readonly property int inset: 1
        readonly property int top: win.floating ? inset : 0
        readonly property int r: Math.max(0, Math.round(notch.r) - inset)
        x: Math.ceil(body.x) + inset
        y: Math.ceil(body.y) + top
        width: Math.max(0, Math.floor(body.width) - inset * 2)
        height: Math.max(0, Math.floor(body.height) - inset - top)
        topLeftRadius: win.floating ? r : 0
        topRightRadius: win.floating ? r : 0
        bottomLeftRadius: r
        bottomRightRadius: r

        EarStrip { row: 0; left: true }
        EarStrip { row: 1; left: true }
        EarStrip { row: 2; left: true }
        EarStrip { row: 0; left: false }
        EarStrip { row: 1; left: false }
        EarStrip { row: 2; left: false }
    }
    // Not while hidden off the surface: an empty region blurs the whole window
    BackgroundEffect.blurRegion: Theme.islandBlur && body.y + body.height > 4 ? blurArea : null

    // One 2 px band of an ear. The ear is filled outside a circle of radius e
    // centered at (0, e) (left ear, shape coordinates), so in a band ending at
    // row y1 it is filled from x = sqrt(e² - (e - y1)²) on; +1 px keeps the strip
    // under the curve's anti-aliasing. It overlaps the body region by 1 px.
    component EarStrip: Region {
        required property int row
        required property bool left
        readonly property real e: notch.ear
        readonly property int y1: (row + 1) * 2
        readonly property int from: e > 0 && y1 < e ? Math.ceil(Math.sqrt(e * e - (e - y1) * (e - y1))) + 1 : 0
        readonly property int w: from > 0 && from < e ? Math.ceil(e) - from + 2 : 0
        x: left ? Math.ceil(body.x) - w + 2 : Math.floor(body.x + body.width) - 2
        y: Math.ceil(body.y) + row * 2
        width: w
        height: w > 0 ? 2 : 0
    }

    Binding {
        target: UiState
        property: "ambient"
        value: win.ambient
        when: win.isFocusedScreen
    }
    // Satellite pills follow the island's live width
    Binding {
        target: UiState
        property: "islandWidth"
        value: body.width
        when: win.isFocusedScreen
    }

    // Click outside closes. The grab starts a moment after opening: activated
    // in the same frame as the keyboard-focus change, Hyprland clears it at once.
    HyprlandFocusGrab {
        id: grab
        windows: [win]
        onCleared: if (win.open) UiState.close()
    }
    Timer {
        id: grabDelay
        interval: 50
        onTriggered: grab.active = win.open
    }
    onOpenChanged: {
        if (open)
            grabDelay.restart();
        else
            grab.active = false;
    }
    onShownChanged: if (!shown) unload.restart()

    // Hover peek: resting on the island (or the top-edge strip above and beside
    // it) for a moment shows the view a click would open, without keyboard
    // focus; leaving closes it after a short grace. Off in game mode, over a
    // fullscreen window, while polkit waits (that needs the keyboard) and while
    // Quick Share shows its buttons or progress.
    // Real fullscreen only: Hyprland's hasFullscreen is also true for a
    // maximized window (fullscreen mode 1), which must not block the peek
    readonly property var activeWorkspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
    readonly property bool fullscreen: (activeWorkspace?.hasFullscreen ?? false) && activeWorkspace.toplevels.values.some(t => t.wayland?.fullscreen ?? false)
    // Collapsed under a fullscreen window nobody sees the island: ambient items
    // pause their animations and live updates (`live` on the loaded item)
    readonly property bool covered: fullscreen && !shown
    readonly property bool peekAllowed: Config.island.hoverPeek && !GameMode.active && !fullscreen && !UiState.hidden && !UiState.overview && ambient !== "polkit" && ambient !== "share"
    // Not over the side slot: it is a button of its own (stop recording), and a
    // peek opening under the pointer would take the click
    readonly property bool hovered: (bodyHover.hovered || stripHover.hovered) && !(sideLoader.item?.hovered ?? false)
    readonly property string peekView: ambient === "notif" ? "notifications" : ambient === "media" ? "media" : "control"

    onHoveredChanged: {
        if (hovered) {
            peekOut.stop();
            if (!shown)
                peekIn.restart();
        } else {
            peekIn.stop();
            if (peek)
                peekOut.restart();
        }
    }
    onPeekAllowedChanged: if (!peekAllowed && peek) UiState.unpeek()
    Timer {
        id: peekIn
        interval: 180
        onTriggered: if (win.hovered && win.peekAllowed && !UiState.expanded) UiState.peek(win.peekView, win.modelData.name)
    }
    Timer {
        id: peekOut
        interval: 300
        onTriggered: if (!win.hovered && win.peek) UiState.unpeek()
    }

    // The top edge above and beside the island: flicking the cursor up there
    // peeks too (Fitts' law), without covering the corner pills
    Item {
        id: hotStrip
        x: body.x - 16
        width: body.width + 32
        height: win.peekAllowed ? 2 : 0
        HoverHandler {
            id: stripHover
        }
    }

    IdleInhibitor {
        window: win
        enabled: UiState.caffeine
    }

    // Keep the view loaded until the collapse has played out
    Timer {
        id: unload
        interval: 450
    }

    RectangularShadow {
        anchors.fill: body
        radius: notch.r
        blur: 30
        spread: 0
        offset: Qt.vector2d(0, 6)
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: win.shown ? 1 : 0
        visible: opacity > 0 && !GameMode.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.normal }
        }
    }

    NotchShape {
        id: notch
        x: body.x - ear
        y: body.y
        bodyWidth: body.width
        bodyHeight: body.height
        ear: Math.min(win.ear, body.height)
        floating: win.floating
        radius: win.shown ? Theme.radius.island : Math.min(body.height / 2, Theme.radius.island)
        color: Theme.island
        rim: Theme.islandBlur ? Theme.glassRim : "transparent"
    }

    Item {
        id: body

        width: win.targetWidth
        height: win.targetHeight
        x: Math.round((win.width - width) / 2)
        y: UiState.hidden ? -height - 4 : win.topGap
        clip: true

        Behavior on width {
            Spring { preset: "smooth" }
        }
        Behavior on height {
            Spring { preset: "smooth" }
        }
        Behavior on y {
            Spring { preset: "snappy" }
        }

        HoverHandler {
            id: bodyHover
        }

        // Click the collapsed island to open what it is showing
        MouseArea {
            anchors.fill: parent
            enabled: !win.shown
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    UiState.open("control");
                    return;
                }
                switch (win.ambient) {
                case "polkit":
                    UiState.open("polkit");
                    break;
                case "notif":
                    Notifs.peeked = null;
                    UiState.open("notifications");
                    break;
                case "media":
                    UiState.open("media");
                    break;
                case "share":
                    UiState.openControl("quickshare");
                    break;
                case "record":
                    Recorder.stop();
                    break;
                case "osd":
                case "privacy":
                    UiState.open("control");
                    break;
                default:
                    UiState.open("search");
                }
            }
            onWheel: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
        }

        // Files dropped on the island go to Quick Share (its page then lists the devices)
        DropArea {
            anchors.fill: parent
            enabled: QuickShare.available
            keys: ["text/uri-list"]
            onDropped: drop => {
                if (drop.hasUrls) {
                    QuickShare.offer(drop.urls.map(u => u.toString()));
                    drop.accept();
                }
            }
        }

        // Collapsed content
        Loader {
            id: ambientLoader
            anchors.centerIn: parent
            // Centered in what the side slot leaves
            anchors.horizontalCenterOffset: -win.sideWidth / 2
            active: !win.shown || unload.running
            opacity: win.shown ? 0 : 1
            visible: opacity > 0
            sourceComponent: {
                switch (win.ambient) {
                case "polkit":
                    return polkitAmbient;
                case "notif":
                    return notifAmbient;
                case "osd":
                    return osdAmbient;
                case "share":
                    return shareAmbient;
                case "privacy":
                    return privacyAmbient;
                case "record":
                    return recordAmbient;
                case "dot":
                    return dotAmbient;
                case "media":
                    return mediaAmbient;
                }
                return clockAmbient;
            }
            onLoaded: {
                if (item.live !== undefined)
                    item.live = Qt.binding(() => !win.covered);
                reveal.play();
            }
            Behavior on opacity {
                NumberAnimation { duration: Motion.fast }
            }
            Reveal {
                id: reveal
                target: ambientLoader.item
            }
        }

        // Side slot, at the right end of the collapsed island
        Loader {
            id: sideLoader
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            active: win.side && (!win.shown || unload.running)
            opacity: win.shown ? 0 : 1
            visible: opacity > 0
            sourceComponent: sideAmbient
            onLoaded: {
                item.live = Qt.binding(() => !win.covered);
                sideReveal.play();
            }
            Behavior on opacity {
                NumberAnimation { duration: Motion.fast }
            }
            Reveal {
                id: sideReveal
                target: sideLoader.item
            }
        }

        // Expanded content
        FocusScope {
            id: keys
            anchors.fill: parent
            anchors.margins: win.pad
            anchors.topMargin: win.pad - 6
            focus: win.open
            opacity: win.shown ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: win.shown ? Motion.normal : Motion.fast }
            }

            Keys.onPressed: event => {
                const v = viewLoader.item;
                if (v?.handleKey) {
                    if (v.handleKey(event))
                        event.accepted = true;
                    return;
                }
                if (UiState.navKey(event))
                    event.accepted = true;
            }

            ViewTabs {
                id: tabs
                visible: win.showTabs
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Loader {
                id: viewLoader
                anchors.top: win.showTabs ? tabs.bottom : parent.top
                anchors.topMargin: win.showTabs ? 10 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: item ? item.implicitWidth : 0
                height: item ? item.implicitHeight : 0
                focus: true
                active: win.shown || unload.running
                sourceComponent: {
                    switch (UiState.view) {
                    case "control":
                        return controlView;
                    case "media":
                        return mediaView;
                    case "notifications":
                        return notificationsView;
                    case "system":
                        return systemView;
                    case "power":
                        return powerView;
                    case "clipboard":
                        return clipboardView;
                    case "emoji":
                        return emojiView;
                    case "gif":
                        return gifView;
                    case "keys":
                        return keysView;
                    case "polkit":
                        return polkitView;
                    case "wallpaper":
                        return wallpaperView;
                    case "translate":
                        return translateView;
                    case "mixer":
                        return mixerView;
                    }
                    return searchView;
                }
                onLoaded: viewReveal.play()
                Reveal {
                    id: viewReveal
                    target: viewLoader.item
                }
            }
        }

        // A press anywhere in a peek opens the full view. Stacked on top and only
        // passive, so the button under the cursor still gets the click.
        Item {
            anchors.fill: parent
            visible: win.peek
            PointHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onActiveChanged: if (active && win.peek) UiState.promote()
            }
        }
    }

    component ViewTabs: Row {
        spacing: 4
        readonly property var icons: ({ search: "search", control: "tune", media: "music_note", notifications: "notifications", system: "monitoring", power: "power_settings_new" })
        Repeater {
            model: UiState.mainViews
            IconButton {
                required property string modelData
                width: 30
                height: 26
                iconSize: 17
                icon: parent.icons[modelData]
                active: UiState.view === modelData
                activeColor: Theme.islandRaisedHover
                iconColor: active ? Theme.fgIsland : Theme.fgIslandDim
                onClicked: UiState.view = modelData
            }
        }
    }

    Component {
        id: clockAmbient
        AmbientClock {}
    }
    Component {
        id: mediaAmbient
        AmbientMedia {}
    }
    Component {
        id: osdAmbient
        AmbientOsd {}
    }
    Component {
        id: notifAmbient
        AmbientNotif {}
    }
    Component {
        id: privacyAmbient
        AmbientPrivacy {}
    }
    Component {
        id: recordAmbient
        AmbientRecord {}
    }
    Component {
        id: shareAmbient
        AmbientShare {}
    }
    Component {
        id: sideAmbient
        AmbientSide {}
    }
    Component {
        id: dotAmbient
        AmbientDot {}
    }
    Component {
        id: polkitAmbient
        Item {
            implicitWidth: polkitRow.implicitWidth
            implicitHeight: Theme.barHeight
            Row {
                id: polkitRow
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "admin_panel_settings"
                    size: 18
                    fill: 1
                    color: Theme.accentIsland
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Authentication needed"
                }
            }
        }
    }

    Component {
        id: searchView
        SearchView {}
    }
    Component {
        id: controlView
        ControlView {}
    }
    Component {
        id: mediaView
        MediaView {}
    }
    Component {
        id: notificationsView
        NotificationsView {}
    }
    Component {
        id: systemView
        SystemView {}
    }
    Component {
        id: powerView
        PowerView {}
    }
    Component {
        id: clipboardView
        ClipboardView {}
    }
    Component {
        id: emojiView
        EmojiView {}
    }
    Component {
        id: gifView
        GifView {}
    }
    Component {
        id: keysView
        KeysView {}
    }
    Component {
        id: polkitView
        PolkitView {}
    }
    Component {
        id: wallpaperView
        WallpaperView {}
    }
    Component {
        id: translateView
        TranslateView {}
    }
    Component {
        id: mixerView
        MixerView {}
    }
}
