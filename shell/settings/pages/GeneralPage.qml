import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// Settings 01 General: the look, where the island sits, the dock, the lock
// screen style and the keyboard layouts. Every change applies at once.
Flickable {
    id: root

    readonly property var c: Theme.paper

    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Wheel and touch scroll; a mouse drag never does (it is for the controls)
    acceptedButtons: Qt.NoButton

    Column {
        id: col
        width: root.width

        // ── Look ──
        SetSection { text: "Look" }
        SetRow {
            label: "Mode"
            IconChoice {
                options: [
                    { value: "light", icon: "light_mode", label: "Light" },
                    { value: "dark", icon: "dark_mode", label: "Dark" }
                ]
                value: Config.theme.mode
                onPicked: v => Config.theme.mode = v
            }
        }
        SetRow {
            label: "Island"
            IconChoice {
                options: [
                    { value: "notch", icon: "top_panel_open", label: "Notch" },
                    { value: "plain", icon: "toast", label: "Plain" },
                    { value: "dock", icon: "dock_to_bottom", label: "Dock" }
                ]
                value: Desktop.style
                onPicked: v => Desktop.island.style = v
            }
        }
        SetRow {
            label: "Island color"
            IconChoice {
                options: [
                    { value: "ink", icon: "fiber_manual_record", label: "Always dark" },
                    { value: "inverse", icon: "contrast", label: "Opposite of the mode" }
                ]
                value: Desktop.island.color === "inverse" ? "inverse" : "ink"
                onPicked: v => Desktop.island.color = v
            }
        }
        SetRow {
            label: "Lock screen"
            Select {
                width: 240
                options: [
                    { value: "headline", label: "Headline" },
                    { value: "island", label: "Island", enabled: false },
                    { value: "contents", label: "Contents page", enabled: false }
                ]
                value: Config.lock.style
                onPicked: v => Config.lock.style = v
            }
        }

        // ── Island ──
        SetSection { text: "Island" }
        SetRow {
            label: "Follow the mouse"
            hint: "The island moves to the monitor the mouse is on."
            Switch {
                checked: Config.island.follow
                onToggled: on => Config.island.follow = on
            }
        }
        SetRow {
            visible: !Config.island.follow
            label: "Monitor"
            Select {
                width: 240
                options: Quickshell.screens.map(s => ({ value: s.name, label: s.name + (s.model ? " · " + s.model : "") }))
                value: Config.island.monitor || (Quickshell.screens[0]?.name ?? "")
                onPicked: v => Config.island.monitor = v
            }
        }

        // ── Dock (its own bar only with the Notch and Plain styles) ──
        SetSection {
            visible: Desktop.style !== "dock"
            text: "Dock"
        }
        SetRow {
            visible: Desktop.style !== "dock"
            label: "Show the dock"
            Switch {
                checked: Desktop.dock.enabled
                onToggled: on => Desktop.dock.enabled = on
            }
        }
        SetRow {
            visible: Desktop.style !== "dock" && Desktop.dock.enabled
            label: "Hide until the mouse comes"
            Switch {
                checked: Desktop.dock.autoHide
                onToggled: on => Desktop.dock.autoHide = on
            }
        }

        // ── Keyboard ──
        SetSection { text: "Keyboard" }
        SetRow {
            label: "Layouts"
            hint: "Super+Space switches between them."
            Row {
                spacing: 8
                Repeater {
                    model: root.layouts
                    LayoutChip {
                        required property string modelData
                        code: modelData
                        removable: root.layouts.length > 1
                        onRemove: root.setLayouts(root.layouts.filter(l => l !== modelData))
                    }
                }
                Select {
                    width: 200
                    placeholder: "Add a layout"
                    options: root.allLayouts.filter(l => !root.layouts.includes(l.value))
                    value: ""
                    onPicked: v => root.setLayouts(root.layouts.concat([v]))
                }
            }
        }
    }

    // ── Keyboard layouts ──
    readonly property var layouts: String(HyprConfig.get(["input", "kb_layout"], "us")).split(",").map(s => s.trim()).filter(s => s)
    function setLayouts(list) {
        if (list.length)
            HyprConfig.set(["input", "kb_layout"], list.join(","));
    }

    // Every layout xkb knows, from its rules list ("  us   English (US)")
    property var allLayouts: []
    FileView {
        path: "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const out = [];
            let inLayouts = false;
            for (const line of text().split("\n")) {
                if (line.startsWith("!")) {
                    inLayouts = line.trim() === "! layout";
                    continue;
                }
                const m = inLayouts ? /^\s+(\S+)\s+(.+)$/.exec(line) : null;
                if (m)
                    out.push({ value: m[1], label: m[2] });
            }
            out.sort((a, b) => a.label.localeCompare(b.label));
            root.allLayouts = out;
        }
    }
    function layoutName(code) {
        const l = allLayouts.find(x => x.value === code);
        return l ? l.label : code;
    }

    // A layout: its code, its name on hover, a remove button
    component LayoutChip: Rectangle {
        id: chip
        property string code
        property bool removable: true
        signal remove

        width: chipRow.implicitWidth + 24
        height: 38
        radius: 12
        color: chipMouse.containsMouse ? root.c.raised : "transparent"
        border.width: 1
        border.color: root.c.line

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: chipMouse.containsMouse ? root.layoutName(chip.code) : chip.code.toUpperCase()
                face: Theme.font.medium
                color: root.c.fg
            }
            Icon {
                visible: chip.removable
                anchors.verticalCenter: parent.verticalCenter
                name: "close"
                size: 16
                color: removeMouse.containsMouse ? root.c.fg : root.c.mute
                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chip.remove()
                }
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
