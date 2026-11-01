pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// The wallpaper and the colors made from it. Setting a wallpaper, or changing
// light/dark or the scheme, runs matugen, which writes the palette and every
// app's colors. State: ~/.local/state/someshell/wall.json.
Singleton {
    id: root

    readonly property string path: state.path
    readonly property bool ready: file.loaded

    function set(newPath) {
        if (!newPath)
            return;
        state.path = newPath.replace(/^file:\/\//, "");
        file.writeAdapter();
        root.recolor();
    }

    // Run matugen for the current wallpaper, mode and scheme. A run already
    // going is replaced, so only the last change counts.
    function recolor() {
        if (!state.path)
            return;
        if (matugen.running)
            pending = true;
        else
            matugen.running = true;
    }
    property bool pending: false

    Process {
        id: matugen
        command: ["matugen", "image", state.path, "-c", Paths.matugenConfig,
            "-t", Config.theme.scheme, "-m", Config.theme.mode, "--source-color-index", "0"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("matugen:", text.trim())
        }
        onExited: code => {
            if (code !== 0)
                console.warn("matugen exited with", code, "for", state.path);
            if (root.pending) {
                root.pending = false;
                running = true;
            }
        }
    }

    // At start: recolor when the palette was made from another wallpaper
    // (or does not exist yet)
    function checkPalette() {
        if (file.loaded && Theme.paletteRead && state.path && Theme.image !== state.path)
            recolor();
    }
    Connections {
        target: Theme
        function onPaletteReadChanged() { root.checkPalette(); }
    }

    // Light/dark and the scheme recolor everything
    Connections {
        target: Config.theme
        function onModeChanged() { root.recolor(); }
        function onSchemeChanged() { root.recolor(); }
    }

    FileView {
        id: file
        path: Paths.state + "/wall.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.checkPalette()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.firstStart = true;
                root.takeV1();
            }
        }
        JsonAdapter {
            id: state
            property string path: ""
        }
    }

    // First start: take the wallpaper v1 used, if there was one
    property bool firstStart: false
    function takeV1() {
        if (!firstStart || !v1.loaded)
            return;
        firstStart = false;
        try {
            const old = JSON.parse(v1.text());
            if (old.path)
                root.set(old.path);
        } catch (e) {}
    }
    FileView {
        id: v1
        path: Paths.state + "/wallpaper.json"
        onLoaded: root.takeV1()
    }
}
