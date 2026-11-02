import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.components
import qs.services

// 02 Control. Tiles in a 4-column grid; a tile's arrow (or a right click)
// opens its own page: Internet, Bluetooth, Sound, Night light.
// Quick edit (the Edit button by the title, or a long press on a tile): tiles
// hold still with a dashed outline, a remove button and a size button; drag
// one onto another to move it there; hidden tiles wait in "Add tiles" below.
// The layout is Desktop.control (saved with presets); see core/ControlTiles.
Item {
    id: root

    readonly property int cell: 180
    readonly property int row: 100
    readonly property int gap: 10
    readonly property var layout: Desktop.control.length ? ControlTiles.clean(Desktop.control) : ControlTiles.defaultLayout
    readonly property var placed: ControlTiles.pack(layout)
    readonly property bool editing: Ui.controlEdit

    implicitWidth: 4 * cell + 3 * gap
    // The backlight may have been changed by another tool since
    Component.onCompleted: Brightness.refresh()
    implicitHeight: Ui.detail ? detailLoader.implicitHeight
        : grid.height + (editing ? tray.implicitHeight + 18 : 0)

    function span(c, r) {
        return { w: c * cell + (c - 1) * gap, h: r * row + (r - 1) * gap };
    }

    // Every change goes through here (one undo step in edit mode). An empty
    // list would mean "the default layout", so removing the last tile keeps
    // a placeholder.
    function setLayout(list) {
        Editor.record();
        Desktop.control = list.length ? list : [{ id: "none", size: "1x1" }];
    }
    function cellX(col) { return col * (cell + gap); }
    function cellY(r) { return r * (row + gap); }

    // A dragged tile dropped with its middle at (cx, cy): it takes the place of
    // the tile there (the others move once), or goes last on an empty spot
    function drop(from, cx, cy) {
        const tiles = placed.tiles;
        const to = tiles.findIndex((t, i) => i !== from
            && cx >= cellX(t.col) && cx < cellX(t.col) + span(t.w, t.h).w
            && cy >= cellY(t.row) && cy < cellY(t.row) + span(t.w, t.h).h);
        const list = layout.slice();
        const moved = list.splice(from, 1)[0];
        if (to < 0)
            list.push(moved);
        else
            list.splice(to, 0, moved);
        if (JSON.stringify(list) !== JSON.stringify(layout))
            setLayout(list);
        return true;
    }

    Item {
        id: grid
        visible: !Ui.detail
        width: parent.width
        height: Math.max(1, root.placed.rows) * root.row + Math.max(0, root.placed.rows - 1) * root.gap

        Repeater {
            model: root.placed.tiles

            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property real homeX: root.cellX(modelData.col)
                readonly property real homeY: root.cellY(modelData.row)
                readonly property var kindInfo: ControlTiles.kind(modelData.id)
                x: homeX
                y: homeY
                width: root.span(modelData.w, modelData.h).w
                height: root.span(modelData.w, modelData.h).h
                z: mover.pressed ? 10 : 0

                ControlTile {
                    anchors.fill: parent
                    kind: slot.modelData.id
                    size: slot.modelData.size
                    onHeld: Ui.controlEdit = true
                }

                // Quick edit: still, outlined; drag to move
                Item {
                    visible: root.editing
                    anchors.fill: parent

                    // Above the tile: its own clicks and sliders are off
                    MouseArea {
                        id: mover
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: slot
                        drag.threshold: 6
                        onReleased: {
                            if (slot.x !== slot.homeX || slot.y !== slot.homeY)
                                root.drop(slot.index, slot.x + slot.width / 2, slot.y + slot.height / 2);
                            // Back to its place (a moved layout rebuilds the tiles anyway)
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
                            fillColor: mover.pressed ? Qt.alpha(Theme.ink.bg, 0.6) : "transparent"
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
                        onClicked: {
                            const list = root.layout.slice();
                            list.splice(slot.index, 1);
                            root.setLayout(list);
                        }
                        Icon { anchors.centerIn: parent; name: "remove"; size: 18; color: parent.fg }
                    }
                    // Size: each click takes the next size the tile allows
                    Tap {
                        visible: (slot.kindInfo?.sizes.length ?? 1) > 1
                        x: parent.width - width + 7
                        y: -7
                        width: sizeText.implicitWidth + 20
                        height: 26
                        radius: 13
                        outlined: true
                        onClicked: {
                            const sizes = slot.kindInfo.sizes;
                            const next = sizes[(sizes.indexOf(slot.modelData.size) + 1) % sizes.length];
                            const list = root.layout.slice();
                            list[slot.index] = { id: slot.modelData.id, size: next };
                            root.setLayout(list);
                        }
                        Rectangle {
                            anchors.fill: parent
                            z: -1
                            radius: 13
                            color: Theme.ink.bg
                        }
                        Txt {
                            id: sizeText
                            anchors.centerIn: parent
                            text: slot.modelData.size.replace("x", " × ")
                            caps: true
                            color: parent.fg
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
                model: ControlTiles.kinds.filter(k => !root.layout.some(t => t.id === k.id))
                Chip {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    onClicked: root.setLayout(root.layout.concat([{ id: modelData.id, size: modelData.sizes[0] }]))
                }
            }
        }
        Txt {
            visible: root.layout.length === ControlTiles.kinds.length
            text: "Every tile is on the page"
            color: Theme.ink.mute
        }
    }

    // A tile's own page
    Loader {
        id: detailLoader
        visible: !!Ui.detail
        width: parent.width
        source: Ui.detail ? "control/" + ({ net: "NetworkDetail", bt: "BluetoothDetail", sound: "SoundDetail", night: "NightDetail" })[Ui.detail] + ".qml" : ""
    }
}
