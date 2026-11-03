pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Things dragged onto the island from other apps. While a drag is over the
// island, `over` and `label` say what it holds (the Drop state); a drop
// keeps it as `item` and opens the Drop page, which lists `actions` for its
// kind and calls `run`. lib/drop.sh does the file work.
//   item: { kind: "files"|"image"|"video"|"link"|"text"|"loading",
//           files: [{ path, name, size, mime, dir, w, h }], url, text, title, web }
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("lib/drop.sh")
    readonly property string captureScript: Quickshell.shellPath("lib/capture.sh")

    property bool over: false
    // The file being read came from the web (a browser's picture, in the cache)
    property bool fromWeb: false
    property string label: ""
    property var item: null

    // Links yt-dlp downloads. Others still open and copy.
    readonly property var videoSites: /^https?:\/\/([a-z0-9-]+\.)*(youtube\.com|youtu\.be|tiktok\.com|vimeo\.com|twitch\.tv|x\.com|twitter\.com|instagram\.com|facebook\.com|fb\.watch|dailymotion\.com|bilibili\.com|reddit\.com|soundcloud\.com|bandcamp\.com|streamable\.com)\//i
    readonly property var imageExt: /\.(png|jpe?g|gif|webp|avif|bmp|svg|tiff?|heic)$/i

    function isVideo(url) { return videoSites.test(url); }
    function siteName(url) {
        const m = url.match(/^https?:\/\/(?:www\.|m\.)?([^\/]+)/i);
        const host = m ? m[1].toLowerCase() : "";
        return host.includes("youtu") ? "YouTube" : host.split(".").slice(-2, -1)[0] ?? "";
    }
    function pathOf(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
    }

    // What a drag holds, from Qt's drag event (urls, text, formats)
    function describe(urls, text, formats) {
        urls = (urls ?? []).map(String);
        const files = urls.filter(u => u.startsWith("file://"));
        const web = urls.filter(u => /^https?:/i.test(u));
        if (files.length > 1)
            return files.length + " files";
        if (files.length === 1)
            return imageExt.test(files[0]) ? "1 image" : "1 file";
        const url = web[0] ?? (/^https?:\/\/\S+$/i.test((text ?? "").trim()) ? text.trim() : "");
        if (url) {
            if ((formats ?? []).includes("application/x-moz-file-promise-url") || imageExt.test(url.split(/[?#]/)[0]))
                return "image";
            if (isVideo(url))
                return siteName(url) + " link";
            return "link";
        }
        return text ? "text" : "something";
    }
    function hover(drag) {
        over = true;
        label = describe(drag.urls, drag.hasText ? drag.text : "", drag.formats);
    }
    function leave() {
        over = false;
    }

    // A drop on the island (also IPC `drop`): urls as strings, text, and the
    // drag's formats with the browser's picture address when it has one
    function take(urls, text, formats, imageUrl) {
        over = false;
        urls = (urls ?? []).map(String);
        text = (text ?? "").trim();
        const files = urls.filter(u => u.startsWith("file://")).map(pathOf);
        fromWeb = false;
        if (files.length > 0) {
            item = { kind: "loading", files: [], label: describe(urls, text, formats) };
            info.command = [script, "info", ...files];
            info.running = true;
        } else {
            let url = urls.find(u => /^https?:/i.test(u)) ?? (/^https?:\/\/\S+$/i.test(text) ? text : "");
            if (imageUrl || (url && imageExt.test(url.split(/[?#]/)[0]))) {
                // A picture from a browser: fetched first, then it is an image
                item = { kind: "loading", url: imageUrl || url, label: "image" };
                fetch.command = [script, "fetch", imageUrl || url];
                fetch.running = true;
            } else if (url && isVideo(url)) {
                item = { kind: "video", url: url, title: "", site: siteName(url) };
                title.command = [script, "title", url];
                title.running = true;
            } else if (url) {
                item = { kind: "link", url: url };
            } else if (text) {
                item = { kind: "text", text: text };
            } else {
                return;
            }
        }
        Ui.openPage("drop");
    }

    Process {
        id: info
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(Boolean).map(l => JSON.parse(l));
                if (list.length === 0) {
                    root.item = null;
                    return;
                }
                const image = list.length === 1 && !list[0].dir && list[0].mime.startsWith("image/");
                root.item = { kind: image ? "image" : "files", files: list, web: root.fromWeb };
            }
        }
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (!path) {
                    const url = root.item?.url ?? "";
                    root.item = { kind: "link", url: url, note: "The picture could not be downloaded" };
                    return;
                }
                root.fromWeb = true;
                info.command = [root.script, "info", path];
                info.running = true;
            }
        }
    }
    Process {
        id: title
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.item?.kind === "video")
                    root.item = Object.assign({}, root.item, { title: text.trim() });
            }
        }
    }

    // The actions for the dropped thing: { id, label, icon }
    readonly property var actions: {
        const k = item?.kind ?? "";
        const share = Share.available ? [{ id: "share", label: "Share", icon: "share" }] : [];
        if (k === "files")
            return share.concat([
                { id: "open", label: item.files.length > 1 ? "Open all" : "Open", icon: "open_in_new" },
                ...(item.files.length === 1 ? [{ id: "show", label: "Show in folder", icon: "folder_open" }] : []),
                { id: "copyFiles", label: "Copy", icon: "content_copy" }
            ]);
        if (k === "image")
            return share.concat([
                { id: "copyImage", label: "Copy image", icon: "content_copy" },
                { id: "save", label: "Save to Pictures", icon: "download" },
                { id: "wallpaper", label: "Wallpaper", icon: "wallpaper" },
                { id: "text", label: "Read text", icon: "text_fields" },
                { id: "lens", label: "Lens", icon: "image_search" },
                { id: "open", label: "Open", icon: "open_in_new" }
            ]);
        if (k === "video")
            return [
                { id: "video", label: "Download video", icon: "download" },
                { id: "audio", label: "Download audio", icon: "music_note" },
                { id: "openUrl", label: "Open", icon: "open_in_new" },
                { id: "copyText", label: "Copy link", icon: "content_copy" }
            ];
        if (k === "link")
            return [
                { id: "openUrl", label: "Open", icon: "open_in_new" },
                { id: "copyText", label: "Copy link", icon: "content_copy" }
            ].concat(Share.available ? [{ id: "shareLink", label: "Share", icon: "share" }] : []);
        if (k === "text")
            return [
                { id: "copyText", label: "Copy", icon: "content_copy" },
                { id: "translate", label: "Translate", icon: "translate" },
                { id: "search", label: "Search the web", icon: "travel_explore" },
                { id: "note", label: "Save as note", icon: "note_add" }
            ];
        return [];
    }

    function run(id) {
        const it = item;
        if (!it)
            return;
        const paths = (it.files ?? []).map(f => f.path);
        const one = paths[0] ?? "";
        const textOf = it.url || it.text || "";
        // The Share page stays open to pick a device; everything else closes
        if (id === "share" || id === "shareLink") {
            Share.offer(id === "share" ? paths : [], id === "shareLink" ? it.url : "");
            return;
        }
        Ui.close();
        switch (id) {
        case "open":
            for (const p of paths)
                Quickshell.execDetached(["xdg-open", p]);
            break;
        case "openUrl":
            Quickshell.execDetached(["xdg-open", it.url]);
            break;
        case "show":
            Quickshell.execDetached([script, "show", one]);
            break;
        case "copyFiles":
            Quickshell.execDetached([script, "copy-files", ...paths]);
            Ui.showAlert(paths.length > 1 ? paths.length + " files copied" : "File copied", "Paste it in a file manager", "Drop", "content_copy");
            break;
        case "copyText":
            Quickshell.execDetached(["wl-copy", "--", textOf]);
            Ui.showAlert(it.kind === "text" ? "Text copied" : "Link copied", textOf, "Drop", "content_copy");
            break;
        case "copyImage":
            Quickshell.execDetached([script, "copy-image", one]);
            Ui.showAlert("Image copied", it.files[0].name, "Drop", "content_copy", { image: one });
            break;
        case "search":
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(textOf)]);
            break;
        case "video":
        case "audio":
            Downloads.start(it.url, id, it.title);
            break;
        default:
            // Work with an answer: save, wallpaper, read text, Lens, translate, note
            worker.kind = id;
            worker.command = id === "save" ? [script, "save", one]
                : id === "wallpaper" ? (it.web ? [script, "save", one, "wallpaper"] : ["echo", one])
                : id === "text" || id === "lens" ? [script, "image", id, one]
                : id === "translate" ? [captureScript, "translate-text", textOf]
                : id === "note" ? [script, "note", textOf]
                : ["true"];
            worker.running = true;
        }
    }
    Process {
        id: worker
        property string kind
        stdout: StdioCollector {
            onStreamFinished: root.answer(worker.kind, text.trim())
        }
    }
    function answer(kind, out) {
        if (kind === "save") {
            if (out)
                Ui.showAlert("Saved to Pictures", out.split("/").pop() + " · click to open", "Drop", "download", { image: out, open: out });
            else
                Ui.showAlert("Could not save", "", "Drop", "error");
        } else if (kind === "wallpaper") {
            if (out)
                Wallpaper.set(out);
        } else if (kind === "note") {
            if (out)
                Ui.showAlert("Note saved", out.split("/").pop() + " · click to open", "Drop", "note_add", { open: out });
        } else if (kind === "text" || kind === "lens" || kind === "translate") {
            // The same answers as the capture picker's
            Capture.done(kind, out);
        }
    }
}
