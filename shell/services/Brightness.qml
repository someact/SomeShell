pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen brightness, 0-100. A laptop panel through brightnessctl (backlight),
// desktop monitors through DDC (ddcutil). DDC is slow, so changes are queued
// and only the last one is sent. Monitors without either are left out.
// `set()` changes every screen (the tile), `setScreen()` one monitor (the
// Displays page in Control); `forMonitor()` finds a Hyprland monitor's screen.
Singleton {
    id: root

    // { kind: "backlight"|"ddc", bus, name, value }
    property var screens: []
    readonly property bool available: screens.length > 0
    // The screens of monitors that are on (the backlight always counts):
    // what the tile shows and sets
    readonly property var shown: {
        const on = Hyprland.monitors.values.map(m => m.name);
        const list = screens.filter(s => s.kind === "backlight" || on.includes(s.name));
        return list.length ? list : screens;
    }
    readonly property int value: shown.length ? shown[0].value : 0
    readonly property string label: shown.length > 1 ? shown.length + " screens" : shown.length ? shown[0].name : "Not available"

    // Set every screen of a monitor that is on (the tile's slider)
    function set(v) {
        v = Math.round(Math.max(1, Math.min(100, v)));
        const names = shown.map(s => s.name);
        screens = screens.map(s => names.includes(s.name) ? Object.assign({}, s, { value: v }) : s);
        const p = Object.assign({}, pending);
        for (const n of names)
            p[n] = v;
        pending = p;
        if (!writer.running)
            flush();
    }
    // Set one screen (its `name`)
    function setScreen(name, v) {
        v = Math.round(Math.max(1, Math.min(100, v)));
        if (!screens.some(s => s.name === name))
            return;
        screens = screens.map(s => s.name === name ? Object.assign({}, s, { value: v }) : s);
        const p = Object.assign({}, pending);
        p[name] = v;
        pending = p;
        if (!writer.running)
            flush();
    }
    // The screen of a Hyprland monitor: DDC by its connector, the backlight
    // for a built-in panel (eDP, DSI, LVDS)
    function forMonitor(monitor) {
        return screens.find(s => s.kind === "ddc" && s.name === monitor)
            ?? (/^(eDP|DSI|LVDS)/.test(monitor) ? screens.find(s => s.kind === "backlight") : undefined)
            ?? null;
    }
    function step(delta) {
        set(value + delta);
    }

    // Read the backlight again (another tool may have changed it); the
    // Control page asks when it opens. DDC is too slow to read each time.
    function refresh() {
        if (screens.some(s => s.kind === "backlight") && !reader.running && !writer.running && Object.keys(pending).length === 0)
            reader.running = true;
    }
    Process {
        id: reader
        command: ["sh", "-c", "brightnessctl -m -c backlight | head -1 | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text);
                if (!isNaN(v) && Object.keys(root.pending).length === 0)
                    root.screens = root.screens.map(s => s.kind === "backlight" ? Object.assign({}, s, { value: v }) : s);
            }
        }
    }

    // Values waiting to be sent, by screen name
    property var pending: ({})
    function flush() {
        const want = pending;
        const names = Object.keys(want);
        if (names.length === 0)
            return;
        pending = {};
        const cmds = screens.filter(s => names.includes(s.name)).map(s => s.kind === "backlight"
            ? "brightnessctl -q s " + want[s.name] + "%"
            : "ddcutil --noverify --bus " + s.bus + " setvcp 10 " + want[s.name]);
        writer.command = ["sh", "-c", cmds.join(" & ") + "; wait"];
        writer.running = true;
    }
    Process {
        id: writer
        onExited: root.flush()
    }

    // Look for screens again: a monitor came, or one that is on has no
    // control (DDC can fail while monitors change). Slow (~15 s), in the background.
    function detect() {
        if (!finder.running)
            finder.running = true;
    }
    Timer {
        id: redetect
        interval: 3000
        onTriggered: root.detect()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2"].includes(event.name))
                redetect.restart();
        }
    }

    // Find screens at start
    Process {
        id: finder
        running: true
        command: ["sh", "-c",
            "if ls /sys/class/backlight/* >/dev/null 2>&1; then echo \"backlight|Display|$(brightnessctl -m | cut -d, -f4 | tr -d %)\"; fi; "
            + "command -v ddcutil >/dev/null || exit 0; "
            + "ddcutil detect --brief 2>/dev/null | awk '/I2C bus:/{split($3,a,\"-\"); bus=a[2]} /DRM connector:/{sub(/^card[0-9]+-/,\"\",$3); con=$3} /Monitor:/{print bus\"|\"con}' | while IFS='|' read -r bus con; do "
            + "v=$(ddcutil --bus $bus getvcp 10 --brief 2>/dev/null | awk '{print $4}'); [ -n \"$v\" ] && echo \"ddc|$con|$v|$bus\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.screens = text.split("\n").filter(Boolean).map(l => {
                    const f = l.split("|");
                    return { kind: f[0], name: f[1], value: parseInt(f[2]) || 50, bus: f[3] ?? "" };
                });
            }
        }
    }
}
