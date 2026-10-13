import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// Bottom dock, one per monitor: pinned apps, then running ones, then the
// overview button. Intellihide slides it away while a window on this monitor
// covers it; touching the bottom edge brings it back. Drag icons to reorder
// pinned apps (dropping a running app among them pins it), drag one up out of
// the dock to unpin it. The menu lives inside this window (no popup surface).
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property string mode: Config.dock.autohide
    readonly property real margin: 6
    readonly property real dockHeight: content.slot + 8

    // Intellihide: does any window on this monitor's visible workspace touch the dock?
    readonly property bool overlapped: {
        const ws = monitor?.activeWorkspace;
        if (!ws)
            return false;
        if (ws.hasFullscreen)
            return true;
        const special = HyprData.special[monitor.name] ?? "";
        const left = (monitor.x ?? 0) + (width - content.fullWidth) / 2;
        const right = left + content.fullWidth;
        const bottom = (monitor.y ?? 0) + height;
        const top = bottom - margin - dockHeight;
        return HyprData.windows.some(t => {
            const wsName = t.workspace?.name ?? "";
            if (t.workspace?.id !== ws.id && (special === "" || wsName !== special))
                return false;
            const o = t.lastIpcObject;
            if (!o?.at || o.hidden || o.mapped === false)
                return false;
            return o.at[0] < right && o.at[0] + o.size[0] > left && o.at[1] < bottom && o.at[1] + o.size[1] > top;
        });
    }
    readonly property bool fullscreen: monitor?.activeWorkspace?.hasFullscreen ?? false

    // Hover keeps the dock up for a moment after the pointer leaves
    property bool held: false
    // The strip below the dock, or the dock itself (its icons block hover from reaching `zone`)
    readonly property bool hovering: hover.hovered || dockHover.hovered
    onHoveringChanged: {
        if (hovering) {
            leave.stop();
            held = true;
        } else {
            leave.restart();
        }
    }
    Timer {
        id: leave
        interval: 450
        onTriggered: win.held = false
    }

    readonly property bool reveal: mode === "never" || held || menu.open || content.dragKey !== "" || (mode === "intelli" && !overlapped)
    readonly property bool shown: !UiState.hidden && !fullscreen && reveal

    visible: Config.dock.enabled && !GameMode.active
    WlrLayershell.namespace: "someshell:dock"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: mode === "never" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: mode === "never" ? dockHeight + margin : 0
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 420   // room above the dock for the menu and tooltip
    color: "transparent"

    // Input: the dock (or the bottom-edge strip while hidden) plus the open menu
    mask: Region {
        item: zone
        Region {
            item: menu.open ? menu : null
        }
    }
    GlassRegion {
        id: blurArea
        target: bg
        Region {
            item: menu.open ? menu : null
            radius: menu.radius
        }
    }
    // Only while the dock is on the surface: an empty region blurs the whole window.
    // The region is the inset, rounded box (y = ceil(bg.y) + 1), so it leaves the surface
    // ~2 px before bg does; the margin keeps it there (the tail of the slide flickered).
    BackgroundEffect.blurRegion: Theme.blur && bg.y < win.height - 4 ? blurArea : null

    // Clicking anywhere else closes the menu
    HyprlandFocusGrab {
        windows: [win]
        active: menu.open
        onCleared: menu.close()
    }

    Item {
        id: zone
        x: bg.x
        width: bg.width
        y: win.shown ? bg.y - 6 : win.height - 2
        height: win.height - y
        HoverHandler {
            id: hover
        }
    }

    Glass {
        id: bg
        x: Math.round((win.width - width) / 2)
        y: win.shown ? win.height - win.margin - height : win.height + 8
        width: content.width + 12
        height: win.dockHeight
        radius: Theme.radius.large

        Behavior on y {
            Spring { preset: "snappy" }
        }
        Behavior on width {
            Spring { preset: "snappy" }
        }

        HoverHandler {
            id: dockHover
        }

        // A click on the dock between icons closes the menu
        MouseArea {
            anchors.fill: parent
            enabled: menu.open
            onClicked: menu.close()
        }

        Item {
            id: content

            readonly property real slot: Config.dock.iconSize + 12
            readonly property real sepWidth: 13

            property Item hoveredItem: null

            // Drag state: the order shown while dragging differs from Taskbar.apps
            property string dragKey: ""
            property int dragIndex: -1        // target position among pinned apps, -1: not pinning
            property bool dragOut: false      // pulled up out of the dock: unpin on drop
            readonly property bool dragWasPinned: dragKey !== "" && Taskbar.isPinned(dragKey)

            readonly property list<string> pinnedShown: {
                if (dragKey === "")
                    return Taskbar.pinned;
                const list = Taskbar.pinned.filter(k => k !== dragKey);
                if (dragIndex >= 0 && !dragOut)
                    list.splice(dragIndex, 0, dragKey);
                return list;
            }
            readonly property list<string> runningShown: {
                const list = Taskbar.running.filter(k => k !== dragKey);
                // A running app that is not being pinned keeps its place
                if (dragKey !== "" && !dragWasPinned && (dragIndex < 0 || dragOut))
                    list.splice(Taskbar.running.indexOf(dragKey), 0, dragKey);
                return list;
            }
            readonly property bool split: pinnedShown.length > 0 && runningShown.length > 0
            readonly property real appsWidth: (pinnedShown.length + runningShown.length) * slot + (split ? sepWidth : 0)
            readonly property real fullWidth: appsWidth + sepWidth + slot + 12

            function slotX(key) {
                const p = pinnedShown.indexOf(key);
                if (p >= 0)
                    return p * slot;
                const r = runningShown.indexOf(key);
                return (pinnedShown.length + Math.max(0, r)) * slot + (split ? sepWidth : 0);
            }

            function startDrag(key) {
                dragKey = key;
                dragIndex = Taskbar.isPinned(key) ? Taskbar.pinned.indexOf(key) : -1;
                dragOut = false;
                win.held = true;
            }
            // cx: icon center in content coordinates, y: offset from its row
            function dragTo(cx, y) {
                const pinnedCount = Taskbar.pinned.filter(k => k !== dragKey).length;
                dragOut = dragWasPinned && y < -slot * 0.9;
                // Pinned apps stay among pinned; running ones pin when dropped left of the separator
                const index = Math.round(cx / slot - 0.5);
                if (dragWasPinned)
                    dragIndex = Math.max(0, Math.min(pinnedCount, index));
                else
                    dragIndex = index <= pinnedCount ? Math.max(0, index) : -1;
            }
            function endDrag() {
                const key = dragKey;
                if (dragOut)
                    Taskbar.unpin(key);
                else if (dragIndex >= 0)
                    Taskbar.pin(key, dragIndex);
                dragKey = "";
                dragIndex = -1;
                dragOut = false;
                if (!win.hovering)
                    leave.restart();
            }
            function openMenu(item) {
                menu.show(item.key, bg.x + content.x + item.x + item.width / 2);
            }

            x: 6
            y: 4
            width: fullWidth - 12
            height: slot

            Repeater {
                model: ScriptModel {
                    values: Taskbar.apps
                }
                DockItem {
                    dock: content
                }
            }

            Separator {
                visible: content.split
                x: content.pinnedShown.length * content.slot + (content.sepWidth - width) / 2
            }
            Separator {
                x: content.appsWidth + (content.sepWidth - width) / 2
            }

            IconButton {
                x: content.appsWidth + content.sepWidth + (content.slot - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: content.slot - 8
                height: width
                radius: Theme.radius.normal
                icon: "grid_view"
                iconSize: 24
                iconColor: Theme.fgSurface
                hoverColor: Qt.rgba(Theme.fgSurface.r, Theme.fgSurface.g, Theme.fgSurface.b, 0.1)
                onClicked: UiState.toggleOverview()
            }
        }
    }

    // App name above the hovered icon
    Rectangle {
        id: tooltip
        readonly property Item target: content.hoveredItem
        property string text: ""
        onTargetChanged: if (target) text = Taskbar.name(target.key)

        visible: opacity > 0
        opacity: target && !menu.open && win.shown ? 1 : 0
        x: target ? Math.round(bg.x + content.x + target.x + target.width / 2 - width / 2) : x
        y: bg.y - height - 10
        width: tipLabel.implicitWidth + 20
        height: 26
        radius: height / 2
        color: Theme.island

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }
        Behavior on x {
            enabled: tooltip.opacity > 0
            Spring { preset: "snappy" }
        }

        Label {
            id: tipLabel
            anchors.centerIn: parent
            text: tooltip.text
            font.pixelSize: Theme.font.small
        }
    }

    DockMenu {
        id: menu
        dockTop: bg.y
        maxX: win.width
    }

    component Separator: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: content.slot * 0.55
        color: Theme.outlineVariant
    }
}
