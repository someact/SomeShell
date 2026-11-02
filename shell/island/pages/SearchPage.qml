import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services
import "../../lib/calc.js" as Calc

// 01 Search. Type to find apps, do math, or search the web; "/" lists the
// commands. The page is as tall as its results, so the island grows and
// shrinks while you type.
//   /clip   clipboard history (Super+V)    /emoji  emoji (Super+.)
//   /wall   wallpapers                     /settings  the settings window
Item {
    id: root

    readonly property int pageWidth: 588
    readonly property string query: input.text
    readonly property string mode: modeOf(query)
    function modeOf(text) {
        return text.startsWith("/clip") ? "clip"
            : text.startsWith("/emoji") ? "emoji"
            : text.startsWith("/wall") ? "wall"
            : text.startsWith("/") ? "commands"
            : "apps";
    }
    readonly property int columns: mode === "emoji" ? 9 : mode === "wall" ? 3 : 1

    property int sel: 0
    property var results: []

    implicitWidth: pageWidth
    implicitHeight: col.implicitHeight

    readonly property var commands: [
        { cmd: "/clip", title: "Clipboard history", icon: "content_paste", keys: "Super+V" },
        { cmd: "/emoji", title: "Emoji", icon: "mood", keys: "Super+." },
        { cmd: "/wall", title: "Wallpaper", icon: "wallpaper", keys: "" },
        { cmd: "/settings", title: "Settings", icon: "settings", keys: "Super+I" }
    ]

    // Reads the input directly: inside its change handler the bindings above
    // still hold the previous text
    function update() {
        sel = 0;
        const query = input.text;
        const mode = modeOf(query);
        // The text after the command word
        const rest = mode === "apps" || mode === "commands" ? query : query.replace(/^\/\S+\s*/, "");
        if (mode === "clip") {
            results = Clipboard.search(rest, 8).map(e => ({ kind: "clip", title: e.text, image: e.image, icon: e.image ? "image" : "content_paste", data: e }));
        } else if (mode === "emoji") {
            results = Emojis.search(rest, 45).map(e => ({ kind: "emoji", title: e.name, emoji: e.emoji, data: e }));
        } else if (mode === "wall") {
            results = Wallpapers.search(rest, 12).map(f => ({ kind: "wall", title: f.name, thumb: f.thumb, data: f }));
        } else if (mode === "commands") {
            const word = query.split(" ")[0];
            results = commands.filter(c => c.cmd.startsWith(word)).map(c => ({ kind: "command", title: c.title, icon: c.icon, tag: c.cmd, data: c }));
        } else {
            const out = [];
            const value = Calc.evaluate(query);
            if (value !== null)
                out.push({ kind: "math", title: "= " + Calc.format(value), icon: "calculate", tag: "Copy", data: value });
            for (const e of Apps.search(query, value !== null ? 4 : 5))
                out.push({ kind: "app", title: e.name, iconSource: Quickshell.iconPath(e.icon, true), icon: "apps", tag: "App", data: e });
            if (query.trim() && out.length < 2)
                out.push({ kind: "web", title: "Search the web for “" + query.trim() + "”", icon: "travel_explore", tag: "Web", data: query.trim() });
            results = out;
        }
    }

    function activate(i) {
        const r = results[i];
        if (!r)
            return;
        switch (r.kind) {
        case "app":
            Apps.launch(r.data);
            Ui.close();
            break;
        case "math":
            Quickshell.execDetached(["wl-copy", String(Math.round(r.data * 1e10) / 1e10)]);
            Ui.close();
            break;
        case "web":
            Qt.openUrlExternally("https://www.google.com/search?q=" + encodeURIComponent(r.data));
            Ui.close();
            break;
        case "command":
            if (r.data.cmd === "/settings") {
                Ui.close();
                Ui.showAlert("Settings", "The settings window comes in step 7.", "SomeShell", "settings");
            } else {
                input.text = r.data.cmd + " ";
            }
            break;
        case "clip":
            Clipboard.copy(r.data);
            Ui.close();
            break;
        case "emoji":
            Emojis.copy(r.data.emoji);
            Ui.close();
            break;
        case "wall":
            Wallpaper.set(r.data.path);
            break;
        }
    }

    function move(step) {
        if (results.length)
            sel = Math.max(0, Math.min(results.length - 1, sel + step));
    }

    onModeChanged: {
        if (mode === "clip") Clipboard.refresh();
        if (mode === "emoji") Emojis.load();
        if (mode === "wall") Wallpapers.refresh();
    }
    Connections {
        target: Clipboard
        function onEntriesChanged() { if (root.mode === "clip") root.update(); }
    }
    Connections {
        target: Emojis
        function onListChanged() { if (root.mode === "emoji") root.update(); }
    }
    Connections {
        target: Wallpapers
        function onFilesChanged() { if (root.mode === "wall") root.update(); }
    }
    Connections {
        target: Apps
        function onAllChanged() { if (root.mode === "apps") root.update(); }
    }

    Component.onCompleted: {
        input.text = Ui.query;
        Ui.query = "";
        update();
        input.forceActiveFocus();
    }

    Column {
        id: col
        width: root.pageWidth
        spacing: 12

        // Query
        Row {
            width: parent.width
            spacing: 14
            Icon {
                id: glass
                anchors.verticalCenter: parent.verticalCenter
                name: root.mode === "apps" ? "search" : root.commands.find(c => root.query.startsWith(c.cmd))?.icon ?? "terminal"
                size: 26
                color: Theme.ink.mute
            }
            TextInput {
                id: input
                width: parent.width - glass.width - 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink.fg
                selectionColor: Theme.ink.accent
                selectedTextColor: Theme.ink.onAccent
                font.family: Theme.font.family
                font.styleName: Theme.font.regular
                font.pixelSize: 26
                clip: true
                focus: true
                onTextChanged: {
                    // Typing turns a hover-opened island into one that stays
                    if (text !== "")
                        Ui.openedByHover = false;
                    root.update();
                }
                Keys.onPressed: event => {
                    const grid = root.columns > 1;
                    if (event.key === Qt.Key_Down) root.move(root.columns);
                    else if (event.key === Qt.Key_Up) root.move(-root.columns);
                    else if (grid && event.key === Qt.Key_Right) root.move(1);
                    else if (grid && event.key === Qt.Key_Left) root.move(-1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate(root.sel);
                    else return;
                    event.accepted = true;
                }

                Txt {
                    visible: input.text === ""
                    text: "Apps, math, or / for commands"
                    size: 26
                    face: Theme.font.light
                    color: Theme.ink.mute
                    opacity: 0.6
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.ink.line
        }

        // Rows: apps, math, web, commands, clipboard
        Column {
            visible: root.columns === 1
            width: parent.width
            spacing: 2

            Repeater {
                model: root.columns === 1 ? root.results : []

                Tap {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isTop: index === 0 && modelData.kind === "app" && root.query.trim() !== ""
                    width: parent.width
                    height: isTop ? 64 : 50
                    radius: 14
                    highlighted: index === root.sel
                    onClicked: root.activate(index)
                    onHoveredChanged: if (hovered) root.sel = index

                    Rectangle {
                        id: badge
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.isTop ? 44 : 36
                        height: width
                        radius: row.isTop ? 13 : 11
                        color: row.isTop ? Theme.ink.accent : "transparent"
                        border.width: row.isTop ? 0 : 1
                        border.color: Theme.ink.line
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: !!row.modelData.image
                            source: row.modelData.image ? "file://" + row.modelData.image : ""
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Image {
                            anchors.centerIn: parent
                            visible: !!row.modelData.iconSource && status === Image.Ready
                            width: parent.width - 12
                            height: width
                            source: row.modelData.iconSource ?? ""
                            sourceSize: Qt.size(width * 2, height * 2)
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !row.modelData.image && !row.modelData.iconSource
                            name: row.modelData.icon ?? "apps"
                            color: row.isTop ? Theme.ink.onAccent : Theme.ink.fg
                        }
                    }

                    Txt {
                        anchors.left: badge.right
                        anchors.leftMargin: 14
                        anchors.right: tag.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.title.replace(/\s+/g, " ")
                        size: row.isTop ? 22 : Theme.font.body
                        face: row.isTop ? Theme.font.bold : Theme.font.regular
                        color: row.pressed ? row.fg : Theme.ink.fg
                    }
                    Txt {
                        id: tag
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.index === root.sel ? "Enter" : (row.modelData.tag ?? "")
                        caps: true
                        color: row.pressed ? row.fg : Theme.ink.mute
                    }
                }
            }
        }

        // Grids: emoji and wallpapers
        Grid {
            visible: root.columns > 1
            columns: root.columns
            spacing: root.mode === "emoji" ? 4 : 10

            Repeater {
                model: root.columns > 1 ? root.results : []

                Tap {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool wall: modelData.kind === "wall"
                    width: wall ? (root.pageWidth - 20) / 3 : (root.pageWidth - 32) / 9
                    height: wall ? width * 9 / 16 : width
                    radius: wall ? 12 : 10
                    highlighted: index === root.sel
                    onClicked: root.activate(index)
                    onHoveredChanged: if (hovered) root.sel = index

                    Text {
                        anchors.centerIn: parent
                        visible: !cell.wall
                        text: cell.modelData.emoji ?? ""
                        // fontconfig's emoji alias: the colour emoji font,
                        // also for text-default ones like ☺ (else a text font
                        // draws them black on the dark island)
                        font.family: "emoji"
                        font.pixelSize: 30
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        visible: cell.wall
                        radius: 9
                        color: Theme.ink.raised
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: cell.wall && Wallpapers.ready[cell.modelData.thumb] ? "file://" + cell.modelData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        Rectangle {
                            visible: cell.wall && cell.modelData.data.path === Wallpaper.path
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.ink.accent
                            Icon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 16
                                color: Theme.ink.onAccent
                            }
                        }
                    }
                }
            }
        }

        Txt {
            visible: root.results.length === 0
            width: parent.width
            topPadding: 8
            bottomPadding: 8
            text: root.mode === "clip" ? (Clipboard.loading ? "Reading the clipboard…" : "Nothing copied yet")
                : root.mode === "wall" ? "No images in " + Wallpapers.folder
                : root.mode === "emoji" ? "No emoji found"
                : "Type to search"
            caps: true
            color: Theme.ink.mute
        }

        // Hints
        Row {
            spacing: 20
            Repeater {
                model: root.columns > 1 ? ["Arrows choose", "Enter picks", "Tab next page", "Esc close"] : ["↑ ↓ choose", "Enter opens", "Tab next page", "Esc close"]
                Txt {
                    required property string modelData
                    text: modelData
                    caps: true
                    color: Theme.ink.mute
                }
            }
        }
    }
}
