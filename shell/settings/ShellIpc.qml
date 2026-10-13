pragma Singleton

import QtQuick
import Quickshell

// Actions that belong to the running shell (matugen, wallpaper, island views)
// go over IPC, so the settings process never runs a second copy of a service.
Singleton {
    function call(target, fn, ...args) {
        Quickshell.execDetached(["qs", "-c", "someshell", "ipc", "call", target, fn].concat(args.map(String)));
    }
}
