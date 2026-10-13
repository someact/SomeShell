pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Hyprland-side choices (~/.config/someshell/hypr.json), read by hypr/lib/util.lua.
// The file holds only what was changed here; everything else shows Hyprland's
// live value (read once at start). Each change is written after a short pause,
// then Hyprland reloads and any config errors are shown.
Singleton {
    id: root

    property var data: ({})
    property var live: ({})        // "general.gaps_in" -> current Hyprland value
    property string errors: ""     // `hyprctl configerrors` plus skipped keybinds after the last reload
    property bool reloading: false
    property bool hasTouchpad: false   // any pointer device named "touchpad" (the Touchpad section shows only then)

    // Options the Hyprland page edits; live values are read for these
    readonly property var options: ["general.gaps_in", "general.gaps_out", "general.border_size", "general.layout", "decoration.rounding", "decoration.blur.enabled", "decoration.blur.size", "decoration.blur.passes", "decoration.shadow.enabled", "decoration.dim_inactive", "animations.enabled", "input.sensitivity", "input.follow_mouse", "input.repeat_rate", "input.repeat_delay", "input.touchpad.natural_scroll", "input.touchpad.tap_to_click", "input.touchpad.disable_while_typing", "input.touchpad.clickfinger_behavior", "input.touchpad.scroll_factor", "misc.vrr"]

    function walk(obj, path) {
        let v = obj;
        for (const part of path.split(".")) {
            if (v === null || typeof v !== "object")
                return undefined;
            v = v[part];
        }
        return v;
    }

    // Saved value, else Hyprland's live one (for "hyprland.*"), else the fallback
    function get(path, fallback) {
        const v = walk(data, path);
        if (v !== undefined && v !== "")
            return v;
        if (path.startsWith("hyprland.")) {
            const l = live[path.slice(9)];
            if (l !== undefined)
                return l;
        }
        return fallback;
    }
    function isSet(path) {
        const v = walk(data, path);
        return v !== undefined && v !== "";
    }

    function set(path, value) {
        const copy = JSON.parse(JSON.stringify(data));
        const parts = path.split(".");
        let o = copy;
        for (const part of parts.slice(0, -1)) {
            if (o[part] === null || typeof o[part] !== "object" || Array.isArray(o[part]))
                o[part] = {};
            o = o[part];
        }
        o[parts[parts.length - 1]] = value;
        data = copy;
        save.restart();
    }
    // Back to the default: drop the key (and empty parents)
    function unset(path) {
        const copy = JSON.parse(JSON.stringify(data));
        const parts = path.split(".");
        const chain = [copy];
        for (const part of parts.slice(0, -1)) {
            const next = chain[chain.length - 1][part];
            if (next === null || typeof next !== "object")
                return;
            chain.push(next);
        }
        delete chain[chain.length - 1][parts[parts.length - 1]];
        for (let i = chain.length - 1; i > 0; i--) {
            if (Object.keys(chain[i]).length === 0)
                delete chain[i - 1][parts[i - 1]];
        }
        data = copy;
        save.restart();
    }

    // Reload Hyprland and collect errors; KeybindStore uses this too
    signal reloaded
    function reload() {
        reloading = true;
        reloadProc.running = true;
    }
    function readLive() {
        liveProc.running = true;
    }

    Timer {
        id: save
        interval: 400
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", Paths.configDir]);
            file.setText(JSON.stringify(root.data, null, 2) + "\n");
            root.reload();
        }
    }

    FileView {
        id: file
        path: Paths.hyprSettings
        printErrors: false
        onLoaded: {
            try {
                root.data = JSON.parse(text()) ?? {};
            } catch (e) {
                root.errors = "hypr.json is not valid JSON: " + e;
            }
        }
    }

    Process {
        id: reloadProc
        // repl answers "unknown request" for an empty string, hence the "binds:" prefix
        command: ["sh", "-c", "hyprctl reload >/dev/null; sleep 0.3; hyprctl configerrors; hyprctl repl 'return \"binds:\" .. table.concat(USER_BINDS_ERRORS or {}, \"\\n\")'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.errors = text.replace(/^binds:/m, "").split("\n").map(l => l.trim()).filter(l => l !== "" && l !== "ok").join("\n");
                root.reloading = false;
                root.readLive();
                root.reloaded();
            }
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hasTouchpad = (JSON.parse(text).mice ?? []).some(m => /touchpad/i.test(m.name));
                } catch (e) {}
            }
        }
    }

    // One `hyprctl repl` returns every option as JSON (gaps are per-side tables: use the top)
    Process {
        id: liveProc
        running: true
        command: ["hyprctl", "repl", "local o = {}; for _, k in ipairs({" + root.options.map(k => JSON.stringify(k)).join(",") + "}) do local v = hl.get_config(k); if type(v) == 'table' then v = v.top end; o[#o + 1] = string.format('%q:%s', k, type(v) == 'string' and string.format('%q', v) or tostring(v)) end; return '{' .. table.concat(o, ',') .. '}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.live = JSON.parse(text);
                } catch (e) {
                    console.warn("HyprSettings: could not read live options", e, text);
                }
            }
        }
    }
}
