pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.core

// Quick Share (SomeShell.md section 5): Google's Quick Share protocol on the
// local network (fast), and Bluetooth file push as the fallback. The helper
// (share/, installed to ~/.local/lib/someshell/someshell-share) does both: it
// sends, and it answers phones that send here. It runs
// while the machine has a Bluetooth adapter and the helper is installed; it
// reads JSON commands and prints JSON events (events, not polling).
// Transfers are jobs (Jobs) on the island; an offer opens the Share page.
Singleton {
    id: root

    readonly property string helper: Paths.home + "/.local/lib/someshell/someshell-share"
    readonly property bool adapter: Bluetooth.defaultAdapter !== null
    property bool installed: false
    property bool ready: false
    readonly property bool alive: adapter && installed && ready
    // Sending works whenever the helper runs
    readonly property bool available: alive
    // Receiving on / off (the Quick Share page, the control tile): off is
    // invisible and refuses incoming files; sending and pairing still work
    readonly property bool receiving: Config.share.receive
    onReceivingChanged: write({ cmd: "receive", on: receiving })
    function toggleReceive() {
        Config.share.receive = !Config.share.receive;
        Ui.showAlert(Config.share.receive ? "Receiving on" : "Receiving off",
            Config.share.receive ? "Phones can send here" : "Not visible; incoming files are refused",
            "Quick Share", Config.share.receive ? "download" : "block");
    }
    // The page's view: "send", "browse" (choosing files) or "recent"
    property string view: "send"
    // The browser: the folder shown and the files ticked
    property string browseDir: Paths.home + "/Pictures"
    property var chosen: []
    // Opens the Quick Share page (/quickshare, the tile)
    function openPage(v) {
        view = v ?? (pending ? "send" : view === "browse" ? "send" : view);
        Ui.openPage("share");
    }

    // The last transfers, both ways: { dir, name, path, peer, via, time }
    property var history: []
    function record(entries) {
        history = entries.concat(history).slice(0, 30);
        historyFile.setText(JSON.stringify(history));
    }
    function clearHistory() {
        history = [];
        historyFile.setText("[]");
    }
    FileView {
        id: historyFile
        path: Paths.state + "/share-history.json"
        // None until the first transfer
        printErrors: false
        onLoaded: {
            try {
                root.history = JSON.parse(text());
            } catch (e) {}
        }
    }
    // What the running send is, for the history: { files, via, peer }
    property var sending: null

    // Paired devices: { address, name, icon, connected, files }
    property var devices: []
    // Quick Share runs (the network part of the helper)
    property bool quick: false
    // Phones found on the network while the Share page is open: { id, name, addr, type }
    property var nearby: []
    // Where to send: Quick Share phones first (fast), then Bluetooth devices
    // that take files, the connected ones first. { via, id, name, sub, icon, … }
    readonly property var targets: nearby.map(n => ({ via: "quick", id: n.id, name: n.name || n.addr, addr: n.addr, sub: "Quick Share · Wi-Fi", icon: n.type === "Laptop" ? "laptop" : n.type === "Tablet" ? "tablet" : "smartphone" }))
        .concat(devices.filter(d => d.files).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
            .map(d => ({ via: "bluetooth", id: d.address, name: d.name, address: d.address, sub: "Bluetooth · " + (d.connected ? "connected" : "paired") + " · slow", icon: d.icon.startsWith("computer") ? "computer" : "smartphone" })))
    // Share pages open (they search the network while open)
    property int scanUsers: 0
    readonly property bool scanningNearby: scanUsers > 0 && ready && quick
    onScanningNearbyChanged: {
        if (!scanningNearby)
            nearby = [];
        write({ cmd: "scan", on: scanningNearby });
    }
    function setScan(on) {
        scanUsers = Math.max(0, scanUsers + (on ? 1 : -1));
    }
    // Waiting for a device on the Share page: { files: [paths], url }
    property var pending: null
    // Incoming files waiting for Accept / Decline: { id, name, size, peer }
    property var offers: []
    // Devices asking to pair: { id, peer, device, passkey } (passkey "" : just a yes)
    property var pairs: []
    // Visible and pairable while a Bluetooth page is open. Counted: on a page
    // switch the new page is made before the old one goes
    property int visibleUsers: 0
    readonly property bool discoverable: visibleUsers > 0 && ready
    onDiscoverableChanged: write({ cmd: "visible", on: discoverable })
    // The page also scans while open (without the helper too)
    readonly property bool scanning: visibleUsers > 0 && (Bluetooth.defaultAdapter?.enabled ?? false)
    onScanningChanged: {
        const a = Bluetooth.defaultAdapter;
        if (a && a.discovering !== scanning)
            a.discovering = scanning;
    }

    property int sendJob: 0
    property int receiveJob: 0
    property string lastName: ""

    // From the Drop page: pick a device next
    function offer(paths, url) {
        pending = { files: paths ?? [], url: url ?? "" };
        refresh();
        openPage("send");
    }
    function refresh() {
        write({ cmd: "devices" });
    }
    // A target from `targets`
    function sendTo(t) {
        const p = pending;
        pending = null;
        Ui.close();
        if (!p || !t)
            return;
        if (p.url) {
            // A link goes as a small .url file
            urlFile.target = t;
            urlFile.command = [Quickshell.shellPath("lib/drop.sh"), "url-file", p.url];
            urlFile.running = true;
        } else {
            sendFiles(t, p.files);
        }
    }
    function sendFiles(t, files) {
        sending = { files: files, via: t.via, peer: t.name };
        if (t.via === "quick")
            write({ cmd: "qsend", id: t.id, name: t.name, addr: t.addr, files: files });
        else
            write({ cmd: "send", device: t.address, files: files });
    }
    function answer(id, yes) {
        write({ cmd: yes ? "accept" : "decline", id: id });
        const wasPair = pairs.some(p => p.id === id);
        offers = offers.filter(o => o.id !== id);
        pairs = pairs.filter(p => p.id !== id);
        if (offers.length === 0 && pairs.length === 0 && Ui.pageId === "share" && !pending && Ui.detail === "")
            Ui.close();
        // Paired from the Share page: on to the Bluetooth page, to send next
        if (wasPair && yes && Ui.pageId === "share" && pending)
            refresh();
    }
    function setVisible(on) {
        visibleUsers = Math.max(0, visibleUsers + (on ? 1 : -1));
    }
    function cancel() {
        write({ cmd: "cancel" });
    }
    function write(cmd) {
        if (helperProc.running)
            helperProc.write(JSON.stringify(cmd) + "\n");
    }

    Process {
        id: check
        command: ["test", "-x", root.helper]
        running: root.adapter
        onExited: code => root.installed = code === 0
    }
    Process {
        id: urlFile
        property var target
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.sendFiles(urlFile.target, [path]);
            }
        }
    }

    // Received files go to share.folder, else the Downloads folder
    Process {
        id: helperProc
        running: root.adapter && root.installed
        stdinEnabled: true
        command: ["sh", "-c", "exec \"$0\" \"${1:-$(xdg-user-dir DOWNLOAD 2>/dev/null || echo \"$HOME/Downloads\")}\"", root.helper, Config.share.folder]
        stdout: SplitParser {
            onRead: line => {
                let e = null;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                root.event(e);
            }
        }
        onRunningChanged: if (!running) {
            root.ready = false;
        }
    }

    function event(e) {
        switch (e.ev) {
        case "ready":
            ready = true;
            quick = e.quick === true;
            // Started receiving; switched off here when the setting says so
            if (!receiving)
                write({ cmd: "receive", on: false });
            refresh();
            if (scanningNearby)
                write({ cmd: "scan", on: true });
            break;
        case "nearby": {
            const rest = nearby.filter(n => n.id !== e.id);
            nearby = e.present ? rest.concat([{ id: e.id, name: e.name, addr: e.addr, type: e.type }]) : rest;
            break;
        }
        case "waiting":
            // The phone is asked; the same PIN shows on it
            if (!sendJob)
                sendJob = Jobs.add("send", "share", e.name, () => root.cancel());
            Jobs.update(sendJob, { title: e.name + (e.pin ? "  ·  PIN " + e.pin : ""), progress: -1, peer: "waiting for the phone" });
            break;
        case "text":
            // A link or text sent from a phone: the Drop page, with its actions
            if (e.kind === "wifi")
                Ui.showAlert("Wi-Fi from " + e.peer, e.text, "Quick Share", "wifi", { wide: true });
            else
                Drop.take(e.kind === "url" ? [e.text] : [], e.text, [], "");
            break;
        case "devices":
            devices = e.list;
            break;
        case "offer":
            offers = offers.concat([{ id: e.id, name: e.name, size: e.size, peer: e.peer || e.device, pin: e.pin ?? "", via: e.via ?? "bluetooth" }]);
            Ui.openPage("share");
            break;
        case "declined":
            offers = offers.filter(o => o.id !== e.id);
            break;
        case "pair":
            pairs = pairs.concat([{ id: e.id, peer: e.peer || e.device, device: e.device, passkey: e.passkey }]);
            // The Bluetooth page shows it itself; anywhere else the Share page does
            if (!(Ui.open && Ui.pageId === "control" && Ui.detail === "bt"))
                Ui.openPage("share");
            break;
        case "pairDone":
            pairs = pairs.filter(p => p.id !== e.id);
            refresh();
            break;
        case "progress": {
            const title = e.count > 1 ? e.name + "  " + (e.index + 1) + "/" + e.count : e.name;
            const p = e.size > 0 ? e.done / e.size : -1;
            const icon = e.via === "quick" ? "share" : "bluetooth";
            if (e.dir === "send") {
                if (!sendJob)
                    sendJob = Jobs.add("send", icon, title, () => root.cancel());
                Jobs.update(sendJob, { title: title, peer: e.peer });
                Jobs.progress(sendJob, p);
            } else {
                if (!receiveJob)
                    receiveJob = Jobs.add("receive", icon, title, () => root.cancel());
                Jobs.update(receiveJob, { title: title, peer: e.peer });
                Jobs.progress(receiveJob, p);
            }
            lastName = e.name;
            break;
        }
        case "done":
            if (e.dir === "receive") {
                endJob("receive");
                const image = /\.(png|jpe?g|gif|webp|heic|avif)$/i.test(e.path);
                record([{ dir: "receive", name: (e.count ?? 1) > 1 ? e.count + " files" : e.name, path: (e.count ?? 1) > 1 ? e.folder : e.path, peer: e.peer, via: e.via ?? "bluetooth", time: Date.now() }]);
                if ((e.count ?? 1) > 1)
                    Ui.showAlert("Received from " + e.peer, e.count + " files · click to open the folder", "Quick Share", "download_done", { open: e.folder });
                else
                    Ui.showAlert("Received from " + e.peer, e.name + " · click to open", "Quick Share", "download_done", image ? { image: e.path, open: e.path } : { open: e.path });
            }
            break;
        case "finished":
            endJob("send");
            if (sending && e.sent > 0)
                record(sending.files.slice(0, e.sent).map(f => ({ dir: "send", name: f.split("/").pop(), path: f, peer: e.peer || sending.peer, via: sending.via, time: Date.now() })));
            sending = null;
            if (e.sent > 0)
                Ui.showAlert("Sent to " + e.peer, e.sent === 1 ? lastName : e.sent + " files", "Quick Share", "send");
            break;
        case "cancelled":
            endJob(e.dir);
            Ui.showAlert("Sharing stopped", e.sent > 0 ? e.sent + " of " + e.count + " sent" : "", "Quick Share", "block");
            break;
        case "error":
            if (e.dir === "start") {
                console.warn("Quick Share: " + e.message);
                break;
            }
            endJob(e.dir);
            Ui.showAlert(e.dir === "receive" ? "Receiving failed" : "Could not send", e.message, "Quick Share", "error", { wide: (e.message ?? "").length > 40 });
            break;
        }
    }
    function endJob(dir) {
        if (dir === "send" && sendJob) {
            Jobs.finish(sendJob);
            sendJob = 0;
        } else if (dir === "receive" && receiveJob) {
            Jobs.finish(receiveJob);
            receiveJob = 0;
        }
    }
}
