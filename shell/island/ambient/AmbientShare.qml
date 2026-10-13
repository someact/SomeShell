import QtQuick
import qs.core
import qs.components
import qs.services

// Quick Share in the collapsed island: an incoming transfer asks to be accepted
// or declined here (nothing is received without that click), and a running
// transfer shows its progress. Streamer mode hides the device and file names.
Item {
    id: root

    readonly property var ask: QuickShare.pending
    readonly property var t: ask ?? QuickShare.current
    readonly property bool masked: Notifs.masked
    readonly property string who: masked ? "A device" : (t?.device ?? "")
    readonly property string what: masked ? ((t?.files ?? []).length > 0 ? "files" : "text") : QuickShare.describe(t)

    implicitWidth: 440
    implicitHeight: 64

    Row {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 4
        anchors.topMargin: 6
        anchors.bottomMargin: 8
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: Theme.radius.normal
            color: Theme.islandRaised
            Icon {
                anchors.centerIn: parent
                name: QuickShare.icon
                size: 22
                color: Theme.accentIsland
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52 - (buttons.visible ? buttons.width + 12 : 0)
            spacing: 3
            Label {
                width: parent.width
                text: root.ask ? root.who + " wants to send " + root.what : (root.t?.direction === "in" ? "Receiving " : "Sending ") + root.what
                font.weight: Theme.font.weightTitle
            }
            Label {
                visible: root.ask !== null
                width: parent.width
                text: "PIN " + (root.ask?.pin ?? "") + (root.ask?.total > 0 ? " · " + QuickShare.size(root.ask.total) : "")
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
            // Progress
            Rectangle {
                visible: root.ask === null
                width: parent.width
                height: 4
                radius: 2
                color: Theme.islandRaisedHover
                Rectangle {
                    width: parent.width * QuickShare.progress(root.t)
                    height: parent.height
                    radius: 2
                    color: Theme.accentIsland
                    Behavior on width {
                        NumberAnimation { duration: Motion.fast }
                    }
                }
            }
        }

        Row {
            id: buttons
            visible: root.ask !== null
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            IconButton {
                width: 36
                height: 36
                iconSize: 20
                icon: "close"
                color: Theme.islandRaised
                onClicked: QuickShare.reject(root.ask.id)
            }
            IconButton {
                width: 36
                height: 36
                iconSize: 20
                icon: "check"
                color: Theme.accentIsland
                iconColor: Theme.fgAccentIsland
                onClicked: QuickShare.accept(root.ask.id)
            }
        }
    }
}
