pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Keybind changes (~/.config/someshell/keybinds.json), applied by hypr/binds/user.lua:
//   overrides: { "<original combo>": { keys: "<new combo>" } | { disabled: true } }
//   custom:    [ { keys, command, description, enabled } ]
// `binds` is what Hyprland has bound right now (`hyprctl binds -j`), refreshed
// after every save so remaps and conflicts are always checked against reality.
Singleton {
    id: root

    property var data: ({ overrides: {}, custom: [] })
    property var binds: []      // { combo, norm, group, action, description, submap }
    property bool loaded: false

    readonly property var modBits: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    readonly property var modAliases: ({ SUPER: "SUPER", WIN: "SUPER", MOD4: "SUPER", LOGO: "SUPER", META: "SUPER", CTRL: "CTRL", CONTROL: "CTRL", ALT: "ALT", MOD1: "ALT", SHIFT: "SHIFT" })

    // Same rule as normalize_keys() in hypr/binds/user.lua: fixed modifier
    // order, lowercase key. Two combos are the same bind iff these match.
    function normalize(keys) {
        const parts = String(keys).split("+").map(p => p.trim());
        const key = (parts.pop() ?? "").toLowerCase();
        const have = new Set(parts.map(p => modAliases[p.toUpperCase()]).filter(m => m));
        return ["SUPER", "CTRL", "ALT", "SHIFT"].filter(m => have.has(m)).concat([key]).join(" + ");
    }
    // "SUPER + SHIFT + s" -> "Super + Shift + S" for display
    function pretty(keys) {
        const names = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" };
        return normalize(keys).split(" + ").map((p, i, a) => i < a.length - 1 ? names[p] : (p.length === 1 ? p.toUpperCase() : p.charAt(0).toUpperCase() + p.slice(1))).join(" + ");
    }
    function comboOf(b) {
        const mods = modBits.filter(m => b.modmask & m[0]).map(m => m[1]);
        return mods.concat([b.key !== "" ? b.key : "code:" + b.keycode]).join(" + ");
    }

    // Original combo for a currently bound one (follows an override back)
    function originOf(norm) {
        for (const [orig, o] of Object.entries(data.overrides ?? {})) {
            if (o.keys && normalize(o.keys) === norm)
                return normalize(orig);
        }
        return norm;
    }
    readonly property var disabled: Object.entries(data.overrides ?? {}).filter(([k, o]) => o.disabled).map(([k]) => normalize(k))

    // Binds (main submap) that already use `norm`, other than the bind being edited
    function conflicts(norm, except) {
        const same = binds.filter(b => b.submap === "" && b.norm === norm && b.norm !== except);
        // A combo's undescribed halves (fallbacks, release binds) only matter if nothing describes it
        const described = same.filter(b => b.description !== "");
        const hits = (described.length > 0 ? described : same).map(b => b.description || b.action);
        for (const c of data.custom ?? []) {
            if (c.enabled !== false && normalize(c.keys) === norm && normalize(c.keys) !== except)
                hits.push(c.description || c.command);
        }
        return [...new Set(hits)];
    }

    function remap(origNorm, newKeys) {
        const o = Object.assign({}, data.overrides);
        if (normalize(newKeys) === origNorm)
            delete o[origNorm];
        else
            o[origNorm] = { keys: newKeys };
        write({ overrides: o, custom: data.custom ?? [] });
    }
    function disable(origNorm) {
        const o = Object.assign({}, data.overrides);
        o[origNorm] = { disabled: true };
        write({ overrides: o, custom: data.custom ?? [] });
    }
    function reset(origNorm) {
        const o = Object.assign({}, data.overrides);
        delete o[origNorm];
        write({ overrides: o, custom: data.custom ?? [] });
    }
    function setCustom(index, entry) {
        const c = (data.custom ?? []).slice();
        if (index < 0)
            c.push(entry);
        else
            c[index] = entry;
        write({ overrides: data.overrides ?? {}, custom: c });
    }
    function removeCustom(index) {
        const c = (data.custom ?? []).slice();
        c.splice(index, 1);
        write({ overrides: data.overrides ?? {}, custom: c });
    }

    function write(next) {
        data = next;
        Quickshell.execDetached(["mkdir", "-p", Paths.configDir]);
        file.setText(JSON.stringify(next, null, 2) + "\n");
        HyprSettings.reload();
    }
    function refresh() {
        proc.running = true;
    }

    // While recording, the app parks Hyprland in a submap with no binds so
    // already-bound combos reach it (hypr/binds/user.lua defines it).
    function recordMode(on) {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.submap("${on ? "someshell-record" : "reset"}")`]);
    }

    // xkb keycode -> Hyprland key name (US names, so Shift and the Thai layout
    // don't change what is recorded). Anything else is bound as code:N.
    readonly property var keyNames: {
        const m = { 9: "Escape", 22: "BackSpace", 23: "Tab", 36: "Return", 65: "space", 20: "minus", 21: "equal", 34: "bracketleft", 35: "bracketright", 47: "semicolon", 48: "apostrophe", 49: "grave", 51: "backslash", 59: "comma", 60: "period", 61: "slash", 107: "Print", 110: "Home", 111: "Up", 112: "Prior", 113: "Left", 114: "Right", 115: "End", 116: "Down", 117: "Next", 118: "Insert", 119: "Delete", 127: "Pause", 95: "F11", 96: "F12" };
        "1234567890".split("").forEach((c, i) => m[10 + i] = c);
        "QWERTYUIOP".split("").forEach((c, i) => m[24 + i] = c);
        "ASDFGHJKL".split("").forEach((c, i) => m[38 + i] = c);
        "ZXCVBNM".split("").forEach((c, i) => m[52 + i] = c);
        for (let i = 0; i < 10; i++)
            m[67 + i] = "F" + (i + 1);
        return m;
    }
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

    // A Qt key event -> "SUPER + SHIFT + S", or "" for a lone modifier
    function comboFromEvent(event) {
        if (modifierKeys.includes(event.key))
            return "";
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        const key = keyNames[event.nativeScanCode] ?? (event.nativeScanCode > 0 ? "code:" + event.nativeScanCode : event.text.toUpperCase());
        return key === "" ? "" : mods.concat([key]).join(" + ");
    }

    Connections {
        target: HyprSettings
        function onReloaded() {
            root.refresh();
        }
    }

    FileView {
        id: file
        path: Paths.keybinds
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.data = { overrides: d.overrides ?? {}, custom: d.custom ?? [] };
            } catch (e) {
                console.warn("KeybindStore: bad keybinds.json", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    Process {
        id: proc
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text).map(b => {
                        const combo = root.comboOf(b);
                        const d = (b.description ?? "").split(":");
                        return {
                            combo,
                            norm: root.normalize(combo),
                            submap: b.submap ?? "",
                            description: b.description ?? "",
                            group: d.length > 1 ? d[0].trim() : "",
                            action: (d.length > 1 ? d.slice(1).join(":") : d[0]).trim() || `${b.dispatcher} ${b.arg}`.trim()
                        };
                    });
                } catch (e) {
                    console.warn("KeybindStore: binds parse failed", e);
                }
            }
        }
    }
}
