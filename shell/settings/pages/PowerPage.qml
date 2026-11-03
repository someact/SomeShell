import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// Settings 04 Power & lock: what happens when idle (services/Idle.qml), what
// the power key does (hypr.json "power.key", read by keybinds.lua), and the
// login screen (sddm/install.sh, run in a terminal: it needs sudo).
Flickable {
    id: root

    readonly property var c: Theme.paper

    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Wheel and touch scroll; a mouse drag never does (it is for the controls)
    acceptedButtons: Qt.NoButton

    readonly property var minutes: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
    function times(none) {
        return minutes.map(m => ({ value: m, label: m < 60 ? m + (m === 1 ? " minute" : " minutes") : (m / 60) + (m === 60 ? " hour" : " hours") }))
            .concat([{ value: 0, label: none }]);
    }
    function setIdle(key, v) {
        Config.idle[key] = v;
        Idle.save();
    }

    Column {
        id: col
        width: root.width

        // ── Idle ──
        SetSection { text: "When idle" }
        SetRow {
            label: "Lock after"
            Select {
                width: 220
                options: root.times("Never")
                value: Config.idle.lock
                onPicked: v => root.setIdle("lock", v)
            }
        }
        SetRow {
            label: "Screens off after"
            Select {
                width: 220
                options: root.times("Never")
                value: Config.idle.screenOff
                onPicked: v => root.setIdle("screenOff", v)
            }
        }
        SetRow {
            label: "Sleep after"
            hint: "The session always locks before it sleeps."
            Select {
                width: 220
                options: root.times("Never")
                value: Config.idle.sleep
                onPicked: v => root.setIdle("sleep", v)
            }
        }

        // ── Power key ──
        SetSection { text: "Power key" }
        SetRow {
            label: "Pressing it"
            IconChoice {
                options: [
                    { value: "lock", icon: "lock", label: "Locks, screens off" },
                    { value: "sleep", icon: "bedtime", label: "Sleeps" },
                    { value: "ask", icon: "power_settings_new", label: "Asks" },
                    { value: "nothing", icon: "block", label: "Does nothing" }
                ]
                value: HyprConfig.getRoot(["power", "key"], "lock")
                onPicked: v => HyprConfig.setRoot(["power", "key"], v, "POWER_KEY = " + JSON.stringify(v))
            }
        }

        // ── Login screen (only with SDDM) ──
        SetSection {
            visible: root.hasSddm
            text: "Login screen"
        }
        SetRow {
            visible: root.hasSddm
            label: "SomeShell login screen"
            hint: root.sddmTheme ? "In use. Update it after a wallpaper change to take the new colors."
                : "Another theme is in use."
            SetButton {
                icon: "login"
                text: root.sddmTheme ? "Update colors" : "Install"
                onClicked: root.installSddm()
            }
        }
    }

    // ── SDDM ──
    property bool hasSddm: false
    property bool sddmTheme: false
    Process {
        id: sddmCheck
        running: true
        command: ["sh", "-c", "command -v sddm >/dev/null && echo sddm; [ -f /etc/sddm.conf.d/someshell.conf ] && echo theme; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSddm = text.includes("sddm");
                root.sddmTheme = text.includes("theme");
            }
        }
    }
    // Look again when the window comes back (after the terminal closes)
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.Window.window?.active)
                sddmCheck.running = true;
        }
    }

    // The installer needs sudo: run it in the terminal (apps.terminal in
    // hypr.json, kitty by default)
    function installSddm() {
        const term = String(HyprConfig.getRoot(["apps", "terminal"], "kitty")).split(" ").filter(s => s && s !== "-1");
        const script = 'sudo "$(realpath "$1")" || true; echo; printf "Press Enter to close. "; read -r _';
        const install = Quickshell.shellDir + "/../sddm/install.sh";
        const run = ["sh", "-c", script, "sh", install];
        Quickshell.execDetached(term[0] === "kitty" ? term.concat(["--title", "SomeShell: login screen"], run) : term.concat(["-e"], run));
    }
}
