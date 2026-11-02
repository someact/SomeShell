pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness, 0-100. A laptop panel through brightnessctl (backlight),
// desktop monitors through DDC (ddcutil). DDC is slow, so changes are queued
// and only the last one is sent. Monitors without either are left out.
Singleton {
    id: root

    // { kind: "backlight"|"ddc", bus, name, value }
    property var screens: []
    readonly property bool available: screens.length > 0
    readonly property int value: screens.length ? screens[0].value : 0
    readonly property string label: screens.length > 1 ? screens.length + " screens" : screens.length ? screens[0].name : "Not available"

    // Set every screen (the tile's slider)
    function set(v) {
        v = Math.round(Math.max(1, Math.min(100, v)));
        screens = screens.map(s => Object.assign({}, s, { value: v }));
        pending = v;
        if (!writer.running)
            flush();
    }
    function step(delta) {
        set(value + delta);
    }

    // Read the backlight again (another tool may have changed it); the
    // Control page asks when it opens. DDC is too slow to read each time.
    function refresh() {
        if (screens.some(s => s.kind === "backlight") && !reader.running && !writer.running && pending < 0)
            reader.running = true;
    }
    Process {
        id: reader
        command: ["sh", "-c", "brightnessctl -m -c backlight | head -1 | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text);
                if (!isNaN(v) && root.pending < 0)
                    root.screens = root.screens.map(s => s.kind === "backlight" ? Object.assign({}, s, { value: v }) : s);
            }
        }
    }

    property int pending: -1
    function flush() {
        if (pending < 0)
            return;
        const v = pending;
        pending = -1;
        const cmds = screens.map(s => s.kind === "backlight"
            ? "brightnessctl -q s " + v + "%"
            : "ddcutil --noverify --bus " + s.bus + " setvcp 10 " + v);
        writer.command = ["sh", "-c", cmds.join(" & ") + "; wait"];
        writer.running = true;
    }
    Process {
        id: writer
        onExited: root.flush()
    }

    // Find screens once at start
    Process {
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
