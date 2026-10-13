import QtQuick
import qs.core
import qs.components
import qs.services

// The Control view's quick tiles and sliders (services/QuickTiles.qml). One
// delegate per id for the life of the view; each sits at its slot with a
// spring, so an item shown, hidden, resized or dragged slides instead of the
// grid being rebuilt.
//
// Items flow on 8 units per row: an icon tile takes 1, a medium tile 2, a full
// tile 4, a slider the whole row; an item that does not fit starts the next row.
//
// Edit mode: shown items first, then a "Hidden" row; click shows or hides an
// item, drag a shown one to reorder (committed on release), the corner badge
// steps a tile through icon → medium → full, and a right-click lists the
// three sizes (`sizeMenu`).
Item {
    id: grid

    property bool edit: false
    property int selected: -1                    // keyboard selection, index into `order`

    // Shown items in order; a local copy while dragging
    property var order: QuickTiles.shown
    readonly property var hiddenTiles: edit ? QuickTiles.hidden : []

    readonly property int spacing: 8
    readonly property int units: 8
    readonly property real unitW: (width - (units - 1) * spacing) / units
    readonly property real labelH: 26
    // Solid, so a badge reads over a slider's light fill too
    readonly property color badgeColor: Qt.tint("black", Theme.islandRaisedHover)

    function unitsOf(id) {
        const s = QuickTiles.size(id);
        return s === "icon" ? 1 : s === "medium" ? 2 : s === "full" ? 4 : units;
    }
    // { slots: id -> { x, y, w, h }, height }
    function pack(list, top) {
        const slots = {};
        let col = 0, y = top, rowH = 0;
        for (const id of list) {
            const u = unitsOf(id);
            const h = QuickTiles.isSlider(id) ? 40 : 52;
            if (col > 0 && col + u > units) {
                y += rowH + spacing;
                col = 0;
                rowH = 0;
            }
            slots[id] = { x: col * (unitW + spacing), y: y, w: u * unitW + (u - 1) * spacing, h: h };
            col += u;
            rowH = Math.max(rowH, h);
        }
        return { slots: slots, height: list.length > 0 ? y + rowH - top : 0 };
    }
    readonly property var shownPack: pack(order, 0)
    readonly property real hiddenTop: shownPack.height + spacing + labelH
    readonly property var hiddenPack: pack(hiddenTiles, hiddenTop)

    signal rightClicked(string id)

    // Edit mode: the tile whose size chooser is open ("" = none)
    property string sizeMenu: ""
    onEditChanged: sizeMenu = ""

    // The view opens with the grid at width 0; springs start one tick after the
    // first real width, so opening lays everything out without animating it
    property bool settled: false
    onWidthChanged: if (width > 0 && !settled)
        Qt.callLater(() => grid.settled = true)

    implicitHeight: edit ? hiddenTop + Math.max(52, hiddenPack.height) : shownPack.height

    function isSlider(i) {
        return i >= 0 && i < order.length && QuickTiles.isSlider(order[i]);
    }
    function run(i) {
        QuickTiles.tile(order[i])?.run();
    }
    function adjust(i, delta) {
        const s = QuickTiles.tile(order[i]);
        s?.set(Math.max(0, Math.min(1, s.value + delta)));
    }
    function toggleShown(id) {
        if (QuickTiles.shown.includes(id))
            QuickTiles.hide(id);
        else
            QuickTiles.show(id);
    }
    // The item whose slot is under the pointer takes the dragged one's place
    function dragTo(id, px, py) {
        let target = -1;
        for (let i = 0; i < order.length; i++) {
            const s = shownPack.slots[order[i]];
            if (px >= s.x && px < s.x + s.w + spacing && py >= s.y && py < s.y + s.h + spacing) {
                target = i;
                break;
            }
        }
        if (target < 0 && py >= shownPack.height)
            target = order.length - 1;
        const from = order.indexOf(id);
        if (from < 0 || target < 0 || target === from)
            return;
        const next = order.filter(t => t !== id);
        next.splice(target, 0, id);
        order = next;
    }
    function commit() {
        QuickTiles.setOrder(order);
        order = Qt.binding(() => QuickTiles.shown);
    }

    Label {
        visible: grid.edit
        y: grid.shownPack.height + grid.spacing + 4
        text: grid.hiddenTiles.length > 0 ? "Hidden · click to add" : "Everything is shown"
        color: Theme.fgIslandDim
        font.pixelSize: Theme.font.small
    }

    Repeater {
        model: QuickTiles.ids

        Item {
            id: cell
            required property string modelData
            readonly property var item: QuickTiles.tile(modelData)
            readonly property bool slider: QuickTiles.isSlider(modelData)
            readonly property string size: QuickTiles.size(modelData)
            readonly property bool iconOnly: size === "icon"
            readonly property int shownIdx: grid.order.indexOf(modelData)
            readonly property bool isShown: shownIdx >= 0
            readonly property var slot: isShown ? grid.shownPack.slots[modelData] : grid.hiddenPack.slots[modelData]
            readonly property bool present: slot !== undefined
            readonly property bool selected: !grid.edit && grid.selected === shownIdx && isShown

            // Dragging follows the pointer; springs only once the item has a place,
            // so an item that appears starts at its slot instead of flying in
            property bool dragging: false
            property real dragX: 0
            property real dragY: 0
            property bool placed: false
            onPresentChanged: {
                placed = false;
                if (present)
                    Qt.callLater(() => cell.placed = cell.present);
            }
            Component.onCompleted: placed = present

            visible: present
            z: dragging ? 2 : 0
            x: dragging ? dragX : (slot?.x ?? 0)
            y: dragging ? dragY : (slot?.y ?? 0)
            width: slot?.w ?? 0
            height: slot?.h ?? 0
            Behavior on x {
                enabled: grid.settled && cell.placed && !cell.dragging
                Spring { preset: "snappy" }
            }
            Behavior on y {
                enabled: grid.settled && cell.placed && !cell.dragging
                Spring { preset: "snappy" }
            }
            Behavior on width {
                enabled: grid.settled && cell.placed
                Spring { preset: "snappy" }
            }

            opacity: grid.edit && !cell.isShown ? 0.45 : 1
            Behavior on opacity {
                NumberAnimation { duration: Motion.fast }
            }

            Loader {
                anchors.fill: parent
                sourceComponent: cell.slider ? sliderItem : toggleItem
            }
            Component {
                id: toggleItem
                Toggle {
                    compact: cell.iconOnly
                    titleOnly: cell.size === "medium"
                    icon: cell.item.icon
                    title: cell.item.title
                    subtitle: cell.item.subtitle
                    active: cell.item.active && !grid.edit
                    highlighted: cell.selected
                    onClicked: cell.item.run()
                    onRightClicked: grid.rightClicked(cell.modelData)
                }
            }
            Component {
                id: sliderItem
                Slider {
                    icon: cell.item.icon
                    value: cell.item.value
                    onMoved: v => cell.item.set(v)
                    onIconClicked: cell.item.iconClick()
                    onRightClicked: cell.item.rightClick()
                    trackColor: cell.selected ? Theme.islandRaisedHover : Theme.islandRaised
                }
            }

            // Edit mode takes the pointer: click shows/hides, drag reorders
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                enabled: grid.edit
                cursorShape: cell.dragging ? Qt.ClosedHandCursor : cell.isShown ? Qt.OpenHandCursor : Qt.PointingHandCursor
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point start
                property bool moved: false
                onPressed: event => {
                    start = Qt.point(event.x, event.y);
                    moved = false;
                    // Right-click a shown tile: its size chooser; any other press closes it
                    const menu = event.button === Qt.RightButton && cell.isShown && !cell.slider && grid.sizeMenu !== cell.modelData;
                    grid.sizeMenu = menu ? cell.modelData : "";
                }
                onPositionChanged: event => {
                    if (!(pressedButtons & Qt.LeftButton) || !cell.isShown)
                        return;
                    if (!moved && Math.hypot(event.x - start.x, event.y - start.y) < 6)
                        return;
                    if (!moved) {
                        moved = true;
                        cell.dragX = cell.x;
                        cell.dragY = cell.y;
                        cell.dragging = true;
                    }
                    const p = mapToItem(grid, event.x, event.y);
                    cell.dragX = p.x - start.x - anchors.margins;
                    cell.dragY = p.y - start.y - anchors.margins;
                    grid.dragTo(cell.modelData, p.x, p.y);
                }
                onReleased: event => {
                    if (cell.dragging) {
                        cell.dragging = false;
                        grid.commit();
                    } else if (!moved && event.button === Qt.LeftButton) {
                        grid.toggleShown(cell.modelData);
                    }
                }
            }

            // Edit badges: remove on shown items, add on hidden ones
            Rectangle {
                visible: grid.edit
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -3
                width: 18
                height: 18
                radius: 9
                color: cell.isShown ? grid.badgeColor : Theme.primary
                Icon {
                    anchors.centerIn: parent
                    name: cell.isShown ? "remove" : "add"
                    size: 14
                    color: cell.isShown ? Theme.fgIsland : Theme.fgPrimary
                }
            }
            // Size: icon → medium → full → icon (tiles only)
            Rectangle {
                visible: grid.edit && cell.isShown && !cell.slider && !cell.dragging
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: -3
                width: 18
                height: 18
                radius: 9
                color: sizeArea.containsMouse ? Theme.primary : grid.badgeColor
                Icon {
                    anchors.centerIn: parent
                    name: cell.size === "full" ? "close_fullscreen" : "open_in_full"
                    size: 12
                    color: sizeArea.containsMouse ? Theme.fgPrimary : Theme.fgIsland
                }
                MouseArea {
                    id: sizeArea
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.sizeMenu = "";
                        QuickTiles.setSize(cell.modelData, QuickTiles.nextSize(cell.size));
                    }
                }
            }
        }
    }

    // Size chooser for the right-clicked tile, just under it
    Rectangle {
        id: chooser
        readonly property var slot: grid.shownPack.slots[grid.sizeMenu]
        visible: grid.edit && slot !== undefined
        z: 3
        x: slot ? Math.max(0, Math.min(grid.width - width, slot.x + slot.w / 2 - width / 2)) : 0
        y: slot ? slot.y + slot.h + 4 : 0
        width: chips.implicitWidth + 8
        height: 34
        radius: 17
        color: grid.badgeColor
        border.width: 1
        border.color: Theme.glassRim

        Row {
            id: chips
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: QuickTiles.sizes
                PressButton {
                    id: chip
                    required property var modelData
                    width: chipLabel.implicitWidth + 22
                    height: 26
                    active: QuickTiles.size(grid.sizeMenu) === modelData.id
                    activeColor: Theme.accentIsland
                    onClicked: {
                        QuickTiles.setSize(grid.sizeMenu, modelData.id);
                        grid.sizeMenu = "";
                    }
                    Label {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.name
                        font.pixelSize: Theme.font.small
                        font.weight: Theme.font.weightTitle
                        color: chip.active ? Theme.fgAccentIsland : Theme.fgIsland
                    }
                }
            }
        }
    }
}
