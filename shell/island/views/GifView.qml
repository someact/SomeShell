import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// /gif: search Klipy or Giphy and pick from animated previews. Arrows move,
// Enter copies the GIF as a file (pastes into chat apps), Ctrl+S saves it.
// Nothing is fetched until something is typed; the previews go with the view.
FocusScope {
    id: root

    readonly property int cols: 4
    readonly property int cellW: 184
    readonly property int cellH: 140
    readonly property int rows: 3
    readonly property var current: Gifs.results[grid.currentIndex] ?? null
    property string flash: ""

    implicitWidth: cols * cellW
    implicitHeight: field.height + 10 + rows * cellH + 8 + footer.height

    Component.onCompleted: {
        field.text = Gifs.seed;
        Gifs.seed = "";
        if (field.text.trim() !== "")
            Gifs.search(field.text);
        field.focusInput();
    }
    Component.onDestruction: Gifs.clear()

    function move(delta) {
        const n = Gifs.results.length;
        const i = grid.currentIndex + delta;
        if (i >= 0 && i < n)
            grid.currentIndex = i;
        else if (i >= n)
            Gifs.more();
    }
    function copy(i) {
        const g = Gifs.results[i];
        if (!g)
            return;
        Gifs.copy(g);
        UiState.close();
    }
    function save(i) {
        const g = Gifs.results[i];
        if (!g)
            return;
        Gifs.save(g);
        flash = "Saving to " + Gifs.saveDir.replace(Paths.home, "~");
        flashTimer.restart();
    }

    function handleKey(event) {
        if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
            save(grid.currentIndex);
            return true;
        }
        switch (event.key) {
        case Qt.Key_Left:
            if (Gifs.results.length === 0)
                return false;
            move(-1);
            return true;
        case Qt.Key_Right:
            if (Gifs.results.length === 0)
                return false;
            move(1);
            return true;
        case Qt.Key_Up:
            move(-cols);
            return true;
        case Qt.Key_Down:
            move(cols);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // Enter right after typing searches now instead of waiting
            if (debounce.running) {
                debounce.stop();
                Gifs.search(field.text);
            } else {
                copy(grid.currentIndex);
            }
            return true;
        }
        return UiState.navKey(event);
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: Gifs.search(field.text)
    }
    Timer {
        id: flashTimer
        interval: 2000
        onTriggered: root.flash = ""
    }

    SearchField {
        id: field
        width: parent.width
        icon: "gif_box"
        placeholder: "Search GIFs on " + Gifs.serviceName
        focus: true
        keyHandler: root.handleKey
        onTextChanged: debounce.restart()
    }

    GridView {
        id: grid
        anchors.top: field.bottom
        anchors.topMargin: 10
        width: parent.width
        height: root.rows * root.cellH
        cellWidth: root.cellW
        cellHeight: root.cellH
        clip: true
        model: Gifs.results
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: true
        currentIndex: 0
        onCountChanged: if (currentIndex >= count) currentIndex = 0
        // Next page when the last row comes into view
        onAtYEndChanged: if (atYEnd && count > 0) Gifs.more()

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool isCurrent: GridView.isCurrentItem
            width: root.cellW
            height: root.cellH

            ClippingRectangle {
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

                AnimatedImage {
                    anchors.fill: parent
                    // A local copy (Gifs.download): cache: false on a network URL crashes Qt
                    source: Gifs.previewUrl(cell.modelData)
                    // Frames are decoded as they play instead of all kept in memory
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    playing: status === AnimatedImage.Ready
                    opacity: status === AnimatedImage.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.normal }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: grid.currentIndex = cell.index
                // Right-click saves
                onClicked: event => event.button === Qt.RightButton ? root.save(cell.index) : root.copy(cell.index)
            }
        }
    }

    // Empty, loading, error and missing-key states
    Column {
        anchors.centerIn: grid
        width: grid.width - 80
        spacing: 10
        visible: Gifs.results.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Gifs.error === "nokey" ? "key" : Gifs.status === "error" ? "error" : Gifs.status === "loading" ? "progress_activity" : "gif_box"
            size: 32
            color: Theme.fgIslandDim
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.fgIslandDim
            text: {
                if (Gifs.error === "nokey")
                    return "GIF search needs a free " + Gifs.serviceName + " API key. Get one at " + Gifs.signupUrl.replace(/^https:\/\//, "") + " and add it in Settings → Island → GIF search.";
                if (Gifs.status === "error")
                    return Gifs.error;
                if (Gifs.status === "loading")
                    return "Searching";
                if (Gifs.status === "ready")
                    return "No GIFs for “" + Gifs.query + "”";
                return "Type to search " + Gifs.serviceName;
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: Gifs.error === "nokey"
            PressButton {
                width: keyLabel.implicitWidth + 28
                height: 34
                color: Theme.islandRaised
                onClicked: Qt.openUrlExternally(Gifs.signupUrl)
                Label {
                    id: keyLabel
                    anchors.centerIn: parent
                    text: "Get a key"
                }
            }
            PressButton {
                width: settingsLabel.implicitWidth + 28
                height: 34
                color: Theme.islandRaised
                onClicked: {
                    UiState.close();
                    Session.openSettings("island");
                }
                Label {
                    id: settingsLabel
                    anchors.centerIn: parent
                    text: "Open settings"
                }
            }
        }
    }

    Item {
        id: footer
        anchors.top: grid.bottom
        anchors.topMargin: 8
        width: parent.width
        height: 22

        Label {
            anchors.left: parent.left
            anchors.right: keysHint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.flash !== "" ? root.flash : root.current?.title || ("Powered by " + Gifs.serviceName)
            color: root.flash !== "" ? Theme.accentIsland : Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Label {
            id: keysHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (Gifs.status === "loading" && Gifs.results.length > 0 ? "Loading more · " : "") + "Enter copy · Ctrl+S save · " + Gifs.serviceName
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }
}
