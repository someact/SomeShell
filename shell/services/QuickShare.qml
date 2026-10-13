pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Quick Share (Nearby Share) with Android, through the helper built by
// scripts/quickshare.sh (tools/quickshare, JSON lines over a pipe; its README
// has the protocol). `available` is false until that helper exists, and
// everything that shows Quick Share hides.
//
// The helper only runs while it has something to do: receiving is on
// (Config.quickshare.enabled), files wait to be sent, or a transfer is going.
// Otherwise there is no process and no open port. Nothing is ever accepted
// without a click: an incoming transfer waits as `pending`.
Singleton {
    id: root

    property bool available: false
    readonly property bool enabled: Config.quickshare.enabled
    readonly property bool running: helper.running
    property bool ready: false                  // the helper answered

    // Devices that can receive, found while `discovering`: [{ id, name, addr, kind }]
    property var devices: []
    // Files chosen to send; a click on a device sends them
    property var outbox: []
    // Every transfer of this session, newest first:
    // { id, direction (in | out), state, device, kind, pin, files, text, textKind, destination, total, done }
    property var transfers: []
    readonly property var active: transfers.filter(t => !isOver(t.state))
    // The incoming transfer waiting for an answer (the island asks)
    readonly property var pending: transfers.find(t => t.direction === "in" && t.state === "waiting") ?? null
    // The transfer the island shows progress for
    readonly property var current: transfers.find(t => t.state === "receiving" || t.state === "sending") ?? null

    readonly property bool discovering: ready && outbox.length > 0
    readonly property bool wanted: available && !swapping && (enabled || outbox.length > 0 || active.length > 0 || handingOver)
    readonly property string downloadDir: Config.quickshare.downloadDir.replace(/^~/, Paths.home)

    readonly property string icon: "nearby"
    // Tile line: "Receiving 42%", "Visible", "Off"
    readonly property string summary: {
        if (current)
            return (current.direction === "in" ? "Receiving " : "Sending ") + Math.round(progress(current) * 100) + "%";
        if (pending)
            return "Asking…";
        return enabled ? "Visible" : "Off";
    }

    function isOver(state) {
        return state === "finished" || state === "rejected" || state === "cancelled" || state === "disconnected";
    }
    function progress(t) {
        return t && t.total > 0 ? Math.min(1, t.done / t.total) : 0;
    }
    // "photo.jpg", "3 files", "a link", "text"
    function describe(t) {
        if (!t)
            return "";
        const files = t.files ?? [];
        if (files.length === 1)
            return files[0].split("/").pop();
        if (files.length > 1)
            return files.length + " files";
        return t.textKind === "url" ? "a link" : t.textKind === "wifi" ? "a Wi-Fi network" : "text";
    }
    function size(bytes) {
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GB";
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB";
        return Math.max(1, Math.round(bytes / 1024)) + " kB";
    }
    function stateText(t) {
        return ({ connecting: "Connecting…", waiting: t.direction === "in" ? "Waiting for you" : "Waiting for the other device", receiving: "Receiving", sending: "Sending", finished: t.direction === "in" ? "Received" : "Sent", rejected: "Declined", cancelled: "Cancelled", disconnected: "Failed" })[t.state] ?? t.state;
    }

    function toggle() {
        Config.quickshare.enabled = !Config.quickshare.enabled;
    }
    function accept(id) {
        send({ cmd: "accept", id: id });
    }
    function reject(id) {
        send({ cmd: "reject", id: id });
    }
    function cancel(id) {
        send({ cmd: "cancel", id: id });
    }
    // Files to send: opens the page that lists the devices
    function offer(paths) {
        const list = paths.map(p => decodeURIComponent(String(p).replace(/^file:\/\//, ""))).filter(p => p.startsWith("/"));
        if (list.length === 0 || !available)
            return;
        outbox = Array.from(new Set(outbox.concat(list)));
        if (!pageOpen)
            UiState.openControl("quickshare");
    }
    function clearOutbox() {
        outbox = [];
    }
    function pick() {
        picker.running = true;
    }
    function sendTo(device) {
        if (outbox.length === 0 || !device.addr)
            return;
        send({ cmd: "send", id: device.id, name: device.name, addr: device.addr, files: outbox });
        // The helper has to live until the transfer shows up (the outbox was
        // what kept it running)
        handingOver = true;
        handOver.restart();
        outbox = [];
    }
    property bool handingOver: false
    Timer {
        id: handOver
        interval: 15000
        onTriggered: root.handingOver = false
    }

    function send(command) {
        if (helper.running)
            helper.write(JSON.stringify(command) + "\n");
    }

    // Bluetooth only while it is on already: the library switches the adapter on
    // whenever its Bluetooth side runs, and that is the user's call (the page
    // has the hint and the button). So there are two builds of the helper, and
    // the one in use follows Bluetooth; it is swapped while nothing transfers.
    readonly property bool ble: BluetoothState.enabled
    property bool swapping: false
    // `swapping` stops the helper; it starts again (as the other build) once it has exited
    onBleChanged: {
        if (helper.running && active.length === 0)
            swapping = true;
    }
    function discover() {
        if (!discovering)
            devices = [];
        send({ cmd: "discover", on: discovering, ble: ble });
    }
    onDiscoveringChanged: discover()

    // Files wait only while their page is open; closing it drops them, so the
    // helper does not keep searching for a send nobody is looking at
    readonly property bool pageOpen: UiState.expanded && UiState.view === "control" && UiState.controlDetail === "quickshare"
    onPageOpenChanged: if (!pageOpen) dropFiles.restart()
    // A moment later, and only if it is still closed: reopening the page (more
    // files offered while it is up) passes through "closed" for an instant
    Timer {
        id: dropFiles
        interval: 400
        onTriggered: if (!root.pageOpen && !picker.running) root.outbox = []
    }
    onEnabledChanged: send({ cmd: "visibility", value: enabled ? "visible" : "invisible" })
    onDownloadDirChanged: send({ cmd: "download", path: downloadDir })

    function onDevice(e) {
        const rest = devices.filter(d => d.id !== e.id);
        // Without an address there is nothing to send to
        devices = e.present && e.addr ? rest.concat([{ id: e.id, name: e.name || "Unknown device", addr: e.addr, kind: e.kind }]) : rest;
    }
    function onTransfer(e) {
        const old = transfers.find(t => t.id === e.id);
        // Later messages may leave out what an earlier one said
        const t = {
            id: e.id,
            direction: e.direction,
            state: e.state,
            device: e.device ?? old?.device ?? "Unknown device",
            kind: e.kind !== "unknown" ? e.kind : old?.kind ?? "unknown",
            pin: e.pin ?? old?.pin ?? "",
            files: e.files ?? old?.files ?? [],
            text: e.text ?? old?.text ?? "",
            textKind: e.text_kind ?? old?.textKind ?? "",
            destination: e.destination ?? old?.destination ?? "",
            total: e.total || old?.total || 0,
            done: e.done || old?.done || 0
        };
        if (old && isOver(old.state))
            return;
        transfers = old ? transfers.map(x => x.id === t.id ? t : x) : [t].concat(transfers).slice(0, 20);
        // Only now: the transfer is what keeps the helper running from here on
        if (t.direction === "out")
            handingOver = false;
        if (isOver(t.state) && (!old || !isOver(old.state)))
            finished(t);
    }
    // Text is copied (a link is never opened on its own); files get a notification
    function finished(t) {
        if (t.state !== "finished") {
            if (t.state === "disconnected" && t.total > 0)
                notify("Quick Share failed", describe(t) + (t.direction === "in" ? " from " : " to ") + t.device, true);
            return;
        }
        if (t.direction === "out") {
            notify("Sent to " + t.device, describe(t), false);
        } else if (t.files.length === 0 && t.text !== "") {
            Quickshell.execDetached(["wl-copy", "--", t.text]);
            notify("From " + t.device, "Copied: " + t.text.slice(0, 120), false);
        } else {
            notify("Received from " + t.device, describe(t) + " · " + (t.destination || downloadDir || "Downloads"), false);
        }
    }
    function notify(title, body, failed) {
        Quickshell.execDetached(["notify-send", "-a", "Quick Share", "-i", "folder-download"].concat(failed ? ["-u", "critical"] : [], [title, body]));
    }

    // Looked for at start, and again when scripts/quickshare.sh has built it (IPC `quickshare refresh`)
    function refresh() {
        probe.running = true;
    }
    Process {
        id: probe
        running: true
        command: ["sh", "-c", 'test -x "$1" && test -x "$1-net"', "sh", Paths.quickshare]
        onExited: code => root.available = code === 0
    }

    Process {
        id: helper
        running: root.wanted
        stdinEnabled: true
        command: [Paths.quickshare + (root.ble ? "" : "-net"), "--visibility", root.enabled ? "visible" : "invisible"].concat(root.downloadDir !== "" ? ["--download", root.downloadDir] : [])
        stdout: SplitParser {
            onRead: line => {
                let e;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                if (e.event === "ready") {
                    root.ready = true;
                    if (root.discovering)
                        root.discover();
                } else if (e.event === "device")
                    root.onDevice(e);
                else if (e.event === "transfer")
                    root.onTransfer(e);
                else if (e.event === "error")
                    console.warn("QuickShare: " + e.message);
            }
        }
        onExited: {
            root.swapping = false;
            root.ready = false;
            root.devices = [];
            // Whatever was going on ended with the helper
            root.transfers = root.transfers.map(t => root.isOver(t.state) ? t : Object.assign({}, t, { state: "disconnected" }));
        }
    }

    Process {
        id: picker
        command: ["kdialog", "--title", "Send with Quick Share", "--multiple", "--separate-output", "--getopenfilename", Paths.home]
        stdout: StdioCollector {
            onStreamFinished: root.offer(text.split("\n").filter(l => l !== ""))
        }
    }
}
