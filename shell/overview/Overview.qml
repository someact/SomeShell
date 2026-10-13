import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// Super+Tab: every workspace of the current group as a tile with live window
// previews, plus the scratchpad (special workspace). The window only exists
// while open (and for its exit animation), so ScreencopyViews never run idle.
//
// Click a tile or window to go there, middle-click a window to close it, drag
// a window onto another tile to move it. Keys: arrows + Enter, 1-0 jump,
// Esc closes, typing anything else hands the text to island search.
Scope {
    id: root

    property ShellScreen screen: Quickshell.screens[0]

    Connections {
        target: UiState
        function onOverviewChanged() {
            if (UiState.overview)
                root.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
            else
                unload.restart();
        }
    }
    Timer {
        id: unload
        interval: 400
    }

    LazyLoader {
        active: UiState.overview || unload.running

        PanelWindow {
            id: win

            readonly property bool shown: UiState.overview

            screen: root.screen
            WlrLayershell.namespace: "someshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"

            Region {
                id: frost
                item: backdrop
            }
            BackgroundEffect.blurRegion: Theme.blur && shown ? frost : null

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, Theme.blur ? 0.4 : 0.7)
                opacity: win.shown ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Motion.normal }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: UiState.overview = false
                }
            }

            Item {
                id: grid

                readonly property int cols: Math.max(1, Config.overview.columns)
                readonly property int rows: Math.max(1, Config.overview.rows)
                readonly property int count: rows * cols
                readonly property int first: Math.floor((HyprData.activeId - 1) / count) * count + 1
                readonly property real tileW: Math.round(win.width * Config.overview.scale)
                readonly property real tileH: Math.round(win.height * Config.overview.scale)
                readonly property real gap: 14
                readonly property bool showSpecial: Config.overview.showSpecial
                readonly property string specialOpen: HyprData.special[root.screen?.name ?? ""] ?? ""
                readonly property real specialX: Math.round((width - tileW) / 2)
                readonly property real specialY: rows * (tileH + gap) + 10
                readonly property int slots: count + (showSpecial ? 1 : 0)

                // Keyboard selection: 0..count-1, or count for the scratchpad
                property int selected: Math.max(0, HyprData.activeId - first)
                property Item dragged: null
                property int dropTarget: -1

                function tileX(i) {
                    return (i % cols) * (tileW + gap);
                }
                function tileY(i) {
                    return Math.floor(i / cols) * (tileH + gap);
                }
                function slotX(i) {
                    return i === count ? specialX : tileX(i);
                }
                function slotY(i) {
                    return i === count ? specialY : tileY(i);
                }
                function isCurrent(i) {
                    return i === count ? specialOpen !== "" : specialOpen === "" && HyprData.activeId === first + i;
                }
                function originFor(t) {
                    if (HyprData.isSpecial(t))
                        return Qt.point(specialX, specialY);
                    const i = (t.workspace?.id ?? 0) - first;
                    return Qt.point(tileX(i), tileY(i));
                }
                // Tile pixels per window pixel, from the window's own monitor
                function factorFor(t) {
                    const m = t.monitor;
                    const logical = m ? m.width / m.scale : win.width;
                    return tileW / logical;
                }
                // Tile under a point: 0..count-1, count for the scratchpad, -1 for none
                function indexAt(px, py) {
                    if (showSpecial && px >= specialX && px <= specialX + tileW && py >= specialY && py <= specialY + tileH)
                        return count;
                    for (let i = 0; i < count; i++) {
                        if (px >= tileX(i) && px <= tileX(i) + tileW && py >= tileY(i) && py <= tileY(i) + tileH)
                            return i;
                    }
                    return -1;
                }
                function dragOver(cx, cy) {
                    dropTarget = indexAt(cx, cy);
                }
                function drop(thumb) {
                    const target = dropTarget;
                    dragged = null;
                    dropTarget = -1;
                    if (!thumb || target < 0)
                        return;
                    const t = thumb.modelData;
                    if (target === count) {
                        if (!HyprData.isSpecial(t))
                            HyprData.moveWindow(t, "special:special");
                    } else if (target + first !== t.workspace?.id || HyprData.isSpecial(t)) {
                        HyprData.moveWindow(t, target + first);
                    }
                }
                function go(i) {
                    UiState.overview = false;
                    if (i === count) {
                        if (specialOpen === "")
                            HyprData.toggleSpecial("special");
                    } else {
                        if (specialOpen !== "")
                            HyprData.toggleSpecial(specialOpen.replace("special:", ""));
                        HyprData.focusWorkspace(first + i);
                    }
                }
                function focusWindow(t) {
                    UiState.overview = false;
                    HyprData.focusWindow(t);
                }

                anchors.centerIn: parent
                width: cols * tileW + (cols - 1) * gap
                height: rows * tileH + (rows - 1) * gap + (showSpecial ? tileH + gap + 10 : 0)

                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.94
                Behavior on opacity {
                    NumberAnimation { duration: win.shown ? Motion.normal : Motion.fast }
                }
                Behavior on scale {
                    Spring { preset: "smooth" }
                }

                focus: true
                Keys.onPressed: event => {
                    const last = showSpecial ? count : count - 1;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        UiState.overview = false;
                        break;
                    case Qt.Key_Left:
                        selected = Math.max(0, selected - 1);
                        break;
                    case Qt.Key_Right:
                        selected = Math.min(last, selected + 1);
                        break;
                    case Qt.Key_Up:
                        selected = selected === count ? count - Math.ceil(cols / 2) : Math.max(0, selected - cols);
                        break;
                    case Qt.Key_Down:
                        selected = selected + cols < count ? selected + cols : last;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        go(selected);
                        break;
                    default:
                        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier)) {
                            const n = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1;
                            if (n < count)
                                go(n);
                        } else if (event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                            UiState.open("search", event.text);
                        } else {
                            return;
                        }
                    }
                    event.accepted = true;
                }

                // Tiles: count workspaces, then the scratchpad
                Repeater {
                    model: grid.slots
                    Tile {
                        required property int index
                        layout: grid
                        slot: index
                    }
                }

                // Windows sit above the tiles in one layer so a drag can cross tiles
                Repeater {
                    model: ScriptModel {
                        values: HyprData.windows.filter(t => {
                            if (HyprData.isSpecial(t))
                                return grid.showSpecial;
                            const id = t.workspace?.id ?? 0;
                            return id >= grid.first && id < grid.first + grid.count;
                        })
                    }
                    WindowThumb {
                        layout: grid
                    }
                }

                // Rings and numbers above the windows (no input)
                Repeater {
                    model: grid.slots
                    TileFrame {
                        required property int index
                        layout: grid
                        slot: index
                    }
                }
            }
        }
    }

    // A workspace tile: the wallpaper under its windows; click to go there
    component Tile: ClippingRectangle {
        id: tile

        required property var layout
        required property int slot
        readonly property bool target: layout.dropTarget === slot

        x: layout.slotX(slot)
        y: layout.slotY(slot)
        width: layout.tileW
        height: layout.tileH
        radius: Theme.radius.normal
        color: Theme.surfaceContainer

        Image {
            anchors.fill: parent
            source: Wallpaper.path === "" ? "" : Paths.url(Wallpaper.isVideo ? Paths.videoFrame : Wallpaper.path)
            sourceSize: Qt.size(tile.width, tile.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.85
        }
        Rectangle {
            anchors.fill: parent
            color: tile.target ? Qt.rgba(Theme.accentIsland.r, Theme.accentIsland.g, Theme.accentIsland.b, 0.25) : hover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }
        HoverHandler {
            id: hover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.layout.go(tile.slot)
        }
    }

    // Ring (current / keyboard selection / drop target) and the workspace badge
    component TileFrame: Rectangle {
        id: frame

        required property var layout
        required property int slot
        readonly property bool special: slot === layout.count
        readonly property bool current: layout.isCurrent(slot)
        readonly property bool selected: layout.selected === slot
        readonly property bool target: layout.dropTarget === slot

        x: layout.slotX(slot)
        y: layout.slotY(slot)
        z: 50
        width: layout.tileW
        height: layout.tileH
        radius: Theme.radius.normal
        color: "transparent"
        border.width: current || selected || target ? 2 : 1
        border.color: target || current ? Theme.accentIsland : selected ? Theme.fgSurface : Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
            x: 8
            y: 8
            width: badge.implicitWidth + 14
            height: 22
            radius: 11
            color: Theme.island
            Row {
                id: badge
                anchors.centerIn: parent
                spacing: 4
                Icon {
                    visible: frame.special
                    anchors.verticalCenter: parent.verticalCenter
                    name: "push_pin"
                    size: 14
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: frame.special ? "Scratchpad" : String(frame.layout.first + frame.slot)
                    mono: !frame.special
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }
}
