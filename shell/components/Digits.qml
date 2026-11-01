import QtQuick
import qs.core

// Text whose digits roll like an odometer when they change (a clock, a timer,
// a volume). Each digit is a column 0-9 in a cell as wide as the widest digit,
// so the text never shifts; other characters are drawn as they are.
//   Digits { text: "12:40"; size: 19; face: Theme.font.bold }
Row {
    id: root

    property string text
    property int size: Theme.font.body
    property string face: Theme.font.bold
    property color color: Theme.ink.fg

    TextMetrics {
        id: widest
        font.family: Theme.font.family
        font.styleName: root.face
        font.pixelSize: root.size
        text: "0"
    }
    readonly property real cell: Math.ceil(widest.advanceWidth)
    readonly property real lineHeight: Math.ceil(root.size * 1.25)

    Repeater {
        model: root.text.length

        Item {
            id: slot
            readonly property string ch: root.text.charAt(index)
            readonly property bool digit: ch >= "0" && ch <= "9"
            width: digit ? root.cell : glyph.implicitWidth
            height: root.lineHeight
            clip: digit

            Text {
                id: glyph
                visible: !slot.digit
                text: slot.ch
                color: root.color
                font.family: Theme.font.family
                font.styleName: root.face
                font.pixelSize: root.size
                height: root.lineHeight
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }

            Column {
                visible: slot.digit
                y: slot.digit ? -Number(slot.ch) * root.lineHeight : 0
                Behavior on y {
                    NumberAnimation { duration: Motion.slow; easing.type: Motion.easing }
                }
                Repeater {
                    model: 10
                    Text {
                        required property int index
                        width: root.cell
                        height: root.lineHeight
                        text: index
                        color: root.color
                        font.family: Theme.font.family
                        font.styleName: root.face
                        font.pixelSize: root.size
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
