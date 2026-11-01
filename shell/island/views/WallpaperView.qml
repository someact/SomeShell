import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// Wallpaper picker: ~/Pictures/Wallpapers (images and videos) with cached
// thumbnails. Arrows move, Enter applies, R random, D dark/light, O other file.
FocusScope {
    id: root

    readonly property int cols: 4
    readonly property int cellW: 196
    readonly property int cellH: 118

    implicitWidth: cols * cellW
    implicitHeight: header.height + 10 + (folder.count > 0 ? grid.height : 80)

    function handleKey(event) {
        const n = folder.count;
        switch (event.key) {
        case Qt.Key_Left:
            grid.currentIndex = Math.max(0, grid.currentIndex - 1);
            return true;
        case Qt.Key_Right:
            grid.currentIndex = Math.min(n - 1, grid.currentIndex + 1);
            return true;
        case Qt.Key_Up:
            grid.currentIndex = Math.max(0, grid.currentIndex - cols);
            return true;
        case Qt.Key_Down:
            grid.currentIndex = Math.min(n - 1, grid.currentIndex + cols);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            apply(grid.currentIndex);
            return true;
        case Qt.Key_R:
            Wallpaper.random();
            return true;
        case Qt.Key_D:
            Wallpaper.toggleLightDark();
            return true;
        case Qt.Key_O:
            UiState.close();
            Wallpaper.pick();
            return true;
        case Qt.Key_Escape:
            UiState.close();
            return true;
        }
        return false;
    }

    function apply(i) {
        const p = folder.get(i, "filePath");
        if (p)
            Wallpaper.set(p);
    }

    FolderListModel {
        id: folder
        folder: Paths.url(Paths.wallpapers)
        nameFilters: Array.from(Wallpaper.imageExts).concat(Array.from(Wallpaper.videoExts)).map(e => "*." + e)
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Time
        onStatusChanged: if (status === FolderListModel.Ready) {
            for (let i = 0; i < count; i++) {
                if (get(i, "filePath") === Wallpaper.path) {
                    grid.currentIndex = i;
                    grid.positionViewAtIndex(i, GridView.Contain);
                }
            }
        }
    }

    Item {
        id: header
        width: parent.width
        height: 32

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "wallpaper"
                size: 18
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpapers"
                font.styleName: Theme.font.styleTitle
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: folder.count + " in ~/Pictures/Wallpapers"
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            IconButton {
                icon: "shuffle"
                width: 32
                height: 32
                iconSize: 18
                onClicked: Wallpaper.random()
            }
            IconButton {
                icon: Wallpaper.mode === "dark" ? "dark_mode" : "light_mode"
                width: 32
                height: 32
                iconSize: 18
                onClicked: Wallpaper.toggleLightDark()
            }
            IconButton {
                icon: "folder_open"
                width: 32
                height: 32
                iconSize: 18
                onClicked: {
                    UiState.close();
                    Wallpaper.pick();
                }
            }
        }
    }

    Label {
        anchors.top: header.bottom
        anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        visible: folder.count === 0
        text: "Put images or videos in ~/Pictures/Wallpapers"
        color: Theme.fgIslandDim
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 10
        width: parent.width
        height: Math.min(Math.ceil(folder.count / root.cols), 3) * root.cellH
        cellWidth: root.cellW
        cellHeight: root.cellH
        clip: true
        model: folder
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: true
        currentIndex: 0

        delegate: Item {
            id: cell
            required property int index
            required property string filePath
            required property string fileName
            readonly property bool isCurrent: GridView.isCurrentItem
            readonly property bool isApplied: filePath === Wallpaper.path

            width: root.cellW
            height: root.cellH

            ClippingRectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radius.normal
                color: Theme.islandRaised
                border.width: cell.isCurrent ? 2 : 0
                border.color: Theme.accentIsland
                scale: mouse.pressed ? 0.96 : 1
                Behavior on scale {
                    Spring { preset: "bouncy" }
                }

                Image {
                    anchors.fill: parent
                    source: Thumbs.url(cell.filePath)
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.normal }
                    }
                }

                Rectangle {
                    visible: Wallpaper.isVideoFile(cell.filePath)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    width: 22
                    height: 22
                    radius: 11
                    color: Qt.rgba(0, 0, 0, 0.6)
                    Icon {
                        anchors.centerIn: parent
                        name: "play_arrow"
                        size: 16
                        fill: 1
                    }
                }
                Rectangle {
                    visible: cell.isApplied
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme.primary
                    Icon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 16
                        color: Theme.fgPrimary
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: root.apply(cell.index)
            }
        }
    }
}
