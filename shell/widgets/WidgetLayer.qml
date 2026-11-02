import QtQuick
import Quickshell
import qs.core

// The widgets of one screen, drawn at the screen's own size. Used by the
// wallpaper window (live: the widgets react to the mouse) and by edit mode's
// card (not live; the card moves and resizes them). While editing, `moveId`
// shifts one widget by (moveDx, moveDy) pixels and `sizeId` shows one at
// (sizeW, sizeH) cells, so the content follows the mouse before the drop.
Item {
    id: wl

    required property var screen         // ShellScreen
    property bool live: true
    property string moveId: ""
    property real moveDx: 0
    property real moveDy: 0
    property string sizeId: ""
    property int sizeW: 0
    property int sizeH: 0

    readonly property var g: Widgets.grid(screen.width, screen.height)
    readonly property var names: Quickshell.screens.map(s => s.name)
    readonly property var list: Widgets.forScreen(screen.name, names)

    width: screen.width
    height: screen.height

    // Items by id, for the card's hit tests
    function itemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it && it.modelData === id)
                return it;
        }
        return null;
    }

    Repeater {
        id: rep
        // Ids only: a moved or changed widget keeps its delegate
        model: ScriptModel {
            values: wl.list.map(w => w.id)
        }

        WidgetFrame {
            required property string modelData
            readonly property var entry: wl.list.find(w => w.id === modelData) ?? null
            readonly property bool sized: wl.sizeId === modelData
            readonly property rect r: entry ? Widgets.rect(wl.g, entry.x, entry.y, sized ? wl.sizeW : entry.w, sized ? wl.sizeH : entry.h) : Qt.rect(0, 0, 0, 0)
            widget: entry
            live: wl.live
            cell: wl.g.cell
            x: r.x + (wl.moveId === modelData ? wl.moveDx : 0)
            y: r.y + (wl.moveId === modelData ? wl.moveDy : 0)
            z: wl.moveId === modelData ? 1 : 0
            width: r.width
            height: r.height
        }
    }
}
