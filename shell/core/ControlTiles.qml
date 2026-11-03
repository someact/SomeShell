pragma Singleton
import QtQuick
import Quickshell

// The control page's tiles as data: every kind with its name, icon and the
// sizes it allows (the first is its default), the default layout, and the
// packing of a layout into the 4-column grid (each tile in order takes the
// first free place, row by row). The layout itself is Desktop.control.
Singleton {
    id: root

    readonly property int columns: 4

    readonly property var kinds: [
        { id: "net", label: "Internet", icon: "wifi", sizes: ["2x1", "1x1"] },
        { id: "bt", label: "Bluetooth", icon: "bluetooth", sizes: ["2x1", "1x1"] },
        { id: "sound", label: "Sound", icon: "volume_up", sizes: ["2x2", "2x1", "1x1"] },
        { id: "night", label: "Night light", icon: "nightlight", sizes: ["1x1", "2x1"] },
        { id: "dnd", label: "Do not disturb", icon: "do_not_disturb_on", sizes: ["1x1", "2x1"] },
        { id: "awake", label: "Keep awake", icon: "coffee", sizes: ["1x1", "2x1"] },
        { id: "game", label: "Game mode", icon: "sports_esports", sizes: ["1x1", "2x1"] },
        { id: "brightness", label: "Brightness", icon: "light_mode", sizes: ["2x1", "2x2", "1x1"] },
        { id: "shot", label: "Screenshot", icon: "screenshot_region", sizes: ["1x1", "2x1"] },
        { id: "record", label: "Record", icon: "screen_record", sizes: ["1x1", "2x1"] },
        { id: "dark", label: "Dark mode", icon: "dark_mode", sizes: ["1x1", "2x1"] },
        { id: "mic", label: "Microphone", icon: "mic", sizes: ["1x1", "2x1"] },
        { id: "picker", label: "Color picker", icon: "colorize", sizes: ["1x1", "2x1"] },
        { id: "clipboard", label: "Clipboard", icon: "content_paste", sizes: ["1x1", "2x1"] },
        { id: "wallpaper", label: "Wallpaper", icon: "shuffle", sizes: ["1x1", "2x1"] },
        { id: "preset", label: "Preset", icon: "dashboard_customize", sizes: ["1x1", "2x1"] },
        { id: "lock", label: "Lock", icon: "lock", sizes: ["1x1", "2x1"] },
        { id: "share", label: "Quick Share", icon: "share", sizes: ["1x1", "2x1"] }
    ]

    // The layout before any edit (the one step 4 built)
    readonly property var defaultLayout: [
        { id: "net", size: "2x1" }, { id: "bt", size: "2x1" }, { id: "sound", size: "2x2" },
        { id: "night", size: "1x1" }, { id: "dnd", size: "1x1" }, { id: "awake", size: "1x1" },
        { id: "game", size: "1x1" }, { id: "brightness", size: "2x1" }, { id: "shot", size: "1x1" },
        { id: "record", size: "1x1" }
    ]

    function kind(id) {
        return kinds.find(k => k.id === id) ?? null;
    }

    // A saved layout, cleaned: known tiles only, once each, allowed sizes
    function clean(list) {
        const out = [];
        const seen = {};
        for (const t of list ?? []) {
            const k = kind(t?.id);
            if (!k || seen[k.id])
                continue;
            seen[k.id] = true;
            out.push({ id: k.id, size: k.sizes.includes(t.size) ? t.size : k.sizes[0] });
        }
        return out;
    }

    // [{ id, size }] → { tiles: [{ id, size, col, row, w, h }], rows }
    function pack(list) {
        const taken = [];
        const free = (c, r, w, h) => {
            for (let y = r; y < r + h; y++)
                for (let x = c; x < c + w; x++)
                    if (taken[y]?.[x])
                        return false;
            return true;
        };
        const tiles = [];
        let rows = 0;
        for (const t of list) {
            const w = Number(t.size[0]), h = Number(t.size[2]);
            for (let r = 0; ; r++) {
                let c = 0;
                while (c <= columns - w && !free(c, r, w, h))
                    c++;
                if (c > columns - w)
                    continue;
                for (let y = r; y < r + h; y++) {
                    taken[y] = taken[y] ?? [];
                    for (let x = c; x < c + w; x++)
                        taken[y][x] = true;
                }
                tiles.push({ id: t.id, size: t.size, col: c, row: r, w: w, h: h });
                rows = Math.max(rows, r + h);
                break;
            }
        }
        return { tiles: tiles, rows: rows };
    }
}
