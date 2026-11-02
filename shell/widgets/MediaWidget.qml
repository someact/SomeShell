import QtQuick
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// Now playing: the cover, title and artist, previous / play / next, and the
// track's progress as a thin line. A click outside the buttons opens the
// island's Media page. "Nothing playing" when no player has a track.
Item {
    id: root

    property var widget: null
    property bool live: true
    property real cell: 80
    property bool card: false
    // The colors: the desktop set on a card, the wallpaper's on bare type
    property var c: Theme.paper

    readonly property real unit: Math.min(height, cell * 2)
    readonly property bool tall: height >= cell * 2.6

    PositionWatch {
        active: root.live && root.visible && Media.active
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.live
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openPage("media")
    }

    ClippingRectangle {
        id: cover
        width: root.tall ? Math.min(root.height, root.width * 0.45) : root.height
        height: width
        anchors.verticalCenter: parent.verticalCenter
        radius: Math.round(root.cell * 0.2)
        color: root.c.raised
        Image {
            anchors.fill: parent
            source: Media.art
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: Media.art !== ""
        }
        Icon {
            anchors.centerIn: parent
            visible: Media.art === ""
            name: "music_note"
            size: Math.round(parent.width * 0.4)
            color: root.c.mute
        }
    }

    Column {
        id: info
        anchors.left: cover.right
        anchors.leftMargin: Math.round(root.cell * 0.22)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.unit * 0.04)

        Txt {
            width: parent.width
            visible: Media.active
            text: "Now playing"
            caps: true
            size: Math.max(10, Math.round(root.unit * 0.07))
            color: root.c.mute
        }
        Txt {
            width: parent.width
            text: Media.active ? Media.title : "Nothing playing"
            size: Math.max(13, Math.round(root.unit * 0.14))
            face: Theme.font.medium
            color: Media.active ? root.c.fg : root.c.mute
        }
        Txt {
            width: parent.width
            visible: Media.active && Media.artist !== ""
            text: Media.artist
            size: Math.max(11, Math.round(root.unit * 0.1))
            color: root.c.mute
        }
        Row {
            visible: Media.active
            spacing: Math.round(root.unit * 0.04)
            leftPadding: -Math.round(root.unit * 0.04)
            WidgetButton {
                c: root.c
                icon: "skip_previous"
                size: Math.round(root.unit * 0.26)
                live: root.live
                onClicked: Media.previous()
            }
            WidgetButton {
                c: root.c
                icon: Media.playing ? "pause" : "play_arrow"
                filled: true
                size: Math.round(root.unit * 0.26)
                live: root.live
                onClicked: Media.toggle()
            }
            WidgetButton {
                c: root.c
                icon: "skip_next"
                size: Math.round(root.unit * 0.26)
                live: root.live
                onClicked: Media.next()
            }
        }
        // The track's progress
        Item {
            visible: Media.active && Media.length > 0
            width: parent.width
            height: Math.max(3, Math.round(root.unit * 0.03)) + 4
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: parent.height - 4
                radius: height / 2
                color: root.c.line
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Media.progress
                height: parent.height - 4
                radius: height / 2
                color: root.c.fg
            }
        }
    }
}
