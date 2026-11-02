import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.core
import "../island"

// The island: a dark tab hanging from the top edge. Its size always comes
// from what it shows; it springs to each new size, and the content is clipped
// to the shape, so nothing ever draws outside it.
Item {
    id: root

    // False on monitors the island is not on
    property bool here: true
    // The screen of this window, to turn the global pointer into window space
    property var shellScreen: null

    readonly property bool floating: Config.island.shape === "float"
    readonly property bool ears: Config.island.shape === "ears" && !floating

    property bool hovered: false
    readonly property string mode: !here || (Ui.hidden && !Ui.open) ? "none"
        : Ui.open ? "open"
        : Ui.alert ? "alert"
        : hovered ? "peek"
        : Ui.quiet ? "quiet"
        : "rest"

    readonly property real radius: mode === "open" ? Theme.shape.openRadius
        : mode === "quiet" ? 3
        : floating && mode === "rest" ? height / 2
        : Theme.shape.restRadius

    // The area that takes the pointer (the window's input region)
    readonly property alias hitArea: hit

    width: content.item ? content.item.implicitWidth : 0
    height: mode === "none" ? 0 : content.item ? content.item.implicitHeight : 0
    y: floating && mode !== "quiet" ? Theme.shape.floatGap : 0
    visible: mode !== "none"

    Behavior on width {
        SpringAnimation { spring: Motion.springStrength; damping: Motion.springDamping; mass: Motion.springMass; epsilon: 0.25 }
    }
    Behavior on height {
        SpringAnimation { spring: Motion.springStrength; damping: Motion.springDamping; mass: Motion.springMass; epsilon: 0.25 }
    }
    Behavior on y {
        NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
    }

    // Body: square top corners on the edge, round below (all round when floating)
    Rectangle {
        id: body
        anchors.fill: parent
        color: Theme.ink.bg
        topLeftRadius: root.floating ? root.radius : 0
        topRightRadius: root.floating ? root.radius : 0
        bottomLeftRadius: Math.min(root.radius, height / 2)
        bottomRightRadius: Math.min(root.radius, height / 2)
        clip: true

        Loader {
            id: content
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            focus: root.mode === "open"
            sourceComponent: ({
                rest: rest, peek: peek, alert: alert, quiet: quiet, open: open
            })[root.mode] ?? null
            // New content fades in while the shape springs to its size
            onLoaded: if (root.mode !== "open") fade.restart()
            NumberAnimation {
                id: fade
                target: content.item
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.fast
            }
        }
    }

    // Ears: the tab curves into the screen edge on both sides
    Repeater {
        model: root.ears && root.mode !== "quiet" ? 2 : 0
        Shape {
            required property int index
            readonly property real e: Theme.shape.ear
            x: index === 0 ? -e : root.width
            y: 0
            width: e
            height: e
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: index === 0 ? 1 : -1; origin.x: e / 2 }
            ShapePath {
                fillColor: Theme.ink.bg
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: e; y: 0 }
                PathLine { x: e; y: e }
                // Quarter circle centred on the ear's bottom-left corner: the tab
                // side flows into the screen edge
                PathCubic { x: 0; y: 0; control1X: e; control1Y: e * 0.4477; control2X: e * 0.5523; control2Y: 0 }
            }
        }
    }

    // Pointer: hover peeks, a click opens. Opened by hover, it closes again
    // shortly after the pointer leaves.
    Item {
        id: hit
        // Under the content: buttons inside the island take their own clicks,
        // the rest of the shape opens it
        z: -1
        anchors.fill: parent
        anchors.leftMargin: root.ears ? -Theme.shape.ear : 0
        anchors.rightMargin: root.ears ? -Theme.shape.ear : 0
        // The quiet line is thin: give it a taller strip to find
        anchors.bottomMargin: root.mode === "quiet" ? -6 : 0

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    leaveTimer.stop();
                    peekTimer.restart();
                } else {
                    peekTimer.stop();
                    root.hovered = false;
                    if (Ui.open && Ui.openedByHover) {
                        pointerAtLeave.running = true;
                        leaveTimer.restart();
                    }
                }
            }
        }
        TapHandler {
            enabled: root.mode !== "open"
            onTapped: Ui.openPage("search", root.hovered)
        }
    }

    Timer {
        id: peekTimer
        interval: 120
        onTriggered: if (hover.hovered && !Ui.open) root.hovered = true
    }
    // A leave is only trusted when the pointer really moved away. Hyprland
    // can send a leave when the shape changes (opening, a page of another
    // size: the centred island slides the clicked tab away), and sends no
    // enter until the pointer moves. So the pointer is asked for once at the
    // leave and once when the timer ends.
    Timer {
        id: leaveTimer
        interval: 450
        onTriggered: if (!hover.hovered && Ui.openedByHover) pointerNow.running = true
    }
    property point leftAt: Qt.point(-1, -1)
    Process {
        id: pointerAtLeave
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = JSON.parse(text);
                root.leftAt = Qt.point(p.x, p.y);
            }
        }
    }
    Process {
        id: pointerNow
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.checkLeave(JSON.parse(text))
        }
    }
    function checkLeave(p) {
        if (hover.hovered || !Ui.open || !Ui.openedByHover)
            return;
        const local = hit.mapFromItem(null, p.x - (shellScreen?.x ?? 0), p.y - (shellScreen?.y ?? 0));
        // Still over the island: the leave was stale
        if (hit.contains(local))
            return;
        // Not moved since the leave: the shape moved, not the pointer. It
        // stays open like a clicked-open island (Esc or a click outside)
        if (Math.abs(p.x - leftAt.x) + Math.abs(p.y - leftAt.y) < 2) {
            Ui.openedByHover = false;
            return;
        }
        Ui.close();
    }
    Connections {
        target: Ui
        function onOpenChanged() {
            if (Ui.open)
                root.hovered = false;
        }
    }

    Component { id: rest; Rest {} }
    Component { id: peek; Peek {} }
    Component { id: alert; Alert {} }
    Component { id: quiet; Quiet {} }
    Component { id: open; Open {} }
}
