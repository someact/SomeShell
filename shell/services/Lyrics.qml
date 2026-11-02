pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Lyrics of the playing song, from LRCLIB through lib/lyrics.sh (which
// caches them). Only looked up while `wanted` (a media page is open).
//   status: "" (nothing asked), "loading", "synced", "plain", "instrumental",
//          "none", "offline"
Singleton {
    id: root

    // Views that show lyrics (the media page); counted, as an old page can
    // be torn down after its replacement starts
    property int viewers: 0
    readonly property bool wanted: viewers > 0

    property string status: ""
    // Synced: [{ t: seconds, text }]; plain: [{ t: -1, text }]
    property var lines: []

    // Titles from video sites carry extras the lyrics library does not know
    function cleanTitle(s) {
        return String(s)
            .replace(/\s*[\(\[][^\)\]]*\b(official|video|audio|lyrics?|m\/?v|visuali[sz]er|hd|4k|live performance)\b[^\)\]]*[\)\]]/gi, "")
            .replace(/\s*\|.*$/, "")
            .trim();
    }
    function cleanArtist(s) {
        return String(s).replace(/\s*-\s*Topic$/i, "").replace(/\s*VEVO$/i, "").split(/\s*,\s*|\s+(?:feat\.?|ft\.?)\s+/i)[0].trim();
    }

    readonly property string title: cleanTitle(Media.title)
    readonly property string artist: cleanArtist(Media.artist)
    readonly property int length: Math.round(Media.length)
    // The song to look up; empty while there is none or nobody shows it.
    // Waits for the length (players report it a moment after the title).
    readonly property string key: wanted && Media.active && Media.kind === "music" && title !== "" && length > 0
        ? title + "\n" + artist + "\n" + length : ""
    onKeyChanged: {
        if (key === "") {
            reader.running = false;
            status = "";
            lines = [];
            return;
        }
        status = "loading";
        lines = [];
        reader.running = false;
        reader.command = [Quickshell.shellPath("lib/lyrics.sh"), title, artist, String(length)];
        reader.asked = key;
        reader.running = true;
    }

    function parse(text, asked) {
        if (asked !== key)
            return;
        let r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            r = { found: false, offline: true };
        }
        if (!r.found) {
            status = r.offline ? "offline" : "none";
            return;
        }
        if (r.instrumental) {
            status = "instrumental";
            return;
        }
        const synced = [];
        for (const line of String(r.synced ?? "").split("\n")) {
            const m = /^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/.exec(line.trim());
            if (m)
                synced.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] });
        }
        if (synced.length > 0) {
            lines = synced;
            status = "synced";
            return;
        }
        const plain = String(r.plain ?? "").split("\n").map(s => ({ t: -1, text: s.trim() }));
        if (plain.some(l => l.text !== "")) {
            lines = plain;
            status = "plain";
        } else {
            status = "none";
        }
    }

    // Lyrics found for this song (shown or not)
    readonly property bool found: ["synced", "plain", "instrumental"].includes(status)

    // Songs whose lyrics were turned off (a wrong match), by title and artist
    readonly property string song: title + "\n" + artist
    readonly property bool off: offFile.loaded && (offList.songs ?? []).includes(song)
    // Found and not turned off
    readonly property bool shown: found && offFile.loaded && !off
    function toggleOff() {
        if (!found)
            return;
        const songs = (offList.songs ?? []).filter(s => s !== song);
        if (!off)
            songs.push(song);
        offList.songs = songs;
        offFile.writeAdapter();
    }
    FileView {
        id: offFile
        path: Paths.state + "/lyrics-off.json"
        property bool loaded: false
        onLoaded: loaded = true
        // A missing file is an empty list
        onLoadFailed: loaded = true
        JsonAdapter {
            id: offList
            property var songs: []
        }
    }

    // Index of the line being sung at `seconds` (-1 before the first)
    function lineAt(seconds) {
        let lo = 0, hi = lines.length - 1, found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].t <= seconds) {
                found = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return found;
    }

    Process {
        id: reader
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: root.parse(text, reader.asked)
        }
    }
}
