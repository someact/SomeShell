import QtQuick
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

Page {
    id: page
    title: "Island"
    subtitle: "What the island shows while collapsed, and for how long."

    // Pill layout: which zone each part sits in, and its order there
    readonly property var zones: ["left", "islandLeft", "islandRight", "right"]
    readonly property var partNames: ({ workspaces: "Workspaces", special: "Special workspaces", title: "App title", tray: "System tray", status: "Status icons", clock: "Date and time" })
    readonly property var partIcons: ({ workspaces: "view_week", special: "star", title: "web_asset", tray: "apps", status: "wifi", clock: "schedule" })
    function zoneOf(id) {
        const l = Config.pills.layout;
        return zones.find(z => (l[z] ?? []).includes(id)) ?? "off";
    }
    function copyLayout() {
        const l = Config.pills.layout, c = {};
        for (const z of zones)
            c[z] = [...(l[z] ?? [])];
        return c;
    }
    function moveTo(id, zone) {
        const c = copyLayout();
        for (const z of zones)
            c[z] = c[z].filter(p => p !== id);
        if (zone !== "off")
            c[zone].push(id);
        Config.pills.layout = c;
    }
    function shift(id, delta) {
        const z = zoneOf(id);
        if (z === "off")
            return;
        const c = copyLayout(), a = c[z], i = a.indexOf(id), j = i + delta;
        if (j < 0 || j >= a.length)
            return;
        [a[i], a[j]] = [a[j], a[i]];
        Config.pills.layout = c;
    }

    Section {
        title: "Pill layout"
        note: "Put each part in a top corner or beside the island, or turn it off. The arrows move it earlier or later within its place."
        Repeater {
            model: ["workspaces", "special", "title", "tray", "status", "clock"]
            SettingRow {
                id: layoutRow
                required property string modelData
                readonly property string zone: page.zoneOf(modelData)
                readonly property var list: Config.pills.layout[zone] ?? []
                icon: page.partIcons[modelData]
                title: page.partNames[modelData]
                subtitle: zone === "off" ? "Hidden" : (list.indexOf(modelData) + 1) + " of " + list.length + " in " + ({ left: "the left corner", islandLeft: "left of the island", islandRight: "right of the island", right: "the right corner" })[zone]
                Row {
                    spacing: 6
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        iconSize: 18
                        icon: "chevron_left"
                        enabled: layoutRow.zone !== "off" && layoutRow.list.indexOf(layoutRow.modelData) > 0
                        iconColor: Theme.fgSurface
                        onClicked: page.shift(layoutRow.modelData, -1)
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        iconSize: 18
                        icon: "chevron_right"
                        enabled: layoutRow.zone !== "off" && layoutRow.list.indexOf(layoutRow.modelData) < layoutRow.list.length - 1
                        iconColor: Theme.fgSurface
                        onClicked: page.shift(layoutRow.modelData, 1)
                    }
                    Choice {
                        anchors.verticalCenter: parent.verticalCenter
                        model: [{ value: "left", label: "Left" }, { value: "islandLeft", label: "◂ Island" }, { value: "islandRight", label: "Island ▸" }, { value: "right", label: "Right" }, { value: "off", label: "Off" }]
                        value: layoutRow.zone
                        onPicked: v => page.moveTo(layoutRow.modelData, v)
                    }
                }
            }
        }
    }

    Section {
        title: "Corner pills"
        note: "Each part is a frosted glass pill (glass parts side by side share one pill) or floats with no background, like a phone's status bar."
        PartRow {
            part: "workspaces"
            icon: "view_week"
            title: "Workspaces"
        }
        SettingRow {
            icon: "cookie"
            title: "Active workspace shape"
            subtitle: "Dynamic gives every workspace number its own shape"
            Choice {
                model: [{ value: "dynamic", label: "Dynamic" }, { value: "cookie7Sided", label: "Cookie" }, { value: "clover4Leaf", label: "Clover" }, { value: "sunny", label: "Sunny" }, { value: "pill", label: "Pill" }, { value: "circle", label: "Circle" }]
                value: Config.pills.workspaceShape
                onPicked: v => Config.pills.workspaceShape = v
            }
        }
        SettingRow {
            icon: "check_box_outline_blank"
            title: "Show empty workspaces"
            subtitle: "Off shows only workspaces with windows and the one you are on; previews can temporarily show them all"
            Switch {
                checked: Config.pills.showEmpty
                onToggled: on => Config.pills.showEmpty = on
            }
        }
        SettingRow {
            icon: "keyboard"
            title: "Show all workspaces on Super hold"
            subtitle: "Hold Super for one second to preview every workspace; release to close"
            Switch {
                checked: Config.pills.superPeek
                onToggled: on => Config.pills.superPeek = on
            }
        }
        SettingRow {
            icon: "touch_app"
            title: "Show all workspaces on hover"
            subtitle: "Resting the pointer on the workspaces shows every one as its shape"
            Switch {
                checked: Config.pills.hoverPeek
                onToggled: on => Config.pills.hoverPeek = on
            }
        }
        PartRow {
            part: "title"
            icon: "web_asset"
            title: "App title"
        }
        PartRow {
            part: "tray"
            icon: "apps"
            title: "System tray"
        }
        PartRow {
            part: "status"
            icon: "wifi"
            title: "Status icons"
            subtitle: "Keyboard layout, network, Bluetooth, volume"
        }
        PartRow {
            part: "clock"
            icon: "schedule"
            title: "Date and time"
        }
        SettingRow {
            icon: "shadow"
            title: "Floating text"
            subtitle: "How floating parts stay readable: a soft shadow, or a thin outline (lightest)"
            enabled: ["workspaces", "title", "tray", "status", "clock"].some(k => Config.pills[k] === "floating")
            Choice {
                model: [{ value: "shadow", label: "Shadow" }, { value: "outline", label: "Outline" }]
                value: Config.pills.halo
                onPicked: v => Config.pills.halo = v
            }
        }
    }

    component PartRow: SettingRow {
        id: partRow
        required property string part
        Choice {
            model: [{ value: "glass", label: "Glass" }, { value: "floating", label: "Floating" }]
            value: Config.pills[partRow.part] ?? "glass"
            onPicked: v => Config.pills[partRow.part] = v
        }
    }

    Section {
        title: "Collapsed"
        SettingRow {
            icon: "touch_app"
            title: "Peek on hover"
            subtitle: "Resting the pointer on the island or the screen edge above it shows a view; click or tap Super to open it fully"
            Switch {
                checked: Config.island.hoverPeek
                onToggled: on => Config.island.hoverPeek = on
            }
        }
        SettingRow {
            icon: "music_note"
            title: "Show media"
            subtitle: "Album art, title and peak bars while something plays"
            Switch {
                checked: Config.island.showMedia
                onToggled: on => Config.island.showMedia = on
            }
        }
        SettingRow {
            icon: "lyrics"
            title: "Lyrics"
            subtitle: "Look up the playing track on lrclib.net (once per track, cached) for the media view and widget"
            Switch {
                checked: Config.media.lyrics
                onToggled: on => Config.media.lyrics = on
            }
        }
        SettingRow {
            visible: Config.media.lyrics
            icon: "subtitles"
            title: "Lyric line in the island"
            subtitle: "While a track with synced lyrics plays, the collapsed island shows the current line instead of the title"
            Switch {
                checked: Config.media.ambientLyrics
                onToggled: on => Config.media.ambientLyrics = on
            }
        }
        SettingRow {
            icon: "notifications"
            title: "Notification peek"
            subtitle: "How long a new notification shows in the island"
            changed: Config.island.peekMs !== 4000
            onReset: Config.island.peekMs = 4000
            ValueSlider {
                from: 1
                to: 10
                stepSize: 0.5
                suffix: " s"
                value: Config.island.peekMs / 1000
                onMoved: v => Config.island.peekMs = Math.round(v * 1000)
            }
        }
        SettingRow {
            icon: "volume_up"
            title: "Volume and brightness display"
            subtitle: "How long the OSD stays after a change"
            changed: Config.island.osdMs !== 1500
            onReset: Config.island.osdMs = 1500
            ValueSlider {
                from: 0.5
                to: 5
                stepSize: 0.25
                suffix: " s"
                value: Config.island.osdMs / 1000
                onMoved: v => Config.island.osdMs = Math.round(v * 1000)
            }
        }
    }

    Section {
        title: "Clock"
        note: "Qt date format: HH hours, mm minutes, ap am/pm, ddd weekday, d day, MMM month."
        SettingRow {
            icon: "schedule"
            title: "Time format"
            subtitle: Qt.formatTime(new Date(), Config.clock.format)
            Field {
                implicitWidth: 180
                mono: true
                text: Config.clock.format
                onCommitted: t => {
                    if (t.trim() !== "")
                        Config.clock.format = t.trim();
                }
            }
        }
        SettingRow {
            icon: "calendar_today"
            title: "Date format"
            subtitle: Qt.formatDate(new Date(), Config.clock.dateFormat)
            Field {
                implicitWidth: 180
                mono: true
                text: Config.clock.dateFormat
                onCommitted: t => {
                    if (t.trim() !== "")
                        Config.clock.dateFormat = t.trim();
                }
            }
        }
    }

    Section {
        title: "Search"
        SettingRow {
            icon: "search"
            title: "Results"
            subtitle: "How many results search lists at most"
            changed: Config.search.maxResults !== 8
            onReset: Config.search.maxResults = 8
            ValueSlider {
                from: 4
                to: 14
                stepSize: 1
                value: Config.search.maxResults
                onMoved: v => Config.search.maxResults = v
            }
        }
        SettingRow {
            icon: "folder_code"
            title: "Projects folder"
            subtitle: "/project opens one of its folders in the code editor"
            changed: Config.search.projectsDir !== ""
            onReset: Config.search.projectsDir = ""
            Field {
                implicitWidth: 260
                placeholder: "~/Projects"
                text: Config.search.projectsDir
                onCommitted: t => Config.search.projectsDir = t.trim()
            }
        }
    }

    Section {
        title: "Notifications"
        SettingRow {
            icon: "history"
            title: "History"
            subtitle: "How many notifications to keep"
            changed: Config.notifications.keep !== 50
            onReset: Config.notifications.keep = 50
            ValueSlider {
                from: 10
                to: 200
                stepSize: 10
                value: Config.notifications.keep
                onMoved: v => Config.notifications.keep = v
            }
        }
    }
}
