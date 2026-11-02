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

    // Known or open networks connect directly; a new secured one needs its password
    function join(network, password) {
        if (network.known || network.security === WifiSecurityType.Open || !password)
            network.connect();
        else
            run(["nmcli", "device", "wifi", "connect", network.name, "password", password]);
    }

    // DNS for the connection in use: a list like "1.1.1.1 1.0.0.1", or "" for automatic
    property string dns: ""
    property string connectionName: ""
    function setDns(servers) {
        if (!connectionName)
            return;
        const auto = servers.trim() === "";
        run(["nmcli", "connection", "modify", connectionName,
            "ipv4.dns", servers.trim(), "ipv4.ignore-auto-dns", auto ? "no" : "yes"]);
        run(["nmcli", "connection", "up", connectionName]);
        readDns.running = true;
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
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
