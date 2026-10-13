pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// The wallpaper: an image (drawn by wallpaper/WallpaperLayer.qml) or a video
// (played by mpvpaper). Every change re-themes the desktop through matugen;
// videos are themed from a frame grabbed with ffmpeg.
//
// mpvpaper pauses itself while the wallpaper is hidden or a window is
// fullscreen (-p -a FULL, which covers games and the lock screen); game mode
// also pauses it explicitly over mpv's IPC socket.
Singleton {
    id: root

    property string path: ""
    property string phase: ""          // last applied schedule slot (Schedule.qml)
    property bool loaded: false        // the saved state has been read (or there is none)
    readonly property bool isVideo: isVideoFile(path)
    readonly property string mode: Config.theme.mode

    readonly property var imageExts: ["jpg", "jpeg", "png", "webp", "bmp", "avif"]
    readonly property var videoExts: ["mp4", "webm", "mkv", "mov", "m4v", "avi", "gif"]

    function ext(p) {
        return p.slice(p.lastIndexOf(".") + 1).toLowerCase();
    }
    function isVideoFile(p) {
        return videoExts.includes(ext(p));
    }
    function isWallpaperFile(p) {
        return imageExts.includes(ext(p)) || videoExts.includes(ext(p));
    }

    function set(file) {
        if (!file || !isWallpaperFile(file)) {
            console.warn("Wallpaper: not an image or video:", file);
            return;
        }
        path = file;
        save();
        syncVideo();
        if (isVideo)
            grabFrame();
        else
            theme(file);
    }

    // Re-run matugen on the current wallpaper (after a mode or scheme change)
    function retheme() {
        if (path !== "")
            theme(isVideo ? Paths.videoFrame : path);
    }

    function toggleLightDark() {
        Config.theme.mode = mode === "dark" ? "light" : "dark";
        retheme();
    }

    function setMode(m) {
        if (m === mode)
            return;
        Config.theme.mode = m;
        retheme();
    }

    // Random wallpaper from a folder (default: ~/Pictures/Wallpapers)
    function random(folder) {
        randomProc.command = ["find", "-L", folder || Paths.wallpapers, "-maxdepth", "2", "-type", "f"];
        randomProc.running = true;
    }

    // Native file dialog for a wallpaper outside the picker folder
    function pick() {
        pickProc.running = true;
    }

    // Rapid changes: each of matugen, the frame grab and mpvpaper control runs
    // one process at a time; a request made while one runs is remembered, and
    // the latest one runs when it finishes. So the last wallpaper picked always
    // wins, whatever order the processes would have finished in.

    function theme(image) {
        matugen.target = [image, mode, Config.theme.scheme];
        matugen.kick();
    }

    function grabFrame() {
        frame.kick();
    }

    // Make mpvpaper match `path`: stop it, then start it again if it is a video
    function syncVideo() {
        mpvCtl.kick();
    }

    component LatestProcess: Process {
        property bool again: false
        function kick() {
            if (running) {
                again = true;
                return;
            }
            again = false;
            command = build();
            running = true;
        }
        function build() {
            return [];
        }
        function finished(code) {}
        onExited: code => {
            if (again)
                kick();
            else
                finished(code);
        }
    }

    LatestProcess {
        id: matugen
        property var target: []
        function build() {
            return ["matugen", "image", target[0], "-m", target[1], "-t", target[2], "--source-color-index", "0"];
        }
    }

    LatestProcess {
        id: frame
        property string file
        function build() {
            file = root.path;
            return ["ffmpeg", "-loglevel", "error", "-y", "-ss", "1", "-i", file, "-frames:v", "1", "-vf", "scale=1280:-2", Paths.videoFrame];
        }
        function finished(code) {
            if (file !== root.path)
                return;     // superseded by an image; nothing to theme from
            if (code === 0)
                root.theme(Paths.videoFrame);
            else
                console.warn("Wallpaper: could not grab a frame from", file);
        }
    }

    LatestProcess {
        id: mpvCtl
        function build() {
            // Stop the old player by PID (a name match can miss one that is still
            // starting) and by name. mpvpaper ignores SIGTERM while auto-paused
            // (hidden), so after 1 s it gets SIGKILL. Then start the new one in its
            // own session so it outlives shell restarts.
            return ["sh", "-c", 'pf="$3"; old="$(cat "$pf" 2>/dev/null) $(pidof mpvpaper)"; rm -f "$pf"; '
                + 'kill $old 2>/dev/null; i=0; while pidof -q mpvpaper && [ $i -lt 20 ]; do sleep 0.05; i=$((i+1)); done; '
                + 'kill -9 $old 2>/dev/null; pkill -9 -x mpvpaper; while pidof -q mpvpaper; do sleep 0.05; done; '
                + '[ -n "$1" ] || exit 0; '
                + 'setsid mpvpaper -p -a FULL -o "no-audio loop hwdec=auto-safe panscan=1.0 input-ipc-server=$2" ALL "$1" >/dev/null 2>&1 & echo $! > "$pf"',
                "_", root.isVideo ? root.path : "", Paths.mpvSocket, Paths.mpvPid];
        }
        function finished(code) {
            if (root.isVideo)
                pauseSync.restart();
        }
    }

    // Never before the saved state is read: a save then would write an empty
    // path over it (a schedule check at start did, before `loaded`)
    function save() {
        if (!loaded)
            return;
        Quickshell.execDetached(["mkdir", "-p", Paths.stateDir]);
        state.setText(JSON.stringify({ path: root.path, phase: root.phase }));
    }

    // Game mode pauses the video wallpaper even when the game is not fullscreen
    readonly property bool shouldPause: GameMode.active
    onShouldPauseChanged: pauseSync.restart()
    Timer {
        id: pauseSync
        interval: 600       // mpvpaper needs a moment to open its socket after start
        onTriggered: if (root.isVideo) {
            mpv.connected = false;
            mpv.connected = true;
        }
    }
    Socket {
        id: mpv
        path: Paths.mpvSocket
        onConnectionStateChanged: if (connected) {
            write(JSON.stringify({ command: ["set_property", "pause", root.shouldPause] }) + "\n");
            flush();
            connected = false;
        }
    }

    Process {
        id: pickProc
        command: ["kdialog", "--title", "Wallpaper", "--getopenfilename", Paths.wallpapers, "*.jpg *.jpeg *.png *.webp *.avif *.mp4 *.webm *.mkv *.mov *.gif|Images and videos"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.set(text.trim())
        }
    }

    Process {
        id: randomProc
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split("\n").filter(f => root.isWallpaperFile(f) && f !== root.path);
                if (files.length > 0)
                    root.set(files[Math.floor(Math.random() * files.length)]);
            }
        }
    }

    // Start mpvpaper at login if the saved wallpaper is a video
    Process {
        id: checkMpv
        command: ["pidof", "mpvpaper"]
        onExited: code => {
            if (code !== 0 && root.isVideo)
                root.syncVideo();
        }
    }

    FileView {
        id: state
        path: Paths.wallpaperState
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.path = s.path ?? "";
                root.phase = s.phase ?? "";
            } catch (e) {}
            root.loaded = true;
            checkMpv.running = true;
        }
        onLoadFailed: root.loaded = true
    }
}
