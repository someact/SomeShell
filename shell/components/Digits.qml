import QtQuick
import qs.core

// Text in Mitr with equal-width digits. Mitr has no tabular figures, so a
// clock or a timer drawn as one Text shifts as its digits change; here every
// digit sits in a cell as wide as Mitr's widest digit.
//   Digits { text: "12:05"; pixelSize: 96; styleName: Theme.font.styleDisplay }
Row {
    id: root

    property string text
    property color color: Theme.fgIsland
    property int pixelSize: Theme.font.normal
    property string styleName: Theme.font.styleTitle
    property int style: Text.Normal
    property color styleColor: "transparent"

    TextMetrics {
        id: widest
        font.family: Theme.font.ui
        font.pixelSize: root.pixelSize
        font.styleName: root.styleName
        text: "0"
    }

    // The model is the length, not the characters: each tick keeps the same
    // delegates and only their text changes
    Repeater {
        model: root.text.length
        Text {
            readonly property string ch: root.text.charAt(index)
            text: ch
            width: ch >= "0" && ch <= "9" ? Math.ceil(widest.advanceWidth) : implicitWidth
            horizontalAlignment: Text.AlignHCenter
            color: root.color
            style: root.style
            styleColor: root.styleColor
            renderType: Text.NativeRendering
            font.family: Theme.font.ui
            font.pixelSize: root.pixelSize
            font.styleName: root.styleName
        }
    }
}
