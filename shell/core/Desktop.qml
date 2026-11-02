pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How the desktop looks (~/.config/someshell/desktop.json): the island style,
// the dock, the control layout, widgets and workspace designs. This is what
// edit mode changes and what a preset saves (with the wallpaper and theme).
// Machine options (which monitor, calendar links) stay in shell.json (Config).
Singleton {
    id: root

    property alias island: adapter.island
    property alias dock: adapter.dock
    property alias control: adapter.control
    property alias widgets: adapter.widgets
    property alias workspaces: adapter.workspaces
    // The preset this look came from (applied or saved last); "" for none
    property alias preset: adapter.preset
    readonly property bool loaded: file.loaded

    // "notch", "plain" or "dock"
    readonly property string style: ["notch", "plain", "dock"].includes(island.style) ? island.style : "notch"

    // The whole look as plain data, for a preset
    function snapshot() {
        return {
            island: { style: island.style, color: island.color },
            dock: { enabled: dock.enabled, autoHide: dock.autoHide, pinned: dock.pinned.slice() },
            control: JSON.parse(JSON.stringify(control)),
            widgets: JSON.parse(JSON.stringify(widgets)),
            workspaces: JSON.parse(JSON.stringify(workspaces))
        };
    }

    // Take a whole look at once (a preset). Every property changes in this one
    // call, so nothing draws a half-applied desktop, and the file is written
    // through a temporary file and a rename (atomicWrites).
    function load(look, presetName) {
        const d = defaults();
        const i = Object.assign(d.island, look?.island ?? {});
        const k = Object.assign(d.dock, look?.dock ?? {});
        island.style = i.style;
        island.color = i.color;
        dock.enabled = k.enabled;
        dock.autoHide = k.autoHide;
        dock.pinned = k.pinned;
        control = look?.control ?? d.control;
        widgets = look?.widgets ?? d.widgets;
        workspaces = look?.workspaces ?? d.workspaces;
        preset = presetName ?? "";
        file.lastWrite = Date.now();
        file.writeAdapter();
    }

    function defaults() {
        return {
            island: { style: "notch", color: "ink" },
            dock: { enabled: false, autoHide: true, pinned: [] },
            control: [],
            widgets: [],
            workspaces: []
        };
    }

    FileView {
        id: file
        path: Paths.config + "/desktop.json"
        watchChanges: true
        atomicWrites: true
        // Our own write changes the file too: ignore that echo for a moment
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onAdapterUpdated: {
            lastWrite = Date.now();
            writeAdapter();
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                old.path = Paths.config + "/shell.json";
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                property string style: "notch"   // notch, plain or dock
                property string color: "ink"     // ink: always dark; inverse: the opposite of the desktop
            }
            property JsonObject dock: JsonObject {
                // The separate dock bar with Notch and Plain (Dock style has its own)
                property bool enabled: false
                property bool autoHide: true
                property var pinned: []          // desktop entry ids
            }
            // Control tiles in order: [{ id, size: "1x1" | "2x1" | "2x2" }]; empty = the default layout
            property var control: []
            property var widgets: []
            property var workspaces: []
            property string preset: ""
        }
    }

    // First start: take the island shape and color from shell.json, where
    // they lived before edit mode (ears and tab → notch, float → plain)
    FileView {
        id: old
        blockLoading: true
        printErrors: false
        onLoaded: root.migrate(text())
        onLoadFailed: root.migrate("")
    }
    function migrate(text) {
        let island = {};
        try {
            island = JSON.parse(text).island ?? {};
        } catch (e) {}
        const look = defaults();
        look.island.style = island.shape === "float" ? "plain" : "notch";
        look.island.color = island.color === "inverse" ? "inverse" : "ink";
        load(look, "");
    }
}
