import QtQuick
import qs.core
import qs.components

// Clock: the time as huge rolling digits, the date in spaced capitals under
// it. Sized from the box: as large as fits its height and width.
Item {
    id: root

    property var widget: null
    property bool live: true
    property real cell: 80
    property bool card: false
    // The colors: the desktop set on a card, the wallpaper's on bare type
    property var c: Theme.paper
    readonly property var o: widget?.opts ?? {}
    readonly property bool showDate: o.date !== false
    readonly property string align: o.align ?? "left"

    // Mitr's time is about 3 em wide (four digit cells and a colon)
    readonly property int size: Math.max(12, Math.floor(Math.min(height * (showDate ? 0.66 : 0.8), width / 3.1)))

    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        x: root.align === "center" ? (root.width - width) / 2 : root.align === "right" ? root.width - width : 0
        spacing: -root.size * 0.12

        Digits {
            id: time
            anchors.left: root.align === "left" ? parent.left : undefined
            anchors.right: root.align === "right" ? parent.right : undefined
            anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
            text: Clock.time
            size: root.size
            face: Theme.font.bold
            color: root.c.fg
        }
        Txt {
            visible: root.showDate
            anchors.left: root.align === "left" ? parent.left : undefined
            anchors.right: root.align === "right" ? parent.right : undefined
            anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
            leftPadding: root.align === "left" ? root.size * 0.04 : 0
            text: Clock.date
            caps: true
            size: Math.max(11, Math.round(root.size * 0.15))
            color: root.c.fg
            opacity: 0.8
        }
    }
}
