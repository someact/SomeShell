import QtQuick
import qs.core

// A scrolling settings page: title, subtitle, then sections
Flickable {
    id: page

    property string title
    property string subtitle
    default property alias content: column.data

    contentHeight: column.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        x: 32
        y: 24
        width: Math.min(page.width - 64, 820)
        spacing: 20

        Column {
            width: parent.width
            spacing: 4
            SText {
                text: page.title
                font.pixelSize: Theme.font.display - 8
                font.styleName: Theme.font.styleTitle
            }
            SText {
                visible: text !== ""
                width: parent.width
                text: page.subtitle
                dim: true
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }
}
