import QtQuick
import qs.core
import qs.components
import qs.services

// Resting island: the clock, with live things beside it in a small form:
// music or video playing on the left, a recording on the right. With both,
// the day is left out to keep the island short.
Item {
    id: root

    readonly property bool media: Media.active && Media.playing
    readonly property bool rec: Recorder.recording

    implicitWidth: row.implicitWidth + 36
    implicitHeight: Theme.shape.band

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        // Playing: cover and a small level meter
        Row {
            visible: root.media
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 6
                color: Theme.ink.raised
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.media ? Media.art : ""
                    sourceSize: Qt.size(44, 44)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                height: 14
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        radius: 1
                        color: Theme.ink.accent
                        height: 5
                        SequentialAnimation on height {
                            running: root.media
                            loops: Animation.Infinite
                            NumberAnimation { to: 14; duration: 380 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: 380 + index * 90; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        Digits {
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.time
            size: Theme.font.title
        }
        Txt {
            visible: !(root.media && root.rec)
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.day
            caps: true
            color: Theme.ink.mute
        }

        // Recording: red dot and the time
        Row {
            visible: root.rec
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: "#ff5a4e"
                SequentialAnimation on opacity {
                    running: root.rec
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            Digits {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.floor(Recorder.seconds / 60) + ":" + String(Recorder.seconds % 60).padStart(2, "0")
                size: Theme.font.small
                face: Theme.font.medium
            }
        }
    }
}
