pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// The shelf: things dropped on the island (island/Island.qml) wait here until
// they are used or dismissed, so several can be collected and sent together.
// Files stay where they are; image data, web images and link files for Quick
// Share are kept in Paths.shelfCache, which is emptied with the shelf.
// Nothing leaves the PC without a click (Lens uploads, Quick Share sends).
Singleton {
    id: root

    // { id, kind: file | image | link | text, path, url, text, name }
    // path: a local file (files, images once they are on disk); url: where a
    // link or a web image points; text: the dropped text
    property var items: []
    readonly property int count: items.length
    property var lastFormats: []   // what the last drop offered (logged too)
    property bool draggingOut: false   // an item is being dragged to another app
    property var recent: []        // recent copy/move folders, newest first
    property string downloads: Paths.home + "/Downloads"
    property string pictures: Paths.home + "/Pictures"
    property int nextId: 1

    readonly property var imageExts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "avif"]
    readonly property var mimeOf: ({ png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", webp: "image/webp", bmp: "image/bmp", avif: "image/avif" })

    function ext(name) {
        const m = String(name).toLowerCase().match(/\.([a-z0-9]+)(?:[?#].*)?$/);
        return m ? m[1] : "";
    }
    function isImage(name) {
        return imageExts.includes(ext(name));
    }
    function baseName(path) {
        return path.replace(/\/+$/, "").split("/").pop();
    }
    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    function inCache(item) {
        return item.path.startsWith(Paths.shelfCache + "/");
    }
    function home(path) {
        return path.startsWith(Paths.home) ? "~" + path.slice(Paths.home.length) : path;
    }

    // What a drag carries, for the drop target ("3 files", "Link · github.com")
    function describe(drag) {
        const urls = drag.hasUrls ? drag.urls.map(u => u.toString()) : [];
        const files = urls.filter(u => u.startsWith("file://"));
        if (files.length > 1)
            return { icon: "file_copy", text: files.length + " files" };
        if (files.length === 1) {
            const name = decodeURIComponent(baseName(files[0]));
            return { icon: isImage(name) ? "image" : "draft", text: name };
        }
        if (drag.formats.some(f => f.startsWith("image/")) || (urls.length > 0 && isImage(urls[0])))
            return { icon: "image", text: "Image" };
        if (urls.length > 0)
            return { icon: "link", text: "Link · " + hostOf(urls[0]) };
        if (drag.hasText)
            return { icon: "notes", text: "Text" };
        return { icon: "move_to_inbox", text: "" };
    }
    function hostOf(url) {
        const m = String(url).match(/^[a-z]+:\/\/([^/?#]+)/i);
        return m ? m[1] : url;
    }

    // A drop: files by path, image data written to the cache, web images
    // downloaded there, links and text kept as they are. Returns how many were added.
    function take(drop) {
        lastFormats = drop.formats;
        console.info("Shelf: drop offered", JSON.stringify(drop.formats));
        const added = [];
        const urls = drop.hasUrls ? drop.urls.map(u => u.toString()) : [];
        const files = urls.filter(u => u.startsWith("file://"));
        const webs = urls.filter(u => /^https?:\/\//i.test(u));

        for (const u of files) {
            const path = decodeURIComponent(u.slice(7));
            if (items.some(i => i.path === path))
                continue;
            added.push(make(isImage(path) ? "image" : "file", { path: path, name: baseName(path) }));
        }
        if (files.length === 0) {
            // Image data (a browser image, a screenshot tool) beats its URL: it is already here
            const format = drop.formats.find(f => /^image\/(png|jpeg|gif|webp|bmp)$/.test(f));
            const webImage = webs.find(u => isImage(u)) ?? (webs.length > 0 && /<img\b/i.test(drop.html ?? "") ? webs[0] : undefined);
            if (format) {
                const e = format === "image/jpeg" ? "jpg" : format.slice(6);
                const item = make("image", { url: webs[0] ?? "", name: webs.length > 0 ? baseName(webs[0].replace(/[?#].*$/, "")) || "Image" : "Image" });
                item.path = Paths.shelfCache + "/" + item.id + "." + e;
                writeFile(item.path, drop.getDataAsArrayBuffer(format), true);
                added.push(item);
            } else if (webImage) {
                const item = make("image", { url: webImage, name: baseName(webImage.replace(/[?#].*$/, "")) || "Image" });
                added.push(item);
                fetch(item);
            } else if (webs.length > 0) {
                for (const u of webs)
                    added.push(make("link", { url: u, name: hostOf(u) }));
            } else if (drop.hasText && drop.text.trim() !== "") {
                const t = drop.text.trim();
                if (/^https?:\/\/\S+$/i.test(t))
                    added.push(make("link", { url: t, name: hostOf(t) }));
                else
                    added.push(make("text", { text: drop.text, name: t.split("\n")[0].slice(0, 80) }));
            }
        }
        if (added.length > 0)
            items = items.concat(added);
        return added.length;
    }
    function make(kind, fields) {
        return Object.assign({ id: String(nextId++), kind: kind, path: "", url: "", text: "", name: "" }, fields);
    }
    function update(item, fields) {
        items = items.map(i => i.id === item.id ? Object.assign({}, i, fields) : i);
    }

    function remove(item) {
        if (item.path !== "" && inCache(item))
            Quickshell.execDetached(["rm", "-f", item.path]);
        items = items.filter(i => i.id !== item.id);
    }
    function clear() {
        items = [];
        Quickshell.execDetached(["rm", "-rf", Paths.shelfCache]);
    }

    // ---- Actions ----

    function copy(item) {
        switch (item.kind) {
        case "image":
            if (item.path !== "") {
                Quickshell.execDetached(["sh", "-c", 'wl-copy -t "$2" < "$1"', "sh", item.path, mimeOf[ext(item.path)] ?? "image/png"]);
                Osd.show("shelf", "content_copy", -1, "Image copied");
            }
            break;
        case "file":
            Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", fileUrl(item.path) + "\n"]);
            Osd.show("shelf", "content_copy", -1, "File copied");
            break;
        case "link":
            Quickshell.execDetached(["wl-copy", "--", item.url]);
            Osd.show("shelf", "content_copy", -1, "Link copied");
            break;
        default:
            Quickshell.execDetached(["wl-copy", "--", item.text]);
            Osd.show("shelf", "content_copy", -1, "Text copied");
        }
    }

    // Copy or move into a folder; a taken name gets an "N_" prefix (as Quick Share does).
    // A moved item leaves the shelf: it now lives in the folder.
    function copyTo(item, dir, move) {
        if (item.path === "" || dir === "")
            return;
        const verb = move && !inCache(item) ? "mv" : "cp";
        Quickshell.execDetached(["bash", "-c", `
src="$1"; dir="$2"; base="\${src##*/}"; t="$dir/$base"; n=1
mkdir -p "$dir" || exit 1
while [ -e "$t" ]; do t="$dir/\${n}_$base"; n=$((n+1)); done
if [ "$3" = mv ]; then mv -- "$src" "$t"; else cp -r -- "$src" "$t"; fi`, "_", item.path, dir, verb]);
        Osd.show("shelf", move ? "drive_file_move" : "file_copy", -1, (move ? "Moved to " : "Copied to ") + baseName(dir));
        remember(dir);
        if (move)
            remove(item);
    }
    function pickFolder(item, move) {
        picker.item = item;
        picker.move = move;
        picker.running = true;
    }
    function remember(dir) {
        if (dir === downloads || dir === pictures)
            return;
        recent = [dir].concat(recent.filter(d => d !== dir)).slice(0, 3);
        state.setText(JSON.stringify({ recent: recent }));
    }

    function quickShare(list) {
        const paths = list.filter(i => i.path !== "").map(i => i.path);
        if (paths.length > 0)
            QuickShare.offer(paths);
    }
    // The Quick Share library sends files only, so a link goes as a small text file
    function sendLink(item) {
        const path = Paths.shelfCache + "/link-" + item.id + ".txt";
        writeFile(path, item.url + "\n", false);
        QuickShare.offer([path]);
    }

    function open(item) {
        if (item.kind === "link")
            Qt.openUrlExternally(item.url);
        else if (item.path !== "")
            Qt.openUrlExternally(fileUrl(item.path));
    }
    function saveNote(item) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "\\n%s\\n" "$2" >> "$1"', "sh", Paths.notes, item.text.trim()]);
        Osd.show("shelf", "sticky_note_2", -1, "Added to notes");
    }
    function translate(item) {
        Capture.sourceText = item.text;
        Capture.translated = "";
        Capture.translate(item.text);
        UiState.open("translate");
    }
    function search(item) {
        Qt.openUrlExternally(Config.search.webSearch.replace("%s", encodeURIComponent(item.text.trim())));
    }
    function ocr(item) {
        if (item.path === "")
            return;
        ocrProc.command = ["sh", "-c", 'tesseract "$1" stdout -l "$(tesseract --list-langs | awk \'NR>1 && $1!="osd"\' | paste -sd+)" 2>/dev/null', "sh", item.path];
        ocrProc.running = true;
    }
    // Uploads the image (uguu.se, kept 3 h) and opens Google Lens on it, as the Lens region tool does
    function lens(item) {
        if (item.path === "")
            return;
        Osd.show("shelf", "image_search", -1, "Uploading to Lens…");
        Quickshell.execDetached(["sh", "-c", 'url=$(curl -sF "files[]=@$1" https://uguu.se/upload | jq -r ".files[0].url") && xdg-open "https://lens.google.com/uploadbyurl?url=$url"', "sh", item.path]);
    }

    // ---- Files ----

    function writeFile(path, data, binary) {
        writer.path = path;
        if (binary)
            writer.setData(data);
        else
            writer.setText(data);
        writer.path = "";
    }

    property var fetchQueue: []
    function fetch(item) {
        fetchQueue = fetchQueue.concat([item]);
        nextFetch();
    }
    function nextFetch() {
        if (fetcher.running || fetchQueue.length === 0)
            return;
        const item = fetchQueue[0];
        fetchQueue = fetchQueue.slice(1);
        const e = ext(item.url);
        fetcher.item = item;
        fetcher.file = Paths.shelfCache + "/" + item.id + "." + (imageExts.includes(e) ? e : "img");
        fetcher.command = ["curl", "-fsSL", "--max-time", "30", "--create-dirs", "-o", fetcher.file, item.url];
        fetcher.running = true;
    }

    FileView {
        id: writer
        preload: false
        blockWrites: true
        printErrors: false
    }

    Process {
        id: fetcher
        property var item
        property string file
        onExited: code => {
            if (root.items.some(i => i.id === fetcher.item.id)) {
                if (code === 0)
                    root.update(fetcher.item, { path: fetcher.file });
                else    // could not download: keep it as a link
                    root.update(fetcher.item, { kind: "link", name: root.hostOf(fetcher.item.url) });
            }
            root.nextFetch();
        }
    }

    Process {
        id: picker
        property var item
        property bool move
        command: ["kdialog", "--title", "Choose a folder", "--getexistingdirectory", root.downloads]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (dir !== "")
                    root.copyTo(picker.item, dir, picker.move);
            }
        }
    }

    Process {
        id: ocrProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === "") {
                    Osd.show("shelf", "document_scanner", -1, "No text found");
                    return;
                }
                Quickshell.execDetached(["wl-copy", "--", t]);
                Osd.show("shelf", "document_scanner", -1, `Copied ${t.length} characters`);
            }
        }
    }

    // The user's Downloads and Pictures folders (their names follow the language)
    Process {
        running: true
        command: ["sh", "-c", "xdg-user-dir DOWNLOAD; xdg-user-dir PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                if (l[0]?.startsWith("/") && l[0] !== Paths.home)
                    root.downloads = l[0];
                if (l[1]?.startsWith("/") && l[1] !== Paths.home)
                    root.pictures = l[1];
            }
        }
    }

    FileView {
        id: state
        path: Paths.shelfState
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text()).recent ?? [];
            } catch (e) {}
        }
    }
}
