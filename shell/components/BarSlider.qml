import QtQuick
import qs.core

// A slider drawn as a row of thin bars, like a printed gauge. Drag or click
// to set; the wheel steps by 5. `value` is 0..1.
//   BarSlider { value: Audio.volume; onMoved: v => Audio.setVolume(v) }
Item {
    id: root

    property real value: 0
    property int bars: 32
    property color fill: Theme.ink.fg
    property color empty: Theme.ink.line

    signal moved(real value)

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
                color: index < Math.round(root.value * root.bars) ? root.fill : root.empty
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        function at(x) {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: event => root.moved(at(event.x))
        onPositionChanged: event => { if (pressed) root.moved(at(event.x)); }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
