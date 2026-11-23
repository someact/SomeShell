pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Each wallpaper's own settings (~/.config/someshell/wallpapers.json), only
// what differs from the defaults: the Wallpaper Engine properties (`props`),
// `fit` (fill, fit, stretch, center), `speed`, `fps` and `scale` (0 = the
// shell's), `pause` rules that override wallpaper.pause. Keyed by the
// workshop id ("ws:<id>", so moving the folder or another machine keeps
// them), else by the path. `describe(path)` reads project.json once (title,
// kind, properties with their defaults); WallEngine waits for it.
Singleton {
    id: root

    // key → entry
    property var map: ({})
    // path → { key, id, title, type, props: [{ key, type, text, value, min, max, step, precision, fraction, options, condition }] }
    property var infos: ({})

    function known(path) {
        return !!infos[path];
    }
    function keyFor(path) {
        return infos[path]?.key ?? path;
    }
    // The entry for a wallpaper ({} for none)
    function forPath(path) {
        return map[keyFor(path)] ?? {};
    }
    // Every property's value now: the default, or the wallpaper's own
    function propValues(path) {
        const out = {};
        for (const p of infos[path]?.props ?? [])
            out[p.key] = p.value;
        return Object.assign(out, forPath(path).props ?? {});
    }
    function defaultOf(path, key) {
        return (infos[path]?.props ?? []).find(p => p.key === key)?.value;
    }

    // A label for a property: Wallpaper Engine's own keys ("ui_browse_properties_scheme_color") in words
    function label(text) {
        if (!text || !text.startsWith("ui_"))
            return text || "";
        const words = text.replace(/^ui_(browse_)?(properties_)?/, "").replace(/_/g, " ");
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    // ── Changing ────────────────────────────────────────────────────────

    function change(path, fn) {
        const k = keyFor(path);
        const m = Object.assign({}, map);
        const e = JSON.parse(JSON.stringify(m[k] ?? {}));
        fn(e);
        if (e.props && !Object.keys(e.props).length)
            delete e.props;
        if (e.pause && !Object.keys(e.pause).length)
            delete e.pause;
        if (Object.keys(e).length)
            m[k] = e;
        else
            delete m[k];
        map = m;
        write();
    }

    function setProp(path, key, value) {
        const def = defaultOf(path, key);
        change(path, e => {
            e.props = e.props ?? {};
            if (value === def || String(value) === String(def))
                delete e.props[key];
            else
                e.props[key] = value;
        });
    }

    // fit, speed, fps, scale; the default value (or null) removes it
    readonly property var defaults: ({ fit: "fill", speed: 1, fps: 0, scale: 0 })
    function setValue(path, name, value) {
        if (!(name in defaults))
            return;
        change(path, e => {
            if (value === null || value === undefined || value === defaults[name])
                delete e[name];
            else
                e[name] = value;
        });
    }

    // A pause rule for this wallpaper only (null: follow wallpaper.pause)
    function setPause(path, rule, on) {
        change(path, e => {
            e.pause = e.pause ?? {};
            if (on === null || on === undefined)
                delete e.pause[rule];
            else
                e.pause[rule] = !!on;
        });
    }

    function reset(path) {
        change(path, e => {
            for (const k in e)
                delete e[k];
        });
    }

    // Some wallpaper pauses under windows on its own (WallPause then watches windows)
    readonly property bool anyCovered: {
        for (const k in map)
            if (map[k].pause?.covered)
                return true;
        return false;
    }

    // ── Undo and presets ────────────────────────────────────────────────

    function snapshot() {
        return JSON.parse(JSON.stringify(map));
    }
    function load(m) {
        map = JSON.parse(JSON.stringify(m ?? {}));
        write();
    }
    function sameAs(m) {
        return JSON.stringify(m ?? {}) === JSON.stringify(map);
    }
    // The entries of these wallpapers (a preset keeps its wallpapers' settings)
    function entriesFor(paths) {
        const out = {};
        for (const p of paths) {
            const k = keyFor(p);
            if (map[k])
                out[k] = JSON.parse(JSON.stringify(map[k]));
        }
        return out;
    }
    function merge(entries) {
        if (!entries || !Object.keys(entries).length)
            return;
        map = Object.assign({}, map, JSON.parse(JSON.stringify(entries)));
        write();
    }

    // ── project.json ───────────────────────────────────────────────────

    property var asking: []
    function describe(path) {
        if (!path || known(path) || asking.indexOf(path) >= 0)
            return;
        asking = asking.concat([path]);
        if (!reader.running)
            readNext();
    }
    function readNext() {
        if (!asking.length)
            return;
        reader.paths = asking;
        reader.command = ["sh", "-c",
            "for p in \"$@\"; do " +
            "if [ -f \"$p/project.json\" ]; then " +
            "  jq -c --arg p \"$p\" '{path: $p, id: ((.workshopid // \"\") | tostring), title: (.title // \"\"), type: ((.type // \"\") | ascii_downcase), " +
            "props: [(.general.properties // {}) | to_entries[] | {key, type: (.value.type // \"\"), text: (.value.text // .key), value: .value.value, " +
            "min: .value.min, max: .value.max, step: .value.step, precision: .value.precision, fraction: .value.fraction, " +
            "options: .value.options, condition: .value.condition, order: (.value.order // 0)}] | sort_by(.order)}' \"$p/project.json\" 2>/dev/null " +
            "  || jq -cn --arg p \"$p\" '{path: $p}'; " +
            "else jq -cn --arg p \"$p\" '{path: $p}'; fi; done",
            "sh", ...asking];
        reader.running = true;
    }
    Process {
        id: reader
        property var paths: []
        stdout: StdioCollector {
            onStreamFinished: {
                const add = Object.assign({}, root.infos);
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    try {
                        const i = JSON.parse(line);
                        i.key = i.id ? "ws:" + i.id : i.path;
                        i.props = i.props ?? [];
                        add[i.path] = i;
                    } catch (e) {}
                }
                // A path jq could not read still counts as known (no properties)
                for (const p of reader.paths)
                    if (!add[p])
                        add[p] = { path: p, key: p, props: [] };
                root.infos = add;
                root.asking = root.asking.filter(p => !add[p]);
                root.readNext();
            }
        }
    }

    // ── File ───────────────────────────────────────────────────────────

    function write() {
        file.lastWrite = Date.now();
        file.setText(JSON.stringify(map, null, 2) + "\n");
    }
    FileView {
        id: file
        path: Paths.config + "/wallpapers.json"
        watchChanges: true
        printErrors: false
        // Our own write also changes the file: ignore that echo for a moment
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onLoaded: {
            try {
                root.map = JSON.parse(text() || "{}");
            } catch (e) {
                console.warn("wallpapers.json is not valid JSON; left as it is");
            }
        }
    }
}
