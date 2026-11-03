pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The keyboard: the active layout as a short code (EN, TH) from Hyprland's
// events (read once at start), and Caps Lock when asked (`readCaps()`:
// Hyprland sends no event for it).
Singleton {
    id: root

    property string code: ""
    property bool caps: false

    function next() { switcher.running = true; }
    function readCaps() { devices.running = true; }

    function from(name) {
        if (!name)
            return "";
        if (/^english/i.test(name))
            return "EN";
        return name.replace(/[^A-Za-z]/g, "").slice(0, 2).toUpperCase();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.code = root.from(event.data.split(",").slice(1).join(","));
        }
    }
    Process {
        id: switcher
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }
    Process {
        id: devices
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards ?? [];
                    const main = kb.find(k => k.main) ?? kb[0];
                    root.code = root.from(main?.active_keymap ?? "");
                    root.caps = main?.capsLock ?? false;
                } catch (e) {}
            }
        }
    }
}
