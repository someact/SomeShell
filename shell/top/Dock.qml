import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core

// The separate dock with the Notch and Plain island styles (Dock style has
// the apps in its own bar): a floating bar of apps on the bottom edge of every
// monitor. Auto-hide: it shows when the pointer touches the bottom edge or the
// workspace has no windows, and never over a fullscreen window.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property var workspace: monitor?.activeWorkspace ?? null
    readonly property bool autoHide: Desktop.dock.autoHide
    readonly property bool empty: (workspace?.toplevels?.values.length ?? 1) === 0
    readonly property bool shown: !(workspace?.hasFullscreen ?? false)
        && (!autoHide || empty || hovering)
    property bool hovering: false

    screen: modelData
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: bar.height + 2 * Theme.shape.floatGap
    color: "transparent"
    exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    exclusiveZone: autoHide ? 0 : implicitHeight

    WlrLayershell.namespace: "someshell:dock"
    WlrLayershell.layer: WlrLayer.Top

    // Hidden: only a thin strip on the bottom edge takes the pointer. Shown:
    // the bar's place (a still item: the region does not follow the bar
    // while it slides in)
    mask: Region { item: win.shown ? place : edge }

    Item {
        id: place
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.shape.floatGap
        width: bar.width
        height: bar.height
        HoverHandler {
            onHoveredChanged: hovered ? leave.stop() : leave.restart()
        }
    }

    Item {
        id: edge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        HoverHandler {
            // Shown from the edge, it hides again unless the pointer goes up onto it
            onHoveredChanged: if (hovered) { win.hovering = true; leave.restart(); }
        }
    }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.shown ? Theme.shape.floatGap : win.implicitHeight + 4
        width: apps.implicitWidth + 16
        height: 54
        radius: height / 2
        color: Theme.ink.bg
        opacity: win.shown ? 1 : 0
        Behavior on y {
            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }

        DockApps {
            id: apps
            anchors.centerIn: parent
        }
    }

    // Hide a moment after the pointer leaves. Hyprland can send a leave when
    // the input region changes under a still pointer (hidden → shown), so the
    // pointer is asked for first; while it is still on the bar, ask again later.
    Timer {
        id: leave
        interval: 900
        onTriggered: pointer.running = true
    }
    Process {
        id: pointer
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = null;
                try {
                    p = JSON.parse(text);
                } catch (e) {}
                const top = win.modelData.y + win.modelData.height - win.implicitHeight;
                const at = p ? place.mapFromItem(null, p.x - win.modelData.x, p.y - top) : null;
                if (win.shown && at && place.contains(at))
                    leave.restart();
                else
                    win.hovering = false;
            }
        }
    }
}
