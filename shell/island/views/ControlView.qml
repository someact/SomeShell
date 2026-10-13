import QtQuick
import qs.core
import qs.components
import qs.services

// Quick tiles and sliders, one layout (TileGrid). ↑/↓ select, Enter toggles,
// ←/→ adjust a selected slider. The pencil edits the layout (show, hide, reorder,
// tile size); the grid button sets every tile to icon or full.
// Right-click a tile: its detail page here (network, Bluetooth, WARP, night light,
// audio devices; Esc or ← goes back) or its page in the settings app.
FocusScope {
    id: root

    implicitWidth: 560
    implicitHeight: col.implicitHeight

    // index into the shown items (TileGrid.order)
    property int selected: -1
    readonly property int total: tiles.order.length

    // The open detail page, "" for the tiles (in UiState so pills can open one)
    readonly property string detail: UiState.controlDetail
    readonly property var detailTitles: ({ wifi: "Network", bluetooth: "Bluetooth", warp: "WARP", nightlight: "Night light", audio: "Sound devices" })

    function openTile(id) {
        const t = QuickTiles.tile(id);
        if (!t)
            return;
        if (t.detail !== "") {
            tiles.edit = false;
            UiState.controlDetail = t.detail;
        } else if (t.settings !== "") {
            Session.openSettings(t.settings);
            UiState.close();
        }
    }

    function handleKey(event) {
        const k = event.key;
        if (detail !== "") {
            if (page.item?.handleKey && page.item.handleKey(event))
                return true;
            if (k === Qt.Key_Escape || k === Qt.Key_Backspace) {
                UiState.controlDetail = "";
                return true;
            }
            return UiState.navKey(event);
        }
        if (tiles.edit && (k === Qt.Key_Escape || k === Qt.Key_Return || k === Qt.Key_Enter)) {
            tiles.edit = false;
            return true;
        }
        if (k === Qt.Key_Down || k === Qt.Key_Up) {
            selected = selected < 0 ? 0 : (selected + (k === Qt.Key_Down ? 1 : -1) + total) % total;
            return true;
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && selected >= 0 && selected < total && !tiles.isSlider(selected)) {
            tiles.run(selected);
            return true;
        }
        if ((k === Qt.Key_Left || k === Qt.Key_Right) && tiles.isSlider(selected)) {
            tiles.adjust(selected, k === Qt.Key_Right ? 0.05 : -0.05);
            return true;
        }
        return UiState.navKey(event);
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // Edit and tile style
        Item {
            width: parent.width
            height: 26
            IconButton {
                id: back
                visible: root.detail !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 26
                iconSize: 18
                icon: "arrow_back"
                onClicked: UiState.controlDetail = ""
            }
            Label {
                visible: root.detail !== ""
                anchors.left: back.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.detailTitles[root.detail] ?? ""
                font.weight: Theme.font.weightTitle
            }
            Label {
                visible: root.detail === ""
                anchors.verticalCenter: parent.verticalCenter
                text: tiles.edit ? "Click to show or hide · drag to reorder · corner badge resizes" : ""
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
            Row {
                visible: root.detail === ""
                anchors.right: parent.right
                spacing: 4
                IconButton {
                    width: 30
                    height: 26
                    iconSize: 17
                    icon: Config.control.tileStyle === "icon" ? "view_agenda" : "grid_view"
                    iconColor: Theme.fgIslandDim
                    onClicked: QuickTiles.setAllSizes(Config.control.tileStyle === "icon" ? "full" : "icon")
                }
                IconButton {
                    width: 30
                    height: 26
                    iconSize: 17
                    icon: tiles.edit ? "check" : "edit"
                    active: tiles.edit
                    activeColor: Theme.islandRaisedHover
                    iconColor: tiles.edit ? Theme.fgIsland : Theme.fgIslandDim
                    onClicked: tiles.edit = !tiles.edit
                }
            }
        }

        Loader {
            id: page
            active: root.detail !== ""
            visible: active
            width: parent.width
            height: item ? item.implicitHeight : 0
            sourceComponent: ({ wifi: networkPage, bluetooth: bluetoothPage, warp: warpPage, nightlight: nightPage, audio: audioPage })[root.detail] ?? null
            onLoaded: {
                item.width = Qt.binding(() => page.width);
                pageIn.play();
            }
            Reveal {
                id: pageIn
                target: page.item
                delay: 0
            }
        }

        TileGrid {
            id: tiles
            visible: root.detail === ""
            width: parent.width
            selected: root.selected
            onRightClicked: id => root.openTile(id)
        }
    }

    Component {
        id: networkPage
        NetworkDetail {}
    }
    Component {
        id: bluetoothPage
        BluetoothDetail {}
    }
    Component {
        id: warpPage
        WarpDetail {}
    }
    Component {
        id: nightPage
        NightLightDetail {}
    }
    Component {
        id: audioPage
        AudioDevices {}
    }
}
