pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Lyrics for the current track from LRCLIB (lrclib.net), one curl per new track,
// cached in ~/.cache/someshell/lyrics/ (misses too, so a track is asked once).
// Synced LRC gives `lines` + `index`; the index follows the playhead with one
// single-shot timer aimed at the next line, and only while someone shows it.
Singleton {
    id: root

    readonly property bool enabled: Config.media.lyrics
    // off | loading | synced | plain | none | error
    property string status: "off"
    property var lines: []          // [{ time: seconds, text }] (synced only)
    property string plain: ""       // unsynced text, or the synced lines joined
    property int index: -1          // current line in `lines`, -1 before the first
    readonly property string line: lines[index]?.text ?? ""
    readonly property bool synced: status === "synced"
    readonly property bool has: status === "synced" || status === "plain"

    // Views that follow the current line raise this; the line timer runs only while > 0
    property int watchers: 0

    property string key: ""         // track the result belongs to

    readonly property string wantKey: enabled && Media.active ? trackKey(Media.artist, Media.title) : ""
    onWantKeyChanged: debounce.restart()

    function trackKey(artist, title) {
        return Qt.md5(artist.toLowerCase() + "\n" + title.toLowerCase());
    }

    // Browser players report "Artist - Title (Official Video)" as the title
    function clean(artist, title) {
        let t = title.replace(/\s*[\(\[][^\)\]]*(official|lyric|video|audio|visuali[sz]er|\bmv\b|\bhd\b|4k|remaster)[^\)\]]*[\)\]]/gi, "").trim();
        let a = artist.replace(/\s*-\s*Topic$/i, "").replace(/VEVO$/, "").trim();
        const dash = t.indexOf(" - ");
        if (dash > 0 && (a === "" || t.toLowerCase().startsWith(a.toLowerCase()))) {
            a = t.slice(0, dash).trim();
            t = t.slice(dash + 3).trim();
        }
        return { artist: a, title: t };
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.fetch()
    }

    function fetch() {
        const k = wantKey;
        if (k === key && status !== "error")
            return;
        fetcher.running = false;
        key = k;
        index = -1;
        lines = [];
        plain = "";
        if (k === "") {
            status = enabled ? "none" : "off";
            return;
        }
        status = "loading";
        const c = clean(Media.artist, Media.title);
        const dur = Media.length > 0 ? String(Math.round(Media.length)) : "";
        fetcher.forKey = k;
        fetcher.command = ["sh", "-c", script, "_", Paths.lyrics + "/" + k + ".json", c.title, c.artist, dur];
        fetcher.running = true;
    }

    // $1 cache file, $2 title, $3 artist, $4 duration (may be empty).
    // Cache hit → print it. Else /api/get (exact), then /api/search; a 200 from either
    // is cached (an empty search "[]" is a cached miss). Network errors are not cached.
    readonly property string script: '
f=$1; [ -s "$f" ] && exec cat "$f"
mkdir -p "$(dirname "$f")"
ua="SomeShell (https://github.com/someact/SomeShell)"
q() { curl -s -m 10 -A "$ua" -o "$f.tmp" -w "%{http_code}" -G "$@"; }
set -- "$2" "$3" "$4"
if [ -n "$2" ]; then
  code=$(q --data-urlencode "track_name=$1" --data-urlencode "artist_name=$2" ${3:+--data-urlencode "duration=$3"} https://lrclib.net/api/get)
  [ "$code" = 200 ] && mv "$f.tmp" "$f" && exec cat "$f"
fi
code=$(q --data-urlencode "track_name=$1" ${2:+--data-urlencode "artist_name=$2"} https://lrclib.net/api/search)
[ "$code" = 200 ] && mv "$f.tmp" "$f" && exec cat "$f"
rm -f "$f.tmp"; exit 1'

    Process {
        id: fetcher
        property string forKey: ""
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (forKey !== root.key)
                return;
            if (code !== 0) {
                root.status = "error";
                return;
            }
            root.apply(out.text);
        }
    }

    function apply(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            status = "error";
            return;
        }
        if (Array.isArray(data)) {
            // Search results: prefer synced, then the closest length
            const len = Media.length;
            const score = r => (r.syncedLyrics ? 0 : 1000) + (len > 0 ? Math.abs((r.duration ?? 0) - len) : 0);
            data = data.filter(r => r.syncedLyrics || r.plainLyrics).sort((a, b) => score(a) - score(b))[0];
        }
        if (!data || data.instrumental || !(data.syncedLyrics || data.plainLyrics)) {
            status = "none";
            return;
        }
        if (data.syncedLyrics) {
            lines = parse(data.syncedLyrics);
            plain = data.plainLyrics || lines.map(l => l.text).join("\n");
            status = lines.length > 0 ? "synced" : "plain";
        } else {
            plain = data.plainLyrics;
            status = "plain";
        }
        sync();
    }

    // "[mm:ss.xx]text", possibly several stamps per line
    function parse(lrc) {
        const out = [];
        const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of lrc.split("\n")) {
            const times = [];
            let m;
            let rest = 0;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(raw)) !== null && m.index === rest) {
                times.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
                rest = stamp.lastIndex;
            }
            const text = raw.slice(rest).trim();
            for (const t of times)
                out.push({ time: t, text: text });
        }
        return out.sort((a, b) => a.time - b.time);
    }

    // Follow the playhead: set index now, then wake exactly at the next line
    readonly property bool following: watchers > 0 && synced && Media.isPlaying
    onFollowingChanged: sync()

    function sync() {
        lineTimer.stop();
        if (!synced || !Media.player) {
            index = -1;
            return;
        }
        const pos = Media.player.position + 0.15;   // show a line a touch early
        let i = -1;
        while (i + 1 < lines.length && lines[i + 1].time <= pos)
            i++;
        index = i;
        if (following && i + 1 < lines.length) {
            lineTimer.interval = Math.max(50, (lines[i + 1].time - pos) * 1000);
            lineTimer.start();
        }
    }

    Timer {
        id: lineTimer
        onTriggered: root.sync()
    }

    // Seeks and the views' position refreshes land here
    Connections {
        target: Media.player
        enabled: root.synced && root.watchers > 0
        function onPositionChanged() {
            root.sync();
        }
        function onPlaybackStateChanged() {
            root.sync();
        }
    }

    function retry() {
        if (status === "error")
            fetch();
    }
}
