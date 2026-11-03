pragma Singleton
import QtQuick
import Quickshell

// The control page's tiles as data: every kind with its name, icon and
// default size, the default layout, and the packing of a layout into the
// 4-column grid (each tile in order takes the first free place, row by row).
// Any tile can take any size from 1x1 to 4x3 ("WxH", in cells). The layout
// itself is Desktop.control.
Singleton {
    id: root

    readonly property int columns: 4
    readonly property int maxRows: 3

    readonly property var kinds: [
        { id: "net", label: "Internet", icon: "wifi", size: "2x1" },
        { id: "bt", label: "Bluetooth", icon: "bluetooth", size: "2x1" },
        { id: "sound", label: "Sound", icon: "volume_up", size: "2x2" },
        { id: "night", label: "Night light", icon: "nightlight", size: "1x1" },
        { id: "dnd", label: "Do not disturb", icon: "do_not_disturb_on", size: "1x1" },
        { id: "awake", label: "Keep awake", icon: "coffee", size: "1x1" },
        { id: "game", label: "Game mode", icon: "sports_esports", size: "1x1" },
        { id: "brightness", label: "Brightness", icon: "light_mode", size: "2x1" },
        { id: "shot", label: "Screenshot", icon: "screenshot_region", size: "1x1" },
        { id: "record", label: "Record", icon: "screen_record", size: "1x1" },
        { id: "dark", label: "Dark mode", icon: "dark_mode", size: "1x1" },
        { id: "mic", label: "Microphone", icon: "mic", size: "1x1" },
        { id: "picker", label: "Color picker", icon: "colorize", size: "1x1" },
        { id: "clipboard", label: "Clipboard", icon: "content_paste", size: "1x1" },
        { id: "wallpaper", label: "Wallpaper", icon: "shuffle", size: "1x1" },
        { id: "preset", label: "Preset", icon: "dashboard_customize", size: "1x1" },
        { id: "lock", label: "Lock", icon: "lock", size: "1x1" },
        { id: "share", label: "Quick Share", icon: "share", size: "1x1" },
        // Only offered with warp-cli installed (the page checks `needs`)
        { id: "warp", label: "WARP", icon: "vpn_lock", size: "1x1", needs: "warp" }
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

    // "WxH" → { w, h }, or null when it is not a size the grid allows
    function parse(size) {
        const m = /^(\d)x(\d)$/.exec(size ?? "");
        if (!m)
            return null;
        const w = Number(m[1]), h = Number(m[2]);
        return w >= 1 && w <= columns && h >= 1 && h <= maxRows ? { w: w, h: h } : null;
    }
    function sizeOf(w, h) {
        return Math.max(1, Math.min(columns, w)) + "x" + Math.max(1, Math.min(maxRows, h));
    }

    // A saved layout, cleaned: known tiles only, once each, sizes the grid allows
    function clean(list) {
        const out = [];
        const seen = {};
        for (const t of list ?? []) {
            const k = kind(t?.id);
            if (!k || seen[k.id])
                continue;
            seen[k.id] = true;
            out.push({ id: k.id, size: parse(t.size) ? t.size : k.size });
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
            const sz = parse(t.size) ?? { w: 1, h: 1 };
            const w = sz.w, h = sz.h;
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
