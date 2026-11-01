pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The emoji list (lib/emoji.tsv, built by scripts/emoji-data.sh), loaded the
// first time /emoji is used. Recently used emoji come first.
Singleton {
    id: root

    property var list: []
    property var recent: []

    // The file is read the first time /emoji opens (setting the path loads it)
    property bool wanted: false
    function load() {
        wanted = true;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        if (!q) {
            const rec = recent.map(e => list.find(x => x.emoji === e)).filter(Boolean);
            const rest = list.filter(x => !recent.includes(x.emoji));
            return rec.concat(rest).slice(0, limit ?? 40);
        }
        const words = q.split(/\s+/);
        const scored = [];
        for (const e of list) {
            const hay = e.name + " " + e.keywords;
            if (!words.every(w => hay.includes(w)))
                continue;
            const s = e.name === q ? 3 : e.name.startsWith(q) ? 2 : 1;
            scored.push({ e: e, s: s + (recent.includes(e.emoji) ? 1 : 0) });
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.slice(0, limit ?? 40).map(x => x.e);
    }

    function copy(emoji) {
        Quickshell.execDetached(["wl-copy", emoji]);
        recent = [emoji].concat(recent.filter(e => e !== emoji)).slice(0, 16);
    }

    FileView {
        id: file
        path: root.wanted ? Quickshell.shellDir + "/lib/emoji.tsv" : ""
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const f = line.split("\t");
                if (f.length >= 3)
                    out.push({ emoji: f[0], group: f[1], name: f[2], keywords: f[3] ?? "" });
            }
            root.list = out;
        }
    }
}
