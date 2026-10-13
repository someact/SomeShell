import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// Region picker over the frozen frame (Capture.selecting). Drag to select,
// click to take the window under the cursor, right-drag a screenshot to
// annotate it in swappy. Tab / 1-6 switch the tool, Enter takes the whole
// monitor, Esc cancels. The window exists only while selecting.
Scope {
    id: root

    LazyLoader {
        active: Capture.selecting

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Capture.monitor) ?? Quickshell.screens[0]
            readonly property HyprlandMonitor mon: Hyprland.monitors.values.find(m => m.name === Capture.monitor) ?? null

            WlrLayershell.namespace: "someshell:capture"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "black"

            // Selection in window coordinates
            property real x0: 0
            property real y0: 0
            property real x1: 0
            property real y1: 0
            property bool dragging: false
            property bool rightButton: false
            readonly property rect sel: Qt.rect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0))
            readonly property bool hasSel: dragging && sel.width > 3 && sel.height > 3

            // Windows on this monitor's visible workspace (and open scratchpad),
            // topmost first: floating, then most recently focused
            readonly property var targets: {
                if (!Config.capture.snapWindows || !mon)
                    return [];
                const wsId = mon.activeWorkspace?.id ?? -1;
                const special = HyprData.special[mon.name] ?? "";
                return HyprData.windows.map(t => t.lastIpcObject).filter(o => o && o.at && o.mapped !== false && !o.hidden && (o.workspace?.id === wsId || (special !== "" && o.workspace?.name === special))).sort((a, b) => {
                    const sa = (a.workspace?.name ?? "").startsWith("special:"), sb = (b.workspace?.name ?? "").startsWith("special:");
                    if (sa !== sb)
                        return sa ? -1 : 1;
                    if (a.floating !== b.floating)
                        return a.floating ? -1 : 1;
                    return (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0);
                }).map(o => ({
                            x: o.at[0] - mon.x,
                            y: o.at[1] - mon.y,
                            width: o.size[0],
                            height: o.size[1],
                            name: o.class
                        }));
            }
            property var hovered: null
            function targetAt(px, py) {
                return targets.find(t => px >= t.x && px < t.x + t.width && py >= t.y && py < t.y + t.height) ?? null;
            }

            function take(r, edit) {
                const cx = Math.max(0, r.x), cy = Math.max(0, r.y);
                Capture.finish({
                    x: cx,
                    y: cy,
                    width: Math.min(r.x + r.width, width) - cx,
                    height: Math.min(r.y + r.height, height) - cy
                }, edit);
            }

            Component.onCompleted: Hyprland.refreshToplevels()

            Image {
                anchors.fill: parent
                source: Paths.url(Paths.freeze)
                cache: false
                asynchronous: false
                smooth: false
            }

            // Dim everything but the selection (or the hovered window)
            Item {
                id: shade
                anchors.fill: parent
                readonly property rect hole: win.hasSel ? win.sel : win.hovered && !win.dragging ? Qt.rect(win.hovered.x, win.hovered.y, win.hovered.width, win.hovered.height) : Qt.rect(0, 0, 0, 0)
                readonly property color dim: Qt.rgba(0, 0, 0, 0.42)
                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: shade.hole.y
                    color: shade.dim
                }
                Rectangle {
                    x: 0
                    y: shade.hole.y + shade.hole.height
                    width: parent.width
                    height: parent.height - y
                    color: shade.dim
                }
                Rectangle {
                    x: 0
                    y: shade.hole.y
                    width: shade.hole.x
                    height: shade.hole.height
                    color: shade.dim
                }
                Rectangle {
                    x: shade.hole.x + shade.hole.width
                    y: shade.hole.y
                    width: parent.width - x
                    height: shade.hole.height
                    color: shade.dim
                }
                Rectangle {
                    visible: shade.hole.width > 0
                    x: shade.hole.x - 1
                    y: shade.hole.y - 1
                    width: shade.hole.width + 2
                    height: shade.hole.height + 2
                    color: "transparent"
                    radius: win.hasSel ? 2 : 10
                    border.width: 2
                    border.color: Theme.accentIsland
                }
            }

            // Size / window name tag under the selection
            Rectangle {
                id: tag
                readonly property rect r: shade.hole
                visible: r.width > 0
                x: Math.min(Math.max(0, r.x), win.width - width)
                y: r.y + r.height + 8 + height > win.height ? r.y + r.height - height - 8 : r.y + r.height + 8
                width: tagLabel.implicitWidth + 20
                height: 26
                radius: 13
                color: Qt.rgba(0, 0, 0, 0.7)
                Label {
                    id: tagLabel
                    anchors.centerIn: parent
                    mono: win.hasSel
                    font.pixelSize: Theme.font.small
                    text: win.hasSel ? `${Math.round(win.sel.width)} × ${Math.round(win.sel.height)}` : (win.hovered?.name ?? "")
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: e => {
                    win.x0 = win.x1 = e.x;
                    win.y0 = win.y1 = e.y;
                    win.dragging = true;
                    win.rightButton = e.button === Qt.RightButton;
                }
                onPositionChanged: e => {
                    if (win.dragging) {
                        win.x1 = e.x;
                        win.y1 = e.y;
                    } else {
                        win.hovered = win.targetAt(e.x, e.y);
                    }
                }
                onReleased: e => {
                    const drag = win.hasSel;
                    win.dragging = false;
                    if (drag) {
                        win.take(win.sel, win.rightButton);
                        return;
                    }
                    const t = win.targetAt(e.x, e.y);
                    if (t)
                        win.take(t, win.rightButton);
                }
            }

            // Tool bar
            Rectangle {
                id: bar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: shown ? 28 : -height
                property bool shown: false
                Component.onCompleted: shown = true
                Behavior on anchors.bottomMargin {
                    Spring { preset: "snappy" }
                }
                width: tools.implicitWidth + 12
                height: 48
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.78)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                opacity: win.dragging ? 0.25 : 1
                Behavior on opacity {
                    NumberAnimation { duration: Motion.fast }
                }

                Row {
                    id: tools
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: Capture.modes
                        PressButton {
                            required property var modelData
                            width: modelData.id === Capture.mode ? 40 + nameLabel.implicitWidth + 10 : 40
                            height: 36
                            radius: 18
                            active: modelData.id === Capture.mode
                            onClicked: Capture.mode = modelData.id
                            Behavior on width {
                                Spring { preset: "snappy" }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    size: 19
                                    fill: modelData.id === Capture.mode ? 1 : 0
                                    color: modelData.id === Capture.mode ? Theme.fgPrimary : Theme.fgIsland
                                }
                                Label {
                                    id: nameLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: modelData.id === Capture.mode
                                    text: modelData.name
                                    color: Theme.fgPrimary
                                    font.weight: Theme.font.weightTitle
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 1
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.15)
                    }
                    IconButton {
                        icon: "close"
                        onClicked: Capture.cancel()
                    }
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: e => {
                    const ids = Capture.modes.map(m => m.id);
                    if (e.key === Qt.Key_Escape) {
                        Capture.cancel();
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        win.take(Qt.rect(0, 0, win.width, win.height), false);
                    } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                        const d = e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier) ? -1 : 1;
                        Capture.mode = ids[(ids.indexOf(Capture.mode) + d + ids.length) % ids.length];
                    } else if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + ids.length) {
                        Capture.mode = ids[e.key - Qt.Key_1];
                    } else {
                        return;
                    }
                    e.accepted = true;
                }
            }
        }
    }
}
