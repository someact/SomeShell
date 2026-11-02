pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// Screen recording with wf-recorder: the focused monitor, with or without
// sound, saved to ~/Videos/Recordings. While it runs the island shows it.
Singleton {
    id: root

    readonly property bool recording: proc.running
    property bool sound: false
    property real startedAt: 0
    property int seconds: 0
    property string file: ""

    function toggle(withSound) {
        if (recording) {
            stop();
            return;
        }
        sound = withSound === true;
        const dir = Paths.home + "/Videos/Recordings";
        file = dir + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss") + ".mp4";
        const output = Hyprland.focusedMonitor?.name ?? "";
        // Sound = what the computer plays (the default output's monitor), not the mic
        proc.command = ["sh", "-c",
            "mkdir -p \"$1\"; f=\"$2\"; o=\"$3\"; s=\"$4\"; set -- wf-recorder -f \"$f\"; "
            + "[ -n \"$o\" ] && set -- \"$@\" -o \"$o\"; "
            + "[ \"$s\" = 1 ] && set -- \"$@\" --audio=\"$(pactl get-default-sink).monitor\"; exec \"$@\"",
            "sh", dir, file, output, sound ? "1" : "0"];
        proc.running = true;
        startedAt = Date.now();
        seconds = 0;
    }
    function stop() {
        proc.signal(2); // SIGINT: wf-recorder finishes the file
    }

    Process {
        id: proc
        onExited: Ui.showAlert("Recording saved", root.file.replace(Paths.home, "~"), "Record", "screen_record")
    }
    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.seconds = Math.round((Date.now() - root.startedAt) / 1000)
    }
}
