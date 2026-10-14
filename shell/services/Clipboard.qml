pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// cliphist history. Read only when the clipboard view opens; the wl-paste
// watchers in hypr/core/execs.lua do the storing.
// Images are decoded once per entry into Paths.clipboardCache (<id>.<ext>);
// files of entries that are gone (deleted, or rotated out by cliphist's
// max-items) are removed on the next refresh. Text entries get a line and
// character count, decoded once per entry and kept for the session.
Singleton {
    id: root

    property var entries: []    // { id, text, isImage, format, width, height, size }
    property var images: ({})   // id -> file path, once decoded
    property var stats: ({})    // id -> { lines, chars } for text entries
    property int revision: 0    // bumps when images or stats change

    // Full text of one entry for the preview pane
    property string previewId: ""
    property string previewText: ""

    function refresh() {
        list.running = true;
    }
    function copy(entry) {
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t%s' \"$1\" \"$2\" | cliphist decode | wl-copy", "_", entry.id, entry.text]);
    }
    function remove(entry) {
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t%s' \"$1\" \"$2\" | cliphist delete; rm -f \"$3\"/\"$1\".*", "_", entry.id, entry.text, Paths.clipboardCache]);
        entries = entries.filter(e => e !== entry);
    }
    function wipe() {
        Quickshell.execDetached(["bash", "-c", "cliphist wipe; rm -rf \"$1\"", "_", Paths.clipboardCache]);
        entries = [];
        images = {};
        revision++;
    }

    function imageUrl(entry) {
        revision; // dependency
        const p = images[entry.id];
        return p ? "file://" + p : "";
    }
    function statsOf(entry) {
        revision; // dependency
        return stats[entry.id] ?? null;
    }
    // "image · 1280×720 · 409 KiB" / "12 lines · 340 characters"
    function describe(entry) {
        if (entry.isImage)
            return ["image", entry.width > 0 ? entry.width + "×" + entry.height : entry.format, entry.size].filter(s => s).join(" · ");
        const s = statsOf(entry);
        if (!s)
            return "text";
        return (s.lines === 1 ? "1 line" : s.lines + " lines") + " · " + (s.chars === 1 ? "1 character" : s.chars + " characters");
    }

    function preview(entry) {
        if (!entry || entry.isImage) {
            previewId = "";
            previewText = "";
            return;
        }
        if (entry.id === previewId)
            return;
        previewId = entry.id;
        previewText = entry.text;    // the one-line preview until the decode lands
        previewDelay.restart();
    }

    function parse(text) {
        return text.split("\n").filter(l => l.includes("\t")).map(l => {
            const tab = l.indexOf("\t");
            const body = l.slice(tab + 1);
            // "[[ binary data 409 KiB png 759x748 ]]"
            const m = body.match(/^\[\[ binary data (\S+ \S+) (\S+)(?: (\d+)x(\d+))? \]\]$/);
            return {
                id: l.slice(0, tab),
                text: body,
                isImage: m !== null,
                size: m ? m[1] : "",
                format: m ? m[2] : "",
                width: m && m[3] ? parseInt(m[3]) : 0,
                height: m && m[4] ? parseInt(m[4]) : 0
            };
        });
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parse(text);
                root.decodeImages();
                root.countText();
            }
        }
    }

    // Decode the images that are not cached yet and drop files of entries
    // that are gone. Prints "<id>\t<path>" for every cached image.
    function decodeImages() {
        const imgs = entries.filter(e => e.isImage).map(e => e.id + ":" + e.format);
        decoder.command = ["bash", "-c", `
dir="$1"; shift
mkdir -p "$dir"
declare -A keep
for pair; do
    id="\${pair%%:*}"; f="$dir/$id.\${pair#*:}"
    keep[$id]=1
    if [ ! -s "$f" ]; then
        cliphist decode "$id" >"$f.part" 2>/dev/null && mv "$f.part" "$f" || { rm -f "$f.part"; continue; }
    fi
    printf '%s\\t%s\\n' "$id" "$f"
done
for f in "$dir"/*; do
    [ -e "$f" ] || continue
    n="\${f##*/}"; [ -n "\${keep[\${n%%.*}]:-}" ] || rm -f "$f"
done`, "_", Paths.clipboardCache].concat(imgs);
        decoder.running = true;
    }

    // Line and character counts for text entries not counted yet
    function countText() {
        const ids = entries.filter(e => !e.isImage && stats[e.id] === undefined).map(e => e.id);
        if (ids.length === 0)
            return;
        counter.command = ["bash", "-c", `
for id; do
    printf '%s\\t' "$id"
    cliphist decode "$id" 2>/dev/null | awk '{ c += length($0) + 1 } END { print NR "\\t" (NR ? c - 1 : 0) }'
done`, "_"].concat(ids);
        counter.running = true;
    }

    Process {
        id: decoder
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const l of text.split("\n")) {
                    const tab = l.indexOf("\t");
                    if (tab > 0)
                        map[l.slice(0, tab)] = l.slice(tab + 1);
                }
                root.images = map;
                root.revision++;
            }
        }
    }

    Process {
        id: counter
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const f = l.split("\t");
                    if (f.length === 3)
                        root.stats[f[0]] = { lines: parseInt(f[1]), chars: parseInt(f[2]) };
                }
                root.revision++;
            }
        }
    }

    // The selection moves fast with the arrows; decode only where it rests
    Timer {
        id: previewDelay
        interval: 120
        onTriggered: {
            const e = root.entries.find(x => x.id === root.previewId);
            if (!e)
                return;
            fullText.running = false;
            fullText.forId = e.id;
            fullText.command = ["bash", "-c", "printf '%s\\t%s' \"$1\" \"$2\" | cliphist decode | head -c 20000", "_", e.id, e.text];
            fullText.running = true;
        }
    }

    Process {
        id: fullText
        property string forId
        stdout: StdioCollector {
            onStreamFinished: {
                if (fullText.forId === root.previewId)
                    root.previewText = text;
            }
        }
    }
}
