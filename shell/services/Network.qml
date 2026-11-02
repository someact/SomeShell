pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.core

// Network state from NetworkManager (Quickshell.Networking, event driven).
// Joining a new secured Wi-Fi and changing DNS go through nmcli.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.nmManaged) ?? null
    readonly property bool hasWifi: wifi !== null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var activeWifi: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property bool wiredUp: wired?.connected ?? false
    readonly property bool online: wiredUp || activeWifi !== null

    // What the tile says
    readonly property string label: wiredUp ? "Ethernet" : activeWifi ? activeWifi.name : hasWifi && wifiOn ? "Not connected" : hasWifi ? "Wi-Fi off" : "Offline"
    readonly property string icon: wiredUp ? "settings_ethernet" : activeWifi ? "wifi" : hasWifi && wifiOn ? "wifi_find" : "wifi_off"

    // Networks by signal, connected first
    readonly property var networks: (wifi?.networks.values ?? []).slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    function setWifi(on) {
        Networking.wifiEnabled = on;
    }

    // Quickshell lists Wi-Fi networks only while the scanner is on: on while
    // the Internet page shows, off otherwise (a binding, so the order in which
    // pages are made and destroyed cannot leave it in the wrong state)
    readonly property bool scanning: Ui.open && Ui.page === Ui.pageIndex("control") && Ui.detail === "net"
    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanning
    }

    // Enterprise (802.1X) networks need a username as well as a password
    function enterprise(network) {
        const t = network?.security;
        return t === WifiSecurityType.Wpa2Eap || t === WifiSecurityType.WpaEap || t === WifiSecurityType.Wpa3SuiteB192;
    }
    function open(network) {
        return network?.security === WifiSecurityType.Open;
    }

    // Joining: the network being joined, and the last failure (by network name)
    property string joining: ""
    property string joinError: ""
    property string errorFor: ""

    // A saved or open network connects as it is
    function connect(network) {
        joinError = "";
        network.connect();
    }
    // A new network, or a saved one with new secrets (Edit): lib/wifi.sh
    // keeps or makes the profile; secrets go on its stdin
    function join(network, user, password) {
        if (joiner.running)
            return;
        joining = network.name;
        joinError = "";
        errorFor = "";
        joiner.secrets = (enterprise(network) ? user + "\n" : "") + password + "\n";
        joiner.command = [Quickshell.shellPath("lib/wifi.sh"), enterprise(network) ? "eap" : "psk", network.name];
        joiner.running = true;
    }
    Process {
        id: joiner
        property string secrets: ""
        stdinEnabled: true
        onStarted: {
            write(secrets);
            secrets = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const last = text.trim().split("\n").pop() ?? "";
                if (last !== "ok") {
                    root.errorFor = root.joining;
                    root.joinError = last.replace(/^error: /, "") || "could not connect";
                }
                root.joining = "";
                joiner.stdinEnabled = true;
            }
        }
    }

    // DNS for the connection in use: a list like "1.1.1.1 1.0.0.1", or "" for automatic
    property string dns: ""
    property string connectionName: ""
    function setDns(servers) {
        if (!connectionName)
            return;
        const auto = servers.trim() === "";
        // In order: save, reconnect, then read back what is in use
        dnsWriter.command = ["sh", "-c", 'nmcli connection modify "$1" ipv4.dns "$2" ipv4.ignore-auto-dns "$3" && nmcli --wait 40 connection up "$1"',
            "sh", connectionName, servers.trim(), auto ? "no" : "yes"];
        dnsWriter.running = true;
    }
    Process {
        id: dnsWriter
        onExited: root.refresh()
    }


    // Name and DNS of the connection in use, read when asked (detail page)
    function refresh() {
        readDns.running = true;
    }
    Process {
        id: readDns
        command: ["sh", "-c", "c=$(nmcli -t -f NAME,DEVICE connection show --active | grep -v ':lo$' | grep -vE ':(docker|br-|veth|tailscale)' | head -1 | cut -d: -f1); echo \"$c\"; nmcli -g ipv4.dns connection show \"$c\" 2>/dev/null; nmcli -g IP4.DNS device show 2>/dev/null | grep -v '^$' | head -2 | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.connectionName = lines[0] ?? "";
                const fixed = (lines[1] ?? "").replace(/,/g, " ").trim();
                root.dns = fixed || ((lines[2] ?? "").trim() ? lines[2].trim() + " (automatic)" : "Automatic");
            }
        }
    }
}
