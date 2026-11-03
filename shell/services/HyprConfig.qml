pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Hyprland options set from the settings window. They live in this machine's
// hypr.json ("hyprland": a partial hl.config table, read by
// hypr/core/settings.lua at start); a change is written there and applied
// live with `hyprctl eval`, so nothing reloads.
//   HyprConfig.set(["input", "kb_layout"], "us,th")
Singleton {
    id: root

    readonly property string path: Paths.config + "/hypr.json"
    property var data: ({})
    readonly property var hyprland: data.hyprland ?? {}

    function get(keys, fallback) {
        let v = hyprland;
        for (const k of keys) {
            if (v === null || typeof v !== "object" || !(k in v))
                return fallback;
            v = v[k];
        }
        return v;
    }

    // Lua for a value: strings quoted, numbers and booleans as they are
    function lua(v) {
        return typeof v === "string" ? JSON.stringify(v) : String(v);
    }

    function set(keys, value) {
        // Live: hl.config({ input = { kb_layout = "us,th" } })
        let table = root.lua(value);
        for (let i = keys.length - 1; i >= 0; i--)
            table = "{ " + keys[i] + " = " + table + " }";
        Quickshell.execDetached(["hyprctl", "eval", "hl.config(" + table + ")"]);
        // Saved: the other keys in hypr.json stay as they are
        const filter = ".hyprland" + keys.map(k => "." + k).join("") + " = $v";
        const arg = typeof value === "string" ? "--arg" : "--argjson";
        writer.command = ["sh", "-c",
            'f="$1"; t=$(mktemp) && { [ -s "$f" ] && cat "$f" || echo "{}"; } | jq "$2" "$3" "$4" "$5" > "$t" && mv "$t" "$f"',
            "sh", root.path, arg, "v", typeof value === "string" ? value : JSON.stringify(value), filter];
        writer.running = true;
        // Show it at once (the file watch confirms it)
        const d = JSON.parse(JSON.stringify(data));
        let o = d.hyprland = d.hyprland ?? {};
        for (let i = 0; i < keys.length - 1; i++)
            o = o[keys[i]] = (o[keys[i]] && typeof o[keys[i]] === "object") ? o[keys[i]] : {};
        o[keys[keys.length - 1]] = value;
        data = d;
    }

    // A JSON value as Lua: arrays and objects as tables
    function luaValue(v) {
        if (Array.isArray(v))
            return "{ " + v.map(luaValue).join(", ") + " }";
        if (v !== null && typeof v === "object")
            return "{ " + Object.keys(v).map(k => k + " = " + luaValue(v[k])).join(", ") + " }";
        return lua(v);
    }

    // One device (a pen tablet, a mouse) in hypr.json "devices", by name;
    // the whole entry is sent again, so its other fields stay
    function device(name) {
        return (data.devices ?? []).find(d => d && d.name === name) ?? null;
    }
    function setDevice(name, key, value) {
        const entry = Object.assign({ name: name }, device(name) ?? {});
        if (value === null || value === undefined)
            delete entry[key];
        else
            entry[key] = value;
        Quickshell.execDetached(["hyprctl", "eval", "hl.device(" + luaValue(entry) + ")"]);
        const list = (data.devices ?? []).filter(d => d && d.name !== name).concat([entry]);
        deviceWriter.command = ["sh", "-c",
            'f="$1"; t=$(mktemp) && { [ -s "$f" ] && cat "$f" || echo "{}"; } | jq --argjson v "$2" "$3" > "$t" && mv "$t" "$f"',
            "sh", root.path, JSON.stringify(list), ".devices = $v"];
        deviceWriter.running = true;
        const d = JSON.parse(JSON.stringify(data));
        d.devices = list;
        data = d;
    }

    Process { id: writer }
    Process { id: deviceWriter }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text()) ?? {};
            } catch (e) {}
        }
    }
}
