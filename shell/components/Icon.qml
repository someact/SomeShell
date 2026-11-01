import QtQuick
import qs.core

// Material Symbols glyph by ligature name, e.g. Icon { name: "volume_up" }
//
// Qt opens a separate font face (an mmap of the 14 MB font plus its own glyph
// cache) for every distinct set of variable-axis values. So the axes are
// snapped: FILL is 0 or 1 and opsz is one of the font's four optical sizes.
// Animating FILL would create a face per frame.
Text {
    property string name
    property real size: 20
    property real fill: 1

    readonly property int _opsz: size >= 44 ? 48 : size >= 32 ? 40 : size >= 22 ? 24 : 20

    text: name
    color: Theme.fgIsland
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font.icon
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill >= 0.5 ? 1 : 0, "opsz": _opsz })
}
