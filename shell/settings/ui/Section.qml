import QtQuick
import qs.core

// A titled card of rows
Column {
    id: section

    property string title
    property string note
    default property alias rows: card.data

    width: parent?.width ?? 600
    spacing: 8

    SText {
        visible: text !== ""
        leftPadding: 4
        text: section.title
        font.pixelSize: Theme.font.small
        font.styleName: Theme.font.styleTitle
        color: Theme.primary
    }
    Rectangle {
        width: parent.width
        height: card.implicitHeight + 8
        radius: Theme.radius.large
        color: Theme.surfaceLow
        Column {
            id: card
            x: 4
            y: 4
            width: parent.width - 8
        }
    }
    SText {
        visible: text !== ""
        width: parent.width
        leftPadding: 4
        text: section.note
        dim: true
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
