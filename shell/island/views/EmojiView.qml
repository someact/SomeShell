import QtQuick
import qs.core
import qs.components
import qs.services

// Emoji grid: category tabs, a recent row on top, search across names and
// keywords. Arrows move, Tab / Shift+Tab switch the category, Enter copies,
// Shift+Enter copies and stays open. The hand button picks the skin tone.
FocusScope {
    id: root

    readonly property int cols: 12
    readonly property int cell: 48
    readonly property int rows: 6

    property string group: "smileys"
    property string flash: ""          // name shown after Shift+Enter
    readonly property string query: field.text.trim()
    // The recent row is padded to a full row so the category starts below it
    readonly property var recentRow: {
        const r = Emojis.recentEntries().slice(0, cols);
        if (r.length === 0)
            return [];
        while (r.length < cols)
            r.push(null);
        return r;
    }
    readonly property var cells: !Emojis.loaded ? [] : query !== "" ? Emojis.query(query, 240) : recentRow.concat(Emojis.inGroup(group))
    readonly property var current: cells[grid.currentIndex] ?? null

    implicitWidth: cols * cell
    implicitHeight: field.height + 8 + tabs.height + 6 + rows * cell + 6 + footer.height

    Component.onCompleted: {
        Emojis.load();
        field.focusInput();
    }
    Component.onDestruction: Emojis.unload()

    onQueryChanged: grid.currentIndex = 0
    // After the model swap, which puts the grid back on 0
    onGroupChanged: Qt.callLater(() => grid.currentIndex = recentRow.length)

    function move(delta) {
        const n = cells.length;
        let i = grid.currentIndex + delta;
        if (i < 0 || i >= n)
            return;
        // Skip the padding after the recent row
        while (cells[i] === null && i > 0 && i < n - 1)
            i += delta > 0 ? 1 : -1;
        if (cells[i] === null)
            return;
        grid.currentIndex = i;
    }
    function stepGroup(delta) {
        const ids = Emojis.groups.map(g => g.id);
        group = ids[(ids.indexOf(group) + delta + ids.length) % ids.length];
    }
    function pick(i, keepOpen) {
        const e = cells[i];
        if (!e)
            return;
        Emojis.copy(e);
        if (keepOpen) {
            flash = Emojis.display(e) + "  copied";
            flashTimer.restart();
        } else {
            UiState.close();
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            return true;
        case Qt.Key_Right:
            move(1);
            return true;
        case Qt.Key_Up:
            move(-cols);
            return true;
        case Qt.Key_Down:
            move(cols);
            return true;
        case Qt.Key_Tab:
            stepGroup(1);
            field.text = "";
            return true;
        case Qt.Key_Backtab:
            stepGroup(-1);
            field.text = "";
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            pick(grid.currentIndex, event.modifiers & Qt.ShiftModifier);
            return true;
        }
        return UiState.navKey(event);
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: root.flash = ""
    }

    SearchField {
        id: field
        width: parent.width
        icon: "mood"
        placeholder: "Search emoji"
        focus: true
        keyHandler: root.handleKey
    }

    Row {
        id: tabs
        anchors.top: field.bottom
        anchors.topMargin: 8
        width: parent.width
        height: 36
        spacing: 2

        Repeater {
            model: Emojis.groups
            IconButton {
                required property var modelData
                width: 36
                height: 36
                icon: modelData.icon
                iconSize: 20
                active: root.query === "" && root.group === modelData.id
                activeColor: Theme.accentIsland
                iconColor: active ? Theme.fgOnIslandFill : Theme.fgIslandDim
                onClicked: {
                    field.text = "";
                    root.group = modelData.id;
                }
            }
        }
    }

    // Skin tone: click steps forward, right-click back
    PressButton {
        id: toneButton
        anchors.right: parent.right
        anchors.verticalCenter: tabs.verticalCenter
        width: 36
        height: 36
        onClicked: Emojis.setTone((Emojis.tone + 1) % Emojis.tones.length)
        onRightClicked: Emojis.setTone((Emojis.tone + Emojis.tones.length - 1) % Emojis.tones.length)
        Text {
            anchors.centerIn: parent
            text: "\u{1F44B}" + Emojis.tones[Emojis.tone]
            font.pixelSize: 20
        }
    }

    GridView {
        id: grid
        anchors.top: tabs.bottom
        anchors.topMargin: 6
        width: parent.width
        height: root.rows * root.cell
        cellWidth: root.cell
        cellHeight: root.cell
        clip: true
        model: root.cells
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Motion.fast
        currentIndex: 0
        onCountChanged: if (currentIndex >= count) currentIndex = 0

        highlight: Rectangle {
            radius: Theme.radius.normal
            color: Theme.islandRaisedHover
        }

        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: root.cell
            height: root.cell

            Text {
                anchors.centerIn: parent
                visible: tile.modelData !== null
                text: Emojis.display(tile.modelData)
                font.pixelSize: 28
                scale: mouse.pressed ? 0.85 : 1
                Behavior on scale {
                    Spring { preset: "bouncy" }
                }
            }

            // Thin line under the recent row
            Rectangle {
                visible: root.query === "" && root.recentRow.length > 0 && tile.index < root.cols
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 1
                color: Theme.islandRaised
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                enabled: tile.modelData !== null
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: grid.currentIndex = tile.index
                // Right-click copies and keeps the picker open
                onClicked: event => root.pick(tile.index, event.button === Qt.RightButton)
            }
        }
    }

    Label {
        anchors.centerIn: grid
        visible: Emojis.loaded && root.cells.length === 0
        text: "Nothing here"
        color: Theme.fgIslandDim
    }

    Item {
        id: footer
        anchors.top: grid.bottom
        anchors.topMargin: 6
        width: parent.width
        height: 22

        Label {
            anchors.left: parent.left
            anchors.right: keysHint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.flash !== "" ? root.flash : root.current ? Emojis.display(root.current) + "  " + root.current.name : ""
            elide: Text.ElideRight
            color: root.flash !== "" ? Theme.accentIsland : Theme.fgIsland
        }
        Label {
            id: keysHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter copy · Shift+Enter keep open · Tab category"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }
}
