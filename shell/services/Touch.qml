pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Touch screens and how the machine is used now (SomeShell.md section 5,
// "Touch"). `lib/touch.sh` lists the input devices (again on every plug or
// unplug) and, only while a touch screen exists, reports which kind of device
// was used last.
//   hasTouch    a touch screen is connected
//   monitor     the monitor it maps to (the built-in panel; "" without one)
//   hasPen      a pen tablet is connected
//   hasMouse    a pointer that has moved since it was plugged in (or since
//               the shell started): a keyboard's unused mouse interface and
//               ydotool do not count
//   touchMode   the last input was a finger (a pointer, pen or keyboard
//               ends it; the shell's own uinput keys do not)
//   access      the inputs can be read (the input group); without it
//               touchMode stays false
Singleton {
    id: root

    property var touchScreens: []
    property var pens: []
    property var pointers: []      // [{ id: "event7", name }]
    property var keyboards: []
    property var used: ({})        // pointer id → true once it moved
    property bool access: true

    readonly property bool hasTouch: touchScreens.length > 0
    readonly property bool hasPen: pens.length > 0
    readonly property bool hasMouse: pointers.some(p => used[p.id] === true)
    readonly property string monitor: hasTouch ? Displays.panel : ""
    property bool touchMode: false
    property string last: ""       // touch | pen | pointer | key

    function take(line) {
        const sp = line.indexOf(" ");
        const what = sp < 0 ? line : line.slice(0, sp);
        const rest = sp < 0 ? "" : line.slice(sp + 1);
        if (what === "devices") {
            let d;
            try {
                d = JSON.parse(rest);
            } catch (e) {
                return;
            }
            touchScreens = d.touch ?? [];
            pens = d.pen ?? [];
            pointers = d.pointer ?? [];
            keyboards = d.keyboard ?? [];
            access = d.access !== false;
            // Unplugged pointers are forgotten (plugged in again: unused)
            const u = {};
            for (const p of pointers)
                if (used[p.id])
                    u[p.id] = true;
            used = u;
            if (!hasTouch)
                touchMode = false;
        } else if (what === "input") {
            const [kind, id] = rest.split(" ");
            last = kind;
            touchMode = kind === "touch";
            if (kind === "pointer" && id && !used[id]) {
                const u = Object.assign({}, used);
                u[id] = true;
                used = u;
            }
        }
    }

    Process {
        id: watcher
        running: true
        // Tied to the shell: a crash leaves no watchers behind
        command: ["setpriv", "--pdeathsig", "TERM", Quickshell.shellPath("lib/touch.sh")]
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
    }
}
