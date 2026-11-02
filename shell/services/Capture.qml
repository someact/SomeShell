pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Capture tools: freeze the screens, let the picker (capture/Picker.qml) choose
// a box, then cut it out (lib/capture.sh). Modes: "shot" (save and copy the
// picture), "text" (copy the text in it). `session` is set while picking.
Singleton {
    id: root

    // { mode, monitors: [{ name, x, y, w, h, scale, file }], windows: [{ x, y, w, h, title, monitor }] }
    property var session: null
    readonly property bool picking: session !== null
    property string mode: ""
    readonly property string script: Quickshell.shellPath("lib/capture.sh")

    function start(m) {
        if (picking || freezer.running || worker.running)
            return;
        mode = m;
        // The open island would be in the picture: close it and wait for it to go
        if (Ui.open) {
            Ui.close();
            delay.restart();
        } else {
            freezer.running = true;
        }
    }
    Timer {
        id: delay
        interval: 350
        onTriggered: freezer.running = true
    }
    Process {
        id: freezer
        command: [root.script, "freeze"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    s.mode = root.mode;
                    root.session = s;
                } catch (e) {
                    Ui.showAlert("Capture failed", "Could not take a picture of the screen", "Capture", "error");
                }
            }
        }
    }

    function monitor(name) {
        return session?.monitors.find(m => m.name === name) ?? null;
    }

    // The box is in layout pixels inside the monitor; the picture is full size
    function finish(name, box) {
        const m = monitor(name);
        if (!m)
            return cancel();
        const x = Math.max(0, Math.round(box.x * m.scale)), y = Math.max(0, Math.round(box.y * m.scale));
        const w = Math.min(Math.round(m.w * m.scale) - x, Math.round(box.w * m.scale));
        const h = Math.min(Math.round(m.h * m.scale) - y, Math.round(box.h * m.scale));
        const kind = session.mode;
        session = null;
        if (w < 2 || h < 2)
            return cleaner.running = true;
        worker.kind = kind;
        worker.command = [script, kind, m.file, String(x), String(y), String(w), String(h)];
        worker.running = true;
    }

    function cancel() {
        session = null;
        cleaner.running = true;
    }

    Process {
        id: worker
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: root.done(worker.kind, text)
        }
        onExited: cleaner.running = true
    }
    Process {
        id: cleaner
        command: [root.script, "clean"]
    }

    function done(kind, out) {
        out = out.trim();
        if (kind === "shot") {
            if (out === "")
                Ui.showAlert("Screenshot failed", "", "Capture", "error");
            else
                Ui.showAlert("Screenshot saved", "Copied · click to open", "Capture", "screenshot_region", { image: out, open: out });
        } else if (out === "") {
            Ui.showAlert("No text found", "Nothing was copied", "Capture", "search_off");
        } else {
            const lines = out.split("\n").filter(l => l.trim() !== "");
            Ui.showAlert("Text copied", lines.slice(0, 2).join("  "), "Capture · " + lines.length + (lines.length === 1 ? " line" : " lines"), "content_copy");
        }
    }
}
