import QtQuick
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// The shelf: everything dropped on the island, with the actions that fit each
// kind. Arrows move, Enter copies, Delete removes, Esc closes. Drag an item's
// picture out to put it into another app.
FocusScope {
    id: root

    readonly property int rowH: 64
    readonly property int maxRows: 5
    readonly property var current: Shelf.items[list.currentIndex] ?? null
    readonly property bool canShare: QuickShare.available && Shelf.items.some(i => i.path !== "")
    // Item whose Copy to / Move to folder row is open: { id, move }
    property var dest: null
    property string hint: ""

    implicitWidth: 640
    implicitHeight: header.height + 10 + (Shelf.count > 0 ? list.height : 90) + 8 + footer.height

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Up:
            list.up();
            return true;
        case Qt.Key_Down:
            list.down();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (current)
                Shelf.copy(current);
            return true;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            if (current)
                Shelf.remove(current);
            return true;
        }
        return UiState.navKey(event);
    }

    // What each kind offers, in order; the first is Enter
    function actions(item) {
        const local = item.path !== "" && !Shelf.inCache(item);
        switch (item.kind) {
        case "file":
            return [["Open", "open_in_new"], ["Copy", "content_copy"], ["Copy to", "file_copy"], ["Move to", "drive_file_move"]].concat(QuickShare.available ? [["Send", "nearby"]] : []);
        case "image":
            if (item.path === "")
                return [["Open link", "open_in_new"]];
            return [["Copy", "content_copy"], local ? ["Copy to", "file_copy"] : ["Save", "download"]].concat(local ? [["Move to", "drive_file_move"]] : [], [["Text", "document_scanner"], ["Lens", "image_search"]], QuickShare.available ? [["Send", "nearby"]] : []);
        case "link":
            return [["Open", "open_in_new"], ["Copy", "content_copy"]].concat(QuickShare.available ? [["To phone", "nearby"]] : []);
        default:
            return [["Copy", "content_copy"], ["Note", "sticky_note_2"], ["Translate", "translate"], ["Search", "travel_explore"]];
        }
    }
    function run(item, action) {
        switch (action) {
        case "Open":
            Shelf.open(item);
            UiState.close();
            break;
        case "Open link":
            Qt.openUrlExternally(item.url);
            UiState.close();
            break;
        case "Copy":
            Shelf.copy(item);
            break;
        case "Copy to":
        case "Save":
            dest = dest && dest.id === item.id && !dest.move ? null : { id: item.id, move: false };
            break;
        case "Move to":
            dest = dest && dest.id === item.id && dest.move ? null : { id: item.id, move: true };
            break;
        case "Send":
            Shelf.quickShare([item]);
            break;
        case "To phone":
            Shelf.sendLink(item);
            break;
        case "Text":
            Shelf.ocr(item);
            break;
        case "Lens":
            Shelf.lens(item);
            break;
        case "Note":
            Shelf.saveNote(item);
            break;
        case "Translate":
            Shelf.translate(item);
            break;
        case "Search":
            Shelf.search(item);
            UiState.close();
            break;
        }
    }
    function subtitle(item) {
        switch (item.kind) {
        case "file":
            return Shelf.home(item.path.slice(0, item.path.lastIndexOf("/")) || "/");
        case "image":
            if (item.path === "")
                return "Downloading from " + Shelf.hostOf(item.url);
            return item.url !== "" ? Shelf.hostOf(item.url) : Shelf.home(item.path.slice(0, item.path.lastIndexOf("/")));
        case "link":
            return item.url;
        default:
            {
                const lines = item.text.split("\n").length;
                return (lines === 1 ? "1 line" : lines + " lines") + " · " + item.text.length + " characters";
            }
        }
    }
    function mime(item) {
        if (item.kind === "link")
            return { "text/uri-list": item.url + "\r\n", "text/plain": item.url };
        if (item.kind === "text")
            return { "text/plain": item.text };
        return { "text/uri-list": Shelf.fileUrl(item.path) + "\r\n" };
    }

    Component.onCompleted: forceActiveFocus()

    Item {
        id: header
        width: parent.width
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "shelves"
                size: 18
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Shelf"
                font.weight: Theme.font.weightTitle
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Shelf.count > 0
                text: Shelf.count === 1 ? "1 thing" : Shelf.count + " things"
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                visible: root.canShare
                icon: "nearby"
                text: "Send all"
                onClicked: Shelf.quickShare(Shelf.items)
            }
            Chip {
                visible: Shelf.count > 0
                icon: "delete_sweep"
                text: "Clear"
                onClicked: Shelf.clear()
            }
        }
    }

    Column {
        anchors.top: header.bottom
        anchors.topMargin: 30
        width: parent.width
        spacing: 6
        visible: Shelf.count === 0
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "move_to_inbox"
            size: 28
            color: Theme.fgIslandDim
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drag files, images, links or text onto the island to keep them here"
            color: Theme.fgIslandDim
        }
    }

    KeyNavList {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 10
        width: parent.width
        height: Math.min(contentHeight, root.rowH * root.maxRows + 40)
        model: Shelf.items
        spacing: 4

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property var item: modelData
            readonly property bool destOpen: root.dest !== null && root.dest.id === item.id
            width: ListView.view.width
            height: root.rowH + (destOpen ? 42 : 0)

            Behavior on height {
                Spring { preset: "smooth" }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.normal
                color: rowHover.hovered && !row.ListView.isCurrentItem ? Theme.islandRaised : "transparent"
                HoverHandler {
                    id: rowHover
                }
                TapHandler {
                    onTapped: list.currentIndex = row.index
                }
            }

            // Picture or icon; also the handle to drag the item out
            ClippingRectangle {
                id: thumb
                x: 8
                y: (root.rowH - height) / 2
                width: 48
                height: 48
                radius: 10
                color: Theme.islandRaised

                Image {
                    anchors.fill: parent
                    visible: row.item.kind === "image" && row.item.path !== ""
                    source: visible ? Shelf.fileUrl(row.item.path) : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !(row.item.kind === "image" && row.item.path !== "")
                    name: row.item.kind === "file" ? "draft" : row.item.kind === "link" ? "link" : row.item.kind === "text" ? "notes" : "downloading"
                    size: 24
                    color: Theme.fgIslandDim
                }

                // Platform drag (Drag.Automatic): the proxy is what the mouse
                // "moves"; the drag itself is handed to the compositor
                Item {
                    id: proxy
                    width: thumb.width
                    height: thumb.height
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: root.mime(row.item)
                    Drag.onDragStarted: Shelf.draggingOut = true
                    Drag.onDragFinished: {
                        Shelf.draggingOut = false;
                        proxy.x = 0;
                        proxy.y = 0;
                    }
                }
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: row.item.kind !== "image" || row.item.path !== ""
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: proxy
                    hoverEnabled: true
                    onEntered: root.hint = "Drag out to put it into another app"
                    onExited: root.hint = ""
                }
            }

            Column {
                x: thumb.x + thumb.width + 12
                y: 10
                width: actionRow.x - x - 10
                spacing: 2
                Label {
                    width: parent.width
                    text: row.item.name || "Untitled"
                    font.weight: row.ListView.isCurrentItem ? Theme.font.weightTitle : Theme.font.weight
                }
                Label {
                    width: parent.width
                    text: root.subtitle(row.item)
                    color: Theme.fgIslandDim
                    font.pixelSize: Theme.font.small
                }
            }

            Row {
                id: actionRow
                x: parent.width - width - 4
                y: (root.rowH - height) / 2
                spacing: 2

                Repeater {
                    model: root.actions(row.item)
                    IconButton {
                        required property var modelData
                        width: 34
                        height: 34
                        iconSize: 18
                        icon: modelData[1]
                        active: row.destOpen && ((modelData[0] === "Move to") === root.dest.move) && (modelData[0] === "Move to" || modelData[0] === "Copy to" || modelData[0] === "Save")
                        activeColor: Theme.accentIsland
                        iconColor: active ? Theme.fgOnIslandFill : Theme.fgIsland
                        onClicked: {
                            list.currentIndex = row.index;
                            root.run(row.item, modelData[0]);
                        }
                        onHoveredChanged: root.hint = hovered ? modelData[0] : ""
                    }
                }
                IconButton {
                    width: 34
                    height: 34
                    iconSize: 18
                    icon: "close"
                    iconColor: Theme.fgIslandDim
                    onClicked: Shelf.remove(row.item)
                    onHoveredChanged: root.hint = hovered ? "Remove from the shelf" : ""
                }
            }

            // Where Copy to / Move to / Save puts it
            Row {
                visible: row.destOpen
                x: thumb.x + thumb.width + 12
                y: root.rowH - 4
                spacing: 6
                Repeater {
                    model: row.destOpen ? [Shelf.downloads, Shelf.pictures].concat(Shelf.recent.filter(d => d !== Shelf.downloads && d !== Shelf.pictures)) : []
                    Chip {
                        required property string modelData
                        icon: "folder"
                        text: modelData.split("/").pop()
                        onClicked: {
                            Shelf.copyTo(row.item, modelData, root.dest.move);
                            root.dest = null;
                        }
                        onHoveredChanged: root.hint = hovered ? Shelf.home(modelData) : ""
                    }
                }
                Chip {
                    icon: "folder_open"
                    text: "Other…"
                    onClicked: {
                        Shelf.pickFolder(row.item, root.dest.move);
                        root.dest = null;
                    }
                }
            }
        }
    }

    Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 20
        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: Theme.fgIsland
            font.pixelSize: Theme.font.small
        }
        Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Shelf.count > 0
            text: "Enter copy · Delete remove · drag a picture out"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }

    component Chip: PressButton {
        id: chip
        property string icon
        property string text
        width: chipRow.implicitWidth + 20
        height: 30
        color: Theme.islandRaised
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 16
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font.pixelSize: Theme.font.small
            }
        }
    }
}
