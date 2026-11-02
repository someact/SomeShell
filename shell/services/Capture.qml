pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// Capture tools: freeze the screens, let the picker (capture/Picker.qml) choose
// a box, then cut it out (lib/capture.sh). Modes (the picker's bar): "shot"
// (save and copy the picture), "text" (copy the text in it), "lens" (search it
// with Google Lens in the browser), "translate" (Thai <-> English on the
// island), "color" (copy a pixel's color). `screen()` takes the whole monitor
// at once, with no picker (PrtSc). `session` is set while picking.
Singleton {
    id: root

    // { mode, monitors: [{ name, x, y, w, h, scale, file }], windows: [{ x, y, w, h, title, monitor }] }
    property var session: null
    readonly property bool picking: session !== null
    property string mode: ""
    readonly property string script: Quickshell.shellPath("lib/capture.sh")
    readonly property var modes: [
        { id: "shot", label: "Screenshot", icon: "screenshot_region", hint: "Drag a box · click a window · Enter: whole screen" },
        { id: "text", label: "Text", icon: "text_fields", hint: "Drag a box around the text to copy it" },
        { id: "lens", label: "Lens", icon: "image_search", hint: "Drag a box to search it with Google Lens" },
        { id: "translate", label: "Translate", icon: "translate", hint: "Drag a box around the text · Thai ↔ English" },
        { id: "color", label: "Color", icon: "colorize", hint: "Click a pixel to copy its color" }
    ]
    // Switch the mode while picking (the picker's bar, Tab, 1-5)
    function setMode(m) {
        if (!session || !modes.some(x => x.id === m))
            return;
        session = Object.assign({}, session, { mode: m });
    }
    function stepMode(by) {
        if (!session)
            return;
        const i = modes.findIndex(x => x.id === session.mode);
        setMode(modes[(i + by + modes.length) % modes.length].id);
    }

    function start(m) {
        if (picking || freezer.running || worker.running)
            return;
        mode = m;
        delay.interval = 350;
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
        onTriggered: root.mode === "screen" ? root.takeScreen() : freezer.running = true
    }

    // The whole monitor the mouse is on, saved and copied
    function screen() {
        if (picking || freezer.running || worker.running)
            return;
        mode = "screen";
        // The open island or the last shot's alert would be in the picture
        if (Ui.open || Ui.alert) {
            // The island springs back from an alert more slowly than it closes
            delay.interval = Ui.alert ? 800 : 350;
            Ui.close();
            Ui.alert = null;
            delay.restart();
        } else {
            takeScreen();
        }
    }
    function takeScreen() {
        const name = Hyprland.focusedMonitor?.name ?? "";
        if (!name)
            return;
        worker.kind = "shot";
        worker.command = [script, "screen", name];
        worker.running = true;
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

    // Color mode: one pixel (layout pixels inside the monitor)
    function pickColor(name, px, py) {
        const m = monitor(name);
        if (!m)
            return cancel();
        session = null;
        worker.kind = "color";
        worker.command = [script, "color", m.file, String(Math.round(px * m.scale)), String(Math.round(py * m.scale))];
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
        onExited: if (root.mode !== "screen") cleaner.running = true
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
        } else if (kind === "lens") {
            if (out.startsWith("https://")) {
                Quickshell.execDetached(["xdg-open", out]);
                Ui.showAlert("Searching with Lens", "Opened in your browser", "Capture · Lens", "image_search");
            } else {
                Ui.showAlert("Lens failed", "Google Lens did not answer", "Capture · Lens", "error");
            }
        } else if (kind === "color") {
            if (out === "")
                Ui.showAlert("No color", "", "Capture · Color", "error");
            else
                Ui.showAlert(out, "Copied", "Capture · Color", "colorize", { image: Quickshell.env("XDG_RUNTIME_DIR") + "/someshell-swatch.png?" + Date.now() });
        } else if (kind === "translate") {
            let t = null;
            try {
                t = JSON.parse(out);
            } catch (e) {}
            if (!t || !t.translation)
                Ui.showAlert(out === "" ? "No text found" : "Translate failed", out === "" ? "Nothing to translate" : "Google Translate did not answer", "Capture · Translate", "translate");
            else
                Ui.showAlert(t.translation, t.text, "Translate · " + t.from.toUpperCase() + " → " + t.to.toUpperCase() + " · copied", "translate", {
                    wide: true,
                    open: "https://translate.google.com/?sl=auto&tl=" + t.to + "&text=" + encodeURIComponent(t.text)
                });
        } else if (out === "") {
            Ui.showAlert("No text found", "Nothing was copied", "Capture", "search_off");
        } else {
            const lines = out.split("\n").filter(l => l.trim() !== "");
            Ui.showAlert("Text copied", lines.slice(0, 2).join("  "), "Capture · " + lines.length + (lines.length === 1 ? " line" : " lines"), "content_copy");
        }
    }
}
