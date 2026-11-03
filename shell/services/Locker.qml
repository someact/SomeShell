pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.core

// The lock screen's state. `lock()` locks the session (lock/Lock.qml draws a
// surface per monitor); the password is checked by PAM (`login`, as
// hyprlock). A file in the state folder marks the session locked, so a shell
// that crashed while locked locks again when it restarts (Hyprland's
// allow_session_lock_restore lets the new lock take over).
// `preview` shows the same page in an ordinary window, without locking: for
// tests and screenshots (Esc closes it).
Singleton {
    id: root

    property bool locked: false
    property bool preview: false
    // True for a moment after unlocking, so the lock is released before its
    // window goes away
    property bool leaving: false
    readonly property bool shown: locked || preview || leaving

    property string password: ""
    property int fails: 0
    property bool checking: false
    // Unlocking: the page wipes away, then the session opens
    property bool opening: false
    property date lockedAt: new Date()
    // Counts up on every wrong password (the page shakes on a change)
    property int wrongTick: 0

    readonly property string marker: Paths.state + "/locked"

    function lock() {
        if (locked)
            return;
        reset();
        preview = false;
        lockedAt = new Date();
        Ui.close();
        Keyboard.readCaps();
        mark.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && echo \"$HYPRLAND_INSTANCE_SIGNATURE\" > \"$1\"", "sh", marker];
        mark.running = true;
        locked = true;
    }

    function showPreview() {
        if (locked)
            return;
        reset();
        lockedAt = new Date();
        Ui.close();
        Keyboard.readCaps();
        preview = true;
    }

    function reset() {
        password = "";
        fails = 0;
        checking = false;
        opening = false;
        if (pam.active)
            pam.abort();
    }

    function add(text) {
        if (checking || opening)
            return;
        password += text;
    }
    function erase() {
        if (!checking && !opening)
            password = password.slice(0, -1);
    }
    // Esc: clears the field; on an empty field it closes a preview
    function cancel() {
        if (checking || opening)
            return;
        if (password === "" && preview)
            preview = false;
        password = "";
    }

    function submit() {
        if (checking || opening || password === "")
            return;
        checking = true;
        if (!pam.start()) {
            checking = false;
            wrong();
        }
    }

    function wrong() {
        fails++;
        password = "";
        wrongTick++;
        Keyboard.readCaps();
    }

    function open() {
        opening = true;
        password = "";
        openTimer.restart();
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success)
                root.open();
            else
                root.wrong();
        }
        onError: {
            root.checking = false;
            root.wrong();
        }
    }

    // The wipe plays, then the session opens
    Timer {
        id: openTimer
        interval: 420
        onTriggered: {
            root.leaving = true;
            root.locked = false;
            root.preview = false;
            root.opening = false;
            root.fails = 0;
            unmark.running = true;
            leaveTimer.restart();
        }
    }
    Timer {
        id: leaveTimer
        interval: 600
        onTriggered: root.leaving = false
    }

    Process { id: mark }
    Process {
        id: unmark
        command: ["rm", "-f", root.marker]
    }
    // Locked when the shell went away, in this same Hyprland session: lock
    // again (a marker left from an earlier session, e.g. a reboot, is not)
    Process {
        running: true
        command: ["sh", "-c", "[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && [ \"$(cat \"$1\" 2>/dev/null)\" = \"$HYPRLAND_INSTANCE_SIGNATURE\" ]", "sh", root.marker]
        onExited: code => {
            if (code === 0)
                root.lock();
        }
    }
}
