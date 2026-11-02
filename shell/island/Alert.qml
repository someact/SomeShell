import QtQuick
import qs.core
import qs.components

// A notification or message, shown over everything for a few seconds.
// The line along the bottom runs out until it closes.
Item {
    id: root

    readonly property var alert: Ui.alert ?? { title: "", body: "", app: "", icon: "notifications", image: "" }
    readonly property int textWidth: Math.min(380, Math.max(title.implicitWidth, body.implicitWidth, app.implicitWidth))

    implicitWidth: 20 + badge.width + 14 + textWidth + 22
    implicitHeight: Math.max(44, col.implicitHeight) + 34

    Rectangle {
        id: badge
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        // A picture (a screenshot) is shown wide; otherwise the icon
        width: root.alert.image ? 78 : 44
        height: 44
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: Theme.ink.line
        Icon {
            visible: !root.alert.image
            anchors.centerIn: parent
            name: root.alert.icon
        }
        Image {
            visible: !!root.alert.image
            anchors.fill: parent
            anchors.margins: 1
            source: root.alert.image ? "file://" + root.alert.image : ""
            sourceSize: Qt.size(156, 88)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        id: col
        anchors.left: badge.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        spacing: 3

        Txt {
            id: app
            text: root.alert.app || "SomeShell"
            caps: true
            color: Theme.ink.mute
            width: parent.width
        }
        Txt {
            id: title
            text: root.alert.title
            face: Theme.font.medium
            width: parent.width
        }
        Txt {
            id: body
            visible: text !== ""
            text: root.alert.body
            size: Theme.font.small
            color: Theme.ink.mute
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        x: 20
        height: 2
        width: (root.width - 40) * fuse.left
        color: Theme.ink.accent
        QtObject {
            id: fuse
            property real left: 1
        }
        NumberAnimation {
            running: true
            target: fuse
            property: "left"
            from: 1
            to: 0
            duration: 4500
        }
    }
}
