pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keep awake: holds a systemd idle block while on, which hypridle respects
// (no lock, no screen off, no sleep). `until` (ms since epoch, 0 = forever)
// turns it off by itself.
Singleton {
    id: root

    property bool on: false
    property real until: 0

    function toggle() {
        on = !on;
        until = 0;
    }
    function forMinutes(m) {
        on = true;
        until = Date.now() + m * 60000;
        timer.interval = m * 60000;
        timer.restart();
    }

    Timer {
        id: timer
        onTriggered: if (root.until > 0) root.on = false
    }

    Process {
        running: root.on
        command: ["systemd-inhibit", "--what=idle", "--who=SomeShell", "--why=Keep awake is on", "sleep", "infinity"]
    }
}
