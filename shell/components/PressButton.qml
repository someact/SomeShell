import QtQuick
import qs.core

// Rounded button with hover tint and a springy squash on press.
// Put content inside; it is centered unless anchored otherwise.
//
// Expressive shape: the corners morph with a spring. `radius` is the resting
// shape, `activeRadius` the toggled-on one (e.g. pill → squircle), and a press
// tightens the corners a little. Springs retarget, so fast clicks never jump.
Item {
    id: root

    default property alias content: inner.data
    property real radius: Math.min(width, height) / 2
    property real activeRadius: radius
    property color color: "transparent"
    property color hoverColor: Theme.islandRaisedHover
    property color activeColor: Theme.primary
    property bool active: false          // toggled-on look
    property bool highlighted: false     // keyboard selection
    property bool enabled: true
    // Hold-to-confirm fill, 0..1, rising from the bottom inside the button's
    // own shape (it follows the corner morph). The owner animates it.
    property real progress: 0
    property color progressColor: Qt.alpha(root.activeColor, 0.5)
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked
    signal rightClicked
    signal middleClicked

    implicitWidth: 36
    implicitHeight: 36
    opacity: enabled ? 1 : 0.4
    // A quick click still shows the squash: it holds for a moment after the
    // press, and the spring retargets from wherever the scale is
    readonly property bool squashed: pressed || squashHold.running
    scale: squashed ? 0.94 : 1
    Timer {
        id: squashHold
        interval: 90
    }
    onPressedChanged: if (pressed) squashHold.restart()

    Behavior on scale {
        Spring { preset: "bouncy" }
    }

    // Hover lift: a clickable thing rises a little under the pointer (off while
    // pressed, so the squash reads as pushing it back down)
    property bool lift: true
    transform: Translate {
        y: root.lift && root.hovered && !root.pressed && root.enabled && !Motion.reduced ? -2 : 0
        Behavior on y {
            Spring { preset: "snappy" }
        }
    }

    // State pulse: one ring when the button turns on. Plain NumberAnimations
    // (a Spring inside a ParallelAnimation crashes Qt).
    onActiveChanged: if (active && !Motion.reduced) pulse.restart()
    Rectangle {
        id: ring
        anchors.fill: parent
        radius: bg.radius
        color: "transparent"
        border.width: 2
        border.color: root.activeColor
        opacity: 0
        visible: pulse.running
    }
    ParallelAnimation {
        id: pulse
        NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.25; duration: 700; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: {
            const r = root.active ? root.activeRadius : root.radius;
            return root.squashed ? r * 0.8 : r;
        }
        Behavior on radius {
            Spring { preset: "snappy" }
        }
        color: root.active ? root.activeColor : (root.hovered || root.highlighted) ? root.hoverColor : root.color
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }

    // Clip window with a straight top edge over a full-size copy of the shape,
    // so the fill reads as liquid in the button: rounded bottom, level surface
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * root.progress
        visible: root.progress > 0
        clip: true
        Rectangle {
            anchors.bottom: parent.bottom
            width: root.width
            height: root.height
            radius: bg.radius
            color: root.progressColor
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (event.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
    }
}
