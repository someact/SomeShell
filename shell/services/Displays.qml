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
// `quick()` is for Control's Displays page: one monitor on or off, extend,
// mirror; built from what Hyprland has now and applied with the same
// countdown (Keep or it goes back).
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
    function refresh() {
        devReader.running = true;
        reader.running = true;
    }

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

    // A switched-off monitor Hyprland reports as 0x0: its biggest mode, fastest rate
    function bestMode(m) {
        let best = null;
        for (const s of m.availableModes ?? []) {
            const mm = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s);
            if (!mm)
                continue;
            const c = [+mm[1] * +mm[2], +mm[3], mm[1] + "x" + mm[2] + "@" + mm[3]];
            if (!best || c[0] > best[0] || (c[0] === best[0] && c[1] > best[1]))
                best = c;
        }
        return best ? best[2] : "preferred";
    }

    function fromHyprland(list) {
        const kept = profiles[list.map(m => m.description || m.name).sort().join(" | ")] ?? [];
        return list.map(m => {
            const k = kept.find(p => p.desc === (m.description || m.name)) ?? {};
            return {
                name: m.name,
                // A built-in panel can have no description (the tablet's DSI
                // panel): then the connector name stands in, as id and output
                desc: m.description || m.name,
                out: m.description ? "desc:" + m.description : m.name,
                make: m.make,
                model: m.model,
                mm: [m.physicalWidth, m.physicalHeight],
                modes: (m.availableModes ?? []).map(s => s.replace(/Hz$/, "")),
                mode: m.disabled ? (k.mode ?? bestMode(m)) : modeOf(m),
                scale: m.disabled && k.scale ? k.scale : Math.round(m.scale * 1e6) / 1e6,
                transform: m.disabled && k.transform !== undefined ? k.transform : m.transform,
                x: m.disabled && k.x !== undefined ? k.x : m.x,
                y: m.disabled && k.y !== undefined ? k.y : m.y,
                on: !m.disabled,
                // Hyprland reports the mirrored monitor's id; rules take its name
                mirror: !m.mirrorOf || m.mirrorOf === "none" ? ""
                    : (list.find(o => String(o.id) === String(m.mirrorOf))?.name ?? String(m.mirrorOf)),
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

    // How the monitors are used now: "single" (one connected), "mirror",
    // "extend" (all on) or "some" (some off)
    readonly property string arrangement: live.length < 2 ? "single"
        : live.some(m => m.on && m.mirror) ? "mirror"
        : live.every(m => m.on) ? "extend" : "some"

    // ── Quick changes (Control) ──
    //   quick("toggle", desc)  that monitor on or off (never the last one on)
    //   quick("extend")        every monitor on, side by side
    //   quick("mirror", name)  every monitor shows `name` (a connector name)
    function quick(kind, arg) {
        if (waiting || rawLive.length === 0)
            return false;
        const now = fromHyprland(rawLive);
        let list = now;
        if (kind === "toggle") {
            const me = now.find(m => m.desc === arg);
            if (!me || (me.on && now.filter(m => m.on).length <= 1))
                return false;
            list = now.map(m => m.desc === arg ? Object.assign({}, m, { on: !m.on, mirror: "" })
                // Mirrors of a monitor that goes off show their own picture
                : m.mirror === me.name && me.on ? Object.assign({}, m, { mirror: "" }) : m);
        } else if (kind === "extend") {
            list = now.map(m => Object.assign({}, m, { on: true, mirror: "" }));
        } else if (kind === "mirror") {
            if (!now.some(m => m.name === arg))
                return false;
            list = now.map(m => Object.assign({}, m, { on: true, mirror: m.name === arg ? "" : arg }));
        } else {
            return false;
        }
        draft = list;
        // A monitor that comes back (was off or a mirror) must not land on another
        for (const m of list) {
            const was = now.find(n => n.desc === m.desc);
            if (m.on && !m.mirror && (!was.on || was.mirror))
                place(m.desc, m.x, m.y);
        }
        apply();
        return true;
    }

    // ── Applying ──
    function luaRule(m) {
        const out = m.out ?? ("desc:" + m.desc);
        if (!m.on)
            return "hl.monitor({ output = " + JSON.stringify(out) + ", disabled = true })";
        // `disabled = false` is needed: without it a monitor that was off stays off
        const parts = [
            "output = " + JSON.stringify(out),
            "disabled = false",
            "mode = " + JSON.stringify(m.mode),
            "position = " + JSON.stringify(m.x + "x" + m.y),
            "scale = " + m.scale,
            "transform = " + m.transform,
            "vrr = " + m.vrr
        ];
        if (m.bits === 10)
            parts.push("bitdepth = 10");
        // Always said: a rule without it keeps an old mirror
        parts.push("mirror = " + JSON.stringify(m.mirror || ""));
        return "hl.monitor({ " + parts.join(", ") + " })";
    }
    function lua(list) {
        const lines = list.map(luaRule);
        const main = list.find(m => m.main && m.on);
        if (main)
            lines.push("hl.config({ cursor = { default_monitor = " + JSON.stringify(main.name) + " } })");
        const touch = touchLua(list);
        if (touch)
            lines.push(touch);
        return lines.join("\n");
    }
    // A touch screen and a pen belong to the built-in panel: they follow its
    // connector and rotation (else a turned panel takes taps at the wrong
    // place). Only said when such devices exist.
    function touchLua(list) {
        const panel = list.find(m => m.on && /^(eDP|DSI|LVDS)-/.test(m.name));
        if (!panel || !(hasTouch || hasPen))
            return "";
        const map = "{ output = " + JSON.stringify(panel.name) + ", transform = " + panel.transform + " }";
        const parts = [];
        if (hasTouch)
            parts.push("touchdevice = " + map);
        if (hasPen)
            parts.push("tablet = " + map);
        return "hl.config({ input = { " + parts.join(", ") + " } })";
    }
    property bool hasTouch: false
    property bool hasPen: false
    property string touchSent: ""
    // Sent whenever the panel or its rotation changes, and once at start
    function sendTouch() {
        const t = touchLua(live);
        if (!t || t === touchSent)
            return;
        touchSent = t;
        Quickshell.execDetached(["hyprctl", "eval", t]);
        // A layout written before this existed gets the mapping too
        const g = generated.text();
        if (g && g.indexOf(t) < 0 && !waiting)
            writeGenerated(live);
    }
    // A change of ours makes Hyprland drop and add monitors for a moment
    // (undoing a mirror does): those are not a new set of monitors
    property real lastSend: 0
    function send(list) {
        lastSend = Date.now();
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
        // Saved for the monitors in the draft (one may be missing from
        // Hyprland's list for a moment while it changes)
        const key = draft.map(m => m.desc).sort().join(" | ");
        const p = Object.assign({}, profiles);
        p[key] = draft.map(m => ({ desc: m.desc, mode: m.mode, scale: m.scale, transform: m.transform, x: m.x, y: m.y, on: m.on, mirror: m.mirror, vrr: m.vrr, bits: m.bits, main: m.main }));
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
    Process {
        id: devReader
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.hasTouch = (d.touch ?? []).length > 0;
                    root.hasPen = (d.tablets ?? []).length > 0;
                } catch (e) {}
                root.sendTouch();
            }
        }
    }
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
                // A new set of monitors with a kept layout: use it. Only
                // after a real plug or unplug (or at start), never while a
                // change of ours settles
                const key = root.setKey;
                const plugged = root.hotplug;
                root.hotplug = false;
                if (key !== root.lastKey) {
                    root.lastKey = key;
                    const kept = root.profiles[key];
                    if (kept && root.profilesRead && plugged && !root.waiting) {
                        const want = root.live.map(m => Object.assign({}, m, kept.find(p => p.desc === m.desc) ?? {}));
                        if (JSON.stringify(want) !== JSON.stringify(root.live)) {
                            root.send(want);
                            root.writeGenerated(want);
                            settle.restart();
                        }
                    }
                }
                if (!root.waiting) {
                    root.draft = root.live;
                    root.sendTouch();
                }
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                return;
            if (event.name !== "configreloaded" && !root.waiting && Date.now() - root.lastSend > 8000)
                root.hotplug = true;
            settle.restart();
        }
    }

    property bool profilesRead: false
    // A monitor was plugged in or out (not by a change of ours)
    property bool hotplug: false
    FileView {
        id: store
        path: Paths.config + "/displays.json"
        onLoaded: {
            try {
                root.profiles = JSON.parse(text()).profiles ?? {};
            } catch (e) {}
            root.profilesRead = true;
            root.lastKey = "";
            root.hotplug = true;
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
        // Read after the first check: check again with the file in hand
        onLoaded: {
            root.touchSent = "";
            root.sendTouch();
        }
    }
}
