import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Wallpaper (the taller, wider panel, EditWindow): the library on the left,
// the chosen wallpaper's settings on the right, side by side.
//   Library: with several monitors, one wallpaper on all or each its own (the
//   monitor map picks which monitor the library sets; Colors from), filters
//   with counts, search, sort; a grid of thumbnails (tags: which monitors show
//   it; a gif preview plays on hover); light/dark, scheme, where the colors
//   come from, the palette.
//   Chosen: the wallpaper the library's monitor shows: its preview, title,
//   Reset; Properties (Wallpaper Engine's own), Playback (fit; speed, frame
//   rate, render scale for animated ones; texture resolution for scenes), Pause (each rule: the shell's, on
//   or off). Every change records Undo first (Editor.record).
Item {
    id: root
    property string tab

    Component.onCompleted: {
        Wallpapers.refresh();
        if (Wallpaper.isAnimatedPath(chosen))
            WallSettings.describe(chosen);
    }

    readonly property var ink: Theme.ink

    // Keys that reach the tab from a focused control: Esc closes edit mode,
    // Ctrl+Z undoes (the window's own key handler only has the focus before)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape)
            Ui.endEdit();
        else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))
            Editor.undo();
        else
            return;
        event.accepted = true;
    }

    // ── Monitors ────────────────────────────────────────────────────────

    // Left to right
    readonly property var screens: Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y)
    readonly property bool several: screens.length > 1
    readonly property bool each: Wallpaper.mode === "each"
    // The monitor the library sets (with "each"): the one picked, else the colors' one
    readonly property string target: each ? (Ui.wallMonitor || Wallpaper.colorsMonitor) : ""
    function usedOn(path) {
        if (!several || !each)
            return [];
        return screens.filter(s => Wallpaper.pathFor(s.name) === path).map(s => s.name);
    }

    // ── Library ─────────────────────────────────────────────────────────

    property string filter: "all"
    property string query: ""
    property string sortBy: "name"
    readonly property var counts: {
        const c = { all: 0, image: 0, video: 0, scene: 0 };
        for (const f of Wallpapers.files) {
            c.all++;
            if (c[f.kind] !== undefined)
                c[f.kind]++;
        }
        return c;
    }
    readonly property var shownFiles: {
        const q = query.trim().toLowerCase();
        const list = Wallpapers.files.filter(f => (filter === "all" || f.kind === filter) && (!q || f.name.toLowerCase().includes(q)));
        if (sortBy === "newest")
            return list.sort((a, b) => b.added - a.added);
        return list.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base", numeric: true }));
    }
    function choose(f) {
        if (!f || f.kind === "unsupported" || f.path === chosen)
            return;
        Editor.record();
        Wallpaper.set(f.path, target);
    }

    readonly property var schemes: [
        ["scheme-smart", "Smart"], ["scheme-tonal-spot", "Tonal spot"], ["scheme-content", "Content"], ["scheme-expressive", "Expressive"],
        ["scheme-fidelity", "Fidelity"], ["scheme-fruit-salad", "Fruit salad"], ["scheme-monochrome", "Monochrome"],
        ["scheme-neutral", "Neutral"], ["scheme-rainbow", "Rainbow"]
    ]

    // ── The chosen wallpaper ────────────────────────────────────────────

    readonly property string chosen: Wallpaper.pathFor(target)
    readonly property var chosenFile: Wallpapers.files.find(f => f.path === chosen) ?? null
    readonly property var info: WallSettings.infos[chosen] ?? null
    readonly property var entry: WallSettings.forPath(chosen)
    readonly property var values: WallSettings.propValues(chosen)
    readonly property string kind: chosenFile?.kind ?? (Wallpaper.isImagePath(chosen) ? "image" : (info?.type === "scene" ? "scene" : "video"))
    readonly property bool animated: kind === "scene" || kind === "video"
    readonly property var props: info?.props ?? []
    readonly property int changes: Object.keys(entry.props ?? {}).length + Object.keys(entry.pause ?? {}).length
        + ["fit", "speed", "fps", "scale", "texres", "colors"].filter(k => entry[k] !== undefined).length
    onChosenChanged: {
        body.contentY = 0;
        if (Wallpaper.isAnimatedPath(chosen))
            WallSettings.describe(chosen);
    }

    readonly property var sections: {
        const s = [];
        if (props.length)
            s.push({ id: "props", label: "Properties", icon: "tune" });
        s.push({ id: "playback", label: animated ? "Playback" : "Fit", icon: animated ? "play_circle" : "fit_screen" });
        if (animated)
            s.push({ id: "pause", label: "Pause", icon: "pause_circle" });
        return s;
    }
    property string section: "props"
    readonly property string shownSection: sections.some(s => s.id === section) ? section : sections[0].id
    // Another section or wallpaper starts at the top
    onShownSectionChanged: body.contentY = 0

    function setProp(key, v) {
        Editor.record();
        WallSettings.setProp(chosen, key, v);
    }
    function setValue(name, v) {
        Editor.record();
        WallSettings.setValue(chosen, name, v);
    }
    function setPause(rule, v) {
        Editor.record();
        WallSettings.setPause(chosen, rule, v);
    }

    // The colors' wallpaper has its own color (Wallpaper Engine schemecolor)
    readonly property string colorsHex: WallSettings.hexOf(WallSettings.propValues(Wallpaper.path).schemecolor)
    readonly property bool colorsFromScheme: (WallSettings.forPath(Wallpaper.path).colors ?? "") === "scheme"

    // ════════════════════════════════════════════════════════════════════
    // Library (left)
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: lib
        width: Math.round(root.width * 0.6)
        height: parent.height

        // Monitors
        Item {
            id: monRow
            visible: root.several
            width: parent.width
            height: root.several ? 34 : 0

            Row {
                spacing: 4
                Chip {
                    icon: "select_all"
                    label: "Same on all"
                    active: !root.each
                    onClicked: if (!active) { Editor.record(); Wallpaper.setMode("all"); }
                }
                Chip {
                    icon: "splitscreen_left"
                    label: "Each its own"
                    active: root.each
                    onClicked: if (!active) { Editor.record(); Wallpaper.setMode("each"); }
                }
                Item { width: 12; height: 1 }

                // The monitors at their shape and place; with "each" a click
                // picks the one the library sets
                Item {
                    id: map
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real minX: Math.min(...root.screens.map(s => s.x))
                    readonly property real minY: Math.min(...root.screens.map(s => s.y))
                    readonly property real spanX: Math.max(...root.screens.map(s => s.x + s.width)) - minX
                    readonly property real spanY: Math.max(...root.screens.map(s => s.y + s.height)) - minY
                    readonly property real k: Math.min(30 / spanY, 130 / spanX)
                    width: spanX * k + (root.screens.length - 1) * 4
                    height: spanY * k
                    Repeater {
                        model: root.screens
                        Tap {
                            id: mon
                            required property var modelData
                            required property int index
                            readonly property bool picked: !root.each || root.target === modelData.name
                            x: (modelData.x - map.minX) * map.k + index * 4
                            y: (modelData.y - map.minY) * map.k
                            width: modelData.width * map.k
                            height: modelData.height * map.k
                            radius: 4
                            outlined: true
                            active: picked
                            enabled: root.each
                            opacity: 1
                            onClicked: Ui.wallTarget = modelData.name
                            Txt {
                                anchors.centerIn: parent
                                text: String(mon.index + 1)
                                size: Theme.font.small
                                face: Theme.font.medium
                                color: mon.fg
                            }
                        }
                    }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    text: root.each ? root.target : "All monitors"
                    caps: true
                    color: root.ink.mute
                }
            }

            // Which monitor's wallpaper makes the colors
            Row {
                visible: root.each
                anchors.right: parent.right
                spacing: 4
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Colors from"
                    caps: true
                    color: root.ink.mute
                    rightPadding: 6
                }
                Repeater {
                    model: root.each ? root.screens : []
                    Chip {
                        required property var modelData
                        icon: "palette"
                        label: modelData.name
                        active: Wallpaper.colorsMonitor === modelData.name
                        onClicked: if (!active) { Editor.record(); Wallpaper.setColorsFrom(modelData.name); }
                    }
                }
            }
        }

        // Filters, search, sort
        Item {
            id: tools
            anchors.top: monRow.bottom
            anchors.topMargin: root.several ? 12 : 0
            width: parent.width
            height: 34

            Row {
                spacing: 4
                Repeater {
                    model: [["all", "", "All"], ["image", "image", "Pictures"], ["video", "movie", "Videos"], ["scene", "auto_awesome", "Scenes"]]
                    Chip {
                        required property var modelData
                        icon: modelData[1]
                        label: modelData[2] + "  " + (root.counts[modelData[0]] ?? 0)
                        active: root.filter === modelData[0]
                        onClicked: root.filter = modelData[0]
                    }
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Field {
                    id: search
                    width: 170
                    placeholder: "Search"
                    onEdited: t => root.query = t
                    Keys.onEscapePressed: event => {
                        if (text !== "") {
                            text = "";
                            root.query = "";
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                }
                Select {
                    c: root.ink
                    width: 132
                    height: 34
                    options: [{ value: "name", label: "By name" }, { value: "newest", label: "Newest" }]
                    value: root.sortBy
                    onPicked: v => root.sortBy = v
                }
            }
        }

        // Thumbnails
        GridView {
            id: grid
            anchors.top: tools.bottom
            anchors.topMargin: 12
            anchors.bottom: colorsRow.top
            anchors.bottomMargin: 12
            width: parent.width + 10
            x: -5
            readonly property int columns: Math.max(3, Math.round(width / 150))
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.round((cellWidth - 10) * 9 / 16) + 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Wheel and touch scroll; a mouse drag never does
            acceptedButtons: Qt.NoButton
            model: root.shownFiles
            activeFocusOnTab: true
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: false
            currentIndex: -1
            Keys.onReturnPressed: root.choose(root.shownFiles[currentIndex])
            Keys.onSpacePressed: root.choose(root.shownFiles[currentIndex])
            onActiveFocusChanged: if (activeFocus && currentIndex < 0) currentIndex = Math.max(0, root.shownFiles.findIndex(f => f.path === root.chosen))

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool current: modelData.path === root.chosen
                readonly property bool usable: modelData.kind !== "unsupported"
                readonly property var where: root.usedOn(modelData.path)
                readonly property bool gif: /\.gif$/i.test(modelData.preview ?? "")
                width: grid.cellWidth
                height: grid.cellHeight

                Tap {
                    id: tap
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 12
                    enabled: cell.usable
                    onClicked: {
                        grid.currentIndex = cell.index;
                        root.choose(cell.modelData);
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 10
                        color: root.ink.raised
                        clip: true
                        border.width: cell.current ? 2 : 0
                        border.color: root.ink.accent

                        Image {
                            anchors.fill: parent
                            anchors.margins: cell.current ? 2 : 0
                            source: Wallpapers.ready[cell.modelData.thumb] ? "file://" + cell.modelData.thumb : ""
                            sourceSize: Qt.size(320, 180)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        // A Wallpaper Engine gif preview plays while the pointer is on it
                        AnimatedImage {
                            anchors.fill: parent
                            anchors.margins: cell.current ? 2 : 0
                            visible: status === AnimatedImage.Ready
                            source: cell.gif && tap.hovered ? "file://" + cell.modelData.preview : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            playing: tap.hovered
                        }
                        // The name on a soft shade
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 26
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: cell.modelData.kind !== "image" ? 30 : 8
                                anchors.bottomMargin: 5
                                text: cell.modelData.name
                                color: "white"
                                font.family: Theme.font.family
                                font.styleName: Theme.font.regular
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }
                        // Which monitors show it
                        Row {
                            x: 6
                            y: 6
                            spacing: 3
                            Repeater {
                                model: cell.where
                                Rectangle {
                                    required property string modelData
                                    width: whereTxt.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: root.ink.accent
                                    Txt {
                                        id: whereTxt
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        caps: true
                                        size: 10
                                        color: root.ink.onAccent
                                    }
                                }
                            }
                        }
                        Rectangle {
                            visible: cell.modelData.kind !== "image"
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Qt.rgba(0, 0, 0, 0.55)
                            Icon {
                                anchors.centerIn: parent
                                name: cell.modelData.kind === "scene" ? "auto_awesome" : cell.modelData.kind === "video" ? "movie" : "block"
                                filled: true
                                size: 13
                                color: "white"
                            }
                        }
                    }
                    // The keyboard's place in the grid
                    Rectangle {
                        anchors.fill: parent
                        visible: grid.activeFocus && grid.currentIndex === cell.index
                        radius: 12
                        color: "transparent"
                        border.width: 2
                        border.color: root.ink.fg
                    }
                }
            }

            Txt {
                visible: root.shownFiles.length === 0
                anchors.centerIn: parent
                text: Wallpapers.files.length === 0 ? "No wallpapers in " + Wallpapers.folder : "Nothing matches"
                caps: true
                color: root.ink.mute
            }
        }

        // Colors: light/dark, scheme, from the picture or its own color, the palette
        Item {
            id: colorsRow
            anchors.bottom: parent.bottom
            width: parent.width
            height: 34

            Row {
                spacing: 4
                Repeater {
                    model: [["dark", "dark_mode", "Dark"], ["light", "light_mode", "Light"]]
                    Chip {
                        required property var modelData
                        icon: modelData[1]
                        label: modelData[2]
                        active: Config.theme.mode === modelData[0]
                        onClicked: if (!active) { Editor.record(); Config.theme.mode = modelData[0]; }
                    }
                }
                Item { width: 12; height: 1 }
                Select {
                    c: root.ink
                    width: 170
                    height: 34
                    options: root.schemes.map(s => ({ value: s[0], label: s[1] }))
                    value: Config.theme.scheme
                    onPicked: v => { Editor.record(); Config.theme.scheme = v; }
                }
                Item { width: 12; height: 1 }
                // A Wallpaper Engine wallpaper with a scheme color can give
                // the colors from it instead of its picture
                Chip {
                    visible: root.colorsHex !== ""
                    icon: "image"
                    label: "Picture"
                    active: !root.colorsFromScheme
                    onClicked: if (!active) { Editor.record(); WallSettings.setValue(Wallpaper.path, "colors", null); }
                }
                Chip {
                    visible: root.colorsHex !== ""
                    icon: "colorize"
                    label: "Its color"
                    active: root.colorsFromScheme
                    onClicked: if (!active) { Editor.record(); WallSettings.setValue(Wallpaper.path, "colors", "scheme"); }
                }
                Rectangle {
                    visible: root.colorsHex !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: root.colorsHex || "transparent"
                    border.width: 1
                    border.color: root.ink.line
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: [Theme.paper.accent, Theme.paper.fg, Theme.paper.mute, Theme.paper.raised, Theme.paper.bg]
                    Rectangle {
                        required property color modelData
                        width: 22
                        height: 22
                        radius: 11
                        color: modelData
                        border.width: 1
                        border.color: root.ink.line
                    }
                }
            }
        }
    }

    Rectangle {
        x: lib.width + 16
        width: 1
        height: parent.height
        color: root.ink.line
    }

    // ════════════════════════════════════════════════════════════════════
    // The chosen wallpaper (right)
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: side
        x: lib.width + 33
        width: parent.width - x
        height: parent.height

        // Preview, title, Reset
        Item {
            id: head
            width: parent.width
            height: 63

            Rectangle {
                id: preview
                width: 112
                height: 63
                radius: 10
                color: root.ink.raised
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.chosenFile && Wallpapers.ready[root.chosenFile.thumb] ? "file://" + root.chosenFile.thumb
                        : Wallpaper.stills[root.chosen] ? "file://" + Wallpaper.stills[root.chosen] : ""
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Its preview gif plays here
                AnimatedImage {
                    anchors.fill: parent
                    visible: status === AnimatedImage.Ready
                    source: /\.gif$/i.test(root.chosenFile?.preview ?? "") ? "file://" + root.chosenFile.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: preview.right
                anchors.leftMargin: 14
                anchors.right: reset.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Txt {
                    width: parent.width
                    text: root.info?.title || root.chosenFile?.name || root.chosen.split("/").pop()
                    face: Theme.font.regular
                }
                Txt {
                    width: parent.width
                    caps: true
                    color: root.ink.mute
                    text: {
                        const k = { image: "Picture", video: "Video", scene: "Scene", unsupported: "Not supported" }[root.kind] ?? "";
                        const on = root.several ? (root.each ? root.usedOn(root.chosen).join(", ") : "All monitors") : "";
                        const ch = root.changes ? root.changes + (root.changes === 1 ? " change" : " changes") : "";
                        return [k, on, ch].filter(Boolean).join("  ·  ");
                    }
                }
            }
            Tap {
                id: reset
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: resetRow.implicitWidth + 24
                implicitHeight: 34
                radius: 17
                outlined: true
                enabled: root.changes > 0
                onClicked: { Editor.record(); WallSettings.reset(root.chosen); }
                Row {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "restart_alt"
                        size: 17
                        color: reset.fg
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Reset"
                        caps: true
                        color: reset.fg
                    }
                }
            }
        }

        // Sections
        Row {
            id: sectionRow
            anchors.top: head.bottom
            anchors.topMargin: 10
            spacing: 2
            Repeater {
                model: root.sections
                Tap {
                    id: st
                    required property var modelData
                    readonly property bool on: root.shownSection === modelData.id
                    implicitWidth: sr.implicitWidth + 22
                    implicitHeight: 36
                    radius: Theme.shape.small
                    onClicked: root.section = modelData.id
                    Row {
                        id: sr
                        anchors.centerIn: parent
                        spacing: 7
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: st.modelData.icon
                            filled: st.on
                            size: 17
                            color: st.pressed ? st.fg : st.on ? root.ink.fg : root.ink.mute
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: st.modelData.label
                            caps: true
                            color: st.pressed ? st.fg : st.on ? root.ink.fg : root.ink.mute
                        }
                    }
                    Rectangle {
                        visible: st.on
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        height: 2
                        color: root.ink.accent
                    }
                }
            }
        }

        Flickable {
            id: body
            anchors.top: sectionRow.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Wheel and touch scroll; a mouse drag never does (it is for the controls)
            acceptedButtons: Qt.NoButton

            Column {
                id: content
                width: body.width

                // ── Properties ──
                Repeater {
                    model: root.shownSection === "props" ? root.props : []
                    PropLine {
                        required property var modelData
                        prop: modelData
                    }
                }

                // ── Playback (a picture: only the fit) ──
                Line {
                    visible: root.shownSection === "playback"
                    label: "Fit"
                    changed: root.entry.fit !== undefined
                    IconChoice {
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        options: [
                            { value: "fill", icon: "crop", label: "Fill" },
                            { value: "fit", icon: "fit_screen", label: "Fit" },
                            { value: "stretch", icon: "open_in_full", label: "Stretch" },
                            { value: "center", icon: "center_focus_strong", label: "Center" }
                        ]
                        value: root.entry.fit ?? "fill"
                        onPicked: v => root.setValue("fit", v)
                    }
                }
                Line {
                    visible: root.shownSection === "playback" && root.animated
                    label: "Speed"
                    changed: root.entry.speed !== undefined
                    SetSlider {
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        width: 300
                        from: 0.25
                        to: 2
                        step: 0.05
                        value: root.entry.speed ?? 1
                        format: v => v.toFixed(2) + "×"
                        onChanged: v => root.setValue("speed", v)
                    }
                }
                Line {
                    visible: root.shownSection === "playback" && root.animated
                    label: "Frame rate"
                    changed: root.entry.fps !== undefined
                    Select {
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        height: 34
                        options: [{ value: 0, label: "Shell (" + Config.wallpaper.fps + ")" }]
                            .concat([15, 24, 30, 48, 60, 75, 100, 120, 144, 165].map(n => ({ value: n, label: n + " fps" })))
                        value: root.entry.fps ?? 0
                        onPicked: v => root.setValue("fps", v)
                    }
                }
                Line {
                    visible: root.shownSection === "playback" && root.animated
                    label: "Render scale"
                    changed: root.entry.scale !== undefined
                    Select {
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        height: 34
                        options: [{ value: 0, label: "Shell (" + Math.round(Config.wallpaper.scale * 100) + "%)" }]
                            .concat([1, 0.75, 0.5, 0.25].map(n => ({ value: n, label: Math.round(n * 100) + "%" })))
                        value: root.entry.scale ?? 0
                        onPicked: v => root.setValue("scale", v)
                    }
                }
                Line {
                    visible: root.shownSection === "playback" && root.kind === "scene"
                    label: "Textures"
                    changed: root.entry.texres !== undefined
                    Select {
                        readonly property var names: ({ 1: "Full", 2: "Half", 4: "Quarter" })
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        height: 34
                        options: [{ value: 0, label: "Shell (" + (names[Config.wallpaper.texres] ?? "Full") + ")" }]
                            .concat([1, 2, 4].map(n => ({ value: n, label: names[n] })))
                        value: root.entry.texres ?? 0
                        onPicked: v => root.setValue("texres", v)
                    }
                }

                // ── Pause ──
                Repeater {
                    model: root.shownSection === "pause" ? [
                        ["fullscreen", "Fullscreen or game"], ["covered", "Covered by windows"],
                        ["battery", "On battery"], ["locked", "While locked"]
                    ] : []
                    Line {
                        id: rule
                        required property var modelData
                        readonly property var own: root.entry.pause?.[modelData[0]]
                        label: modelData[1]
                        changed: own !== undefined
                        IconChoice {
                            c: root.ink
                            showLabel: false
                            anchors.verticalCenter: parent.verticalCenter
                            options: [
                                { value: "shell", text: "Shell · " + (Config.wallpaper.pause[rule.modelData[0]] ? "on" : "off") },
                                { value: "on", text: "On" },
                                { value: "off", text: "Off" }
                            ]
                            value: rule.own === undefined ? "shell" : rule.own ? "on" : "off"
                            onPicked: v => root.setPause(rule.modelData[0], v === "shell" ? null : v === "on")
                        }
                    }
                }
                Line {
                    visible: root.shownSection === "pause"
                    label: "Paused now (every animated wallpaper)"
                    Switch {
                        c: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Wallpaper.userPaused
                        onToggled: on => Wallpaper.setPaused(on)
                    }
                }
            }
        }
    }

    // ── Rows ────────────────────────────────────────────────────────────

    // A setting: its name on the left (a dot when it differs from the
    // default), the control on the right
    component Line: Item {
        id: line
        property string label
        property bool changed: false
        property bool met: true
        default property alias control: slot.data
        width: parent?.width ?? 0
        height: visible ? 44 : 0
        opacity: met ? 1 : 0.4

        Rectangle {
            visible: line.changed
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.ink.accent
        }
        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: slot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: line.label
        }
        // Only the visible controls take room (a property line holds one of each kind)
        Row {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 4
            height: parent.height
        }
    }

    // A Wallpaper Engine property, by its type: bool → switch, slider →
    // slider, combo → dropdown, color → swatch (opens chips and a hex field),
    // textinput → field; a plain text is a caption
    component PropLine: Column {
        id: pl
        property var prop
        readonly property var value: root.values[prop.key]
        readonly property bool met: WallSettings.conditionMet(root.chosen, prop.condition)
        readonly property bool changed: (root.entry.props ?? {})[prop.key] !== undefined
        property bool picking: false
        width: parent?.width ?? 0
        // The opened chips scroll into view, once the column has room for them
        onPickingChanged: if (picking) reveal.restart()
        Timer {
            id: reveal
            interval: 30
            onTriggered: {
                const end = pl.mapToItem(content, 0, 0).y + pl.height;
                if (end > body.contentY + body.height)
                    body.contentY = Math.max(0, Math.min(end, content.height) - body.height);
            }
        }

        Line {
            visible: pl.prop.type !== "text" && pl.prop.type !== "group"
            label: WallSettings.label(pl.prop.text)
            changed: pl.changed
            met: pl.met

            Switch {
                visible: pl.prop.type === "bool"
                c: root.ink
                anchors.verticalCenter: parent.verticalCenter
                enabled: pl.met
                checked: !!pl.value
                onToggled: on => root.setProp(pl.prop.key, on)
            }
            SetSlider {
                visible: pl.prop.type === "slider"
                c: root.ink
                anchors.verticalCenter: parent.verticalCenter
                enabled: pl.met
                width: 300
                from: Number(pl.prop.min ?? 0)
                to: Number(pl.prop.max ?? 1)
                step: Number(pl.prop.step) || (pl.prop.fraction ? 0.01 : 1)
                value: Number(pl.value ?? 0)
                format: v => v.toFixed(pl.prop.precision ?? (pl.prop.fraction ? 2 : 0))
                onChanged: v => root.setProp(pl.prop.key, v)
            }
            Select {
                visible: pl.prop.type === "combo"
                c: root.ink
                anchors.verticalCenter: parent.verticalCenter
                enabled: pl.met
                width: 220
                height: 34
                options: (pl.prop.options ?? []).map(o => ({ value: o.value, label: WallSettings.label(String(o.label ?? o.value)) }))
                value: pl.value
                onPicked: v => root.setProp(pl.prop.key, v)
            }
            Field {
                visible: pl.prop.type === "textinput"
                anchors.verticalCenter: parent.verticalCenter
                enabled: pl.met
                width: 220
                text: String(pl.value ?? "")
                onAccepted: t => root.setProp(pl.prop.key, t)
            }
            Tap {
                id: swatch
                visible: pl.prop.type === "color"
                anchors.verticalCenter: parent.verticalCenter
                enabled: pl.met
                implicitWidth: swRow.implicitWidth + 20
                implicitHeight: 34
                radius: 17
                outlined: true
                active: pl.picking
                onClicked: pl.picking = !pl.picking
                Row {
                    id: swRow
                    anchors.centerIn: parent
                    spacing: 8
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WallSettings.hexOf(pl.value)
                        caps: true
                        color: swatch.fg
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: WallSettings.hexOf(pl.value) || "transparent"
                        border.width: 1
                        border.color: root.ink.line
                    }
                }
            }
        }
        // The color's chips and hex field
        Row {
            visible: pl.picking && pl.prop.type === "color"
            height: visible ? 40 : 0
            leftPadding: 14
            spacing: 6
            Repeater {
                model: pl.picking ? [WallSettings.hexOf(WallSettings.defaultOf(root.chosen, pl.prop.key)), String(Theme.ink.accent), String(Theme.paper.accent),
                    "#ffffff", "#000000", "#ff6b6b", "#ffe066", "#6bcb77", "#4cc9f0", "#b5179e"] : []
                Tap {
                    id: chipC
                    required property string modelData
                    anchors.verticalCenter: parent?.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: root.setProp(pl.prop.key, WallSettings.rgbOf(modelData))
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: chipC.modelData
                        border.width: WallSettings.hexOf(pl.value).toLowerCase() === chipC.modelData.toLowerCase().slice(0, 7) ? 2 : 1
                        border.color: WallSettings.hexOf(pl.value).toLowerCase() === chipC.modelData.toLowerCase().slice(0, 7) ? root.ink.fg : root.ink.line
                    }
                }
            }
            Field {
                anchors.verticalCenter: parent.verticalCenter
                width: 110
                placeholder: "#rrggbb"
                text: WallSettings.hexOf(pl.value)
                onAccepted: t => {
                    const rgb = WallSettings.rgbOf(t.startsWith("#") ? t : "#" + t);
                    if (rgb)
                        root.setProp(pl.prop.key, rgb);
                }
            }
        }
        // A caption the author put between properties
        Txt {
            visible: pl.prop.type === "text"
            width: parent.width
            height: visible ? 32 : 0
            verticalAlignment: Text.AlignVCenter
            leftPadding: 14
            text: WallSettings.label(pl.prop.text)
            caps: true
            color: root.ink.mute
        }
    }
}
