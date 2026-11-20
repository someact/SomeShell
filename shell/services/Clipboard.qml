pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Clipboard history from cliphist (Hyprland's autostart stores every copy).
// Read when the clipboard page (Super+V) opens, never watched. Images are decoded once into
// ~/.cache/someshell/clipboard/<id>.png for their thumbnail. An image that is
// a screenshot the shell saved (lib/capture.sh lists them by hash in
// ~/.local/state/someshell/shots.tsv) gets its file as `file`, while it exists.
Singleton {
    id: root

    // { id, text, image, file } newest first; `image` is the cached picture,
    // `file` the saved screenshot it came from ("" when unknown or gone)
    property var entries: []
    property bool loading: false

    function refresh() {
        loading = true;
        list.running = true;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        return entries.filter(e => !q || (!e.image && e.text.toLowerCase().includes(q))).slice(0, limit ?? 8);
    }

    // Put an entry back on the clipboard
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.raw]);
    }

    // Drop one entry from the history (and its thumbnail)
    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        removal.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete; rm -f \"$2\" \"${2%.png}.sha1\"", "sh", entry.raw, entry.image || "/nonexistent"];
        removal.running = true;
    }
    Process {
        id: removal
    }

    // The whole text of one entry (the list only has its start), for a preview
    property string fullId: ""
    property string fullText: ""
    function readFull(entry) {
        if (!entry || entry.image || entry.id === fullId)
            return;
        fullId = entry.id;
        fullText = entry.text;
        full.running = false;
        full.command = ["sh", "-c", "cliphist decode \"$1\" | head -c 6000", "sh", entry.raw];
        full.running = true;
    }
    Process {
        id: full
        property string forId: ""
        onCommandChanged: forId = root.fullId
        stdout: StdioCollector {
            onStreamFinished: if (full.forId === root.fullId) root.fullText = text
        }
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const images = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const id = line.slice(0, tab);
                    const body = line.slice(tab + 1);
                    const img = /^\[\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) /i.exec(body);
                    const e = { id: id, raw: line, text: body, image: "", file: root.files[id] ?? "" };
                    if (img) {
                        e.image = Paths.cache + "/clipboard/" + id + ".png";
                        const dims = /(\d+)x(\d+)/.exec(body);
                        e.text = dims ? "Image " + dims[1] + " × " + dims[2] : "Image";
                        images.push(id);
                    }
                    out.push(e);
                    if (out.length >= 200)
                        break;
                }
                root.entries = out;
                root.loading = false;
                if (images.length) {
                    // Decode, then hash each picture once (<id>.sha1) and print
                    // "<id>\t<path>" for the ones that are saved screenshots
                    thumbs.command = ["sh", "-c",
                        "d=\"$1\"; s=\"$2\"; shift 2; mkdir -p \"$d\"; "
                        + "for id; do [ -s \"$d/$id.png\" ] || cliphist decode \"$id\" > \"$d/$id.png\" 2>/dev/null; done; "
                        + "[ -s \"$s\" ] || exit 0; "
                        + "for id; do [ -s \"$d/$id.sha1\" ] || sha1sum < \"$d/$id.png\" | cut -c1-40 > \"$d/$id.sha1\"; printf '%s\\t%s\\n' \"$id\" \"$(cat \"$d/$id.sha1\")\"; done "
                        + "| awk -F '\\t' 'NR == FNR { p[$1] = $2; next } ($2 in p) { print $1 \"\\t\" p[$2] }' \"$s\" - "
                        + "| while IFS=\"$(printf '\\t')\" read -r id p; do [ -e \"$p\" ] && printf '%s\\t%s\\n' \"$id\" \"$p\"; done",
                        "sh", Paths.cache + "/clipboard", Paths.state + "/shots.tsv", ...images];
                    thumbs.running = true;
                }
            }
        }
    }

    // Screenshot files by entry id, from the last read
    property var files: ({})
    // Counts finished decodes: a picture that was missing when first shown
    // loads again (pictures add it to their address)
    property int decoded: 0

    // Decodes images that have no cached file yet and finds saved screenshots
    Process {
        id: thumbs
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        found[line.slice(0, tab)] = line.slice(tab + 1);
                }
                root.files = found;
                root.decoded++;
                root.entries = root.entries.map(e => e.image ? Object.assign({}, e, { file: found[e.id] ?? "" }) : e);
            }
        }
    }

    // A saved screenshot's file: open it, show it in its folder, copy its path
    function openFile(entry) {
        if (entry?.file)
            Quickshell.execDetached(["xdg-open", entry.file]);
    }
    function showFile(entry) {
        if (entry?.file)
            Quickshell.execDetached([Quickshell.shellPath("lib/drop.sh"), "show", entry.file]);
    }
    function copyPath(entry) {
        if (entry?.file)
            Quickshell.execDetached(["wl-copy", "--", entry.file]);
    }
}
