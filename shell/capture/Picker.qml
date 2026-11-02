import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// The capture picker on one monitor: the frozen picture, dimmed except the
// chosen box. Hover lights a window, a click takes it, a drag draws a box,
// Enter takes the whole monitor, Esc or a right click cancels.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData
    readonly property var mon: Capture.monitor(modelData.name)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.namespace: "someshell:capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Windows on this monitor in its own coordinates, front first
    readonly property var windows: {
        const out = [];
        for (const w of Capture.session?.windows ?? []) {
            if (mon && w.monitor === mon.name)
                out.push({ x: w.x - mon.x, y: w.y - mon.y, w: w.w, h: w.h });
        }
        return out;
    }
    function windowAt(x, y) {
        return windows.find(w => x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) ?? null;
    }

    property point from: Qt.point(0, 0)
    property point to: Qt.point(0, 0)
    property bool dragging: false
    property var hovered: null
    // The box that would be taken now
    readonly property var box: dragging
        ? { x: Math.min(from.x, to.x), y: Math.min(from.y, to.y), w: Math.abs(to.x - from.x), h: Math.abs(to.y - from.y) }
        : hovered

    function take(b) {
        // A window can reach past the monitor's edge
        const x = Math.max(0, b.x), y = Math.max(0, b.y);
        Capture.finish(mon.name, { x: x, y: y, w: Math.min(b.x + b.w, width) - x, h: Math.min(b.y + b.h, height) - y });
    }

    Image {
        anchors.fill: parent
        source: win.mon ? "file://" + win.mon.file : ""
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
    }

    // Dim everything but the box
    readonly property color dim: Qt.rgba(0, 0, 0, 0.5)
    Rectangle { visible: !win.box; anchors.fill: parent; color: win.dim }
    Item {
        visible: !!win.box
        anchors.fill: parent
        readonly property var b: win.box ?? { x: 0, y: 0, w: 0, h: 0 }
        Rectangle { x: 0; y: 0; width: parent.width; height: parent.b.y; color: win.dim }
        Rectangle { x: 0; y: parent.b.y + parent.b.h; width: parent.width; height: parent.height - y; color: win.dim }
        Rectangle { x: 0; y: parent.b.y; width: parent.b.x; height: parent.b.h; color: win.dim }
        Rectangle { x: parent.b.x + parent.b.w; y: parent.b.y; width: parent.width - x; height: parent.b.h; color: win.dim }
        Rectangle {
            x: parent.b.x - 1
            y: parent.b.y - 1
            width: parent.b.w + 2
            height: parent.b.h + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.ink.accent
        }
        // Size in picture pixels, above the box (inside it at the top edge)
        Rectangle {
            readonly property real above: parent.b.y - height - 8
            x: Math.min(parent.b.x, parent.width - width - 8)
            y: above >= 8 ? above : parent.b.y + 8
            width: size.implicitWidth + 20
            height: size.implicitHeight + 10
            radius: height / 2
            color: Theme.ink.bg
            Txt {
                id: size
                anchors.centerIn: parent
                text: Math.round(parent.parent.b.w * (win.mon?.scale ?? 1)) + " × " + Math.round(parent.parent.b.h * (win.mon?.scale ?? 1))
                caps: true
                size: Theme.font.small
            }
        }
    }

    // What to do, at the top
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        // Below the island
        y: 64
        width: hint.implicitWidth + 32
        height: hint.implicitHeight + 16
        radius: height / 2
        color: Theme.ink.bg
        Txt {
            id: hint
            anchors.centerIn: parent
            text: (Capture.session?.mode === "text" ? "Copy text" : "Screenshot") + "   ·   drag a box  ·  click a window  ·  enter: whole screen  ·  esc"
            caps: true
            size: Theme.font.small
            color: Theme.ink.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        onPressed: event => {
            if (event.button === Qt.RightButton) {
                Capture.cancel();
                return;
            }
            win.from = Qt.point(event.x, event.y);
            win.to = win.from;
        }
        onPositionChanged: event => {
            if (pressed && !win.dragging && Math.abs(event.x - win.from.x) + Math.abs(event.y - win.from.y) > 6)
                win.dragging = true;
            if (win.dragging)
                win.to = Qt.point(Math.max(0, Math.min(win.width, event.x)), Math.max(0, Math.min(win.height, event.y)));
            else
                win.hovered = win.windowAt(event.x, event.y);
        }
        onReleased: event => {
            if (event.button !== Qt.LeftButton)
                return;
            if (win.dragging) {
                win.dragging = false;
                win.take({ x: Math.min(win.from.x, win.to.x), y: Math.min(win.from.y, win.to.y), w: Math.abs(win.to.x - win.from.x), h: Math.abs(win.to.y - win.from.y) });
            } else if (win.hovered) {
                win.take(win.hovered);
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Capture.cancel()
        Keys.onReturnPressed: win.take({ x: 0, y: 0, w: win.width, h: win.height })
        Keys.onEnterPressed: win.take({ x: 0, y: 0, w: win.width, h: win.height })
    }
}
