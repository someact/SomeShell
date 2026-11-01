import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.settings
import qs.settings.ui
import "../../lib/schedule.js" as Slots

Page {
    id: page
    title: "Wallpaper"
    subtitle: "Images and videos. Colors follow the wallpaper."

    // The shell owns the wallpaper (mpvpaper, matugen); this page reads its state
    // and asks it to change over IPC.
    property string current: ""
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov|m4v|avi|gif)$/i.test(current)
    readonly property var schedule: Config.theme.schedule

    FileView {
        path: Paths.wallpaperState
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                page.current = JSON.parse(text()).path ?? "";
            } catch (e) {}
        }
    }

    // Folder and file choosers for a schedule slot
    Process {
        id: chooser
        property string slot
        property string field      // folder | file
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") page.setSlot(chooser.slot, ({ [chooser.field]: text.trim() }))
        }
    }
    function choose(slot, field) {
        chooser.slot = slot;
        chooser.field = field;
        chooser.command = field === "folder" ? ["kdialog", "--title", "Wallpaper folder", "--getexistingdirectory", Paths.wallpapers] : ["kdialog", "--title", "Wallpaper", "--getopenfilename", Paths.wallpapers, "*.jpg *.jpeg *.png *.webp *.avif *.mp4 *.webm *.mkv *.mov *.gif|Images and videos"];
        chooser.running = true;
    }

    // Schedule model (lib/schedule.js); the shell applies it, this page only edits
    readonly property var slots: Slots.slots(schedule)
    property var sun: null
    readonly property var starts: Slots.starts(schedule, slots, sun)
    readonly property var line: Slots.timeline(slots, starts)
    readonly property bool fromSun: schedule.sunTimes && sun !== null
    property string expanded: ""
    function setSlot(name, patch) {
        schedule.slots = Slots.withSlot(schedule, name, patch);
    }
    function shortPath(p) {
        return p.replace(Paths.home, "~");
    }
    function summary(name) {
        const s = slots[name];
        const src = ({ keep: "Keep the wallpaper", file: s.file ? s.file.split("/").pop() : "No file chosen", folder: s.folder ? "Random from " + s.folder.split("/").pop() : "No folder chosen", dynamic: s.folder ? "Every " + s.interval + " min from " + s.folder.split("/").pop() : "No folder chosen" })[s.source];
        const mode = ({ keep: "", dark: " · dark", light: " · light" })[s.mode];
        const nl = ({ keep: "", on: " · night light", off: " · night light off" })[s.nightLight];
        return Slots.hhmm(starts[name]) + " · " + src + mode + nl;
    }
    readonly property var slotColors: ({ sunrise: "#f4a261", noon: "#e9c46a", sunset: "#e76f51", night: "#5c6bc0", midnight: "#2b2d6e" })

    FileView {
        path: Paths.stateDir + "/sun.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                page.sun = JSON.parse(text());
            } catch (e) {}
        }
    }

    Section {
        title: "Current"
        Item {
            width: parent.width
            height: 236
            Cover {
                id: preview
                x: 16
                y: 16
                width: 360
                height: 204
                radius: Theme.radius.normal
                color: Theme.surfaceHigh
                fallbackIcon: "wallpaper"
                source: page.current === "" ? "" : Paths.url(page.isVideo ? Paths.videoFrame : page.current)
            }
            Column {
                anchors.left: preview.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 16
                spacing: 10
                SText {
                    width: parent.width
                    text: page.current === "" ? "No wallpaper set" : page.current.split("/").pop()
                    font.styleName: Theme.font.styleTitle
                }
                SText {
                    width: parent.width
                    text: page.isVideo ? "Video (mpvpaper, paused while a game or fullscreen window is up)" : page.current.slice(0, page.current.lastIndexOf("/"))
                    dim: true
                    font.pixelSize: Theme.font.small
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                Item {
                    width: 1
                    height: 6
                }
                SButton {
                    kind: "filled"
                    icon: "photo_library"
                    text: "Choose…"
                    onClicked: ShellIpc.call("island", "open", "wallpaper")
                }
                Row {
                    spacing: 8
                    SButton {
                        icon: "shuffle"
                        text: "Random"
                        onClicked: ShellIpc.call("wallpaper", "random")
                    }
                    SButton {
                        icon: "folder_open"
                        text: "From file…"
                        onClicked: ShellIpc.call("wallpaper", "pick")
                    }
                }
            }
        }
    }

    Section {
        title: "Time of day"
        note: "Each slot starts at its time and sets the wallpaper (keep, one file, a random one from a folder, or a new random one every few minutes), the colors and night light. Preview applies a slot until the next one starts."
        SettingRow {
            icon: "schedule"
            title: "Switch on a schedule"
            Switch {
                checked: page.schedule.enabled
                onToggled: on => page.schedule.enabled = on
            }
        }
        SettingRow {
            enabled: page.schedule.enabled
            icon: "wb_sunny"
            title: "Follow the sun"
            subtitle: !page.schedule.sunTimes ? "Use the times set below" : page.sun ? "Sunrise " + Slots.hhmm(page.sun.sunrise) + " · sunset " + Slots.hhmm(page.sun.sunset) + " (" + (Config.widgets.weatherCity || "your location") + "). Noon and midnight from those; night an hour after sunset; each moved by its offset" : "Looking up sun times…"
            Switch {
                checked: page.schedule.sunTimes
                onToggled: on => page.schedule.sunTimes = on
            }
        }

        // 24 h bar: one band per slot that is on, until the next one starts
        Item {
            width: parent.width
            height: 46
            enabled: page.schedule.enabled
            opacity: enabled ? 1 : 0.45
            Item {
                id: bar
                x: 16
                y: 6
                width: parent.width - 32
                height: 14
                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: Theme.surfaceHigh
                }
                Repeater {
                    model: {
                        const l = page.line, out = [];
                        l.forEach((s, i) => {
                            const end = i + 1 < l.length ? l[i + 1].start : l[0].start + 1440;
                            out.push({ name: s.name, a: s.start, b: Math.min(end, 1440) });
                            if (end > 1440)
                                out.push({ name: s.name, a: 0, b: end - 1440 });
                        });
                        return out;
                    }
                    Rectangle {
                        required property var modelData
                        x: modelData.a / 1440 * bar.width
                        width: Math.max(2, (modelData.b - modelData.a) / 1440 * bar.width)
                        height: bar.height
                        radius: 7
                        color: page.slotColors[modelData.name]
                    }
                }
                Repeater {
                    model: page.line
                    Item {
                        required property var modelData
                        x: modelData.start / 1440 * bar.width
                        Rectangle {
                            x: -1
                            width: 2
                            height: bar.height
                            color: Theme.surface
                        }
                        SText {
                            x: -width / 2
                            y: bar.height + 3
                            text: Slots.hhmm(modelData.start)
                            dim: true
                            font.pixelSize: Theme.font.small - 1
                        }
                    }
                }
            }
        }

        Repeater {
            model: Slots.names
            Column {
                id: slot
                required property string modelData
                readonly property var s: page.slots[modelData]
                readonly property bool open: page.expanded === modelData && s.on
                width: parent.width
                enabled: page.schedule.enabled
                opacity: enabled ? 1 : 0.45

                SettingRow {
                    icon: Slots.info[slot.modelData].icon
                    title: Slots.info[slot.modelData].title
                    subtitle: slot.s.on ? page.summary(slot.modelData) : "Off"
                    Row {
                        spacing: 8
                        Field {
                            visible: slot.s.on && !page.fromSun
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 76
                            mono: true
                            text: slot.s.start
                            onCommitted: t => {
                                if (Slots.validTime(t))
                                    page.setSlot(slot.modelData, { start: Slots.hhmm(Slots.minutes(t)) });
                            }
                        }
                        Field {
                            visible: slot.s.on && page.fromSun
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 76
                            mono: true
                            placeholder: "± min"
                            text: slot.s.offset === 0 ? "" : (slot.s.offset > 0 ? "+" : "") + slot.s.offset
                            onCommitted: t => page.setSlot(slot.modelData, { offset: parseInt(t) || 0 })
                        }
                        Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: slot.s.on
                            onToggled: on => page.setSlot(slot.modelData, { on: on })
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slot.s.on
                            width: 32
                            height: 32
                            iconSize: 20
                            icon: slot.open ? "expand_less" : "expand_more"
                            iconColor: Theme.fgSurfaceVariant
                            hoverColor: Theme.surfaceHigh
                            onClicked: page.expanded = slot.open ? "" : slot.modelData
                        }
                    }
                }

                Column {
                    visible: slot.open
                    width: parent.width
                    SettingRow {
                        icon: "image"
                        title: "Wallpaper"
                        Choice {
                            model: [{ value: "keep", label: "Keep" }, { value: "file", label: "File" }, { value: "folder", label: "Folder" }, { value: "dynamic", label: "Dynamic" }]
                            value: slot.s.source
                            onPicked: v => page.setSlot(slot.modelData, { source: v })
                        }
                    }
                    SettingRow {
                        visible: slot.s.source === "file"
                        icon: "photo"
                        title: "File"
                        subtitle: slot.s.file ? page.shortPath(slot.s.file) : "Image or video"
                        SButton {
                            text: "Choose…"
                            onClicked: page.choose(slot.modelData, "file")
                        }
                    }
                    SettingRow {
                        visible: slot.s.source === "folder" || slot.s.source === "dynamic"
                        icon: "folder"
                        title: "Folder"
                        subtitle: slot.s.folder ? page.shortPath(slot.s.folder) : (slot.s.source === "dynamic" ? "A new random wallpaper from it every few minutes" : "One random wallpaper from it when the slot starts")
                        SButton {
                            text: "Choose…"
                            onClicked: page.choose(slot.modelData, "folder")
                        }
                    }
                    SettingRow {
                        visible: slot.s.source === "dynamic"
                        icon: "timer"
                        title: "Change every"
                        subtitle: "Minutes; paused in game mode"
                        Field {
                            implicitWidth: 76
                            mono: true
                            text: String(slot.s.interval)
                            onCommitted: t => {
                                const n = parseInt(t);
                                if (n >= 1)
                                    page.setSlot(slot.modelData, { interval: n });
                            }
                        }
                    }
                    SettingRow {
                        icon: "contrast"
                        title: "Colors"
                        Choice {
                            model: [{ value: "keep", label: "Keep" }, { value: "dark", label: "Dark" }, { value: "light", label: "Light" }]
                            value: slot.s.mode
                            onPicked: v => page.setSlot(slot.modelData, { mode: v })
                        }
                    }
                    SettingRow {
                        icon: "nightlight"
                        title: "Night light"
                        Choice {
                            model: [{ value: "keep", label: "Keep" }, { value: "on", label: "On" }, { value: "off", label: "Off" }]
                            value: slot.s.nightLight
                            onPicked: v => page.setSlot(slot.modelData, { nightLight: v })
                        }
                    }
                    SettingRow {
                        icon: "visibility"
                        title: "Preview"
                        subtitle: "Apply this slot now; the schedule takes over at the next start"
                        SButton {
                            icon: "play_arrow"
                            text: "Preview"
                            onClicked: ShellIpc.call("wallpaper", "slot", slot.modelData)
                        }
                    }
                }
            }
        }
    }
}
