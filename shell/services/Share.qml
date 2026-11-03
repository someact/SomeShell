pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.core

// Quick Share: Bluetooth file push (SomeShell.md section 5). The helper
// (share/, installed to ~/.local/lib/someshell/someshell-share) talks to
// bluez's obexd: it sends, and it answers phones that send here. It runs
// while the machine has a Bluetooth adapter and the helper is installed; it
// reads JSON commands and prints JSON events (events, not polling).
// Transfers are jobs (Jobs) on the island; an offer opens the Share page.
Singleton {
    id: root

    readonly property string helper: Paths.home + "/.local/lib/someshell/someshell-share"
    readonly property bool adapter: Bluetooth.defaultAdapter !== null
    property bool installed: false
    property bool ready: false
    readonly property bool available: adapter && installed && ready

    // Paired devices: { address, name, icon, connected, files }
    property var devices: []
    // Those that take files, the connected ones first
    readonly property var targets: devices.filter(d => d.files).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
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
        Ui.openPage("share");
    }
    function refresh() {
        write({ cmd: "devices" });
    }
    function sendTo(address) {
        const p = pending;
        pending = null;
        Ui.close();
        if (!p)
            return;
        if (p.url) {
            // A link goes as a small .url file
            urlFile.address = address;
            urlFile.command = [Quickshell.shellPath("lib/drop.sh"), "url-file", p.url];
            urlFile.running = true;
        } else {
            write({ cmd: "send", device: address, files: p.files });
        }
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
        property string address
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.write({ cmd: "send", device: urlFile.address, files: [path] });
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
            refresh();
            break;
        case "devices":
            devices = e.list;
            break;
        case "offer":
            offers = offers.concat([{ id: e.id, name: e.name, size: e.size, peer: e.peer || e.device }]);
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
            if (e.dir === "send") {
                if (!sendJob)
                    sendJob = Jobs.add("send", "bluetooth", title, () => root.cancel());
                Jobs.update(sendJob, { title: title, peer: e.peer });
                Jobs.progress(sendJob, p);
            } else {
                if (!receiveJob)
                    receiveJob = Jobs.add("receive", "bluetooth", title, () => root.cancel());
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
                Ui.showAlert("Received from " + e.peer, e.name + " · click to open", "Quick Share", "download_done", image ? { image: e.path, open: e.path } : { open: e.path });
            }
            break;
        case "finished":
            endJob("send");
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
