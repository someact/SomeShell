pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Images in the wallpaper folder (shell.json "wallpaper.folder", default
// ~/Pictures/Wallpapers, subfolders included), listed when /wall opens.
// Thumbnails are made once with ImageMagick into ~/.cache/someshell/thumbs,
// so the picker never decodes a full-size image.
Singleton {
    id: root

    readonly property string folder: Config.wallpaper.folder || Paths.home + "/Pictures/Wallpapers"
    // The posters that ship with the shell are listed too
    readonly property string bundled: Quickshell.shellDir + "/assets/wallpapers"
    readonly property string thumbDir: Paths.cache + "/thumbs"
    // { path, name, thumb }
    property var files: []
    // Thumbnails that exist, by path: each shows as soon as it is made
    property var ready: ({})

    function refresh() {
        find.running = true;
    }

    // A random wallpaper other than the current one (Ctrl+Super+Alt+T)
    property bool pickRandom: false
    function random() {
        pickRandom = true;
        refresh();
    }
    onFilesChanged: {
        if (!pickRandom)
            return;
        pickRandom = false;
        const others = files.filter(f => f.path !== Wallpaper.path);
        if (others.length)
            Wallpaper.set(others[Math.floor(Math.random() * others.length)].path);
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        return files.filter(f => !q || f.name.toLowerCase().includes(q)).slice(0, limit ?? 12);
    }

    function thumbFor(path) {
        // Same name for the same file: path with slashes replaced
        return thumbDir + "/" + path.replace(/[^A-Za-z0-9._-]/g, "_") + ".jpg";
    }

    Process {
        id: find
        command: ["find", "-L", root.folder, root.bundled, "-maxdepth", "3", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = text.split("\n").filter(Boolean).sort();
                const list = paths.map(p => ({ path: p, name: p.split("/").pop().replace(/\.[^.]+$/, ""), thumb: root.thumbFor(p) }));
                root.files = list;
                // Pairs of (image, thumbnail) as arguments. Qt's JavaScript has no flatMap
                const args = [];
                for (const f of list)
                    args.push(f.path, f.thumb);
                make.command = ["sh", "-c",
                    "d=\"$1\"; shift; mkdir -p \"$d\"; while [ $# -gt 0 ]; do [ -s \"$2\" ] || magick \"$1[0]\" -thumbnail 320x180^ -gravity center -extent 320x180 -quality 85 \"$2\" 2>/dev/null; [ -s \"$2\" ] && echo \"$2\"; shift 2; done",
                    "sh", root.thumbDir, ...args];
                make.running = true;
            }
        }
    }

    Process {
        id: make
        stdout: SplitParser {
            onRead: line => {
                const r = Object.assign({}, root.ready);
                r[line] = true;
                root.ready = r;
            }
        }
    }
}
