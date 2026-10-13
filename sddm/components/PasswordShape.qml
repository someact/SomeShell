import QtQuick
import QtQuick.Shapes
import "password-shapes.js" as Shapes

// The same Material outlines as SomeShell's lock screen, normalized to 0..1.
Item {
    id: root
    property string shape: "circle"
    property color color: "white"
    Shape {
        width: 1
        height: 1
        scale: Math.min(root.width, root.height)
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            PathSvg { path: Shapes.paths[root.shape] || Shapes.paths.gem }
        }
    }
}
