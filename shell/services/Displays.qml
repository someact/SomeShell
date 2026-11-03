pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// Monitors for the settings window's Displays page (SomeShell.md section 5).
//   live    what Hyprland has now (`hyprctl monitors all -j`)
//   draft   what the page shows and changes; `apply()` sends it to Hyprland
//           and counts down 15 s: `keep()` saves it, else it goes back
// Kept layouts are saved per set of monitors (make, model and serial) in
// ~/.config/someshell/displays.json and applied again when that set
// connects; the one in use is written to hypr/generated/monitors.lua for the
// next start. Every monitor always gets its own rule: a rule for one monitor
// moves the others while they are on "auto".
Singleton {
    id: root

    property var live: []
    property var draft: []
    property var profiles: ({})
    // The set of monitors connected now, and whether it has a saved layout
    readonly property string setKey: live.map(m => m.desc).sort().join(" | ")
    readonly property bool saved: setKey in profiles

    property bool waiting: false
    property int left: 0
    readonly property int timeout: 15
    property var before: []
    property bool identifying: false

    // How many settings differ from what Hyprland has
    readonly property int changes: {
        const keys = ["on", "mode", "scale", "transform", "x", "y", "mirror", "vrr", "bits", "main"];
        let n = 0;
        for (const d of draft) {
            const l = live.find(m => m.desc === d.desc);
            if (!l)
                continue;
            for (const k of keys)
                if (String(d[k]) !== String(l[k]))
                    n++;
        }
        return n;
    }

    // ── Reading ──
    function refresh() { reader.running = true; }

    // A mode as Hyprland writes it in a rule: 1920x1080@100.00
    function modeOf(m) {
        const want = m.refreshRate;
        let best = "", diff = 1e9;
        for (const s of m.availableModes ?? []) {
            const mm = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s);
            if (!mm || +mm[1] !== m.width || +mm[2] !== m.height)
                continue;
            const d = Math.abs(+mm[3] - want);
            if (d < diff) {
                diff = d;
                best = mm[1] + "x" + mm[2] + "@" + mm[3];
            }
        }
        return best || (m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2));
    }

    function fromHyprland(list) {
        const kept = profiles[list.map(m => m.description).sort().join(" | ")] ?? [];
        return list.map(m => {
            const k = kept.find(p => p.desc === m.description) ?? {};
            return {
                name: m.name,
                desc: m.description,
                make: m.make,
                model: m.model,
                mm: [m.physicalWidth, m.physicalHeight],
                modes: (m.availableModes ?? []).map(s => s.replace(/Hz$/, "")),
                mode: m.disabled && k.mode ? k.mode : modeOf(m),
                scale: m.disabled && k.scale ? k.scale : Math.round(m.scale * 1e6) / 1e6,
                transform: m.disabled && k.transform !== undefined ? k.transform : m.transform,
                x: m.disabled && k.x !== undefined ? k.x : m.x,
                y: m.disabled && k.y !== undefined ? k.y : m.y,
                on: !m.disabled,
                mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "",
                // Hyprland does not report the rule's VRR or main monitor:
                // what was kept, else the defaults (VRR for games only)
                vrr: k.vrr ?? 2,
                bits: /2101010/.test(m.currentFormat ?? "") ? 10 : 8,
                main: k.main ?? false
            };
        });
    }

    // ── Changing ──
    function set(desc, key, value) {
        if (waiting)
            return;
        draft = draft.map(m => {
            if (m.desc !== desc) {
                // Only one main monitor
                return key === "main" && value ? Object.assign({}, m, { main: false }) : m;
            }
            const n = Object.assign({}, m);
            n[key] = value;
            if (key === "res") {
                // A new resolution: its refresh rate nearest the old one, scale 1 if the old one does not fit
                const hz = +m.mode.split("@")[1];
                const rates = m.modes.filter(s => s.startsWith(value + "@")).map(s => +s.split("@")[1]);
                rates.sort((a, b) => Math.abs(a - hz) - Math.abs(b - hz));
                n.mode = value + "@" + (rates.length ? rates[0].toFixed(2) : "60.00");
                delete n.res;
                if (!root.scales(n).some(s => s.value === n.scale))
                    n.scale = 1;
            }
            return n;
        });
    }
    // Moved monitors: dropped on top of another, it goes to the nearest free
    // place touching one (never overlapping); the layout starts at 0,0
    function place(desc, x, y) {
        if (waiting)
            return;
        const me = draft.find(m => m.desc === desc);
        if (!me)
            return;
        const L = logical(me);
        const others = draft.filter(m => m.desc !== desc && m.on && !m.mirror);
        const overlaps = (px, py) => others.some(o => {
            const O = logical(o);
            return px < o.x + O.w && px + L.w > o.x && py < o.y + O.h && py + L.h > o.y;
        });
        x = Math.round(x);
        y = Math.round(y);
        if (overlaps(x, y)) {
            let best = null, bestD = 1e12;
            for (const o of others) {
                const O = logical(o);
                const cy = Math.max(o.y - L.h, Math.min(o.y + O.h, y));
                const cx = Math.max(o.x - L.w, Math.min(o.x + O.w, x));
                for (const [px, py] of [[o.x - L.w, cy], [o.x + O.w, cy], [cx, o.y - L.h], [cx, o.y + O.h]]) {
                    const d = Math.hypot(px - x, py - y);
                    if (d < bestD && !overlaps(px, py)) {
                        bestD = d;
                        best = [px, py];
                    }
                }
            }
            if (best)
                [x, y] = best;
        }
        let list = draft.map(m => m.desc === desc ? Object.assign({}, m, { x: x, y: y }) : m);
        const minX = Math.min(...list.map(m => m.x)), minY = Math.min(...list.map(m => m.y));
        draft = list.map(m => Object.assign({}, m, { x: m.x - minX, y: m.y - minY }));
    }
    function undo() {
        if (!waiting)
            draft = fromHyprland(rawLive);
    }

    // The size a monitor takes in the layout (rotation and scale applied)
    function logical(m) {
        const [w, h] = m.mode.split("@")[0].split("x").map(Number);
        const turned = m.transform % 2 === 1;
        return { w: Math.round((turned ? h : w) / m.scale), h: Math.round((turned ? w : h) / m.scale) };
    }
    // Scales Hyprland takes for this resolution (the logical size must be whole pixels)
    function scales(m) {
        const [w, h] = m.mode.split("@")[0].split("x").map(Number);
        const out = [];
        for (const s of [1, 1.25, 1.333333, 1.5, 1.6, 1.666667, 1.75, 2, 2.4, 2.5, 3]) {
            const lw = w / s, lh = h / s;
            if (Math.abs(lw - Math.round(lw)) < 0.01 && Math.abs(lh - Math.round(lh)) < 0.01)
                out.push({ value: s, label: Math.round(s * 100) + "%  ·  " + Math.round(lw) + " × " + Math.round(lh) });
        }
        return out;
    }

    // ── Applying ──
    function luaRule(m) {
        const out = "desc:" + m.desc;
        if (!m.on)
            return "hl.monitor({ output = " + JSON.stringify(out) + ", disabled = true })";
        const parts = [
            "output = " + JSON.stringify(out),
            "mode = " + JSON.stringify(m.mode),
            "position = " + JSON.stringify(m.x + "x" + m.y),
            "scale = " + m.scale,
            "transform = " + m.transform,
            "vrr = " + m.vrr
        ];
        if (m.bits === 10)
            parts.push("bitdepth = 10");
        if (m.mirror)
            parts.push("mirror = " + JSON.stringify(m.mirror));
        return "hl.monitor({ " + parts.join(", ") + " })";
    }
    function lua(list) {
        const lines = list.map(luaRule);
        const main = list.find(m => m.main && m.on);
        if (main)
            lines.push("hl.config({ cursor = { default_monitor = " + JSON.stringify(main.name) + " } })");
        return lines.join("\n");
    }
    function send(list) {
        Quickshell.execDetached(["hyprctl", "eval", lua(list)]);
    }

    function apply() {
        if (waiting || changes === 0)
            return;
        before = fromHyprland(rawLive);
        send(draft);
        left = timeout;
        waiting = true;
        countdown.restart();
    }
    function keep() {
        if (!waiting)
            return;
        countdown.stop();
        waiting = false;
        const p = Object.assign({}, profiles);
        p[setKey] = draft.map(m => ({ desc: m.desc, mode: m.mode, scale: m.scale, transform: m.transform, x: m.x, y: m.y, on: m.on, mirror: m.mirror, vrr: m.vrr, bits: m.bits, main: m.main }));
        profiles = p;
        store.setText(JSON.stringify({ profiles: p }, null, 2) + "\n");
        writeGenerated(draft);
        settle.restart();
    }
    function revert() {
        if (!waiting)
            return;
        countdown.stop();
        waiting = false;
        send(before);
        settle.restart();
    }

    function writeGenerated(list) {
        generated.setText("-- Written by SomeShell's settings (Displays) for:\n--   " + setKey
            + "\n-- Changes here are overwritten; change them in the settings window.\n\n" + lua(list) + "\n");
    }

    function identify() {
        identifying = true;
        identifyTimer.restart();
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.left--;
            if (root.left <= 0)
                root.revert();
        }
    }
    Timer {
        id: identifyTimer
        interval: 2200
        onTriggered: root.identifying = false
    }
    // Hyprland takes a moment to set a mode: read it again after
    Timer {
        id: settle
        interval: 700
        onTriggered: root.refresh()
    }

    // ── Hyprland ──
    property var rawLive: []
    property string lastKey: ""
    Process {
        id: reader
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.rawLive = list;
                root.live = root.fromHyprland(list);
                // A new set of monitors with a kept layout: use it
                const key = root.setKey;
                if (key !== root.lastKey) {
                    root.lastKey = key;
                    const kept = root.profiles[key];
                    if (kept && root.profilesRead) {
                        const want = root.live.map(m => Object.assign({}, m, kept.find(p => p.desc === m.desc) ?? {}));
                        if (JSON.stringify(want) !== JSON.stringify(root.live)) {
                            root.send(want);
                            root.writeGenerated(want);
                            settle.restart();
                        }
                    }
                }
                if (!root.waiting)
                    root.draft = root.live;
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                settle.restart();
        }
    }

    property bool profilesRead: false
    FileView {
        id: store
        path: Paths.config + "/displays.json"
        onLoaded: {
            try {
                root.profiles = JSON.parse(text()).profiles ?? {};
            } catch (e) {}
            root.profilesRead = true;
            root.lastKey = "";
            root.refresh();
        }
        onLoadFailed: {
            root.profilesRead = true;
            root.refresh();
        }
    }
    FileView {
        id: generated
        path: Paths.hypr + "/generated/monitors.lua"
    }
}
