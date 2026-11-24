pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// The wallpapers and the colors made from them. One wallpaper on every
// monitor (`mode` "all"), or each monitor its own ("each"). A wallpaper is a
// picture (drawn by WallpaperWindow), a video file, or a Wallpaper Engine
// folder (`scene` / `video` with `project.json`); the animated ones are drawn
// by somewall (WallEngine: one per distinct animated wallpaper). The colors
// (matugen) come from one monitor's wallpaper (`colorsFrom`, empty = the
// first monitor), through its still picture.
// State: ~/.local/state/someshell/wall.json.
Singleton {
    id: root

    readonly property bool ready: file.loaded
    readonly property string mode: state.mode === "each" ? "each" : "all"
    readonly property var monitorNames: Quickshell.screens.map(s => s.name)
    readonly property string colorsFrom: state.colorsFrom
    readonly property string colorsMonitor: monitorNames.indexOf(state.colorsFrom) >= 0 ? state.colorsFrom : (monitorNames[0] ?? "")

    // The wallpaper the colors come from, and its still picture
    readonly property string path: pathFor(colorsMonitor)
    readonly property string stillPath: stills[path] ?? ""

    function pathFor(monitor) {
        if (mode === "each" && monitor && state.monitors[monitor])
            return state.monitors[monitor];
        return state.path;
    }
    // A picture for a monitor: the wallpaper itself, or a still frame of it
    function stillFor(monitor) {
        return stills[pathFor(monitor)] ?? "";
    }
    // Some monitor shows it
    function shown(p) {
        for (const n of monitorNames)
            if (pathFor(n) === p)
                return true;
        return false;
    }

    function isImagePath(p) {
        return /\.(jpe?g|png|webp|bmp|avif)$/i.test(p || "");
    }
    function isAnimatedPath(p) {
        return !!p && !isImagePath(p);
    }
    function clean(p) {
        return (p || "").replace(/^file:\/\//, "").replace(/\/+$/, "");
    }

    // ── Choosing ────────────────────────────────────────────────────────

    // Set a wallpaper: on every monitor, or with "each" on `monitor` (default:
    // the focused one)
    function set(newPath, monitor) {
        if (!newPath)
            return;
        const p = clean(newPath);
        remember();
        // Chosen again on purpose: try it again even if it failed before
        forgetBad(p);
        if (mode === "each") {
            const m = monitor || Hyprland.focusedMonitor?.name || colorsMonitor;
            const mons = Object.assign({}, state.monitors);
            mons[m] = p;
            state.monitors = mons;
        } else {
            state.path = p;
        }
        save();
    }

    // "all" or "each". Going back to one wallpaper keeps the one the colors
    // come from (each monitor's own choice is remembered); going to "each"
    // brings those back, and a monitor without one starts with what it shows
    function setMode(m) {
        if (m === mode)
            return;
        remember();
        if (m === "each") {
            const mons = Object.assign({}, state.monitors);
            for (const n of monitorNames)
                if (!mons[n])
                    mons[n] = state.path;
            state.monitors = mons;
        } else {
            state.path = path;
        }
        state.mode = m;
        save();
    }

    function setColorsFrom(monitor) {
        state.colorsFrom = monitor;
        save();
    }

    function save() {
        write();
        if (path !== colored)
            recolor();
    }

    // The whole choice, for presets and Undo
    function snapshot() {
        return { mode: mode, path: state.path, monitors: Object.assign({}, state.monitors), colorsFrom: state.colorsFrom };
    }
    function sameAs(walls) {
        return JSON.stringify(normal(walls)) === JSON.stringify(snapshot());
    }
    // Older presets keep one path
    function normal(walls) {
        if (typeof walls === "string")
            return { mode: "all", path: clean(walls), monitors: {}, colorsFrom: "" };
        return { mode: walls?.mode === "each" ? "each" : "all", path: clean(walls?.path), monitors: walls?.monitors ?? {}, colorsFrom: walls?.colorsFrom ?? "" };
    }

    // Wallpapers, light/dark and scheme together (a preset, Undo): one matugen run
    function applyLook(walls, mode, scheme) {
        if (!reverting)
            remember();
        holding = true;
        if (walls) {
            const w = normal(walls);
            if (w.path)
                state.path = w.path;
            state.monitors = w.monitors;
            state.colorsFrom = w.colorsFrom;
            state.mode = w.mode;
        }
        if (mode)
            Config.theme.mode = mode;
        if (scheme)
            Config.theme.scheme = scheme;
        holding = false;
        write();
        recolor();
    }
    property bool holding: false

    // ── Failures ───────────────────────────────────────────────────────

    // The choice before the last change: a wallpaper that does not load puts it back
    property var previous: null
    property bool reverting: false
    function remember() {
        previous = snapshot();
    }
    // Wallpapers that did not load (or kept crashing) this session: no
    // somewall is started for them again until one is chosen again
    property var bad: ({})
    function forgetBad(p) {
        if (bad[p]) {
            const b = Object.assign({}, bad);
            delete b[p];
            bad = b;
        }
    }
    function titleOf(p) {
        return WallSettings.infos[p]?.title || p.split("/").pop();
    }
    function engineFailed(p, reason) {
        // Back to the choice before (unless that is this one too), first: the
        // same somewall then loads it instead of being started again
        const prev = previous;
        const back = prev && JSON.stringify(prev).indexOf(JSON.stringify(p)) < 0;
        Ui.showAlert("Wallpaper did not load", titleOf(p) + (reason ? " · " + reason : "") + (back ? " · the previous one is back" : ""), "Wallpaper", "broken_image", { wide: !!reason });
        if (back) {
            reverting = true;
            applyLook(prev, "", "");
            reverting = false;
        }
        const b = Object.assign({}, bad);
        b[p] = true;
        bad = b;
    }
    function engineGaveUp(p) {
        const b = Object.assign({}, bad);
        b[p] = true;
        bad = b;
        Ui.showAlert("Animated wallpaper stopped", titleOf(p) + " crashed again and again · its picture shows instead", "Wallpaper", "error");
    }

    // ── Still pictures ──────────────────────────────────────────────────

    // Path → its still picture: itself for a picture; a frame rendered by
    // somewall for a scene, a video's own frame, else the project's preview
    // (made once at the largest screen's size, cached in ~/.cache/someshell/we-stills)
    property var stills: ({})
    readonly property string stillSize: {
        let w = 1920, h = 1080;
        for (const sc of Quickshell.screens) {
            const r = sc.devicePixelRatio || 1;
            if (sc.width * sc.height * r * r > w * h) {
                w = Math.round(sc.width * r);
                h = Math.round(sc.height * r);
            }
        }
        return w + "x" + h;
    }
    readonly property var allPaths: {
        const out = [];
        if (state.path)
            out.push(state.path);
        if (mode === "each")
            for (const n of monitorNames) {
                const p = pathFor(n);
                if (p && out.indexOf(p) < 0)
                    out.push(p);
            }
        return out;
    }
    function resolveStills() {
        const add = Object.assign({}, stills);
        const missing = [];
        for (const p of allPaths) {
            if (add[p])
                continue;
            if (isImagePath(p))
                add[p] = p;
            else if (stillProc.asked.indexOf(p) < 0)
                missing.push(p);
        }
        stills = add;
        if (missing.length && !stillProc.running) {
            stillProc.asked = stillProc.asked.concat(missing);
            stillProc.command = ["sh", "-c",
                "outdir=\"$1\"; helper=\"$2\"; assets=\"$3\"; size=\"$4\"; shift 4; mkdir -p \"$outdir\"; " +
                "w=${size%x*}; h=${size#*x}; " +
                "for p in \"$@\"; do " +
                "h1=$(printf '%s %s' \"$p\" \"$size\" | cksum | awk '{print $1}'); out=\"$outdir/$h1.png\"; " +
                "if [ ! -s \"$out\" ]; then " +
                "  d=\"$p\"; [ -f \"$d\" ] && [ \"$(basename \"$d\")\" = \"project.json\" ] && d=\"$(dirname \"$d\")\"; " +
                "  if [ -d \"$d\" ] && [ -f \"$d/project.json\" ]; then " +
                "    type=$(jq -r '(.type // \"scene\") | ascii_downcase' \"$d/project.json\" 2>/dev/null); " +
                "    file=$(jq -r '.file // empty' \"$d/project.json\" 2>/dev/null); " +
                // A scene: one frame rendered by somewall at the screen's size
                "    if [ \"$type\" = scene ] && [ -x \"$helper\" ]; then " +
                // No assets folder set: a harmless pair in its place (somewall then looks in the Steam paths)
                "      if [ -n \"$assets\" ]; then sa=--assets; sv=\"$assets\"; else sa=--fps; sv=60; fi; " +
                "      timeout 60 \"$helper\" \"$sa\" \"$sv\" --headless-shot \"$out.ppm\" --size \"$size\" --frames 30 \"$d\" >/dev/null 2>&1 " +
                "        && magick \"$out.ppm\" \"$out\" 2>/dev/null; rm -f \"$out.ppm\"; " +
                // A video: its own frame, covering the screen
                "    elif [ \"$type\" = video ] && [ -n \"$file\" ] && [ -f \"$d/$file\" ]; then " +
                "      ffmpeg -y -loglevel error -ss 00:00:01 -i \"$d/$file\" -frames:v 1 -vf \"scale=$w:$h:force_original_aspect_ratio=increase\" \"$out\" 2>/dev/null; " +
                "    fi; " +
                // Else (or when that failed) the project's preview
                "    if [ ! -s \"$out\" ]; then " +
                "      prev=$(jq -r '.preview // empty' \"$d/project.json\" 2>/dev/null); " +
                "      [ -n \"$prev\" ] && [ -f \"$d/$prev\" ] && magick \"$d/$prev[0]\" \"$out\" 2>/dev/null; " +
                "    fi; " +
                "  elif [ -f \"$p\" ]; then " +
                "    ffmpeg -y -loglevel error -ss 00:00:01 -i \"$p\" -frames:v 1 -vf \"scale=$w:$h:force_original_aspect_ratio=increase\" \"$out\" 2>/dev/null " +
                "    || ffmpeg -y -loglevel error -i \"$p\" -frames:v 1 \"$out\" 2>/dev/null; " +
                "  fi; " +
                "fi; " +
                "[ -s \"$out\" ] && printf '%s\\t%s\\n' \"$p\" \"$out\"; done",
                "sh", Paths.cache + "/we-stills", root.helper, Config.wallpaper.assets, root.stillSize, ...missing];
            stillProc.running = true;
        }
    }
    Process {
        id: stillProc
        property var asked: []
        stdout: StdioCollector {
            onStreamFinished: {
                const add = Object.assign({}, root.stills);
                for (const line of text.split("\n")) {
                    const parts = line.split("\t");
                    if (parts.length === 2)
                        add[parts[0]] = parts[1];
                }
                root.stills = add;
            }
        }
        // Paths that came in while this one ran
        onExited: root.resolveStills()
    }

    onStillPathChanged: {
        if (!stillPath)
            return;
        tone.running = true;
        if (pendingRecolor) {
            pendingRecolor = false;
            recolorNow();
        }
        checkPalette();
    }

    // How bright the colors' wallpaper is (0..1), measured once per wallpaper:
    // bare desktop widgets draw light type on a dark wallpaper and dark on a
    // light one, whatever the theme mode (Theme.onWall)
    Process {
        id: tone
        command: ["magick", root.stillPath + "[0]", "-resize", "64x64!", "-colorspace", "gray", "-format", "%[fx:mean]", "info:"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text);
                if (!isNaN(v))
                    Theme.wallDark = v < 0.55;
            }
        }
    }

    // ── Colors ──────────────────────────────────────────────────────────

    // The wallpaper matugen last ran for
    property string colored: ""
    // The colors' wallpaper may give its own color instead of its picture
    // (a Wallpaper Engine `schemecolor`, chosen in the tab): its hex, else ""
    readonly property string schemeHex: (WallSettings.forPath(path).colors ?? "") === "scheme"
        ? WallSettings.hexOf(WallSettings.propValues(path).schemecolor) : ""
    onSchemeHexChanged: if (file.loaded && colored) recolor()
    // Run matugen for the colors' wallpaper, mode and scheme. A run already
    // going is replaced, so only the last change counts.
    function recolor() {
        if (!path)
            return;
        colored = path;
        if (!stillPath && !schemeHex) {
            pendingRecolor = true;
            return;
        }
        recolorNow();
    }
    property bool pendingRecolor: false
    function recolorNow() {
        if (!stillPath && !schemeHex)
            return;
        if (matugen.running) {
            pending = true;
        } else {
            matugen.begin();
        }
    }
    property bool pending: false

    Process {
        id: matugen
        // The command is made when a run starts: a binding could change
        // (or be empty for a moment) while it runs
        property string image: ""
        function begin() {
            image = root.stillPath;
            command = root.schemeHex
                ? ["matugen", "color", "hex", root.schemeHex, "-c", Paths.matugenConfig, "-t", Config.theme.scheme, "-m", Config.theme.mode]
                : ["matugen", "image", image, "-c", Paths.matugenConfig,
                    "-t", Config.theme.scheme, "-m", Config.theme.mode, "--source-color-index", "0"];
            running = true;
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("matugen:", text.trim())
        }
        onExited: code => {
            if (code !== 0)
                console.warn("matugen exited with", code, "for", image);
            if (root.pending) {
                root.pending = false;
                begin();
            }
        }
    }

    // At start: recolor when the palette was made from another wallpaper
    // (or does not exist yet)
    function checkPalette() {
        if (!file.loaded || !Theme.paletteRead || !stillPath)
            return;
        // From a color, matugen writes the image as "Null"
        if (Theme.image !== (schemeHex ? "Null" : stillPath))
            recolor();
        else
            colored = path;
    }
    Connections {
        target: Theme
        function onPaletteReadChanged() { root.checkPalette(); }
    }

    // Light/dark and the scheme recolor everything
    Connections {
        target: Config.theme
        function onModeChanged() { if (!root.holding) root.recolor(); }
        function onSchemeChanged() { if (!root.holding) root.recolor(); }
    }

    // ── Animated wallpapers (somewall) ─────────────────────────────────

    readonly property string helper: Paths.home + "/.local/lib/someshell/somewall"
    property bool engineInstalled: false
    Process {
        running: true
        command: ["test", "-x", root.helper]
        onExited: code => root.engineInstalled = code === 0
    }

    // Which somewalls should run: key → { path, outputs }. One wallpaper on
    // every monitor: one somewall for all ("*", it also takes monitors plugged
    // in later). Each its own: one per animated wallpaper, on its monitors.
    readonly property var groups: {
        const out = {};
        if (!file.loaded || !engineInstalled)
            return out;
        if (mode === "all") {
            if (isAnimatedPath(state.path) && !bad[state.path])
                out["*"] = { path: state.path, outputs: [] };
            return out;
        }
        const byPath = {};
        for (const n of monitorNames) {
            const p = pathFor(n);
            if (isAnimatedPath(p) && !bad[p])
                (byPath[p] = byPath[p] ?? []).push(n);
        }
        for (const p in byPath) {
            const outs = byPath[p].sort();
            out[outs.join(",")] = { path: p, outputs: outs };
        }
        return out;
    }
    onGroupsChanged: syncEngines()

    property var engines: ({})
    function syncEngines() {
        const next = {};
        for (const key in engines) {
            const e = engines[key];
            if (groups[key]) {
                e.load(groups[key].path);
                next[key] = e;
            } else {
                e.stop();
                e.destroy();
            }
        }
        for (const key in groups) {
            if (next[key])
                continue;
            const e = engineComp.createObject(root, {
                helper: root.helper,
                path: groups[key].path,
                outputs: groups[key].outputs
            });
            e.userPaused = Qt.binding(() => root.userPaused);
            e.failed.connect(root.engineFailed);
            e.gaveUp.connect(root.engineGaveUp);
            e.start();
            next[key] = e;
        }
        engines = next;
    }
    Component {
        id: engineComp
        WallEngine {}
    }

    // Monitors where somewall draws now (WallpaperWindow stops drawing there)
    readonly property var liveMonitors: {
        const out = {};
        for (const key in engines) {
            const e = engines[key];
            if (!e.ready)
                continue;
            for (const n of (e.outputs.length ? e.outputs : monitorNames))
                out[n] = true;
        }
        return out;
    }
    function liveOn(monitor) {
        return !!liveMonitors[monitor];
    }
    readonly property bool live: Object.keys(liveMonitors).length > 0

    // Pausing by hand (IPC `pause`), on top of the rules (WallPause)
    property bool userPaused: false
    function setPaused(on) {
        userPaused = on;
    }

    // ── Each wallpaper's settings (WallSettings) ───────────────────────

    // The wallpaper a change is for: the monitor's, else with "each" the
    // focused monitor's, else the one on every monitor
    function targetPath(monitor) {
        if (monitor)
            return pathFor(monitor);
        if (mode === "each")
            return pathFor(Hyprland.focusedMonitor?.name ?? colorsMonitor);
        return state.path;
    }
    // Text from IPC: true/false and numbers as such, the rest as text
    function parseValue(raw) {
        if (typeof raw !== "string")
            return raw;
        if (raw === "true")
            return true;
        if (raw === "false")
            return false;
        if (raw !== "" && !isNaN(Number(raw)))
            return Number(raw);
        return raw;
    }
    // A Wallpaper Engine property; saved, live on the wallpaper's somewall
    function setProp(key, value, monitor) {
        if (key)
            WallSettings.setProp(targetPath(monitor), key, parseValue(value));
    }
    // fit, speed, fps, scale, or pause.<rule> ("default" removes it)
    function setting(name, value, monitor) {
        const p = targetPath(monitor);
        const v = value === "default" ? null : parseValue(value);
        if (name.startsWith("pause."))
            WallSettings.setPause(p, name.slice(6), v);
        else
            WallSettings.setValue(p, name, v);
    }
    function resetSettings(monitor) {
        WallSettings.reset(targetPath(monitor));
    }
    // project.json of every wallpaper shown, read ahead (titles, properties)
    onAllPathsChanged: {
        resolveStills();
        for (const p of allPaths)
            if (isAnimatedPath(p))
                WallSettings.describe(p);
    }

    // For `ipc call wallpaper engine`
    function engineState() {
        const list = [];
        for (const key in engines) {
            const e = engines[key];
            list.push({ outputs: e.outputs, path: e.path, ready: e.ready, info: e.info, sent: e.sentPause, settings: e.settings });
        }
        return { bad: bad, mode: mode, colorsFrom: colorsMonitor, colors: path, still: stillPath, colored: colored, stills: stills, rules: WallPause.paused, user: userPaused, engines: list };
    }

    // ── State file ─────────────────────────────────────────────────────

    FileView {
        id: file
        path: Paths.state + "/wall.json"
        watchChanges: true
        // Our own write also changes the file: ignore that echo for a moment,
        // or the reload empties the state while a change is still being made
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onLoaded: root.checkPalette()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.firstStart = true;
                root.takeV1();
            }
        }
        JsonAdapter {
            id: state
            // The wallpaper on every monitor (and for monitors "each" has none for)
            property string path: ""
            property string mode: "all"
            // Monitor name → wallpaper, used with "each"
            property var monitors: ({})
            // The monitor the colors come from ("" = the first)
            property string colorsFrom: ""
        }
    }

    function write() {
        file.lastWrite = Date.now();
        file.writeAdapter();
    }

    // The poster that ships with the shell (scripts/poster-wallpaper.sh)
    readonly property string defaultPath: Quickshell.shellDir + "/assets/wallpapers/poster-moon.png"

    // First start: the wallpaper v1 used if there was one, else the default
    property bool firstStart: false
    property bool v1Read: false
    function takeV1() {
        if (!firstStart || !v1Read)
            return;
        firstStart = false;
        let old = "";
        try {
            old = v1.loaded ? JSON.parse(v1.text()).path ?? "" : "";
        } catch (e) {}
        root.set(old || defaultPath);
    }
    FileView {
        id: v1
        path: Paths.state + "/wallpaper.json"
        onLoaded: { root.v1Read = true; root.takeV1(); }
        onLoadFailed: { root.v1Read = true; root.takeV1(); }
    }
}
