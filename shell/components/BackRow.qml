import QtQuick
import qs.core

// Top of a tile's own page: back to the grid, the name, and room on the
// right for an action.
Item {
    id: root

    property string title
    default property alias actions: right.data

    implicitHeight: 40
    width: parent?.width ?? 400

    Tap {
        id: back
        width: backRow.implicitWidth + 24
        height: 36
        outlined: true
        onClicked: Ui.detail = ""
        Row {
            id: backRow
            anchors.centerIn: parent
            spacing: 8
            Icon {
                name: "arrow_back"
                size: 18
                color: back.fg
            }
            Txt {
                text: root.title
                caps: true
                color: back.fg
            }
        }
    }
    Row {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
