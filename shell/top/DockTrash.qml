import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.core
import qs.components

// The trash can at the end of a dock (Desktop.dock.trash). It watches the
// home trash folder (FolderListModel: a file watcher, no polling) and shows
// full or empty. Click: open the trash in the file manager. Drop files on it:
// they go to the trash. Right click: empty it, after a second right click
// within a few seconds (the can turns red and says so meanwhile).
Item {
    id: root

    property int iconSize: 30
    property int cellSize: 42
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share"
    readonly property bool full: files.count > 0
    property bool confirming: false

    width: cellSize
    height: cellSize

    FolderListModel {
        id: files
        folder: "file://" + root.dataHome + "/Trash/files"
        showDirs: true
        showHidden: true
        showDotAndDotDot: false
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirming = false
    }

    function openTrash() {
        Quickshell.execDetached(["sh", "-c", "gio open trash:/// || xdg-open trash:///"]);
    }
    function emptyTrash() {
        confirming = false;
        Quickshell.execDetached(["gio", "trash", "--empty"]);
    }
    function trashUrls(urls) {
        const paths = [];
        for (const u of urls) {
            const s = String(u);
            if (s.startsWith("file://"))
                paths.push(decodeURIComponent(s.slice(7)));
        }
        if (paths.length)
            Quickshell.execDetached(["gio", "trash", "--"].concat(paths));
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.confirming ? Theme.ink.error
            : mouse.pressed ? Theme.ink.fg
            : mouse.containsMouse || drop.containsDrag ? Theme.ink.raised : "transparent"
        border.width: drop.containsDrag ? 2 : 0
        border.color: Theme.ink.accent
    }
    Image {
        id: can
        anchors.centerIn: parent
        visible: !root.confirming
        width: root.iconSize
        height: root.iconSize
        source: Quickshell.iconPath(root.full ? "user-trash-full" : "user-trash", true)
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
    }
    // No icon theme with a trash can, or asking to empty: a symbol
    Icon {
        anchors.centerIn: parent
        visible: root.confirming || can.status !== Image.Ready
        name: root.confirming ? "delete_forever" : "delete"
        filled: root.full || root.confirming
        size: 24
        color: root.confirming ? Theme.ink.bg : mouse.pressed ? Theme.ink.bg : Theme.ink.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button !== Qt.RightButton) {
                root.confirming = false;
                root.openTrash();
            } else if (!root.full) {
                root.confirming = false;
            } else if (root.confirming) {
                root.emptyTrash();
            } else {
                root.confirming = true;
                confirmTimer.restart();
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onEntered: drag => drag.accepted = drag.hasUrls
        onDropped: drop => {
            if (!drop.hasUrls)
                return;
            root.trashUrls(drop.urls);
            drop.acceptProposedAction();
        }
    }
}
