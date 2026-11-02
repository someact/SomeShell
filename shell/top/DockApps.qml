import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// The apps in a dock: pinned ones first (Desktop.dock.pinned, desktop entry
// ids), then the others that have a window open. A dot under an icon means it
// is running, a line that it has the focus. Click: launch, or focus its window
// (again: the next window). Middle click: a new window. Right click: pin/unpin.
Row {
    id: root

    property int iconSize: 30
    property int cellSize: 42
    spacing: 4

    function keyOf(appId) {
        return DesktopEntries.heuristicLookup(appId)?.id ?? appId;
    }

    // [{ id, entry, windows }]
    readonly property var apps: {
        // Read again once the app list is loaded (lookups before it find nothing)
        DesktopEntries.applications.values.length;
        const out = [];
        const byId = {};
        for (const id of Desktop.dock.pinned) {
            // An app that is no longer installed is left out (it stays pinned)
            const entry = DesktopEntries.byId(id);
            if (!entry)
                continue;
            const a = { id: id, entry: entry, windows: [] };
            byId[id] = a;
            out.push(a);
        }
        for (const t of ToplevelManager.toplevels.values) {
            if (!t.appId)
                continue;
            const id = keyOf(t.appId);
            if (!byId[id]) {
                byId[id] = { id: id, entry: DesktopEntries.heuristicLookup(t.appId), windows: [] };
                out.push(byId[id]);
            }
            byId[id].windows.push(t);
        }
        return out;
    }

    function togglePin(id) {
        const pinned = Desktop.dock.pinned.slice();
        const at = pinned.indexOf(id);
        if (at < 0)
            pinned.push(id);
        else
            pinned.splice(at, 1);
        Desktop.dock.pinned = pinned;
    }

    function open(app) {
        if (!app.windows.length) {
            if (app.entry)
                Apps.launch(app.entry);
            return;
        }
        const at = app.windows.findIndex(w => w.activated);
        app.windows[(at + 1) % app.windows.length].activate();
    }

    Repeater {
        model: root.apps

        Item {
            id: cell
            required property var modelData
            readonly property bool running: modelData.windows.length > 0
            readonly property bool focused: modelData.windows.some(w => w.activated)
            width: root.cellSize
            height: root.cellSize

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: mouse.pressed ? Theme.ink.fg : mouse.containsMouse ? Theme.ink.raised : "transparent"
            }
            Image {
                id: appIcon
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                source: Quickshell.iconPath(cell.modelData.entry?.icon ?? "", true)
                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                name: "apps"
                size: 24
                color: mouse.pressed ? Theme.ink.bg : Theme.ink.fg
            }
            // Running: a dot; focused: a short line
            Rectangle {
                visible: cell.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                width: cell.focused ? 12 : 4
                height: 4
                radius: 2
                color: cell.focused ? Theme.ink.accent : Theme.ink.mute
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton)
                        root.togglePin(cell.modelData.id);
                    else if (event.button === Qt.MiddleButton && cell.modelData.entry)
                        Apps.launch(cell.modelData.entry);
                    else
                        root.open(cell.modelData);
                }
            }
        }
    }
}
