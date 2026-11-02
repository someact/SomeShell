pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Night light through hyprsunset (Hyprland's own). On while `on`, or while
// the schedule says so when `auto` is set (shell.json nightLight: from, to).
// The schedule is checked once a minute with the clock, nothing else polls.
Singleton {
    id: root

    property bool manual: false
    readonly property bool scheduled: Config.nightLight.auto && inWindow(Clock.time)
    readonly property bool on: manual || scheduled
    readonly property int temperature: Config.nightLight.temperature

    function inWindow(t) {
        const from = Config.nightLight.from, to = Config.nightLight.to;
        return from <= to ? (t >= from && t < to) : (t >= from || t < to);
    }

    function toggle() {
        // Turning it off during the scheduled window turns the schedule off too
        if (on && scheduled)
            Config.nightLight.auto = false;
        manual = !on;
    }

    // hyprsunset runs only while the night light is on
    Process {
        id: sunset
        running: root.on
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
    onTemperatureChanged: if (on) Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(temperature)])
}
