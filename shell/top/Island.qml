import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.core
import qs.services
import "../island"

// The island: a dark tab hanging from the top edge (Notch), a pill below it
// (Plain), or part of the bottom dock (Dock: it grows upward from
// `bottomLine`). Its size always comes from what it shows; it springs to each
// new size, and the content is clipped to the shape, so nothing ever draws
// outside it.
Item {
    id: root

    // False on monitors the island is not on
    property bool here: true
    // The screen of this window, to turn the global pointer into window space
    property var shellScreen: null

    readonly property bool docked: Desktop.style === "dock"
    readonly property bool floating: Desktop.style === "plain" || docked
    readonly property bool ears: Desktop.style === "notch"
    // Dock: where the island's bottom edge stays while it grows
    property real bottomLine: 0
    // The resting size (the dock keeps room for it while the island is bigger)
    // (written by the Rest content itself: a binding on the loader's item
    // also caught the next state's size while the content was switching)
    property real restWidth: 0
    property real restHeight: 0

    property bool hovered: false
    readonly property string mode: !here || (Ui.hidden && !Ui.open) ? "none"
        : Ui.open ? "open"
        : Drop.over ? "drop"
        : Ui.level !== "" ? "level"
        : Ui.alert ? "alert"
        : Spaces.flash ? "flash"
        : hovered ? "peek"
        : Ui.quiet ? "quiet"
        : "rest"

    readonly property real radius: mode === "open" ? Theme.shape.openRadius
        : mode === "quiet" ? 3
        : floating && (mode === "rest" || mode === "flash") ? height / 2
        : Theme.shape.restRadius

    // The area that takes the pointer (the window's input region)
    readonly property alias hitArea: hit

    width: content.item ? content.item.implicitWidth : 0
    // The open island's whole height; while a finger pulls it down from the
    // top edge (Ui.pull) it is cut to the finger, never shorter than at rest
    readonly property real full: content.item ? content.item.implicitHeight : 0
    height: mode === "none" ? 0
        : mode === "open" && Ui.pull >= 0 && !docked ? Math.max(restHeight, Math.min(full, Ui.pull))
        : full
    Binding {
        target: Ui
        property: "pullFull"
        value: root.full
        when: root.here && root.mode === "open"
    }
    y: docked ? bottomLine - height : floating && mode !== "quiet" ? Theme.shape.floatGap : 0
    visible: mode !== "none"

    Behavior on width {
        SpringAnimation { spring: Motion.springStrength; damping: Motion.springDamping; mass: Motion.springMass; epsilon: 0.25 }
    }
    Behavior on height {
        SpringAnimation { spring: Motion.springStrength; damping: Motion.springDamping; mass: Motion.springMass; epsilon: 0.25 }
    }
    Behavior on y {
        enabled: !root.docked
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
            // Docked, the island grows upward: the content rises with it
            anchors.top: root.docked ? undefined : parent.top
            anchors.bottom: root.docked ? parent.bottom : undefined
            anchors.horizontalCenter: parent.horizontalCenter
            focus: root.mode === "open"
            sourceComponent: ({
                rest: rest, peek: peek, alert: alert, quiet: quiet, open: open, level: level, flash: flash, drop: dropping
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

        // Finger swipes on the open island and on an alert (SomeShell.md
        // section 5): sideways switches pages, up closes (Dock style: down,
        // the way it came). Above the content but only watching: a tap still
        // reaches the buttons below, and a slider (preventStealing) keeps its
        // drag. A swipe that starts on a list that scrolls only goes sideways.
        Item {
            id: swipe
            anchors.fill: parent
            z: 10
            enabled: (root.mode === "open" && !Ui.controlEdit) || root.mode === "alert"

            property real dx: 0
            property real dy: 0
            // The items under a point, outermost first
            function chainAt(x, y) {
                const out = [];
                let it = content.item;
                let p = swipe.mapToItem(it, x, y);
                while (it) {
                    out.push(it);
                    const c = it.childAt(p.x, p.y);
                    if (!c)
                        break;
                    p = it.mapToItem(c, p.x, p.y);
                    it = c;
                }
                return out;
            }
            PointHandler {
                acceptedDevices: PointerDevice.TouchScreen
                onActiveChanged: {
                    if (!active)
                        return;
                    swipe.dx = 0;
                    swipe.dy = 0;
                    let fixed = false, scrollsY = false, scrollsX = false;
                    for (const it of swipe.chainAt(point.position.x, point.position.y)) {
                        if (it.preventStealing === true)
                            fixed = true;
                        if (it.contentHeight !== undefined && it.flickableDirection !== undefined) {
                            if (it.contentHeight > it.height + 1)
                                scrollsY = true;
                            if (it.contentWidth > it.width + 1)
                                scrollsX = true;
                        }
                    }
                    drag.xAxis.enabled = !fixed && !scrollsX && root.mode === "open";
                    drag.yAxis.enabled = !fixed && !scrollsY;
                }
            }
            DragHandler {
                id: drag
                target: null
                acceptedDevices: PointerDevice.TouchScreen
                onTranslationChanged: {
                    if (active) {
                        swipe.dx = translation.x;
                        swipe.dy = translation.y;
                    }
                }
                onActiveChanged: {
                    if (active)
                        return;
                    // translation reads 0 again by now: the kept values
                    const dx = swipe.dx, dy = swipe.dy;
                    const away = root.docked ? dy : -dy;
                    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) >= 60 && root.mode === "open")
                        Ui.nextPage(dx < 0 ? 1 : -1);
                    // An alert is short: a shorter swipe dismisses it
                    else if (Math.abs(dy) >= Math.abs(dx) && away >= (root.mode === "open" ? 60 : 30)) {
                        if (root.mode === "open")
                            Ui.close();
                        else
                            Ui.alert = null;
                    }
                }
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
        // Things dragged from other apps: the Drop state while over the
        // island, the Drop page after a drop (services/Drop.qml). Always a
        // copy: the source keeps its file.
        DropArea {
            anchors.fill: parent
            onEntered: drag => {
                Drop.hover(drag);
                drag.accept(Qt.CopyAction);
            }
            onExited: Drop.leave()
            onDropped: drop => {
                const promise = "application/x-moz-file-promise-url";
                Drop.take(drop.urls, drop.hasText ? drop.text : "", drop.formats,
                    drop.formats.includes(promise) ? drop.getDataAsString(promise) : "");
                drop.accept(Qt.CopyAction);
            }
        }
        TapHandler {
            enabled: root.mode !== "open"
            onTapped: {
                // An alert about a file (a screenshot) opens it
                if (root.mode === "alert" && Ui.alert?.open) {
                    Quickshell.execDetached(["xdg-open", Ui.alert.open]);
                    Ui.alert = null;
                    return;
                }
                Ui.openPage("search", root.hovered);
            }
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

    Component {
        id: rest
        Rest {
            onImplicitWidthChanged: root.restWidth = implicitWidth
            onImplicitHeightChanged: root.restHeight = implicitHeight
            Component.onCompleted: {
                root.restWidth = implicitWidth;
                root.restHeight = implicitHeight;
            }
        }
    }
    Component { id: peek; Peek {} }
    Component { id: alert; Alert {} }
    Component { id: quiet; Quiet {} }
    Component { id: open; Open {} }
    Component { id: level; Level {} }
    Component { id: flash; Flash {} }
    Component { id: dropping; Dropping {} }
}
