import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// One somewall: an animated wallpaper on some monitors (`outputs`, empty =
// every monitor). Made and ended by Wallpaper, one per distinct animated
// wallpaper; a new wallpaper on the same monitors is a `load`, not a restart.
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

    function send(obj) {
        if (proc.running)
            proc.write(JSON.stringify(obj) + "\n");
    }

    function start() {
        const args = [helper, "--stdin-ipc", "--fps", String(Config.wallpaper.fps),
            "--scale", String(Config.wallpaper.scale), "--hwdec", Config.wallpaper.hwdec || "auto"];
        if (Config.wallpaper.assets)
            args.push("--assets", Config.wallpaper.assets);
        if (outputs.length)
            args.push("--output", outputs.join(","));
        args.push(path);
        proc.command = args;
        proc.running = true;
    }

    function load(p) {
        if (p === path)
            return;
        path = p;
        ready = false;
        send({ cmd: "load", path: p });
    }

    function stop() {
        send({ cmd: "quit" });
        proc.running = false;
    }

    function syncPause() {
        if (!proc.running)
            return;
        const want = WallPause.paused;
        const sent = Object.assign({}, sentPause);
        const names = outputs.length ? outputs : Object.keys(want);
        for (const name of names) {
            const on = userPaused || (want[name] ?? false);
            if (sent[name] !== on) {
                send({ cmd: on ? "pause" : "resume", monitor: name });
                sent[name] = on;
            }
        }
        sentPause = sent;
    }
    onUserPausedChanged: syncPause()
    Connections {
        target: WallPause
        function onPausedChanged() { eng.syncPause(); }
    }

    // Frame rate and render scale apply live
    Connections {
        target: Config.wallpaper
        function onFpsChanged() { eng.send({ cmd: "fps", value: Config.wallpaper.fps }); }
        function onScaleChanged() { eng.send({ cmd: "scale", value: Config.wallpaper.scale }); }
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
                if (ev.event === "ready") {
                    eng.ready = true;
                    // A new somewall knows nothing: tell it every monitor's state
                    eng.sentPause = {};
                    eng.syncPause();
                } else if (ev.event === "loaded") {
                    eng.ready = !!ev.ok;
                }
            }
        }
        stderr: SplitParser {
            onRead: line => { if (line.trim()) console.log("somewall:", line); }
        }
        onExited: eng.ready = false
    }
}
