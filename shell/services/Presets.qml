pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Presets: a whole desktop look saved under a name (~/.config/someshell/presets/
// <slug>/preset.json + thumb.png): the desktop (Desktop.snapshot()), the
// wallpaper, and light/dark with the scheme. Applying one changes it all at once.
Singleton {
    id: root

    readonly property string dir: Paths.config + "/presets"
    readonly property string script: Quickshell.shellPath("lib/preset.sh")

    // [{ slug, name, saved, thumb }] newest first; read on refresh()
    property var list: []
    readonly property string current: Desktop.preset

    function slugOf(name) {
        return name.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
            || "preset-" + Date.now().toString(36);
    }
    function find(nameOrSlug) {
        return list.find(p => p.slug === nameOrSlug || p.name === nameOrSlug) ?? null;
    }

    function refresh() {
        lister.running = true;
    }
    Process {
        id: lister
        command: [root.script, "list", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text);
                } catch (e) {
                    root.list = [];
                }
            }
        }
    }

    // Save the current look as `name` (a new preset, or over the one with that
    // name). `monitor` takes a picture of that screen for the thumbnail.
    function save(name, monitor) {
        name = (name || current || "Preset").trim();
        const slug = find(name)?.slug ?? slugOf(name);
        const preset = {
            name: name,
            saved: new Date().toISOString(),
            wallpaper: Wallpaper.path,
            theme: { mode: Config.theme.mode, scheme: Config.theme.scheme },
            desktop: Desktop.snapshot()
        };
        saver.name = name;
        saver.command = [script, "save", dir, slug, JSON.stringify(preset), monitor ?? ""];
        saver.running = true;
    }
    Process {
        id: saver
        property string name: ""
        onExited: code => {
            if (code === 0) {
                Desktop.preset = saver.name;
                Ui.showAlert("Preset saved", saver.name, "Presets", "bookmark_added");
            } else {
                Ui.showAlert("Could not save the preset", saver.name, "Presets", "error");
            }
            root.refresh();
        }
    }

    // Apply a saved preset: desktop, wallpaper and theme together
    function apply(nameOrSlug) {
        const p = find(nameOrSlug);
        reader.path = "";
        reader.path = root.dir + "/" + (p?.slug ?? slugOf(nameOrSlug)) + "/preset.json";
    }
    FileView {
        id: reader
        blockLoading: true
        printErrors: false
        onLoaded: {
            let p = null;
            try {
                p = JSON.parse(text());
            } catch (e) {}
            if (!p)
                return Ui.showAlert("Preset not readable", path, "Presets", "error");
            Desktop.load(p.desktop ?? {}, p.name ?? "");
            Wallpaper.applyLook(p.wallpaper ?? "", p.theme?.mode ?? "", p.theme?.scheme ?? "");
        }
        onLoadFailed: if (path) Ui.showAlert("No such preset", path.split("/").slice(-2, -1)[0], "Presets", "error")
    }

    function remove(nameOrSlug) {
        const p = find(nameOrSlug);
        if (!p)
            return;
        if (Desktop.preset === p.name)
            Desktop.preset = "";
        remover.command = [script, "remove", dir, p.slug];
        remover.running = true;
    }
    Process {
        id: remover
        onExited: root.refresh()
    }

    Component.onCompleted: refresh()
}
