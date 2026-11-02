import QtQuick
import qs.core
import qs.components
import qs.services

// The pointer is on the island: a bigger clock, and one row per live thing
// with its own controls (pause the music, stop the recording). With nothing
// live, a hint that a click opens the island.
Item {
    id: root

    readonly property bool media: Media.active
    readonly property bool rec: Recorder.recording

    function time(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec;
    }

    // The top row sets the width: clock, date and (with nothing live) the hint
    implicitWidth: Math.max(col.implicitWidth + 44, 400,
        clock.width + 14 + date.implicitWidth + (hint.visible ? 28 + hint.implicitWidth : 0) + 44)
    implicitHeight: col.implicitHeight + 30

    Column {
        id: col
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 44
        spacing: 10

        Item {
            width: parent.width
            height: clock.height
            Digits {
                id: clock
                text: Clock.time
                size: Theme.font.headline
            }
            Txt {
                id: date
                anchors.left: clock.right
                anchors.leftMargin: 14
                anchors.verticalCenter: clock.verticalCenter
                text: Clock.date
                caps: true
                color: Theme.ink.mute
            }
            Txt {
                id: hint
                visible: !root.media && !root.rec
                anchors.right: parent.right
                anchors.verticalCenter: clock.verticalCenter
                text: "Click to open"
                caps: true
                color: Theme.ink.mute
            }
        }

        // Music or video
        Item {
            visible: root.media
            width: parent.width
            height: 48
            Rectangle {
                id: cover
                width: 48
                height: 48
                radius: 10
                color: Theme.ink.raised
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.media ? Media.art : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: cover.right
                anchors.leftMargin: 12
                anchors.right: controls.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    width: parent.width
                    text: Media.title
                    face: Theme.font.medium
                }
                Txt {
                    width: parent.width
                    text: Media.artist || Media.source
                    caps: true
                    color: Theme.ink.mute
                }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [{ icon: "skip_previous", run: () => Media.previous() }, { icon: Media.playing ? "pause" : "play_arrow", run: () => Media.toggle(), main: true }, { icon: "skip_next", run: () => Media.next() }]
                    Tap {
                        required property var modelData
                        width: 36
                        height: 36
                        radius: 18
                        active: modelData.main === true
                        onClicked: modelData.run()
                        Icon {
                            anchors.centerIn: parent
                            name: parent.parent.modelData.icon
                            filled: true
                            color: parent.fg
                        }
                    }
                }
            }
        }

        // Elapsed, a thin progress line, the length; a click on the line seeks
        Item {
            id: progressRow
            visible: root.media && Media.length > 0
            width: parent.width
            height: 18

            PositionWatch { active: progressRow.visible }

            Txt {
                id: elapsed
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                text: root.time(Media.position)
                size: Theme.font.small
                color: Theme.ink.mute
            }
            Item {
                id: track
                anchors.left: elapsed.right
                anchors.right: total.left
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                height: parent.height
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Theme.ink.line
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Media.progress
                    height: 3
                    radius: 1.5
                    color: Theme.ink.accent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => Media.seek(event.x / width * Media.length)
                }
            }
            Txt {
                id: total
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                horizontalAlignment: Text.AlignRight
                text: root.time(Media.length)
                size: Theme.font.small
                color: Theme.ink.mute
            }
        }

        // Recording
        Item {
            visible: root.rec
            width: parent.width
            height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: "#ff5a4e"
                }
                Digits {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.floor(Recorder.seconds / 60) + ":" + String(Recorder.seconds % 60).padStart(2, "0")
                    size: Theme.font.title
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.sound ? "Recording with sound" : "Recording"
                    caps: true
                    color: Theme.ink.mute
                }
            }
            Tap {
                anchors.right: parent.right
                width: 80
                height: 34
                active: true
                onClicked: Recorder.stop()
                Txt {
                    anchors.centerIn: parent
                    text: "Stop"
                    caps: true
                    color: parent.fg
                }
            }
        }
    }
}
