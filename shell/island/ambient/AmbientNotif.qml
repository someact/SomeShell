import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Notification peek: app icon or image, summary and the first lines of body.
Item {
    id: root
    readonly property var n: Notifs.peeked

    implicitWidth: 420
    implicitHeight: 64

    Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.topMargin: 6
        anchors.bottomMargin: 8
        spacing: 12

        Cover {
            width: 40
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radius.normal
            source: Notifs.icon(root.n)
            fallbackIcon: "notifications"
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52
            spacing: 2
            Label {
                width: parent.width
                text: root.n?.summary || root.n?.appName || ""
                font.styleName: Theme.font.styleTitle
            }
            Label {
                width: parent.width
                text: (root.n?.body ?? "").replace(/\n/g, " ")
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
                maximumLineCount: 1
                visible: text !== ""
            }
        }
    }
}
