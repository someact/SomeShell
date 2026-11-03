import QtQuick
import qs.core

// A slider drawn as a row of thin bars, like a printed gauge. Drag or click
// to set; the wheel steps by 5. `value` is 0..1.
// `live: false` (a track's position): while dragging the bars follow the
// pointer (`shown`, `dragging`) and `moved` is sent once, on release.
//   BarSlider { value: Audio.volume; onMoved: v => Audio.setVolume(v) }
Item {
    id: root

    property real value: 0
    property int bars: 32
    property color fill: Theme.ink.fg
    property color empty: Theme.ink.line
    property bool live: true

    readonly property bool dragging: mouse.pressed
    property real dragValue: 0
    // What the bars show: the pointer while dragging a non-live slider
    readonly property real shown: dragging && !live ? dragValue : value

    signal moved(real value)

    // Keyboard (Open.qml): Left/Right step 5% (not while the control
    // page's tiles are being moved)
    readonly property bool kbNav: enabled && !Ui.controlEdit
    function kbStep(d) {
        moved(Math.max(0, Math.min(1, value + 0.05 * d)));
        return true;
    }
    KeyRing {
        target: root
        radiusOf: 4
    }

    implicitHeight: 24

    Row {
        anchors.fill: parent
        spacing: 3
        Repeater {
            model: root.bars
            Rectangle {
                required property int index
                width: (root.width - (root.bars - 1) * 3) / root.bars
                height: root.height
                radius: 1
                color: index < Math.round(root.shown * root.bars) ? root.fill : root.empty
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        function at(x) {
            return Math.max(0, Math.min(1, x / width));
        }
        function set(x) {
            root.dragValue = at(x);
            if (root.live)
                root.moved(root.dragValue);
        }
        onPressed: event => set(event.x)
        onPositionChanged: event => { if (pressed) set(event.x); }
        onReleased: event => { if (!root.live) root.moved(at(event.x)); }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
