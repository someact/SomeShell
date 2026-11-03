pragma Singleton
import QtQuick
import Quickshell

// Quick Share: Bluetooth file push (see SomeShell.md section 5). Filled in by
// the next task (the Rust helper in share/); until then nothing offers it.
Singleton {
    id: root

    readonly property bool available: false
    function offer(paths, url) {}
}
