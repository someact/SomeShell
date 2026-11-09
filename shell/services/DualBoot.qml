pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Dual boot with Android through the A/B slots (lib/android.sh). Checked once
// at start; the power page shows "Android" only where `available`.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/lib/android.sh"
    property bool available: false

    Process {
        running: true
        command: [root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() === "android"
        }
    }

    // Sets the other slot active and restarts. Without passwordless sudo it
    // asks for the password in the terminal (apps.terminal, kitty by default).
    function go() {
        goProc.running = true;
    }
    // Test mode: say which slot it would start, nothing changes
    function plan() {
        planProc.running = true;
    }

    Process {
        id: goProc
        command: [root.script, "go"]
        stderr: StdioCollector { id: goErr }
        onExited: code => {
            if (code === 3)
                root.inTerminal();
            else if (code !== 0)
                Ui.showAlert("Android", goErr.text.trim() || "Could not switch the boot slot", "Power", "android");
        }
    }
    Process {
        id: planProc
        command: [root.script, "plan"]
        stdout: StdioCollector { id: planOut }
        stderr: StdioCollector { id: planErr }
        onExited: code => Ui.showAlert("Android", code === 0 ? "Would run: qbootctl -s " + planOut.text.trim() + ", then systemctl reboot"
            : code === 3 ? "Would ask for the password in a terminal" : planErr.text.trim(), "Power (test)", "android")
    }

    function inTerminal() {
        const term = String(HyprConfig.getRoot(["apps", "terminal"], "kitty")).split(" ").filter(s => s && s !== "-1");
        const script = 'sudo "$1" go || { echo; printf "Press Enter to close. "; read -r _; }';
        const run = ["sh", "-c", script, "sh", root.script];
        Quickshell.execDetached(term[0] === "kitty" ? term.concat(["--title", "SomeShell: Android"], run) : term.concat(["-e"], run));
    }
}
