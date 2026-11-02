pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The latest lib/sysmon.sh sample for the desktop System widget, every 2 s
// while at least one live widget uses it (`users`). Copies of the widget in
// edit mode read the same sample without starting another sampler.
Singleton {
    id: root

    property int users: 0
    property var s: null

    Process {
        running: root.users > 0
        command: [Quickshell.shellPath("lib/sysmon.sh"), "2"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.s = JSON.parse(line);
                } catch (e) {}
            }
        }
    }
}
