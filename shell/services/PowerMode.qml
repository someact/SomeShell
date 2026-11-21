pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Power mode through power-profiles-daemon (Quickshell's PowerProfiles,
// D-Bus events). `available` is false without the daemon.
Singleton {
    id: root

    property bool available: false
    readonly property int profile: PowerProfiles.profile
    readonly property bool saver: available && profile === PowerProfile.PowerSaver

    // The modes this machine offers, in order
    readonly property var modes: {
        const list = [
            { id: "saver", label: "Power saver", icon: "energy_savings_leaf", value: PowerProfile.PowerSaver },
            { id: "balanced", label: "Balanced", icon: "balance", value: PowerProfile.Balanced }
        ];
        if (PowerProfiles.hasPerformanceProfile)
            list.push({ id: "performance", label: "Performance", icon: "bolt", value: PowerProfile.Performance });
        return list;
    }
    readonly property var current: modes.find(m => m.value === profile) ?? modes[1]
    readonly property string label: available ? current.label : "No power modes"

    function set(id) {
        const m = modes.find(m => m.id === id);
        if (available && m)
            PowerProfiles.profile = m.value;
    }
    // The tile: Power saver on, or back to Balanced
    function toggleSaver() {
        set(saver ? "balanced" : "saver");
    }

    // Once: is the daemon there?
    Process {
        running: true
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1"]
        onExited: code => root.available = code === 0
    }
}
