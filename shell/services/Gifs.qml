pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// GIF search for /gif over Klipy or Giphy (Config.gif; both need a free key,
// Tenor closed its API in June 2026). Nothing is fetched until a search is
// typed, and the results are dropped when the view closes (clear()).
// Previews are downloaded with curl into Paths.gifPreviews and played from
// there: an AnimatedImage on a network URL with cache: false recurses until
// the stack overflows (Qt 6.12, crashed the shell), and cache: true holds
// every frame (~150 MB for one page). The folder goes with the view.
// Copy downloads the GIF into Paths.gifCache and puts it on the clipboard as a
// file (text/uri-list), which chat apps paste as an upload; save downloads it
// into Config.gif.saveDir. SOMESHELL_GIF_FIXTURE (a JSON file in the chosen
// service's format) replaces the network for tests.
Singleton {
    id: root

    readonly property string service: Config.gif.service === "giphy" ? "giphy" : "klipy"
    readonly property string serviceName: service === "giphy" ? "GIPHY" : "KLIPY"
    readonly property string signupUrl: service === "giphy" ? "https://developers.giphy.com/dashboard/" : "https://partner.klipy.com/"
    readonly property bool hasKey: Config.gif.key.trim() !== "" || fixture !== ""
    readonly property string fixture: Quickshell.env("SOMESHELL_GIF_FIXTURE") || ""
    readonly property string saveDir: (Config.gif.saveDir || Paths.home + "/Pictures/gif").replace(/^~/, Paths.home)
    readonly property int perPage: 24

    property string query: ""
    property var results: []      // { id, title, preview, width, height, copyUrl, saveUrl }
    property string status: "idle"    // idle | loading | ready | error
    property string error: ""
    property int page: 1
    property bool hasMore: false
    property string seed: ""      // /gif <words> hands the words to the view
    property var previews: ({})   // id -> local file, once downloaded
    property int revision: 0      // bumps when previews changes
    property var queue: []        // { id, url } waiting for the downloader

    function search(text) {
        const q = text.trim();
        if (q === query && status !== "error")
            return;
        query = q;
        results = [];
        queue = [];
        page = 1;
        hasMore = false;
        fetch();
    }
    function more() {
        if (!hasMore || status === "loading")
            return;
        page++;
        fetch();
    }
    function clear() {
        request.running = false;
        downloader.running = false;
        queue = [];
        previews = {};
        revision++;
        Quickshell.execDetached(["rm", "-rf", Paths.gifPreviews]);
        query = "";
        results = [];
        status = "idle";
        error = "";
        hasMore = false;
    }

    function url() {
        const q = encodeURIComponent(query);
        const key = encodeURIComponent(Config.gif.key.trim());
        const lang = Qt.locale().name.split("_")[0] || "en";
        if (service === "giphy")
            return `https://api.giphy.com/v1/gifs/search?api_key=${key}&q=${q}&limit=${perPage}&offset=${(page - 1) * perPage}&rating=pg-13&lang=${lang}`;
        // customer_id: Klipy wants a stable id per user; a hash, not the name
        return `https://api.klipy.com/api/v1/${key}/gifs/search?q=${q}&per_page=${perPage}&page=${page}&locale=${lang}&content_filter=medium&customer_id=${Qt.md5(Paths.home)}`;
    }

    function fetch() {
        request.running = false;
        if (query === "") {
            status = "idle";
            return;
        }
        if (!hasKey) {
            status = "error";
            error = "nokey";
            return;
        }
        status = "loading";
        error = "";
        request.forQuery = query;
        request.forPage = page;
        request.command = ["curl", "-sSL", "--max-time", "15", fixture !== "" ? "file://" + fixture : url()];
        request.running = true;
    }

    function parse(text) {
        const j = JSON.parse(text);
        if (service === "giphy") {
            // A bad key still answers with an empty list; meta.status says why
            if ((j.meta?.status ?? 200) >= 400 || !Array.isArray(j.data))
                throw new Error("GIPHY: " + (j.meta?.msg || j.message || "unexpected answer") + ((j.meta?.status === 401 || j.meta?.status === 403) ? " (check the API key in Settings → Island)" : ""));
            const total = j.pagination?.total_count ?? 0;
            hasMore = (j.pagination?.offset ?? 0) + j.data.length < total;
            return j.data.filter(g => g.images?.fixed_width?.url).map(g => ({
                id: "giphy-" + g.id,
                title: g.title || "",
                preview: g.images.fixed_width.url,
                width: parseInt(g.images.fixed_width.width) || 200,
                height: parseInt(g.images.fixed_width.height) || 200,
                copyUrl: (g.images.downsized_medium ?? g.images.original).url,
                saveUrl: g.images.original.url
            }));
        }
        if (j.result === false)
            throw new Error(j.errors?.message?.[0] || "Unexpected answer");
        const items = j.data?.data ?? [];
        hasMore = j.data?.has_next === true;
        // Ads come in the same list without a file; they are left out
        return items.filter(g => g.file?.sm?.gif?.url).map(g => ({
            id: "klipy-" + g.id,
            title: g.title || "",
            preview: g.file.sm.gif.url,
            width: g.file.sm.gif.width || 200,
            height: g.file.sm.gif.height || 200,
            copyUrl: (g.file.md?.gif ?? g.file.sm.gif).url,
            saveUrl: (g.file.hd?.gif ?? g.file.md?.gif ?? g.file.sm.gif).url
        }));
    }

    // Local preview URL, "" until it is downloaded
    function previewUrl(item) {
        revision; // dependency
        const p = previews[item.id];
        return p ? "file://" + p : "";
    }
    function download(list) {
        queue = queue.concat(list.filter(g => !previews[g.id]).map(g => ({ id: g.id, url: g.preview })));
        nextDownload();
    }
    function nextDownload() {
        if (downloader.running || queue.length === 0)
            return;
        const batch = queue;
        queue = [];
        let args = ["curl", "-sS", "--fail", "--location", "--max-time", "30", "--create-dirs", "--parallel", "--parallel-max", "6", "-w", "%{http_code} %{filename_effective}\\n"];
        for (const g of batch)
            args = args.concat(["-o", Paths.gifPreviews + "/" + g.id + ".gif", g.url]);
        downloader.command = args;
        downloader.running = true;
    }

    function fileName(item) {
        const slug = item.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48);
        return (slug ? slug + "-" : "") + item.id + ".gif";
    }

    // Download in the background, then copy as a file. Cached copies older than
    // a day are removed (the clipboard only needs the newest).
    function copy(item) {
        Quickshell.execDetached(["bash", "-c", `
dir="$1"; f="$dir/$2"
mkdir -p "$dir" && find "$dir" -name '*.gif' -mtime +1 -delete
if [ -s "$f" ] || { curl -fsSL --max-time 30 -o "$f.part" "$3" && mv "$f.part" "$f"; }; then
    printf 'file://%s\\n' "$f" | wl-copy -t text/uri-list
else
    rm -f "$f.part"; notify-send -a GIF -u critical "GIF not copied" "The download failed"
fi`, "_", Paths.gifCache, fileName(item), item.copyUrl]);
    }
    function save(item) {
        Quickshell.execDetached(["bash", "-c", `
f="$1/$2"
if mkdir -p "$1" && curl -fsSL --max-time 60 -o "$f.part" "$3" && mv "$f.part" "$f"; then
    notify-send -a GIF -i image-gif "GIF saved" "$f"
else
    rm -f "$f.part"; notify-send -a GIF -u critical "GIF not saved" "The download failed"
fi`, "_", saveDir, fileName(item), item.saveUrl]);
    }

    Process {
        id: request
        property string forQuery
        property int forPage
        stdout: StdioCollector {
            onStreamFinished: {
                if (request.forQuery !== root.query || request.forPage !== root.page)
                    return;
                try {
                    const list = root.parse(text);
                    root.results = request.forPage === 1 ? list : root.results.concat(list);
                    root.download(list);
                    root.status = "ready";
                } catch (e) {
                    if (root.status === "error")
                        return;    // curl already said why
                    root.status = "error";
                    root.error = text.trim() === "" ? "No answer from " + root.serviceName : String(e.message ?? e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "" && request.forQuery === root.query) {
                    root.status = "error";
                    root.error = text.trim().split("\n").pop().replace(/^curl: \(\d+\) /, "");
                }
            }
        }
    }

    // One line per finished preview: "<http code> <file>"
    Process {
        id: downloader
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ");
                if (line.slice(0, sp) !== "200")
                    return;
                const file = line.slice(sp + 1);
                root.previews[file.slice(file.lastIndexOf("/") + 1, -4)] = file;
                root.revision++;
            }
        }
        onExited: root.nextDownload()
    }
}
