import QtQuick
import QtQuick.Shapes
import qs.core
import qs.services

// The playing track's cover as a circle, with a thin ring around it that
// fills clockwise from the top as the track plays. While shown it keeps
// Media's position ticking (Media.watchers).
//   CoverRing { size: 30 }
Item {
    id: root

    property real size: 30
    property real ring: 2
    property real gap: 2
    // Colors: the island's by default (the lock page passes its own)
    property color disc: Theme.ink.raised
    property color track: Theme.ink.line
    property color fill: Theme.ink.accent
    readonly property real coverSize: size - 2 * (ring + gap)

    implicitWidth: size
    implicitHeight: size

    PositionWatch { active: root.visible }

    Image {
        id: art
        visible: false
        source: Media.art
        sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
        fillMode: Image.PreserveAspectCrop
        width: root.coverSize
        height: root.coverSize
        asynchronous: true
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Cover (or a plain disc while it loads)
        ShapePath {
            strokeWidth: -1
            fillColor: root.disc
            fillItem: art.status === Image.Ready ? art : null
            fillTransform: PlanarTransform.fromTranslate(root.ring + root.gap, root.ring + root.gap)
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.coverSize / 2
                radiusY: root.coverSize / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
        // Track of the ring
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.ring
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.ring) / 2
                radiusY: (root.size - root.ring) / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
        // Progress
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.fill
            strokeWidth: root.ring
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.ring) / 2
                radiusY: (root.size - root.ring) / 2
                startAngle: -90
                sweepAngle: 360 * Media.progress
            }
        }
    }
}
