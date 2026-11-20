pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Keep awake: holds a systemd idle block while on, which hypridle respects
// (no lock, no screen off, no sleep).
//   session  on until turned off, or for a time (`until`, ms since epoch;
//            0 = until turned off). Kept in $XDG_RUNTIME_DIR, so it outlives
//            a shell restart and ends with the session (reboot, log out).
//   always   `Config.keepAwake.always`: on, and on again after a reboot.
Singleton {
    id: root

    readonly property bool always: Config.keepAwake.always
    property bool session: false
    property real until: 0
    readonly property bool on: always || session

    // For the tile and the page: "Always", "Until 18:30", "On", "Off"
    readonly property string status: always ? "Always"
        : !session ? "Off"
        : until > 0 ? "Until " + Qt.formatTime(new Date(until), "HH:mm") : "On"

    // The tile: off when on (also Always), else on until turned off
    function toggle() {
        if (on)
            off();
        else
            forMinutes(0);
    }
    // On for `m` minutes (0 = until turned off)
    function forMinutes(m) {
        Config.keepAwake.always = false;
        session = true;
        until = m > 0 ? Date.now() + m * 60000 : 0;
        arm();
        save();
    }
    function setAlways(v) {
        Config.keepAwake.always = v;
        if (v) {
            session = false;
            until = 0;
            arm();
            save();
        }
    }
    function off() {
        Config.keepAwake.always = false;
        session = false;
        until = 0;
        arm();
        save();
    }

    function arm() {
        timer.stop();
        if (session && until > 0) {
            const left = until - Date.now();
            if (left <= 0) {
                session = false;
                until = 0;
                return;
            }
            // Timer takes an int: a very long time is checked again later
            timer.interval = Math.min(left, 2000000000);
            timer.start();
        }
    }
    Timer {
        id: timer
        onTriggered: {
            if (Date.now() >= root.until - 500) {
                root.session = false;
                root.until = 0;
                root.save();
            } else {
                root.arm();
            }
        }
    }

    // The session part, kept over a shell restart
    function save() {
        store.setText(JSON.stringify({ session: session, until: until }) + "\n");
    }
    FileView {
        id: store
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/someshell-awake.json"
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.session = !!s.session;
                root.until = s.until || 0;
                root.arm();
            } catch (e) {}
        }
    }

    Process {
        running: root.on
        command: ["systemd-inhibit", "--no-ask-password", "--what=idle", "--who=SomeShell", "--why=Keep awake is on", "sleep", "infinity"]
    }
}
