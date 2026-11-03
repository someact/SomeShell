import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.components
import qs.services

// 02 Control. Tiles in a 4-column grid; a tile's arrow (or a right click)
// opens its own page: Internet, Bluetooth, Sound, Night light, WARP.
// Quick edit (the Edit button by the title, or a long press on a tile): tiles
// hold still with a dashed outline, a remove button and a resize handle.
// Drag a tile and the others make room as you go; drag the handle and the
// tile follows the mouse, snapping to whole cells. Hidden tiles wait in
// "Add tiles" below. The layout is Desktop.control (saved with presets);
// see core/ControlTiles.
//
// One slot per kind, kept for the page's life, so a change in the layout
// moves and resizes the slots (with a glide) instead of rebuilding them.
Item {
    id: root

    readonly property int cell: 180
    readonly property int row: 100
    readonly property int gap: 10
    readonly property var layout: Desktop.control.length ? ControlTiles.clean(Desktop.control) : ControlTiles.defaultLayout
    // While dragging or resizing: the layout as it would be on release
    property var preview: null
    readonly property var shown: preview ?? layout
    readonly property var placed: ControlTiles.pack(shown)
    // id → { col, row, w, h, size } for the tiles on the page
    readonly property var where: {
        const m = {};
        for (const t of placed.tiles)
            m[t.id] = t;
        return m;
    }
    readonly property bool editing: Ui.controlEdit
    // The kinds this machine can show (WARP only with warp-cli)
    readonly property var available: ControlTiles.kinds.filter(k => !k.needs || (k.needs === "warp" && Warp.installed))

    implicitWidth: 4 * cell + 3 * gap
    // The backlight may have been changed by another tool since
    Component.onCompleted: Brightness.refresh()
    implicitHeight: Ui.detail ? detailLoader.implicitHeight
        : grid.height + (editing ? tray.implicitHeight + 18 : 0)

    onEditingChanged: preview = null

    function span(c, r) {
        return { w: c * cell + (c - 1) * gap, h: r * row + (r - 1) * gap };
    }
    function cellX(col) { return col * (cell + gap); }
    function cellY(r) { return r * (row + gap); }

    // Every change goes through here (one undo step in edit mode). An empty
    // list would mean "the default layout", so removing the last tile keeps
    // a placeholder.
    function setLayout(list) {
        if (JSON.stringify(list) === JSON.stringify(layout))
            return;
        Editor.record();
        Desktop.control = list.length ? list : [{ id: "none", size: "1x1" }];
    }

    // Dragging tile `id` with its top left at (x, y): the place in the order
    // that packs it nearest to there. The others make room live.
    function dragTo(id, x, y) {
        const rest = layout.filter(t => t.id !== id);
        const me = layout.find(t => t.id === id);
        let best = null, bestD = Infinity;
        for (let i = 0; i <= rest.length; i++) {
            const list = rest.slice();
            list.splice(i, 0, me);
            const p = ControlTiles.pack(list).tiles.find(t => t.id === id);
            const dx = cellX(p.col) - x, dy = cellY(p.row) - y;
            const d = dx * dx + dy * dy;
            if (d < bestD) {
                bestD = d;
                best = list;
            }
        }
        if (JSON.stringify(best) !== JSON.stringify(shown))
            preview = best;
    }
    // Resizing tile `id` to w × h cells (the others reflow live)
    function resizeTo(id, w, h) {
        const size = ControlTiles.sizeOf(w, h);
        const list = layout.map(t => t.id === id ? { id: t.id, size: size } : t);
        if (JSON.stringify(list) !== JSON.stringify(shown))
            preview = list;
    }
    // Release: the preview becomes the layout
    function commit() {
        const list = preview;
        preview = null;
        if (list)
            setLayout(list);
    }

    Item {
        id: grid
        visible: !Ui.detail
        width: parent.width
        height: Math.max(1, root.placed.rows) * root.row + Math.max(0, root.placed.rows - 1) * root.gap
        Behavior on height {
            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
        }

        Repeater {
            model: ControlTiles.kinds

            Item {
                id: slot
                required property var modelData
                readonly property string kindId: modelData.id
                readonly property var spot: root.where[kindId] ?? null
                readonly property bool on: spot !== null
                // Where it last was, so a removed tile fades out in place
                property var last: null
                onSpotChanged: if (spot) last = spot
                Component.onCompleted: if (spot) { last = spot; settled = true; }
                // Glides only once it has been placed (an added tile pops in
                // where it lands, not from the corner)
                property bool settled: false
                onOnChanged: if (on) Qt.callLater(() => slot.settled = true)

                readonly property real homeX: last ? root.cellX(last.col) : 0
                readonly property real homeY: last ? root.cellY(last.row) : 0
                readonly property real homeW: last ? root.span(last.w, last.h).w : root.cell
                readonly property real homeH: last ? root.span(last.w, last.h).h : root.row
                readonly property bool lifted: mover.drag.active
                property bool resizing: false

                x: homeX
                y: homeY
                width: homeW
                height: homeH
                z: lifted || resizing ? 10 : 0
                visible: opacity > 0
                opacity: on ? 1 : 0

                Behavior on x {
                    enabled: slot.settled && !slot.lifted
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                }
                Behavior on y {
                    enabled: slot.settled && !slot.lifted
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                }
                Behavior on width {
                    enabled: slot.settled && !slot.resizing
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                }
                Behavior on height {
                    enabled: slot.settled && !slot.resizing
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                }
                Behavior on opacity {
                    NumberAnimation { duration: slot.on ? Motion.normal : Motion.quick }
                }

                // The tile; sinks a little in edit, pops in when added
                Loader {
                    id: tile
                    anchors.fill: parent
                    active: slot.visible
                    scale: (slot.on ? 1 : 0.85) * (root.editing && !slot.lifted ? 0.95 : 1)
                    Behavior on scale {
                        NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                    }
                    sourceComponent: ControlTile {
                        kind: slot.kindId
                        size: slot.last ? slot.last.size : "1x1"
                        onHeld: Ui.controlEdit = true
                    }
                }

                // Quick edit: outlined; drag to move, the corner to resize
                Item {
                    id: editLayer
                    anchors.fill: parent
                    opacity: root.editing && slot.on ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                    }

                    // Above the tile: its own clicks and sliders are off
                    MouseArea {
                        id: mover
                        anchors.fill: parent
                        enabled: root.editing && slot.on
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: slot
                        drag.threshold: 6
                        drag.minimumX: -20
                        drag.maximumX: grid.width - slot.width + 20
                        drag.minimumY: -20
                        drag.maximumY: grid.height - slot.height + root.row
                        onPositionChanged: if (drag.active) root.dragTo(slot.kindId, slot.x, slot.y)
                        onReleased: {
                            root.commit();
                            // Glides into its (new) place
                            slot.x = Qt.binding(() => slot.homeX);
                            slot.y = Qt.binding(() => slot.homeY);
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Theme.ink.accent
                            strokeWidth: 1.5
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [4, 3]
                            fillColor: slot.lifted || slot.resizing ? Qt.alpha(Theme.ink.bg, 0.6) : "transparent"
                            PathRectangle {
                                x: 0.75
                                y: 0.75
                                width: slot.width - 1.5
                                height: slot.height - 1.5
                                radius: 16
                            }
                        }
                    }
                    // Remove
                    Tap {
                        x: -7
                        y: -7
                        width: 26
                        height: 26
                        radius: 13
                        active: true
                        kbNav: root.editing && slot.on
                        scale: root.editing ? 1 : 0.5
                        Behavior on scale {
                            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                        }
                        onClicked: root.setLayout(root.layout.filter(t => t.id !== slot.kindId))
                        Icon { anchors.centerIn: parent; name: "remove"; size: 18; color: parent.fg }
                    }

                    // The size while resizing
                    Rectangle {
                        anchors.centerIn: parent
                        visible: slot.resizing
                        width: sizeText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: Theme.ink.accent
                        Txt {
                            id: sizeText
                            anchors.centerIn: parent
                            text: slot.spot ? slot.spot.w + " × " + slot.spot.h : ""
                            caps: true
                            color: Theme.ink.onAccent
                        }
                    }

                    // Resize: drag the corner; the tile follows the mouse and
                    // snaps to whole cells on release. Keyboard: Left/Right
                    // change the width, Enter the height.
                    Item {
                        id: handle
                        x: parent.width - width + 7
                        y: parent.height - height + 7
                        width: 26
                        height: 26
                        scale: root.editing ? 1 : 0.5
                        Behavior on scale {
                            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
                        }

                        readonly property bool kbNav: root.editing && slot.on
                        readonly property string label: "Resize " + slot.kindId
                        function kbStep(d) {
                            const s = slot.spot;
                            if (!s)
                                return false;
                            root.setLayout(root.layout.map(t => t.id === slot.kindId
                                ? { id: t.id, size: ControlTiles.sizeOf(s.w + d, s.h) } : t));
                            return true;
                        }
                        function kbClick() {
                            const s = slot.spot;
                            if (s)
                                root.setLayout(root.layout.map(t => t.id === slot.kindId
                                    ? { id: t.id, size: ControlTiles.sizeOf(s.w, s.h % ControlTiles.maxRows + 1) } : t));
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 13
                            color: sizer.pressed ? Theme.ink.fg : sizer.containsMouse ? Theme.ink.raised : Theme.ink.bg
                            border.width: sizer.pressed ? 0 : 1
                            border.color: Theme.ink.line
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: "open_in_full"
                            rotation: 90
                            size: 16
                            color: sizer.pressed ? Theme.ink.bg : Theme.ink.fg
                        }
                        KeyRing {
                            target: handle
                            radiusOf: 13
                        }
                        MouseArea {
                            id: sizer
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            enabled: root.editing && slot.on
                            cursorShape: Qt.SizeFDiagCursor
                            preventStealing: true
                            property real startW
                            property real startH
                            property point start
                            onPressed: mouse => {
                                start = mapToItem(grid, mouse.x, mouse.y);
                                startW = slot.width;
                                startH = slot.height;
                                slot.resizing = true;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return;
                                const p = mapToItem(grid, mouse.x, mouse.y);
                                const w = Math.max(root.cell, Math.min(root.span(ControlTiles.columns, 1).w, startW + p.x - start.x));
                                const h = Math.max(root.row, Math.min(root.span(1, ControlTiles.maxRows).h, startH + p.y - start.y));
                                slot.width = w;
                                slot.height = h;
                                root.resizeTo(slot.kindId,
                                    Math.round((w + root.gap) / (root.cell + root.gap)),
                                    Math.round((h + root.gap) / (root.row + root.gap)));
                            }
                            onReleased: {
                                root.commit();
                                slot.resizing = false;
                                // Snaps to its cells
                                slot.width = Qt.binding(() => slot.homeW);
                                slot.height = Qt.binding(() => slot.homeH);
                            }
                            onCanceled: released(null)
                        }
                    }
                }
            }
        }
    }

    // Quick edit: the tiles not on the page; a click adds one at the end
    Column {
        id: tray
        visible: root.editing && !Ui.detail
        anchors.top: grid.bottom
        anchors.topMargin: 18
        width: parent.width
        spacing: 10
        Txt {
            text: "Add tiles  ·  click one"
            caps: true
            color: Theme.ink.mute
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.available.filter(k => !root.layout.some(t => t.id === k.id))
                Chip {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    onClicked: root.setLayout(root.layout.concat([{ id: modelData.id, size: modelData.size }]))
                }
            }
        }
        Txt {
            visible: root.available.every(k => root.layout.some(t => t.id === k.id))
            text: "Every tile is on the page"
            color: Theme.ink.mute
        }
    }

    // A tile's own page
    Loader {
        id: detailLoader
        visible: !!Ui.detail
        width: parent.width
        source: Ui.detail ? "control/" + ({ net: "NetworkDetail", bt: "BluetoothDetail", sound: "SoundDetail", night: "NightDetail", warp: "WarpDetail" })[Ui.detail] + ".qml" : ""
    }
}
