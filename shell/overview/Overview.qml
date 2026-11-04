import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// The overview (Super+Tab, SomeShell.md section 5): all ten shared
// workspaces as pages on the monitor the mouse was on. Loaded only while
// open. Hyprland owns windows and focus: every action here is a dispatch.
//   Click a page: go there. Click a window: go to it and focus it.
//   Drag a window onto a page: move it there; onto a page's monitor spot:
//   also show that workspace on that monitor. Drag a page onto a monitor in
//   the header's map: show it there.
//   The scratchpad (Super+S) is a drawer under the pages: click it to show
//   it, drag windows in and out of it.
//   Keys: arrows, 1-0, S (scratchpad), Enter, Esc (Super+Tab again closes too).
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Ui.overviewMonitor) ?? Quickshell.screens[0]
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "someshell:overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property real sw: screen.width
    readonly property real sh: screen.height
    // Sizes are drawn for 1920x1080 and shrink on smaller screens
    readonly property real u: Math.min(1, sw / 1920, sh / 1080)
    readonly property var pal: Theme.paper
    readonly property string here: Ui.overviewMonitor
    // Every picture of the wallpaper here uses this one decode (the image
    // cache shares it; scaled down on the GPU). Many decodes at different
    // sizes at once crashed Qt's image threads.
    readonly property size wallSize: Qt.size(Math.round(sw), Math.round(sh))

    // ---- What Hyprland has, read when it opens and on its events ----------
    property var monitors: []      // [{ name, x, y, w, h, active }], left to right
    property var wsMonitor: ({})   // workspace id -> monitor name
    property var windows: ({})     // workspace id -> [window]
    property var scratch: []       // the scratchpad's windows, most recent first
    readonly property string scratchName: "special:special"
    readonly property string scratchOn: monitors.find(m => m.special === scratchName)?.name ?? ""
    property bool loaded: false
    readonly property var hereMon: monitors.find(m => m.name === here) ?? null
    readonly property int current: hereMon?.active ?? 1
    property int sel: 1              // 1-10 a page, 11 the scratchpad
    property int selCol: 1           // the column last selected (for Up/Down)
    onSelChanged: if (sel <= 10) selCol = (sel - 1) % 5 + 1

    function load(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;
        }
        const mons = [];
        const byId = {};
        for (const m of d.m) {
            const turned = m.transform % 2 === 1;
            const g = { name: m.name, x: m.x, y: m.y, w: (turned ? m.height : m.width) / m.scale, h: (turned ? m.width : m.height) / m.scale, active: m.activeWorkspace?.id ?? 0, special: m.specialWorkspace?.name ?? "" };
            mons.push(g);
            byId[m.id] = g;
        }
        mons.sort((a, b) => a.x - b.x || a.y - b.y);
        const wsm = {};
        for (const w of d.w)
            wsm[w.id] = w.monitor;
        const wins = {};
        const sp = [];
        const clients = d.c.filter(c => c.mapped && !c.hidden)
            .sort((a, b) => b.focusHistoryID - a.focusHistoryID);
        for (const c of clients) {
            if (c.workspace.name === scratchName) {
                const entry = DesktopEntries.heuristicLookup(c.class);
                sp.unshift({ address: c.address, name: entry?.name || c.class || "Window", icon: entry?.icon ?? "", title: c.title });
                continue;
            }
            if (c.workspace.id < 1 || c.workspace.id > 10)
                continue;
            const g = byId[c.monitor] ?? mons[0];
            if (!g)
                continue;
            const entry = DesktopEntries.heuristicLookup(c.class);
            const list = wins[c.workspace.id] ?? (wins[c.workspace.id] = []);
            list.push({
                address: c.address,
                rx: Math.max(0, (c.at[0] - g.x) / g.w),
                ry: Math.max(0, (c.at[1] - g.y) / g.h),
                rw: Math.min(1, c.size[0] / g.w),
                rh: Math.min(1, c.size[1] / g.h),
                name: entry?.name || c.class || "Window",
                icon: entry?.icon ?? "",
                title: c.title
            });
        }
        monitors = mons;
        wsMonitor = wsm;
        windows = wins;
        scratch = sp;
        if (!loaded) {
            loaded = true;
            sel = current;
        }
    }
    Process {
        id: reader
        command: ["bash", "-c", "jq -cn --argjson c \"$(hyprctl -j clients)\" --argjson m \"$(hyprctl -j monitors)\" --argjson w \"$(hyprctl -j workspaces)\" '{c: $c, m: $m, w: $w}'"]
        stdout: StdioCollector {
            onStreamFinished: win.load(text)
        }
    }
    Component.onCompleted: reader.running = true
    // Windows and workspaces change: read again (a burst of events reads once)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            refresh.restart();
        }
    }
    Timer {
        id: refresh
        interval: 60
        onTriggered: reader.running ? restart() : reader.running = true
    }

    // ---- Actions (all Hyprland dispatches) -------------------------------
    function dsp(s) {
        Hyprland.dispatch(s);
    }
    function close() {
        Ui.closeOverview();
    }
    function go(n) {
        dsp(`hl.dsp.focus({ workspace = ${n} })`);
        close();
    }
    function focusWindow(w) {
        // A scratchpad window: open the scratchpad on this monitor first
        if (wsOf(w) === -1 && scratchOn !== here) {
            dsp(`hl.dsp.focus({ monitor = "${here}" })`);
            dsp(`hl.dsp.workspace.toggle_special("special")`);
        }
        dsp(`hl.dsp.focus({ window = "address:${w.address}" })`);
        close();
    }
    // The scratchpad on this monitor (it moves here when open elsewhere)
    function showScratch() {
        if (scratchOn !== here) {
            dsp(`hl.dsp.focus({ monitor = "${here}" })`);
            dsp(`hl.dsp.workspace.toggle_special("special")`);
        }
        close();
    }
    function moveToScratch(w) {
        dsp(`hl.dsp.window.move({ workspace = "${scratchName}", window = "address:${w.address}", follow = false })`);
    }
    function moveWindow(w, n) {
        dsp(`hl.dsp.window.move({ workspace = ${n}, window = "address:${w.address}", follow = false })`);
    }
    // Show workspace n on monitor `mon`, keeping the focus on this monitor
    function showOn(n, mon, exists) {
        const back = current;
        if (exists || wsMonitor[n] !== undefined)
            dsp(`hl.dsp.workspace.move({ workspace = ${n}, monitor = "${mon}" })`);
        else
            dsp(`hl.dsp.focus({ monitor = "${mon}" })`);
        dsp(`hl.dsp.focus({ workspace = ${n} })`);
        if (mon !== here && back !== n && back > 0)
            dsp(`hl.dsp.focus({ workspace = ${back} })`);
    }

    // ---- Look --------------------------------------------------------------
    Item {
        id: view
        anchors.fill: parent
        opacity: 0
        scale: 0.985
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic }
        }

        // The wallpaper, faintly, under the paper
        Image {
            anchors.fill: parent
            source: Wallpaper.path ? "file://" + Wallpaper.path : ""
            sourceSize: win.wallSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: win.pal.bg
            opacity: 0.94
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 96 * win.u
            anchors.rightMargin: 96 * win.u
            anchors.topMargin: 64 * win.u
            anchors.bottomMargin: 56 * win.u

            // Header: the current workspace set big
            Column {
                id: headline
                spacing: 10 * win.u
                Row {
                    spacing: 14 * win.u
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Overview"
                        caps: true
                        size: Math.round(12 * win.u)
                        color: win.pal.mute
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40 * win.u
                        height: 1
                        color: win.pal.line
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Super + Tab"
                        caps: true
                        size: Math.round(12 * win.u)
                        color: win.pal.mute
                    }
                }
                Row {
                    spacing: 28 * win.u
                    Txt {
                        text: String(win.current).padStart(2, "0")
                        size: Math.round(112 * win.u)
                        face: Theme.font.medium
                        color: win.pal.mute
                    }
                    Txt {
                        visible: text !== ""
                        text: Spaces.design(win.current)?.name ?? ""
                        size: Math.round(112 * win.u)
                        face: Theme.font.bold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: size * 0.08
                        color: win.pal.fg
                    }
                }
                Txt {
                    readonly property int count: (win.windows[win.current] ?? []).length
                    text: [win.here, count + (count === 1 ? " window" : " windows"), Qt.locale("en_US").toString(Clock.now, "ddd dd MMM"), win.roman(Clock.now.getFullYear())].join("  ·  ")
                    caps: true
                    size: Math.round(12 * win.u)
                    color: win.pal.mute
                }
            }

            // The keys and the index, top right
            Column {
                id: keysBlock
                anchors.right: parent.right
                anchors.bottom: headline.bottom
                spacing: 18 * win.u
                Row {
                    anchors.right: parent.right
                    spacing: 18 * win.u
                    // A barcode, like the posters'
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6 * win.u
                        spacing: 2
                        Repeater {
                            model: [2, 1, 3, 1, 1, 2, 4, 1, 2, 1, 1, 3, 2, 1, 4, 1, 2, 2, 1, 3, 1, 1, 2, 1]
                            Rectangle {
                                required property int modelData
                                required property int index
                                width: modelData
                                height: 30 * win.u
                                color: index % 5 === 2 ? win.pal.mute : win.pal.fg
                            }
                        }
                    }
                    Row {
                        Txt {
                            text: String(win.current).padStart(2, "0") + " "
                            size: Math.round(30 * win.u)
                            face: Theme.font.medium
                            color: win.pal.fg
                        }
                        Txt {
                            text: "/ 10"
                            size: Math.round(30 * win.u)
                            face: Theme.font.medium
                            color: win.pal.mute
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 10 * win.u
                    Repeater {
                        model: [["← → ↑ ↓", "Move"], ["1–0", "Pick"], ["S", "Scratchpad"], ["Enter", "Go"], ["Esc", "Close"]]
                        Rectangle {
                            id: pill
                            required property var modelData
                            width: keyRow.implicitWidth + 28 * win.u
                            height: 30 * win.u
                            radius: height / 2
                            color: "transparent"
                            border.width: 1
                            border.color: win.pal.line
                            Row {
                                id: keyRow
                                anchors.centerIn: parent
                                spacing: 8 * win.u
                                Txt {
                                    text: pill.modelData[0]
                                    size: Math.round(11 * win.u)
                                    face: Theme.font.medium
                                    color: win.pal.fg
                                }
                                Txt {
                                    text: pill.modelData[1]
                                    caps: true
                                    size: Math.round(11 * win.u)
                                    color: win.pal.mute
                                }
                            }
                        }
                    }
                }
            }

            // The monitor map: each monitor and what it shows; drop a page here
            Column {
                id: mapBlock
                anchors.right: keysBlock.left
                anchors.rightMargin: 48 * win.u
                anchors.bottom: headline.bottom
                spacing: 10 * win.u
                Txt {
                    text: "Monitors · drag a page's name here"
                    caps: true
                    size: Math.round(11 * win.u)
                    color: win.pal.mute
                }
                Row {
                    id: mapRow
                    spacing: 14 * win.u
                    readonly property real f: 150 * win.u / win.monitors.reduce((a, m) => Math.max(a, m.w), 1)
                    Repeater {
                        id: mapRep
                        model: win.monitors
                        Column {
                            id: mapCell
                            required property var modelData
                            readonly property bool mine: modelData.name === win.here
                            readonly property bool target: ptr.kind === "page" && ptr.overMonitor === modelData.name
                            readonly property alias screenBox: screenBox
                            anchors.bottom: parent.bottom
                            spacing: 8 * win.u
                            Rectangle {
                                id: screenBox
                                width: mapCell.modelData.w * mapRow.f
                                height: mapCell.modelData.h * mapRow.f
                                radius: 8 * win.u
                                color: win.pal.bg
                                clip: true
                                border.width: mapCell.mine || mapCell.target ? 2 : 1
                                border.color: mapCell.target ? win.pal.fg : mapCell.mine ? win.pal.accent : win.pal.line
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: parent.border.width
                                    source: Wallpaper.path ? "file://" + Wallpaper.path : ""
                                    sourceSize: win.wallSize
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    opacity: mapCell.mine ? 0.65 : 0.4
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4 * win.u
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 8 * win.u
                                        Txt {
                                            text: String(mapCell.modelData.active).padStart(2, "0")
                                            size: Math.round(15 * win.u)
                                            face: Theme.font.medium
                                            color: win.pal.mute
                                        }
                                        Txt {
                                            visible: text !== ""
                                            text: Spaces.design(mapCell.modelData.active)?.name ?? ""
                                            size: Math.round(14 * win.u)
                                            face: Theme.font.bold
                                            font.capitalization: Font.AllUppercase
                                            font.letterSpacing: size * 0.14
                                            color: win.pal.fg
                                        }
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !mapCell.target && mapCell.modelData.special === win.scratchName
                                        text: "+ Scratchpad"
                                        caps: true
                                        size: Math.round(9 * win.u)
                                        color: win.pal.fg
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mapCell.target
                                        text: "Show " + String(ptr.page).padStart(2, "0") + " here"
                                        caps: true
                                        size: Math.round(9 * win.u)
                                        color: win.pal.fg
                                    }
                                }
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: mapCell.modelData.name
                                caps: true
                                size: Math.round(10 * win.u)
                                color: mapCell.mine ? win.pal.fg : win.pal.mute
                            }
                        }
                    }
                }
            }

            // The ten pages, two rows of five, as large as the space allows
            Grid {
                id: grid
                readonly property real gapX: 32 * win.u
                readonly property real gapY: 46 * win.u
                readonly property real drawerGap: 20 * win.u
                readonly property real extra: (30 + 12 + 12 + 14) * win.u      // label, gaps, caption
                readonly property real availH: footer.y - (headline.y + headline.height) - 38 * win.u - 40 * win.u - drawer.height - drawerGap
                readonly property real byWidth: (content.width - 4 * gapX) / 5
                readonly property real byHeight: ((availH - gapY) / 2 - extra) * win.sw / win.sh
                // (byHeight is NaN before the footer is laid out: fall back to the width)
                readonly property real pw: Math.max(80, isFinite(byHeight) && byHeight > 0 ? Math.min(byWidth, byHeight) : byWidth)
                anchors.horizontalCenter: parent.horizontalCenter
                y: headline.y + headline.height + 38 * win.u
                columns: 5
                columnSpacing: gapX
                rowSpacing: gapY
                Repeater {
                    id: pages
                    model: 10
                    OverviewPage {
                        required property int index
                        n: index + 1
                        u: win.u
                        wallSize: win.wallSize
                        fw: grid.pw
                        fh: grid.pw * win.sh / win.sw
                        wins: win.windows[n] ?? []
                        shownOn: win.monitors.find(m => m.active === n)?.name ?? ""
                        onHere: shownOn !== "" && shownOn === win.here
                        current: n === win.current
                        selected: n === win.sel && ptr.kind === ""
                        hovered: ptr.hoverPage === n
                        hoverWin: ptr.hoverWin
                        dragWin: ptr.kind === "window" ? ptr.moving?.address ?? "" : ""
                        dropTarget: ptr.kind === "window" && ptr.hoverPage === n
                        zones: win.monitors.length > 1 ? win.monitors.map(m => m.name) : []
                        hotZone: dropTarget ? ptr.overZone : ""
                    }
                }
            }

            // The scratchpad, a drawer on the grid under the pages
            Scratchpad {
                id: drawer
                x: grid.x
                y: grid.y + grid.height + grid.drawerGap
                width: grid.width
                u: win.u
                labelW: grid.pw
                gap: grid.gapX
                wins: win.scratch
                shownOn: win.scratchOn
                onHere: win.scratchOn !== "" && win.scratchOn === win.here
                selected: win.sel === 11 && ptr.kind === ""
                hovered: ptr.hoverScratch && ptr.kind === ""
                hoverWin: ptr.hoverWin
                dragWin: ptr.kind === "window" ? ptr.moving?.address ?? "" : ""
                dropTarget: ptr.kind === "window" && ptr.hoverScratch && win.wsOf(ptr.moving) !== -1
            }

            // Footer: a hairline with crosshairs and what the mouse does
            Row {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 18 * win.u
                readonly property var lines: ptr.kind === "window"
                    ? ["Drop on a page: move the window", "Drop on a monitor spot: also show the workspace there", "Esc: cancel"]
                    : ptr.kind === "page"
                    ? ["Drop on a monitor in the map: show it there", "", "Esc: cancel"]
                    : ["Click a page: go there", "Click a window: go and focus it", "Drag a window onto a page: move it"]
                readonly property real fill: (width - 2 * plusA.width - capA.implicitWidth - capB.implicitWidth - capC.implicitWidth - 6 * spacing) / 2
                Txt {
                    id: plusA
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    size: Math.round(18 * win.u)
                    color: win.pal.fg
                }
                Txt {
                    id: capA
                    anchors.verticalCenter: parent.verticalCenter
                    text: footer.lines[0]
                    caps: true
                    size: Math.round(11 * win.u)
                    color: win.pal.mute
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, footer.fill)
                    height: 1
                    color: win.pal.line
                }
                Txt {
                    id: capB
                    anchors.verticalCenter: parent.verticalCenter
                    text: footer.lines[1]
                    caps: true
                    size: Math.round(11 * win.u)
                    color: win.pal.mute
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, footer.fill)
                    height: 1
                    color: win.pal.line
                }
                Txt {
                    id: capC
                    anchors.verticalCenter: parent.verticalCenter
                    text: footer.lines[2]
                    caps: true
                    size: Math.round(11 * win.u)
                    color: win.pal.mute
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    size: Math.round(18 * win.u)
                    color: win.pal.fg
                }
            }
        }

        // What is being dragged, under the pointer
        Rectangle {
            visible: ptr.kind !== ""
            x: ptr.pos.x + 18
            y: ptr.pos.y + 22
            width: ghostRow.implicitWidth + 24 * win.u
            height: (ptr.kind === "window" ? 58 : 40) * win.u
            radius: 7 * win.u
            color: win.pal.fg
            Column {
                id: ghostRow
                anchors.left: parent.left
                anchors.leftMargin: 12 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * win.u
                Txt {
                    text: ptr.kind === "window" ? ptr.moving?.name ?? "" : String(ptr.page).padStart(2, "0") + "  " + (Spaces.design(ptr.page)?.name ?? "")
                    size: Math.round(12 * win.u)
                    face: Theme.font.medium
                    color: win.pal.bg
                }
                Txt {
                    visible: ptr.kind === "window"
                    width: Math.min(implicitWidth, 220 * win.u)
                    text: ptr.moving?.title ?? ""
                    size: Math.round(10 * win.u)
                    color: win.pal.bg
                    opacity: 0.75
                }
            }
        }
    }

    // ---- Mouse: one handler for hover, clicks and both drags ---------------
    QtObject {
        id: ptr
        property string kind: ""          // "", "window" or "page"
        property point pos: Qt.point(0, 0)
        property point start: Qt.point(0, 0)
        property bool down: false
        property int pressPage: 0
        property var pressWin: null
        property var moving: null        // the window being dragged
        property int page: 0
        property int hoverPage: 0
        property bool hoverScratch: false
        property bool pressScratch: false
        property string hoverWin: ""
        property string overZone: ""
        property string overMonitor: ""
        // (qualified: an unqualified `win` here would be the window's id)
        function reset() {
            ptr.kind = "";
            ptr.down = false;
            ptr.pressPage = 0;
            ptr.pressWin = null;
            ptr.pressScratch = false;
            ptr.moving = null;
            ptr.page = 0;
            ptr.overZone = "";
            ptr.overMonitor = "";
        }
    }

    // The page, window, spot or map monitor under a point (view coordinates)
    function hit(px, py) {
        const r = { page: 0, win: null, zone: "", monitor: "", scratch: false };
        const b = drawer.band.mapFromItem(view, px, py);
        if (b.x >= 0 && b.y >= 0 && b.x <= drawer.band.width && b.y <= drawer.band.height) {
            r.scratch = true;
            r.win = drawer.windowAt(b.x, b.y);
            return r;
        }
        for (let i = 0; i < 10; i++) {
            const p = pages.itemAt(i);
            if (!p)
                continue;
            const q = p.frame.mapFromItem(view, px, py);
            if (q.x >= 0 && q.y >= 0 && q.x <= p.frame.width && q.y <= p.frame.height) {
                r.page = i + 1;
                r.win = p.windowAt(q.x, q.y);
                r.zone = p.zoneAt(q.x, q.y);
                break;
            }
            const l = p.label.mapFromItem(view, px, py);
            if (l.x >= 0 && l.y >= 0 && l.x <= p.label.width && l.y <= p.label.height) {
                r.page = i + 1;
                break;
            }
        }
        for (let i = 0; i < mapRep.count; i++) {
            const c = mapRep.itemAt(i);
            const q = c.screenBox.mapFromItem(view, px, py);
            if (q.x >= -6 && q.y >= -6 && q.x <= c.screenBox.width + 6 && q.y <= c.screenBox.height + 6)
                r.monitor = c.modelData.name;
        }
        return r;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: ptr.kind !== "" ? Qt.ClosedHandCursor : ptr.hoverPage || ptr.hoverScratch ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: m => {
            const h = win.hit(m.x, m.y);
            ptr.pos = Qt.point(m.x, m.y);
            ptr.hoverPage = h.page;
            ptr.hoverScratch = h.scratch;
            ptr.hoverWin = h.win?.address ?? "";
            if (ptr.down && ptr.kind === "" && Math.hypot(m.x - ptr.start.x, m.y - ptr.start.y) > 6) {
                if (ptr.pressWin) {
                    ptr.kind = "window";
                    ptr.moving = ptr.pressWin;
                } else if (ptr.pressPage) {
                    ptr.kind = "page";
                    ptr.page = ptr.pressPage;
                }
            }
            ptr.overZone = ptr.kind === "window" ? h.zone : "";
            ptr.overMonitor = ptr.kind === "page" ? h.monitor : "";
        }
        onPressed: m => {
            const h = win.hit(m.x, m.y);
            ptr.reset();
            ptr.down = true;
            ptr.start = Qt.point(m.x, m.y);
            ptr.pos = ptr.start;
            ptr.pressPage = h.page;
            ptr.pressWin = h.win;
            ptr.pressScratch = h.scratch;
        }
        onReleased: m => {
            const h = win.hit(m.x, m.y);
            const kind = ptr.kind;
            const w = ptr.moving, page = ptr.page, pressPage = ptr.pressPage, pressWin = ptr.pressWin, pressScratch = ptr.pressScratch;
            ptr.reset();
            if (kind === "window") {
                if (h.scratch) {
                    if (win.wsOf(w) !== -1)
                        win.moveToScratch(w);
                } else if (h.page && h.zone) {
                    if (h.page !== win.wsOf(w))
                        win.moveWindow(w, h.page);
                    win.showOn(h.page, h.zone, true);
                } else if (h.page && h.page !== win.wsOf(w)) {
                    win.moveWindow(w, h.page);
                }
            } else if (kind === "page") {
                if (h.monitor)
                    win.showOn(page, h.monitor, false);
            } else if (pressWin && h.win && h.win.address === pressWin.address) {
                win.focusWindow(pressWin);
            } else if (pressPage && h.page === pressPage) {
                win.go(pressPage);
            } else if (pressScratch && h.scratch) {
                win.showScratch();
            }
        }
    }
    function wsOf(w) {
        if (!w)
            return 0;
        if (scratch.some(x => x.address === w.address))
            return -1;
        for (let n = 1; n <= 10; n++)
            if ((windows[n] ?? []).some(x => x.address === w.address))
                return n;
        return 0;
    }

    // ---- Keys ----------------------------------------------------------------
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                if (ptr.kind !== "")
                    ptr.reset();
                else
                    win.close();
            } else if (k === Qt.Key_Left)
                win.sel = win.sel === 11 ? 10 : (win.sel + 8) % 10 + 1;
            else if (k === Qt.Key_Right)
                win.sel = win.sel === 11 ? 1 : win.sel % 10 + 1;
            // Up and down pass through the scratchpad under row 2
            else if (k === Qt.Key_Up)
                win.sel = win.sel === 11 ? 5 + win.selCol : win.sel <= 5 ? 11 : win.sel - 5;
            else if (k === Qt.Key_Down)
                win.sel = win.sel === 11 ? win.selCol : win.sel <= 5 ? win.sel + 5 : 11;
            else if (k === Qt.Key_S)
                win.sel = 11;
            else if (k >= Qt.Key_1 && k <= Qt.Key_9)
                win.sel = k - Qt.Key_0;
            else if (k === Qt.Key_0)
                win.sel = 10;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                win.sel === 11 ? win.showScratch() : win.go(win.sel);
            else
                return;
            event.accepted = true;
        }
    }

    function roman(y) {
        const t = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [v, r] of t)
            while (y >= v) {
                s += r;
                y -= v;
            }
        return s;
    }
}
