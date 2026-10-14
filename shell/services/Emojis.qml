pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/fuzzysort.js" as Fuzzy

// The emoji list (lib/emoji.tsv, made by scripts/emoji-data.sh, shared with the
// fuzzel fallback). Held only while the emoji view is open: load() on open,
// unload() on close. Recent picks and the skin tone live in the state dir.
Singleton {
    id: root

    readonly property var groups: [
        { id: "smileys", icon: "mood", label: "Smileys" },
        { id: "people", icon: "waving_hand", label: "People" },
        { id: "animals", icon: "pets", label: "Animals" },
        { id: "food", icon: "restaurant", label: "Food" },
        { id: "travel", icon: "flight", label: "Travel" },
        { id: "activities", icon: "sports_soccer", label: "Activities" },
        { id: "objects", icon: "lightbulb", label: "Objects" },
        { id: "symbols", icon: "emoji_symbols", label: "Symbols" },
        { id: "flags", icon: "flag", label: "Flags" }
    ]
    // Skin tone modifiers U+1F3FB..1F3FF; tone 0 is the plain yellow form
    readonly property var tones: ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]

    property var entries: []      // { emoji, group, name, keywords, toned, target, kwTarget }
    property var byEmoji: ({})
    property bool loaded: false
    property var recent: []       // base emoji, newest first
    property int tone: 0
    readonly property int recentMax: 27

    function load() {
        if (!loaded)
            file.path = Quickshell.shellPath("lib/emoji.tsv");
    }
    function unload() {
        file.path = "";
        entries = [];
        byEmoji = {};
        loaded = false;
    }

    function inGroup(group) {
        return entries.filter(e => e.group === group);
    }
    function recentEntries() {
        return recent.map(r => byEmoji[r]).filter(e => e !== undefined);
    }
    function query(text, limit) {
        return Fuzzy.go(text, entries, { keys: ["target", "kwTarget"], limit: limit, threshold: 0.35 }).map(r => r.obj);
    }

    // The form to show and copy: the chosen skin tone where the emoji takes one
    function display(entry) {
        if (!entry || tone === 0 || entry.toned === "")
            return entry ? entry.emoji : "";
        return entry.toned.replace(/\u{1F3FB}/gu, tones[tone]);
    }
    function copy(entry) {
        Quickshell.execDetached(["wl-copy", "--", display(entry)]);
        recent = [entry.emoji].concat(recent.filter(r => r !== entry.emoji)).slice(0, recentMax);
        save.restart();
    }
    function setTone(t) {
        tone = t;
        save.restart();
    }

    FileView {
        id: file
        printErrors: false
        onLoaded: {
            const list = [];
            const map = {};
            for (const line of text().split("\n")) {
                const f = line.split("\t");
                if (f.length < 5)
                    continue;
                const e = { emoji: f[0], group: f[1], name: f[2], keywords: f[3], toned: f[4], target: Fuzzy.prepare(f[2]), kwTarget: Fuzzy.prepare(f[3]) };
                list.push(e);
                map[e.emoji] = e;
            }
            root.entries = list;
            root.byEmoji = map;
            root.loaded = true;
        }
    }

    Timer {
        id: save
        interval: 500
        onTriggered: state.setText(JSON.stringify({ recent: root.recent, tone: root.tone }))
    }

    FileView {
        id: state
        path: Paths.emojiState
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.recent = s.recent ?? [];
                root.tone = s.tone ?? 0;
            } catch (e) {}
        }
    }
}
