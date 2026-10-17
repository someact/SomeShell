pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// SomeLauncher (13i): a read-mostly client of its daemon, somelauncherd, over
// its unix socket (JSON lines: requests with an id, replies, and events; the
// protocol is docs/protocol.md in the SomeLauncher repo). It shows what runs
// and downloads even while the launcher window is hidden or closed.
// It never starts the daemon, and does not poll for it: it connects when the
// shell starts and when a window opens (a game, Steam or the launcher always
// opens one; again 2 s later, since the launcher opens its window before it
// starts the daemon), once the socket exists. `available` is false without the daemon.
Singleton {
    id: root

    readonly property int protocol: 1
    readonly property string socketPath: Quickshell.env("SOMELAUNCHER_SOCKET") || (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/somelauncher.sock"
    property bool available: false            // connected, and the daemon speaks our protocol

    property var games: ({})                  // id → game (name, playtime, lastPlayed, …)
    property var running: ({})                // id → {state, since, step?}
    property var downloads: ({})              // job id → {label, done, total}

    // The game being played (the first that runs; one that is starting otherwise)
    readonly property var playing: {
        const ids = Object.keys(running);
        const id = ids.find(i => running[i].state === "running") ?? ids[0];
        if (id === undefined)
            return null;
        const g = games[id];
        return { id: Number(id), name: g ? g.name : "", state: running[id].state, step: running[id].step ?? "", since: running[id].since ?? 0, playtime: g ? g.playtime : 0 };
    }
    // The download shown (the one with the most left), as {label, done, total, fraction}
    readonly property var download: {
        const list = Object.values(downloads);
        if (list.length === 0)
            return null;
        const d = list.reduce((a, b) => (b.total - b.done > a.total - a.done ? b : a));
        return Object.assign({ fraction: d.total > 0 ? d.done / d.total : 0, count: list.length }, d);
    }
    // Played games, most recent first (the overlay card)
    readonly property var recent: Object.values(games).filter(g => g.lastPlayed && !g.hidden).sort((a, b) => b.lastPlayed - a.lastPlayed).slice(0, 5)
    readonly property bool active: available && (playing !== null || download !== null)

    // Unix seconds, ticked once a minute while something is played and someone shows it
    property real now: Date.now() / 1000
    property bool clockWanted: false
    Timer {
        running: root.clockWanted && root.playing !== null && root.playing.state === "running"
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now() / 1000
    }

    // "12 min", "1 h 05"
    function duration(seconds) {
        const m = Math.max(0, Math.floor(seconds / 60));
        return m < 1 ? "<1 min" : m < 60 ? m + " min" : Math.floor(m / 60) + " h " + String(m % 60).padStart(2, "0");
    }
    function hours(seconds) {
        const h = seconds / 3600;
        return h >= 10 ? Math.round(h) + " h" : h >= 1 ? h.toFixed(1) + " h" : Math.max(1, Math.round(seconds / 60)) + " min";
    }

    // The launcher window: shown through its IPC, else started
    function open() {
        Quickshell.execDetached(["sh", "-c", "qs -c somelauncher ipc call launcher open >/dev/null 2>&1 || qs -c somelauncher"]);
    }
    function openGame(id) {
        Quickshell.execDetached(["sh", "-c", `qs -c somelauncher ipc call launcher game ${Number(id)} >/dev/null 2>&1 || qs -c somelauncher`]);
    }

    // --- the socket

    property int _next: 1
    property var _pending: ({})
    function call(method, params, callback) {
        if (!sock.connected)
            return;
        const id = _next++;
        if (callback)
            _pending[id] = callback;
        sock.write(JSON.stringify(params === undefined ? { id, method } : { id, method, params }) + "\n");
        sock.flush();
    }

    // Only once the socket is there, so a missing daemon logs nothing
    function connect() {
        if (!sock.connected && !probe.running)
            probe.running = true;
    }
    Process {
        id: probe
        command: ["test", "-S", root.socketPath]
        onExited: code => {
            if (code === 0)
                sock.connected = true;
        }
    }
    Timer {
        id: again
        interval: 2000
        onTriggered: root.connect()
    }
    function _refresh() {
        call("games.list", { includeHidden: true }, list => {
            const m = {};
            for (const g of list ?? [])
                m[g.id] = g;
            root.games = m;
        });
        call("games.running", undefined, list => {
            const r = {};
            for (const g of list ?? [])
                r[g.id] = { state: g.since === null ? "starting" : "running", since: g.since };
            root.running = r;
        });
        call("downloads.list", undefined, list => {
            const d = {};
            for (const j of list ?? [])
                d[j.id] = j;
            root.downloads = d;
        });
    }
    function _receive(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.id !== undefined) {
            const cb = _pending[msg.id];
            delete _pending[msg.id];
            if (cb && !msg.error)
                cb(msg.result);
            return;
        }
        const data = msg.data;
        switch (msg.event) {
        case "hello":
            available = data.protocol === protocol;
            if (available)
                _refresh();
            else
                console.warn(`Launcher: somelauncherd speaks protocol ${data.protocol}, the shell knows ${protocol}`);
            break;
        case "game.state": {
            const r = Object.assign({}, running);
            if (data.state === "stopped")
                delete r[data.id];
            else
                r[data.id] = data;
            running = r;
            break;
        }
        case "download.progress": {
            const d = Object.assign({}, downloads);
            d[data.id] = data;
            downloads = d;
            break;
        }
        case "download.done": {
            const d = Object.assign({}, downloads);
            delete d[data.id];
            downloads = d;
            break;
        }
        case "library.changed":
            // Playtime lands here when a game ends; changes come in bursts
            libraryChanged.restart();
            break;
        }
    }
    Timer {
        id: libraryChanged
        interval: 500
        onTriggered: root.call("games.list", { includeHidden: true }, list => {
            const m = {};
            for (const g of list ?? [])
                m[g.id] = g;
            root.games = m;
        })
    }

    Socket {
        id: sock
        path: root.socketPath
        onConnectionStateChanged: {
            if (!connected) {
                root.available = false;
                root._pending = {};
                root.running = {};
                root.downloads = {};
            }
        }
        parser: SplitParser {
            onRead: line => root._receive(line)
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" && !sock.connected) {
                root.connect();
                again.restart();
            }
        }
    }
    Component.onCompleted: connect()
}
