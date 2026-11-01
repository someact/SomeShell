import QtQuick
import qs.core

// A Material Symbols Rounded icon: a thin outline, or filled when `filled`
// (turned on). The axes are snapped to two looks, since every distinct value
// opens another copy of the font.
Text {
    property string name
    property bool filled: false
    property int size: 20

    text: name
    color: Theme.ink.fg
    font.family: Theme.font.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": filled ? 400 : 300, "opsz": size >= 32 ? 40 : 24 })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
