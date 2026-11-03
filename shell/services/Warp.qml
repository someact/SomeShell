pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cloudflare WARP through warp-cli: connected or not, and the mode. Only
// when warp-cli is installed (and its service runs). The status follows
// `warp-cli -l status` (one line per change); the mode is read from the
// settings at start and after each change made here.
Singleton {
    id: root

    property bool installed: false
    // Connected, Connecting, Disconnected, … ("" until the service answers)
    property string status: ""
    property string reason: ""
    property string mode: "warp"
    property int proxyPort: 40000
    readonly property bool connected: status === "Connected"
    readonly property bool busy: status === "Connecting" || status === "Disconnecting"
    readonly property bool on: connected || status === "Connecting"

    // Every mode warp-cli has, in the order the page shows them
    readonly property var modes: [
        { id: "warp", label: "WARP", sub: "Everything through Cloudflare", icon: "vpn_lock" },
        { id: "warp+doh", label: "WARP + DoH", sub: "Tunnel, names over HTTPS", icon: "vpn_lock" },
        { id: "warp+dot", label: "WARP + DoT", sub: "Tunnel, names over TLS", icon: "vpn_lock" },
        { id: "doh", label: "DNS only (DoH)", sub: "1.1.1.1 over HTTPS, no tunnel", icon: "dns" },
        { id: "dot", label: "DNS only (DoT)", sub: "1.1.1.1 over TLS, no tunnel", icon: "dns" },
        { id: "proxy", label: "Proxy", sub: "SOCKS5 on localhost", icon: "lan" },
        { id: "tunnel_only", label: "Tunnel only", sub: "Tunnel, your own DNS", icon: "route" }
    ]
    function modeInfo(id) {
        return modes.find(m => m.id === id) ?? { id: id, label: id, sub: "", icon: "vpn_lock" };
    }
    readonly property string modeLabel: modeInfo(mode).label
    // Short text for the tile
    readonly property string label: !installed ? "Not installed"
        : status === "" ? "No service"
        : status === "Connected" ? modeLabel
        : status === "Connecting" ? "Connecting…"
        : "Off"

    function setOn(v) {
        if (!installed)
            return;
        // Shown at once; the stream confirms
        status = v ? "Connecting" : "Disconnecting";
        Quickshell.execDetached(["warp-cli", v ? "connect" : "disconnect"]);
    }
    function toggle() { setOn(!on); }
    function setMode(id) {
        if (!installed || !modes.some(m => m.id === id) || id === mode)
            return;
        mode = id;
        setter.command = ["warp-cli", "mode", id];
        setter.running = true;
    }
    function refresh() {
        if (installed && !reader.running)
            reader.running = true;
    }

    // Installed?
    Process {
        running: true
        command: ["sh", "-c", "command -v warp-cli"]
        onExited: code => {
            root.installed = code === 0;
            root.refresh();
        }
    }

    // Status: one line per change ("Status update: Connected", "Reason: …").
    // The stream ends when the service stops; try again a little later.
    Process {
        id: stream
        running: root.installed
        command: ["warp-cli", "-l", "--no-paginate", "status"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^Status update:\s*(.+)$/);
                if (m) {
                    root.status = m[1].trim();
                    root.reason = "";
                    return;
                }
                const r = line.match(/^Reason:\s*(.+)$/);
                if (r)
                    root.reason = r[1].trim();
            }
        }
        onExited: {
            root.status = "";
            retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 10000
        onTriggered: stream.running = root.installed
    }

    Process {
        id: reader
        command: ["warp-cli", "-j", "--no-paginate", "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text).settings;
                    root.mode = s.operation_mode ?? root.mode;
                    root.proxyPort = s.proxy_port ?? s.warp_proxy_port ?? 40000;
                } catch (e) {}
            }
        }
    }
    Process {
        id: setter
        onExited: root.refresh()
    }
}
