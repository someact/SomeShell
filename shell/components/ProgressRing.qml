import QtQuick
import QtQuick.Shapes
import qs.core

// A thin ring that fills clockwise from the top (0..1), with an icon inside.
// A progress below 0 (not known yet) shows a short arc that turns.
//   ProgressRing { value: job.progress; icon: "download" }
Item {
    id: root

    property real value: 0
    property string icon: ""
    property real size: 26
    property real ring: 2
    property color color: Theme.ink.accent
    readonly property bool unknown: value < 0

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.ink.line
            strokeWidth: root.ring
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: (root.size - root.ring) / 2; radiusY: (root.size - root.ring) / 2
                startAngle: 0; sweepAngle: 360
            }
        }
    }
    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.ring
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: (root.size - root.ring) / 2; radiusY: (root.size - root.ring) / 2
                startAngle: -90
                sweepAngle: root.unknown ? 70 : 360 * Math.max(0, Math.min(1, root.value))
            }
        }
        // Turning only while the progress is not known; back to the top after
        rotation: 0
        RotationAnimation on rotation {
            id: turn
            running: root.unknown && root.visible
            onRunningChanged: if (!running) arc.rotation = 0
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
        }
    }
    Icon {
        anchors.centerIn: parent
        visible: root.icon !== ""
        name: root.icon
        filled: true
        size: Math.round(root.size * 0.55)
        color: Theme.ink.fg
    }
}
