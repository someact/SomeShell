import QtQuick
import qs.core

// Text in Mitr. `caps` gives the poster-style label: small spaced capitals.
//   Txt { text: "Hello" }
//   Txt { text: "now playing"; caps: true }
//   Txt { text: "12:40"; size: Theme.font.headline; face: Theme.font.bold }
Text {
    property bool caps: false
    property int size: caps ? Theme.font.caption : Theme.font.body
    property string face: caps ? Theme.font.regular : Theme.font.light

    color: Theme.ink.fg
    font.family: Theme.font.family
    font.styleName: face
    font.pixelSize: size
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: caps ? size * 0.16 : 0
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    maximumLineCount: 1
}
