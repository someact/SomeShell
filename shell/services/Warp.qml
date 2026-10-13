pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cloudflare WARP through warp-cli; `available` is false when it is not
// installed, and everything that shows WARP hides. `warp-cli -l status`
// streams every status change, so nothing polls. The mode is not in that
// stream; it is read from `settings` at start and after each status change
// (another client may have changed it).
Singleton {
    id: root

    property bool available: false      // warp-cli is installed
    readonly property bool service: listener.running    // the daemon (warp-svc) answers
    property string status: ""          // Connected | Connecting | Disconnected | Unable | ...
    property string reason: ""          // NetworkHealthy, Manual, RegistrationMissing, ...
    property string mode: ""            // one of `modes`
    readonly property bool connected: status === "Connected"
    readonly property bool connecting: status === "Connecting"
    readonly property bool registered: service && !/registration/i.test(reason)

    // warp-cli mode names. Tunnel modes route traffic; the DNS-only ones just encrypt lookups
    readonly property var modes: [
        { id: "warp", name: "WARP", note: "All traffic through the tunnel", icon: "vpn_lock" },
        { id: "warp+doh", name: "WARP + DoH", note: "Tunnel, DNS over HTTPS", icon: "vpn_lock" },
        { id: "warp+dot", name: "WARP + DoT", note: "Tunnel, DNS over TLS", icon: "vpn_lock" },
        { id: "doh", name: "DNS over HTTPS", note: "1.1.1.1 only, no tunnel", icon: "dns" },
        { id: "dot", name: "DNS over TLS", note: "1.1.1.1 only, no tunnel", icon: "dns" },
        { id: "proxy", name: "Proxy", note: "Tunnel as a local SOCKS5 proxy", icon: "lan" },
        { id: "tunnel_only", name: "Tunnel only", note: "Tunnel without DNS proxying", icon: "vpn_key" }
    ]
    readonly property string modeName: modes.find(m => m.id === mode)?.name ?? mode
    readonly property string icon: connected ? "vpn_lock" : "vpn_key_off"
    // Tile and detail line: "DNS over HTTPS", "Connecting…", "Off", "Not registered"
    readonly property string summary: {
        if (!service)
            return "Service not running";
        if (!registered)
            return "Not registered";
        if (connected)
            return modeName || "On";
        if (connecting)
            return "Connecting…";
        return "Off";
    }

    function toggle() {
        run([connected || connecting ? "disconnect" : "connect"]);
    }
    function setMode(id) {
        if (!modes.some(m => m.id === id) || id === mode)
            return;
        mode = id;                      // shown at once; the read after the command corrects it
        run(["mode", id]);
    }
    // One command at a time; a click made while one runs replaces whatever waits
    property var _next: null
    function run(args) {
        if (!service)
            return;
        if (cli.running) {
            _next = args;
            return;
        }
        cli.command = ["warp-cli", "--accept-tos"].concat(args);
        cli.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v warp-cli"]
        onExited: code => {
            root.available = code === 0;
            listener.running = root.available;
        }
    }

    // One JSON object per status change (pretty-printed over several lines by
    // some versions, so lines are collected until they parse)
    Process {
        id: listener
        property string buffer: ""
        command: ["warp-cli", "--accept-tos", "-l", "-j", "status"]
        stdout: SplitParser {
            onRead: line => {
                listener.buffer += line;
                let s;
                try {
                    s = JSON.parse(listener.buffer);
                } catch (e) {
                    if (listener.buffer.length > 4000)
                        listener.buffer = "";
                    return;
                }
                listener.buffer = "";
                if (typeof s.status !== "string")
                    return;
                root.status = s.status;
                root.reason = typeof s.reason === "string" ? s.reason : "";
                settings.running = true;
            }
        }
        // The daemon stopped (or is not started yet): look again in a while
        onExited: {
            buffer = "";
            root.status = "";
            root.reason = "";
            retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 30000
        onTriggered: listener.running = root.available
    }

    Process {
        id: settings
        command: ["warp-cli", "--accept-tos", "-j", "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text).settings.operation_mode;
                    if (typeof m === "string")
                        root.mode = m.toLowerCase();
                } catch (e) {}
            }
        }
    }

    Process {
        id: cli
        stderr: StdioCollector {
            id: cliErr
        }
        onExited: code => {
            if (code !== 0)
                console.warn("Warp: " + command.slice(2).join(" ") + " failed: " + cliErr.text.trim());
            if (root._next) {
                const args = root._next;
                root._next = null;
                root.run(args);
            } else {
                settings.running = true;
            }
        }
    }
}
