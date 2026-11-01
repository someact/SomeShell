import QtQuick
import qs.core
import qs.components
import qs.services

// Keyboard shortcut cheatsheet from bind descriptions ("Group: Action" in
// keybinds.lua, plus your custom ones), grouped, with key caps. Type to
// filter; Enter opens the Keybinds settings page to change one.
FilterListView {
    id: root
    icon: "keyboard"
    placeholder: "Search shortcuts"
    maxRows: 12
    rowHeight: 36

    // Rows: a header per group, then its binds
    results: {
        const q = query.toLowerCase();
        const groups = new Map();
        for (const b of Keybinds.binds) {
            if (q !== "" && !(b.group + " " + b.action + " " + b.keys).toLowerCase().includes(q))
                continue;
            if (!groups.has(b.group))
                groups.set(b.group, []);
            groups.get(b.group).push(b);
        }
        const rows = [];
        for (const [group, binds] of groups) {
            rows.push({ header: true, group });
            for (const b of binds)
                rows.push(b);
        }
        return rows;
    }

    // Keep the highlight off the group headers
    onResultsChanged: list.currentIndex = Math.max(0, results.findIndex(r => !r.header))
    Component.onCompleted: Keybinds.refresh()
    onActivated: {
        UiState.close();
        Session.openSettings("keybinds");
    }

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool header: modelData.header === true

        width: ListView.view.width
        height: header ? 30 : 36

        Label {
            visible: row.header
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            x: 10
            text: row.modelData.group ?? ""
            color: Theme.accentIsland
            font.pixelSize: Theme.font.small
            font.styleName: Theme.font.styleTitle
        }

        Label {
            visible: !row.header
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            width: parent.width - caps.width - 30
            text: row.modelData.action ?? ""
        }
        Row {
            id: caps
            visible: !row.header
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: row.header ? [] : row.modelData.keys.split(" + ")
                Rectangle {
                    required property string modelData
                    width: Math.max(24, cap.implicitWidth + 12)
                    height: 22
                    radius: 6
                    color: Theme.islandRaised
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    Label {
                        id: cap
                        anchors.centerIn: parent
                        text: parent.modelData
                        mono: true
                        font.pixelSize: Theme.font.small
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !row.header
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated(row.index)
        }
    }
}
