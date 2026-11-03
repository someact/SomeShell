import QtQuick
import qs.core

// A slider for the settings window: a hairline track, the filled part in ink,
// a round knob, the value written left of it. `changed` fires on release (or
// a key), so a drag does not write a file on every step.
//   SetSlider { from: 10; to: 60; step: 1; value: 35; format: v => v + " /s"; onChanged: v => ... }
Item {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property var format: v => String(v)
    readonly property var c: Theme.paper
    // While dragging: the value under the knob (not yet sent)
    property real shown: value
    property bool dragging: false
    signal changed(real value)

    implicitWidth: 320
    implicitHeight: 38
    activeFocusOnTab: true
    onValueChanged: if (!dragging) shown = value

    function snap(v) {
        v = Math.max(from, Math.min(to, v));
        return Math.round(Math.round((v - from) / step) * step * 1e6) / 1e6 + from;
    }
    function nudge(d) {
        const v = snap(value + d * step);
        if (v !== value)
            changed(v);
    }
    Keys.onLeftPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: 76
        horizontalAlignment: Text.AlignRight
        caps: true
        color: root.dragging || root.activeFocus ? root.c.fg : root.c.mute
        text: root.format(root.shown)
    }

    Item {
        id: track
        anchors.left: label.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        readonly property real frac: (root.shown - root.from) / (root.to - root.from)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            radius: 1
            color: root.c.line
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * track.frac
            height: 2
            radius: 1
            color: root.c.fg
        }
        Rectangle {
            x: parent.width * track.frac - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.dragging || mouse.containsMouse ? 18 : 14
            height: width
            radius: width / 2
            color: root.c.fg
            border.width: 3
            border.color: root.c.bg
            Behavior on width { NumberAnimation { duration: Motion.fast } }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function at(mx) {
                return root.snap(root.from + (mx - 10) / track.width * (root.to - root.from));
            }
            onPressed: m => {
                root.forceActiveFocus();
                root.dragging = true;
                root.shown = at(m.x);
            }
            onPositionChanged: m => {
                if (root.dragging)
                    root.shown = at(m.x);
            }
            onReleased: {
                root.dragging = false;
                if (root.shown !== root.value)
                    root.changed(root.shown);
            }
            onCanceled: {
                root.dragging = false;
                root.shown = root.value;
            }
        }
    }
}
