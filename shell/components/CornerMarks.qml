import QtQuick

// Print-style corner marks inside an item: a short L in each corner (the
// overview's pages, the power buttons). `inset` moves them in or out.
Item {
    id: root
    property real u: 1
    property color color: "white"
    readonly property real len: 12 * u
    property real inset: 6 * u
    readonly property real t: 2

    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atLower: index > 1
            x: atRight ? root.width - root.inset - root.len : root.inset
            y: atLower ? root.height - root.inset - root.len : root.inset
            width: root.len
            height: root.len
            Rectangle {
                y: parent.atLower ? parent.height - root.t : 0
                width: parent.width
                height: root.t
                color: root.color
            }
            Rectangle {
                x: parent.atRight ? parent.width - root.t : 0
                width: root.t
                height: parent.height
                color: root.color
            }
        }
    }
}
