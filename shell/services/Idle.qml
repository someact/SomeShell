pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// What happens when nobody uses the machine: lock, screens off, sleep after
// Config.idle's minutes (0 = never). `save()` writes the whole hypridle
// config to hypr/generated/hypridle.conf (autostart uses it when it exists)
// and restarts hypridle with it. Locking always goes through lock.sh, and
// the session always locks before sleep.
Singleton {
    id: root

    readonly property string file: Paths.hypr + "/generated/hypridle.conf"

    function listener(minutes, onTimeout, onResume) {
        if (minutes <= 0)
            return "";
        return "\nlistener {\n    timeout = " + minutes * 60 + "\n    on-timeout = " + onTimeout
            + (onResume ? "\n    on-resume = " + onResume : "") + "\n}\n";
    }

    function save() {
        const i = Config.idle;
        const on = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        const off = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
        const text = "# Written by SomeShell's settings (Power & lock). Changes here are overwritten.\n"
            + "# Lock after " + (i.lock || "never") + ", screens off after " + (i.screenOff || "never")
            + ", sleep after " + (i.sleep || "never") + " (minutes).\n\n"
            + "general {\n    lock_cmd = ~/.config/hypr/scripts/lock.sh\n    before_sleep_cmd = loginctl lock-session\n"
            + "    after_sleep_cmd = " + on + "\n    inhibit_sleep = 3\n}\n"
            + listener(i.lock, "loginctl lock-session", "")
            + listener(i.screenOff, off, on)
            + listener(i.sleep, "systemctl suspend || loginctl suspend", "");
        writer.setText(text);
        restart.restart();
    }

    // After the file is written: hypridle again, with it
    Timer {
        id: restart
        interval: 300
        onTriggered: Quickshell.execDetached(["sh", "-c", 'pkill -x hypridle; sleep 0.3; exec hypridle -c "$1"', "sh", root.file])
    }

    FileView {
        id: writer
        path: root.file
    }
}
