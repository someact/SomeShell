pragma Singleton

import QtQuick
import Quickshell

// Power and session actions.
Singleton {
    // Settings app: raise the running one, or start it (optionally on a page)
    function openSettings(page) {
        const app = Quickshell.shellPath("settings.qml");
        Quickshell.execDetached(["sh", "-c", `qs -p "$1" ipc call settingsApp focus "$2" 2>/dev/null || SOMESHELL_SETTINGS_PAGE="$2" qs -p "$1"`, "sh", app, page ?? ""]);
    }

    function lock() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function logout() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }
    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
    function firmware() {
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }
}
