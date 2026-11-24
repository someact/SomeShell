import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// One somewall: an animated wallpaper on some monitors (`outputs`, empty =
// every monitor). Made and ended by Wallpaper, one per distinct animated
// wallpaper; a new wallpaper on the same monitors is a `load`, not a restart.
// The wallpaper's own settings (WallSettings) go with the start or the load,
// so its first frame has them; later changes are sent one by one.
Scope {
    id: eng

    property string helper: ""
    property string path: ""
    property var outputs: []
    property bool userPaused: false
    // Running and drawing the current wallpaper
    property bool ready: false
    // somewall's last report: type, decoder, cursor, fps, scale
    property var info: ({})
    // What somewall was last told, per monitor: only changes are sent
    property var sentPause: ({})

    // The wallpaper's settings, and what somewall has now
    readonly property var settings: WallSettings.forPath(path)
    property var sent: null
    // Waiting for project.json before a start or a load
    property string waiting: ""

    // Failures. `failed`: this wallpaper did not load (Wallpaper puts the
    // previous one back). A crash restarts somewall up to three times (the
    // count starts over after two minutes running well); then `gaveUp`, and
    // the still picture shows.
    // `reason`: why, in words, when somewall knows ("" otherwise)
    signal failed(string path, string reason)
    signal gaveUp(string path)
    property bool stopping: false
    property bool everReady: false
    property string reason: ""
    property int crashes: 0
    readonly property int maxCrashes: 3

    function fpsOf(s) {
        return s.fps || Config.wallpaper.fps;
    }
    function scaleOf(s) {
        return s.scale || Config.wallpaper.scale;
    }
    function texresOf(s) {
        return s.texres || Config.wallpaper.texres || 1;
    }
    function now() {
        return {
            props: WallSettings.propValues(path),
            fit: settings.fit ?? "fill",
            speed: settings.speed ?? 1,
            fps: fpsOf(settings),
            scale: scaleOf(settings),
            texres: texresOf(settings)
        };
    }

    function send(obj) {
        if (proc.running)
            proc.write(JSON.stringify(obj) + "\n");
    }

    function start() {
        if (!WallSettings.known(path)) {
            waiting = "start";
            WallSettings.describe(path);
            return;
        }
        const n = now();
        const args = [helper, "--stdin-ipc", "--fps", String(n.fps), "--scale", String(n.scale),
            "--fit", n.fit, "--speed", String(n.speed), "--texres", String(n.texres), "--hwdec", Config.wallpaper.hwdec || "auto"];
        if (Config.wallpaper.assets)
            args.push("--assets", Config.wallpaper.assets);
        if (outputs.length)
            args.push("--output", outputs.join(","));
        for (const k in settings.props ?? {})
            args.push("--prop", k + "=" + String(settings.props[k]));
        args.push(path);
        sent = n;
        everReady = false;
        proc.command = args;
        proc.running = true;
    }

    function load(p) {
        if (p === path && waiting !== "load")
            return;
        ready = false;
        // Waiting first: the path change updates `settings`, and nothing may
        // reach the old wallpaper meanwhile
        waiting = "load";
        path = p;
        if (!WallSettings.known(p)) {
            WallSettings.describe(p);
            return;
        }
        waiting = "";
        const n = now();
        send({ cmd: "load", path: p, props: settings.props ?? {}, fit: n.fit, speed: n.speed, texres: n.texres });
        if (!sent || n.fps !== sent.fps)
            send({ cmd: "fps", value: n.fps });
        if (!sent || n.scale !== sent.scale)
            send({ cmd: "scale", value: n.scale });
        sent = n;
    }

    function stop() {
        stopping = true;
        restart.stop();
        send({ cmd: "quit" });
        proc.running = false;
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: if (!eng.stopping) eng.start()
    }
    // Two minutes running well: earlier crashes no longer count
    Timer {
        id: healthy
        interval: 120000
        running: eng.ready
        onTriggered: eng.crashes = 0
    }

    // project.json read: go on with what was waiting
    Connections {
        target: WallSettings
        function onInfosChanged() {
            if (!eng.waiting || !WallSettings.known(eng.path))
                return;
            if (eng.waiting === "start") {
                eng.waiting = "";
                eng.start();
            } else {
                eng.load(eng.path);
            }
        }
    }

    // A setting changed: send what differs (a property back at its default
    // is sent as the default)
    function applySettings() {
        if (!sent || waiting || !proc.running)
            return;
        const n = now();
        // Textures are made when a scene loads: load it again (with
        // everything, so nothing else needs sending)
        if (n.texres !== sent.texres) {
            send({ cmd: "load", path: path, props: n.props, fit: n.fit, speed: n.speed, texres: n.texres });
            ready = false;
            sent = Object.assign({}, n, { fps: sent.fps, scale: sent.scale });
        }
        for (const k in n.props)
            if (JSON.stringify(n.props[k]) !== JSON.stringify(sent.props[k]))
                send({ cmd: "set_prop", key: k, value: n.props[k] });
        if (n.fit !== sent.fit)
            send({ cmd: "fit", value: n.fit });
        if (n.speed !== sent.speed)
            send({ cmd: "speed", value: n.speed });
        if (n.fps !== sent.fps)
            send({ cmd: "fps", value: n.fps });
        if (n.scale !== sent.scale)
            send({ cmd: "scale", value: n.scale });
        sent = n;
        syncPause();
    }
    onSettingsChanged: applySettings()
    Connections {
        target: Config.wallpaper
        function onFpsChanged() { eng.applySettings(); }
        function onScaleChanged() { eng.applySettings(); }
        function onTexresChanged() { eng.applySettings(); }
    }

    // Pausing: the shell's rules with this wallpaper's own on top
    function syncPause() {
        if (!proc.running)
            return;
        const st = WallPause.state;
        const rules = WallPause.rulesWith(settings.pause);
        const sentNow = Object.assign({}, sentPause);
        const names = outputs.length ? outputs : Object.keys(st);
        for (const name of names) {
            const on = userPaused || WallPause.pausedWith(st[name], rules);
            if (sentNow[name] !== on) {
                send({ cmd: on ? "pause" : "resume", monitor: name });
                sentNow[name] = on;
            }
        }
        sentPause = sentNow;
    }
    onUserPausedChanged: syncPause()
    Connections {
        target: WallPause
        function onStateChanged() { eng.syncPause(); }
        function onRulesChanged() { eng.syncPause(); }
    }
    Connections {
        target: Config.wallpaper.pause
        function onFullscreenChanged() { eng.syncPause(); }
        function onCoveredChanged() { eng.syncPause(); }
        function onBatteryChanged() { eng.syncPause(); }
        function onLockedChanged() { eng.syncPause(); }
    }

    Process {
        id: proc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let ev = null;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.event === "ready" || ev.event === "loaded" || ev.event === "status")
                    eng.info = ev;
                if (ev.event === "error") {
                    eng.reason = ev.reason ?? "";
                } else if (ev.event === "ready") {
                    eng.ready = true;
                    eng.everReady = true;
                    // A new somewall knows nothing: tell it every monitor's state
                    eng.sentPause = {};
                    eng.syncPause();
                } else if (ev.event === "loaded") {
                    eng.ready = !!ev.ok;
                    if (!ev.ok)
                        eng.failed(eng.path, ev.reason ?? "");
                }
            }
        }
        stderr: SplitParser {
            onRead: line => { if (line.trim()) console.log("somewall:", line); }
        }
        onExited: (code, status) => {
            eng.ready = false;
            if (eng.stopping)
                return;
            // Ended before it was ready with an error: the wallpaper itself
            // did not load (somewall exits 1); no restart
            if (!eng.everReady && status === 0 && code !== 0) {
                console.warn("somewall could not load", eng.path);
                eng.failed(eng.path, eng.reason);
                eng.reason = "";
                return;
            }
            eng.crashes++;
            console.warn("somewall ended (code", code + ", status", status + "), crash", eng.crashes, "of", eng.maxCrashes);
            if (eng.crashes > eng.maxCrashes)
                eng.gaveUp(eng.path);
            else
                restart.start();
        }
    }
}
