import QtQuick
import qs.core

// Text: poster type that fills its box (the largest size at which every word
// fits). Light, regular or bold; left, centre or right.
Item {
    id: root

    property var widget: null
    property bool live: true
    property real cell: 80
    property bool card: false
    // The colors: the desktop set on a card, the wallpaper's on bare type
    property var c: Theme.paper
    readonly property var o: widget?.opts ?? {}
    readonly property var faces: ({ light: Theme.font.light, regular: Theme.font.regular, bold: Theme.font.bold })

    Text {
        anchors.fill: parent
        text: root.o.text ?? ""
        color: root.c.fg
        font.family: Theme.font.family
        font.styleName: root.faces[root.o.face] ?? Theme.font.bold
        font.pixelSize: Math.max(10, root.height)
        minimumPixelSize: 10
        fontSizeMode: Text.Fit
        wrapMode: Text.WordWrap
        lineHeight: 0.92
        horizontalAlignment: root.o.align === "center" ? Text.AlignHCenter : root.o.align === "right" ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }
}
