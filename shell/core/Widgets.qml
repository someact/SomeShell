pragma Singleton
import QtQuick
import Quickshell

// Desktop widgets: the kinds, the grid and the changes to Desktop.widgets.
// An entry: { id, kind, monitor, x, y, w, h (cells), card, opts }.
// The grid has square cells, 12 rows to the screen's height and as many
// columns as fit, centred. Widgets never overlap. Callers record the look
// for Undo first (Editor.record(), in services).
Singleton {
    id: root

    readonly property int rows: 12
    readonly property var kinds: [
        { id: "clock", label: "Clock", icon: "schedule", size: [5, 3], min: [3, 2], max: [14, 7], card: false, opts: { date: true, align: "left" } },
        { id: "text", label: "Text", icon: "title", size: [6, 2], min: [2, 1], max: [20, 10], card: false, opts: { text: "Stay curious", align: "left", face: "bold" } },
        { id: "media", label: "Now playing", icon: "music_note", size: [6, 2], min: [4, 2], max: [9, 4], card: true, opts: {} },
        { id: "calendar", label: "Calendar", icon: "calendar_month", size: [4, 4], min: [3, 3], max: [7, 7], card: true, opts: {} },
        { id: "system", label: "System", icon: "monitoring", size: [4, 2], min: [3, 2], max: [9, 3], card: true, opts: {} }
    ]
    function kind(id) {
        return kinds.find(k => k.id === id) ?? null;
    }

    // --- the grid of one screen (logical size) ---
    function grid(sw, sh) {
        const cell = Math.floor(sh / rows);
        const cols = Math.floor(sw / cell);
        return { cell: cell, cols: cols, rows: rows, ox: Math.floor((sw - cols * cell) / 2), oy: Math.floor((sh - rows * cell) / 2) };
    }
    // A widget's rectangle in screen pixels, with a gap between neighbours
    function rect(g, x, y, w, h) {
        const gap = Math.round(g.cell * 0.12);
        return Qt.rect(g.ox + x * g.cell + gap / 2, g.oy + y * g.cell + gap / 2, w * g.cell - gap, h * g.cell - gap);
    }
    // The cell nearest a point (the widget's top left corner)
    function cellAt(g, px, py) {
        return { x: Math.round((px - g.ox) / g.cell), y: Math.round((py - g.oy) / g.cell) };
    }

    // --- which widgets show on a screen ---
    // Its own monitor, or the first screen when its monitor is not here
    function onScreen(entry, name, names) {
        if (entry.monitor === name)
            return true;
        return !names.includes(entry.monitor) && names[0] === name;
    }
    function forScreen(name, names) {
        const out = [];
        for (const w of Desktop.widgets)
            if (onScreen(w, name, names))
                out.push(w);
        return out;
    }

    // --- free places ---
    function fits(g, list, skip, x, y, w, h) {
        if (x < 0 || y < 0 || x + w > g.cols || y + h > g.rows)
            return false;
        for (const o of list) {
            if (o.id === skip)
                continue;
            if (x < o.x + o.w && o.x < x + w && y < o.y + o.h && o.y < y + h)
                return false;
        }
        return true;
    }
    // The free place nearest (x, y), or null when the screen is full
    function nearest(g, list, skip, x, y, w, h) {
        let best = null, bestD = Infinity;
        for (let cy = 0; cy + h <= g.rows; cy++)
            for (let cx = 0; cx + w <= g.cols; cx++) {
                const d = (cx - x) * (cx - x) + (cy - y) * (cy - y);
                if (d < bestD && fits(g, list, skip, cx, cy, w, h)) {
                    best = { x: cx, y: cy };
                    bestD = d;
                }
            }
        return best;
    }
    // The first free place, row by row from the top left
    function firstFree(g, list, w, h) {
        for (let cy = 0; cy + h <= g.rows; cy++)
            for (let cx = 0; cx + w <= g.cols; cx++)
                if (fits(g, list, "", cx, cy, w, h))
                    return { x: cx, y: cy };
        return null;
    }

    // --- changes ---
    function newId() {
        return "w" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }
    // Adds a widget of `kindId` near (x, y) (or the first free place when x
    // is undefined); returns its id, or "" when there is no room
    function add(kindId, monitor, g, list, x, y) {
        const k = kind(kindId);
        if (!k)
            return "";
        const w = Math.min(k.size[0], g.cols), h = Math.min(k.size[1], g.rows);
        const at = x === undefined ? firstFree(g, list, w, h) : nearest(g, list, "", x, y, w, h);
        if (!at)
            return "";
        const id = newId();
        Desktop.widgets = Desktop.widgets.concat([{
            id: id, kind: kindId, monitor: monitor, x: at.x, y: at.y, w: w, h: h,
            card: k.card, opts: JSON.parse(JSON.stringify(k.opts))
        }]);
        return id;
    }
    // The same on a screen (ShellScreen), from its grid and its widgets
    function addOn(kindId, scr, x, y) {
        const names = Quickshell.screens.map(s => s.name);
        return add(kindId, scr.name, grid(scr.width, scr.height), forScreen(scr.name, names), x, y);
    }
    function screenNamed(name) {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }
    function change(id, fields) {
        Desktop.widgets = Desktop.widgets.map(w => w.id === id ? Object.assign({}, w, fields) : w);
    }
    function setOpt(id, key, value) {
        const w = find(id);
        if (!w)
            return;
        const opts = Object.assign({}, w.opts ?? {});
        opts[key] = value;
        change(id, { opts: opts });
    }
    function remove(id) {
        Desktop.widgets = Desktop.widgets.filter(w => w.id !== id);
    }
    function find(id) {
        return Desktop.widgets.find(w => w.id === id) ?? null;
    }
}
