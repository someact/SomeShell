pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// The wallpaper and the colors made from it. Supports static images, video
// files, and Wallpaper Engine folders (`scene` / `video` with `project.json`)
// rendered by ~/.local/lib/someshell/somewall on WlrLayer.Background.
// Setting a wallpaper, or changing light/dark or the scheme, runs matugen on
// the still image (`stillPath`). State: ~/.local/state/someshell/wall.json.
Singleton {
    id: root

    readonly property string path: state.path
    readonly property bool ready: file.loaded
    readonly property string helper: Paths.home + "/.local/lib/someshell/somewall"
    property bool engineInstalled: false
    property bool engineReady: false
    readonly property bool animated: isAnimatedPath(state.path)
    // True once somewall is actively rendering on the background layer
    readonly property bool live: animated && engineInstalled && engineReady
    // Static image representing the current wallpaper (for matugen, brightness,
    // DeskCard, Overview). Same as `path` for static images; cached PNG preview
    // frame for Wallpaper Engine folders and videos.
    property string stillPath: ""

    function isImagePath(p) {
        return /\.(jpe?g|png|webp|bmp|avif)$/i.test(p || "");
    }
    function isAnimatedPath(p) {
        if (!p)
            return false;
        if (/\.(mp4|webm|mkv|mov)$/i.test(p))
            return true;
        if (/\/project\.json$/i.test(p))
            return true;
        return !isImagePath(p);
    }

    function sendEngine(obj) {
        if (engineProc.running)
            engineProc.write(JSON.stringify(obj) + "\n");
    }

    function syncEngine() {
        if (!engineInstalled || !state.path)
            return;
        if (!isAnimatedPath(state.path)) {
            if (engineProc.running) {
                sendEngine({ cmd: "quit" });
                engineProc.running = false;
            }
            engineReady = false;
            return;
        }
        if (engineProc.running) {
            sendEngine({ cmd: "load", path: state.path });
        } else {
            const args = [helper, "--stdin-ipc", "--fps", "60"];
            if (Config.wallpaper.assets)
                args.push("--assets", Config.wallpaper.assets);
            args.push(state.path);
            engineProc.command = args;
            engineProc.running = true;
        }
    }

    function setProp(key, rawValue) {
        if (!key)
            return;
        let v = rawValue;
        if (rawValue === "true") v = true;
        else if (rawValue === "false") v = false;
        else if (typeof rawValue === "string" && rawValue !== "" && !isNaN(Number(rawValue))) v = Number(rawValue);
        sendEngine({ cmd: "set_prop", key: key, value: v });
    }

    function setPaused(on) {
        sendEngine({ cmd: on ? "pause" : "resume" });
    }

    function setMonitorPaused(monitor, on) {
        if (!monitor)
            return;
        sendEngine({ cmd: on ? "pause" : "resume", monitor: monitor });
    }

    Process {
        id: checkEngine
        running: true
        command: ["test", "-x", root.helper]
        onExited: code => {
            root.engineInstalled = (code === 0);
            if (root.engineInstalled && root.isAnimatedPath(state.path))
                root.syncEngine();
        }
    }

    Process {
        id: engineProc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line);
                    if (ev.event === "ready")
                        root.engineReady = true;
                    else if (ev.event === "loaded")
                        root.engineReady = !!ev.ok;
                } catch (e) {}
            }
        }
        stderr: SplitParser {
            onRead: line => { if (line.trim()) console.log("somewall:", line); }
        }
        onExited: root.engineReady = false
    }

    onPathChanged: {
        syncEngine();
        if (!path) {
            stillPath = "";
            return;
        }
        if (isImagePath(path)) {
            stillPath = path;
            tone.running = true;
            if (pendingRecolor) {
                pendingRecolor = false;
                recolorNow();
            }
        } else {
            resolveStill.command = ["sh", "-c",
                "p=\"$1\"; outdir=\"$2\"; mkdir -p \"$outdir\"; " +
                "h=$(printf '%s' \"$p\" | cksum | awk '{print $1}'); out=\"$outdir/$h.png\"; " +
                "if [ -s \"$out\" ]; then printf '%s' \"$out\"; exit 0; fi; " +
                "d=\"$p\"; [ -f \"$d\" ] && [ \"$(basename \"$d\")\" = \"project.json\" ] && d=\"$(dirname \"$d\")\"; " +
                "if [ -d \"$d\" ] && [ -f \"$d/project.json\" ]; then " +
                "  prev=$(jq -r '.preview // empty' \"$d/project.json\" 2>/dev/null); " +
                "  if [ -n \"$prev\" ] && [ -f \"$d/$prev\" ]; then " +
                "    magick \"$d/$prev[0]\" \"$out\" 2>/dev/null && [ -s \"$out\" ] && { printf '%s' \"$out\"; exit 0; }; " +
                "  fi; " +
                "fi; " +
                "if [ -f \"$p\" ]; then " +
                "  ffmpeg -y -loglevel error -ss 00:00:01 -i \"$p\" -frames:v 1 \"$out\" 2>/dev/null " +
                "  || ffmpeg -y -loglevel error -i \"$p\" -frames:v 1 \"$out\" 2>/dev/null; " +
                "  [ -s \"$out\" ] && { printf '%s' \"$out\"; exit 0; }; " +
                "fi",
                "sh", path, Paths.cache + "/we-stills"];
            resolveStill.running = true;
        }
    }

    property bool pendingRecolor: false
    Process {
        id: resolveStill
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (s) {
                    root.stillPath = s;
                    tone.running = true;
                    if (root.pendingRecolor) {
                        root.pendingRecolor = false;
                        root.recolorNow();
                    }
                }
            }
        }
    }

    // How bright the wallpaper is (0..1), measured once per wallpaper: bare
    // desktop widgets draw light type on a dark wallpaper and dark on a light
    // one, whatever the theme mode (Theme.onWall)
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

    function set(newPath) {
        if (!newPath)
            return;
        const clean = newPath.replace(/^file:\/\//, "").replace(/\/+$/, "");
        state.path = clean;
        file.writeAdapter();
        root.recolor();
    }

    // Wallpaper, light/dark and scheme together (a preset): one matugen run
    function applyLook(newPath, mode, scheme) {
        holding = true;
        if (newPath)
            state.path = newPath.replace(/^file:\/\//, "").replace(/\/+$/, "");
        if (mode)
            Config.theme.mode = mode;
        if (scheme)
            Config.theme.scheme = scheme;
        holding = false;
        file.writeAdapter();
        recolor();
    }
    property bool holding: false

    // Run matugen for the current wallpaper, mode and scheme. A run already
    // going is replaced, so only the last change counts.
    function recolor() {
        if (!state.path)
            return;
        if (!stillPath || (!isImagePath(state.path) && resolveStill.running)) {
            pendingRecolor = true;
            return;
        }
        recolorNow();
    }
    function recolorNow() {
        if (!stillPath)
            return;
        if (matugen.running)
            pending = true;
        else
            matugen.running = true;
    }
    property bool pending: false

    Process {
        id: matugen
        command: ["matugen", "image", root.stillPath, "-c", Paths.matugenConfig,
            "-t", Config.theme.scheme, "-m", Config.theme.mode, "--source-color-index", "0"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("matugen:", text.trim())
        }
        onExited: code => {
            if (code !== 0)
                console.warn("matugen exited with", code, "for", root.stillPath);
            if (root.pending) {
                root.pending = false;
                running = true;
            }
        }
    }

    // At start: recolor when the palette was made from another wallpaper
    // (or does not exist yet)
    function checkPalette() {
        if (file.loaded && Theme.paletteRead && stillPath && Theme.image !== stillPath)
            recolor();
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

    FileView {
        id: file
        path: Paths.state + "/wall.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.checkPalette()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.firstStart = true;
                root.takeV1();
            }
        }
        JsonAdapter {
            id: state
            property string path: ""
        }
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
