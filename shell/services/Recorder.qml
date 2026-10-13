pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// Screen recording with wf-recorder, owned by the shell so the island knows
// when it runs. Config.capture.encoder picks the encoder (auto: NVENC with an
// NVIDIA GPU, x264 otherwise); stopping sends SIGINT so the file is
// finalized. The CLI fallback (hypr/scripts/record.sh)
// only runs while the shell is down.
Singleton {
    id: root

    readonly property bool active: proc.running
    property bool sound: false
    property string file: ""
    property real startedAt: 0
    property int elapsed: 0              // seconds, ticks only while recording
    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60), s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string dir: Config.capture.recordDir || Paths.videos

    // geometry: "x,y wxh" in layout pixels, or "" for the focused monitor
    function start(geometry, withSound) {
        if (active)
            return;
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss");
        root.file = `${dir}/recording_${stamp}.mp4`;
        root.sound = !!withSound;
        const args = ["wf-recorder", "-y", "-f", root.file];
        let enc = Config.capture.encoder;
        if (enc === "auto")
            enc = Gpu.nvidia ? "h264_nvenc" : "libx264";
        if (enc === "h264_nvenc")
            args.push("-c", enc, "-p", "preset=p5", "-p", "rc=vbr", "-p", "cq=23");
        else if (enc !== "")
            args.push("-c", enc, "--pixel-format", "yuv420p");
        if (geometry)
            args.push("-g", geometry);
        else
            args.push("-o", Hyprland.focusedMonitor?.name ?? "");
        if (root.sound && Audio.sink)
            args.push("--audio=" + Audio.sink.name + ".monitor");
        proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", dir, ...args];
        proc.running = true;
        root.startedAt = Date.now();
        root.elapsed = 0;
    }

    function stop() {
        if (active)
            proc.signal(2);   // SIGINT: wf-recorder writes the trailer and exits
    }

    // The record keys work while locked (to stop), but never start one there
    function toggleScreen(withSound) {
        if (active)
            stop();
        else if (!Lock.locked)
            start("", withSound);
    }

    Process {
        id: proc
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            if (code === 0 || code === 130 || code === 2)
                Quickshell.execDetached(["notify-send", "-a", "Recorder", "-i", "video-x-generic", "Recording saved", root.file]);
            else
                Quickshell.execDetached(["notify-send", "-a", "Recorder", "-u", "critical", "Recording failed", err.text.trim().split("\n").slice(-2).join("\n")]);
        }
    }

    Timer {
        running: root.active
        interval: 1000
        repeat: true
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }
}
