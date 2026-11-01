pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Clipboard history from cliphist (Hyprland's autostart stores every copy).
// Read when /clip opens, never watched. Images are decoded once into
// ~/.cache/someshell/clipboard/<id>.png for their thumbnail.
Singleton {
    id: root

    // { id, text, image } newest first; `image` is a file path for images
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
                    const e = { id: id, raw: line, text: body, image: "" };
                    if (img) {
                        e.image = Paths.cache + "/clipboard/" + id + ".png";
                        e.text = "Image";
                        images.push(id);
                    }
                    out.push(e);
                    if (out.length >= 200)
                        break;
                }
                root.entries = out;
                root.loading = false;
                if (images.length) {
                    thumbs.command = ["sh", "-c",
                        "d=\"$1\"; shift; mkdir -p \"$d\"; for id; do [ -s \"$d/$id.png\" ] || cliphist decode \"$id\" > \"$d/$id.png\" 2>/dev/null; done",
                        "sh", Paths.cache + "/clipboard", ...images];
                    thumbs.running = true;
                }
            }
        }
    }

    // Decodes images that have no cached file yet
    Process {
        id: thumbs
        onExited: root.entries = root.entries.slice()
    }
}
