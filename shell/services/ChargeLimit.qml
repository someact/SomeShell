pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Charge limit: stop charging at `limit` percent, start again at `start`
// (Config.battery). How is found at runtime by lib/charge.sh:
//   kernel        the battery's own thresholds (set once, kept by the firmware
//                 or the kernel; set again at every start)
//   conservation  Lenovo conservation mode: on/off, the laptop picks the level
//   software      a charger whose input current can be set (the Pad 6): the
//                 shell holds it at 0 from `limit` down to `start`. Only while
//                 the shell runs; the hold gives the current back when the
//                 shell goes away.
//   none          nothing to set
Singleton {
    id: root

    property var info: ({ method: "" })
    readonly property string method: info.method ?? ""
    readonly property bool supported: method === "kernel" || method === "conservation" || method === "software"
    // A start level can be set (kernel without a start file stops only)
    readonly property bool hasStart: method === "software" || (method === "kernel" && (info.start ?? -1) >= 0)

    readonly property int limit: Config.battery.limit
    readonly property int start: Math.min(Config.battery.start, limit - 5)
    readonly property bool on: limit < 100

    // The software limit is holding the charger off right now
    property bool holding: false
    // A write was refused (no udev rule, sudo asks for a password)
    property bool denied: false

    readonly property string status: !supported ? "Not supported"
        : !on ? "Off"
        : method === "conservation" ? "Conservation"
        : hasStart ? start + "–" + limit + "%" : "Stops at " + limit + "%"

    // `stop` 100 = off. `from` is where charging starts again.
    function set(stop, from) {
        stop = Math.max(50, Math.min(100, Math.round(stop)));
        Config.battery.limit = stop;
        if (from !== undefined)
            Config.battery.start = Math.max(0, Math.min(stop - 5, Math.round(from)));
        else if (Config.battery.start >= stop)
            Config.battery.start = stop - 5;
        denied = false;
        apply();
    }
    function setConservation(v) {
        set(v ? 80 : 100);
    }

    function apply() {
        if (!Config.loaded || method === "")
            return;
        if (method === "kernel") {
            const end = on ? limit : 100;
            const s = !hasStart ? -1 : on ? start : 0;
            if (end !== info.end || (hasStart && s !== info.start))
                run(["kernel", info.dir, String(s), String(end)]);
        } else if (method === "conservation") {
            if (on !== info.on)
                run(["write", info.file, on ? "1" : "0"]);
        } else if (method === "software") {
            judge();
        }
    }

    // Software limit: hold from `limit` down to `start` (Battery.percent, so
    // `battery simulate` tests it)
    readonly property int percent: Battery.percent
    onPercentChanged: judge()
    onOnChanged: judge()
    function judge() {
        if (method !== "software")
            return;
        const want = on && !denied && Battery.available
            && (percent >= limit || (hold.running && percent > start));
        if (want !== hold.running)
            hold.running = want;
    }

    Process {
        id: hold
        stdinEnabled: true
        command: [Quickshell.shellPath("lib/charge.sh"), "hold", root.info.file ?? "", String(root.info.max ?? 1500000)]
        stdout: SplitParser {
            onRead: line => { if (line === "held") root.holding = true; }
        }
        onRunningChanged: if (!running) root.holding = false
        onExited: code => {
            if (code !== 0) {
                root.denied = true;
                root.refused();
            }
        }
    }

    // One write; reads the state back after
    function run(args) {
        writer.command = [Quickshell.shellPath("lib/charge.sh")].concat(args);
        writer.running = true;
    }
    Process {
        id: writer
        onExited: code => {
            if (code !== 0) {
                root.denied = true;
                root.refused();
            }
            detect.running = true;
        }
    }
    function refused() {
        Ui.showAlert("Charge limit", "No permission to set it. Run: sudo scripts/charge-access.sh", "Battery", "battery_alert", { wide: true });
    }

    Process {
        id: detect
        running: true
        command: [Quickshell.shellPath("lib/charge.sh"), "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const first = root.method === "";
                    root.info = JSON.parse(text);
                    if (first)
                        root.apply();
                } catch (e) {
                    root.info = { method: "none" };
                }
            }
        }
    }
    Connections {
        target: Config
        function onLoadedChanged() { root.apply(); }
    }
    Connections {
        target: Battery
        function onAvailableChanged() { root.judge(); }
    }
}
