pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's settings (~/.config/someshell/shell.json). Missing keys take the
// defaults below; a change from anywhere (here, the settings window, an
// editor) is picked up live. `Config.island.shape = "float"` saves at once.
Singleton {
    id: root

    property alias island: adapter.island
    property alias theme: adapter.theme
    readonly property bool loaded: file.loaded

    FileView {
        id: file
        path: Paths.config + "/shell.json"
        watchChanges: true
        // Our own write also changes the file: ignore that echo for a moment,
        // or several settings changed in one handler would undo each other
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onAdapterUpdated: {
            lastWrite = Date.now();
            writeAdapter();
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                lastWrite = Date.now();
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                // Follow the mouse to the monitor it is on (while closed), or
                // stay on `monitor` (a monitor name; empty = the first one)
                property bool follow: true
                property string monitor: ""
                // "ears" (tab curving into the edge), "tab", or "float"
                property string shape: "ears"
                // "ink": always dark. "inverse": the opposite of the desktop
                property string color: "ink"
            }

            property JsonObject theme: JsonObject {
                property string mode: "dark"          // dark or light
                property string scheme: "scheme-smart" // matugen scheme
            }
        }
    }
}
