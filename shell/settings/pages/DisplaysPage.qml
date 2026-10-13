import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

// Port of the ii display page: edits every monitor, writes hypr/generated/monitors.lua
// and reloads. After applying, the old file comes back in 15 s unless kept.
Page {
    id: page
    title: "Displays"
    subtitle: "Resolution, refresh rate, position, scale and rotation. Saved to hypr/generated/monitors.lua (this machine only)."

    property var monitors: []          // hyprctl monitors all -j
    property var drafts: ({})          // name -> { enabled, mode, x, y, scale, transform }
    property string selected: ""
    property string previous: ""       // monitors.lua before the last apply
    property int countdown: 0

    readonly property var mon: monitors.find(m => m.name === selected) ?? null
    readonly property var draft: drafts[selected] ?? null

    function load(list) {
        monitors = list;
        const d = {};
        for (const m of list) {
            d[m.name] = {
                enabled: !m.disabled,
                mode: m.width > 0 ? `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}` : (m.availableModes?.[0] ?? "preferred").replace("Hz", ""),
                x: m.x,
                y: m.y,
                scale: m.scale > 0 ? m.scale : 1,
                transform: m.transform ?? 0
            };
        }
        drafts = d;
        if (!list.some(m => m.name === selected))
            selected = list.find(m => m.focused)?.name ?? list[0]?.name ?? "";
    }
    function edit(key, value) {
        const d = Object.assign({}, drafts);
        d[selected] = Object.assign({}, d[selected], { [key]: value });
        drafts = d;
    }
    // Modes as "WxH@R", highest resolution then refresh first, duplicates dropped
    function modesOf(m) {
        const list = [...new Set((m?.availableModes ?? []).map(s => s.replace("Hz", "")))];
        const parse = s => s.split(/[x@]/).map(Number);
        return list.sort((a, b) => {
            const [aw, ah, ar] = parse(a), [bw, bh, br] = parse(b);
            return bw * bh - aw * ah || br - ar;
        });
    }
    function lua() {
        const lines = ["-- Written by SomeShell Settings (Displays page)"];
        for (const m of monitors) {
            const d = drafts[m.name];
            if (!d.enabled) {
                lines.push(`hl.monitor({ output = "${m.name}", disabled = true })`);
                continue;
            }
            const [res, rate] = d.mode.split("@");
            const mode = rate === undefined ? "preferred" : `${res}@${Math.round(Number(rate) * 100) / 100}Hz`;
            lines.push(`hl.monitor({ output = "${m.name}", mode = "${mode}", position = "${d.x}x${d.y}", scale = ${d.scale}, transform = ${d.transform} })`);
        }
        return lines.join("\n") + "\n";
    }
    function apply() {
        previous = file.text();
        file.setText(lua());
        HyprSettings.reload();
        countdown = 15;
        revert.restart();
    }
    function keep() {
        revert.stop();
        countdown = 0;
    }
    function undo() {
        revert.stop();
        countdown = 0;
        file.setText(previous);
        HyprSettings.reload();
    }

    Component.onCompleted: fetch.running = true
    Connections {
        target: HyprSettings
        function onReloaded() {
            fetch.running = true;
        }
    }

    Timer {
        id: revert
        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown--;
            if (page.countdown <= 0)
                page.undo();
        }
    }

    FileView {
        id: file
        path: Paths.monitors
        blockLoading: true
        printErrors: false
    }

    Process {
        id: fetch
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.load(JSON.parse(text));
                } catch (e) {
                    console.warn("Displays: bad hyprctl output", e);
                }
            }
        }
    }

    // Keep-or-revert banner
    Rectangle {
        visible: page.countdown > 0
        width: parent.width
        height: 64
        radius: Theme.radius.large
        color: Theme.primaryContainer
        SText {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            text: `Keep these display settings? Reverting in ${page.countdown} s`
            color: Theme.fgPrimaryContainer
            font.weight: Theme.font.weightTitle
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            SButton {
                kind: "text"
                text: "Revert"
                onClicked: page.undo()
            }
            SButton {
                kind: "filled"
                text: "Keep"
                onClicked: page.keep()
            }
        }
    }

    // Arrangement, to scale; click a screen to select it
    Rectangle {
        id: layout
        width: parent.width
        height: 200
        radius: Theme.radius.large
        color: Theme.surfaceLow

        readonly property var boxes: page.monitors.map(m => {
            const d = page.drafts[m.name];
            const [w, h] = (d?.mode ?? "1920x1080").split("@")[0].split("x").map(Number);
            const rotated = (d?.transform ?? 0) % 2 === 1;
            return { name: m.name, x: d?.x ?? 0, y: d?.y ?? 0, w: (rotated ? h : w) / (d?.scale ?? 1), h: (rotated ? w : h) / (d?.scale ?? 1), on: d?.enabled ?? true };
        })
        readonly property real minX: Math.min(...boxes.map(b => b.x), 0)
        readonly property real minY: Math.min(...boxes.map(b => b.y), 0)
        readonly property real spanW: Math.max(...boxes.map(b => b.x + b.w), 1) - minX
        readonly property real spanH: Math.max(...boxes.map(b => b.y + b.h), 1) - minY
        readonly property real k: Math.min((width - 40) / spanW, (height - 40) / spanH)

        Repeater {
            model: layout.boxes
            PressButton {
                id: box
                required property var modelData
                x: (layout.width - layout.spanW * layout.k) / 2 + (modelData.x - layout.minX) * layout.k
                y: (layout.height - layout.spanH * layout.k) / 2 + (modelData.y - layout.minY) * layout.k
                width: modelData.w * layout.k
                height: modelData.h * layout.k
                radius: Theme.radius.small
                color: page.selected === modelData.name ? Theme.primaryContainer : Theme.surfaceHigh
                hoverColor: Theme.surfaceHighest
                opacity: modelData.on ? 1 : 0.5
                onClicked: page.selected = modelData.name
                SText {
                    anchors.centerIn: parent
                    text: box.modelData.name
                    font.weight: Theme.font.weightTitle
                }
            }
        }
    }

    Section {
        visible: page.mon !== null && page.draft !== null
        title: page.mon ? page.mon.name + " · " + (page.mon.description || page.mon.model || "") : ""
        SettingRow {
            icon: "monitor"
            title: "Enabled"
            Switch {
                checked: page.draft?.enabled ?? false
                onToggled: on => page.edit("enabled", on)
            }
        }
        SettingRow {
            enabled: page.draft?.enabled ?? false
            icon: "aspect_ratio"
            title: "Scale"
            Choice {
                model: [1, 1.25, 1.5, 1.75, 2].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                value: page.draft?.scale
                onPicked: v => page.edit("scale", v)
            }
        }
        SettingRow {
            enabled: page.draft?.enabled ?? false
            icon: "screen_rotation"
            title: "Rotation"
            Choice {
                model: [0, 1, 2, 3].map(v => ({ value: v, label: v * 90 + "°" }))
                value: page.draft?.transform
                onPicked: v => page.edit("transform", v)
            }
        }
        SettingRow {
            enabled: page.draft?.enabled ?? false
            icon: "open_with"
            title: "Position"
            subtitle: "Top-left corner in the layout, in logical pixels"
            Row {
                spacing: 8
                Field {
                    implicitWidth: 90
                    mono: true
                    text: String(page.draft?.x ?? 0)
                    onCommitted: t => {
                        if (/^-?\d+$/.test(t.trim()))
                            page.edit("x", Number(t));
                    }
                }
                Field {
                    implicitWidth: 90
                    mono: true
                    text: String(page.draft?.y ?? 0)
                    onCommitted: t => {
                        if (/^-?\d+$/.test(t.trim()))
                            page.edit("y", Number(t));
                    }
                }
            }
        }
        SettingRow {
            enabled: page.draft?.enabled ?? false
            icon: "high_quality"
            title: "Mode"
            subtitle: (page.draft?.mode ?? "").replace("@", " @ ") + " Hz"
        }
        Flow {
            enabled: page.draft?.enabled ?? false
            opacity: enabled ? 1 : 0.45
            x: 16
            width: parent.width - 32
            spacing: 6
            bottomPadding: 12
            Repeater {
                model: page.modesOf(page.mon)
                SButton {
                    required property string modelData
                    readonly property bool on: Math.abs(Number(modelData.split("@")[1]) - Number((page.draft?.mode ?? "@0").split("@")[1])) < 0.05 && modelData.split("@")[0] === (page.draft?.mode ?? "").split("@")[0]
                    implicitHeight: 30
                    kind: on ? "filled" : "tonal"
                    readonly property real rate: Number(modelData.split("@")[1])
                    // 59.94 and 60 are different modes: keep decimals unless whole
                    text: modelData.split("@")[0] + " · " + (Math.abs(rate - Math.round(rate)) < 0.01 ? Math.round(rate) : rate.toFixed(2)) + " Hz"
                    onClicked: page.edit("mode", modelData)
                }
            }
        }
    }

    Row {
        spacing: 8
        SButton {
            kind: "filled"
            icon: "check"
            text: "Apply"
            enabled: page.countdown === 0 && page.monitors.length > 0
            onClicked: page.apply()
        }
        SButton {
            icon: "refresh"
            text: "Reload from Hyprland"
            onClicked: fetch.running = true
        }
    }
}
