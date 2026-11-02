pragma Singleton
import QtQuick
import Quickshell
import qs.core

// Edit mode's memory: every change first records the look as it was, so
// Undo can step back; `edited` says the look differs from its preset.
Singleton {
    id: root

    property var history: []
    property bool edited: false
    readonly property bool canUndo: history.length > 0

    function look() {
        return { desktop: Desktop.snapshot(), wallpaper: Wallpaper.path, mode: Config.theme.mode, scheme: Config.theme.scheme };
    }

    // Call before changing anything
    function record() {
        history = history.concat([look()]).slice(-40);
        edited = true;
    }

    function undo() {
        if (!history.length)
            return;
        const l = history[history.length - 1];
        history = history.slice(0, -1);
        Desktop.load(l.desktop, Desktop.preset);
        // matugen only when the colors change
        if (l.wallpaper !== Wallpaper.path || l.mode !== Config.theme.mode || l.scheme !== Config.theme.scheme)
            Wallpaper.applyLook(l.wallpaper, l.mode, l.scheme);
        if (!history.length)
            edited = false;
    }

    // A fresh start each time edit mode opens; applying or saving a preset
    // makes the look match it again
    function start() {
        history = [];
        edited = false;
    }
    function matched() {
        edited = false;
    }
}
