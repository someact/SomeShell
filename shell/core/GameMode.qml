pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Game mode lives in Hyprland (hypr/modes/gamemode.lua). It announces every
// change as a `custom>>someshell_gamemode,<0|1>` event; after a config reload
// (which resets it without an event) the state is read back once.
Singleton {
    id: root

    property bool active: false

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data.startsWith("someshell_gamemode,"))
                root.active = event.data.endsWith(",1");
            else if (event.name === "configreloaded")
                read.running = true;
        }
    }

    Process {
        id: read
        running: true
        command: ["hyprctl", "repl", "return GameMode and GameMode.active"]
        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "true"
        }
    }

    function toggle() {
        Hyprland.dispatch("hl.dsp.exec_cmd(\"hyprctl eval 'GameMode.toggle()'\")");
    }
}
