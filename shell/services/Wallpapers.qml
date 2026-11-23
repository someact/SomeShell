pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Wallpapers in the wallpaper folder (shell.json "wallpaper.folder", default
// ~/Pictures/Wallpapers, subfolders included), listed when /wall or the
// Wallpaper tab opens: pictures, videos, and Wallpaper Engine folders dropped
// there as they came (lib/wallpapers.sh). Web and application wallpapers are
// listed as "unsupported" and never chosen.
// Thumbnails are made once with ImageMagick into ~/.cache/someshell/thumbs,
// so the picker never decodes a full-size image.
Singleton {
    id: root

    readonly property string folder: Config.wallpaper.folder || Paths.home + "/Pictures/Wallpapers"
    // The posters that ship with the shell are listed too
    readonly property string bundled: Quickshell.shellDir + "/assets/wallpapers"
    readonly property string thumbDir: Paths.cache + "/thumbs"
    // { path, name, thumb, kind: image | video | scene | unsupported,
    //   preview: the picture the thumbnail is made from (maybe a gif), added: seconds }
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
        const others = files.filter(f => f.kind !== "unsupported" && f.path !== Wallpaper.path);
        if (others.length)
            Wallpaper.set(others[Math.floor(Math.random() * others.length)].path);
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        return files.filter(f => f.kind !== "unsupported" && (!q || f.name.toLowerCase().includes(q))).slice(0, limit ?? 12);
    }

    function thumbFor(path) {
        // Same name for the same file: path with slashes replaced
        return thumbDir + "/" + path.replace(/[^A-Za-z0-9._-]/g, "_") + ".jpg";
    }

    Process {
        id: find
        // kind, path, name, picture for the thumbnail, when added (lib/wallpapers.sh)
        command: [Quickshell.shellPath("lib/wallpapers.sh"), root.folder, root.bundled]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(Boolean);
                const list = [];
                const args = [];
                for (const line of lines) {
                    const parts = line.split("\t");
                    if (parts.length < 4)
                        continue;
                    const kind = parts[0];
                    const path = parts[1];
                    const name = parts[2];
                    const preview = parts[3];
                    const thumb = root.thumbFor(path);
                    list.push({ path: path, name: name, thumb: thumb, kind: kind, preview: preview, added: Number(parts[4] ?? 0) || 0 });
                    args.push(preview || path, thumb);
                }
                root.files = list;
                make.command = ["sh", "-c",
                    "d=\"$1\"; shift; mkdir -p \"$d\"; while [ $# -gt 0 ]; do " +
                    "src=\"$1\"; dst=\"$2\"; " +
                    "if [ ! -s \"$dst\" ] && [ -f \"$src\" ]; then " +
                    "  case \"$(printf '%s' \"$src\" | tr 'A-Z' 'a-z')\" in " +
                    "    *.mp4|*.webm|*.mkv|*.mov) " +
                    "      ffmpeg -y -loglevel error -ss 00:00:01 -i \"$src\" -frames:v 1 -vf 'scale=320:180:force_original_aspect_ratio=increase,crop=320:180' \"$dst\" 2>/dev/null " +
                    "      || ffmpeg -y -loglevel error -i \"$src\" -frames:v 1 -vf 'scale=320:180:force_original_aspect_ratio=increase,crop=320:180' \"$dst\" 2>/dev/null ;; " +
                    "    *) magick \"$src[0]\" -thumbnail 320x180^ -gravity center -extent 320x180 -quality 85 \"$dst\" 2>/dev/null ;; " +
                    "  esac; " +
                    "fi; " +
                    "[ -s \"$dst\" ] && echo \"$dst\"; shift 2; done",
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
