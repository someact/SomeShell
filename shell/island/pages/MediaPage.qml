import QtQuick
import qs.core
import qs.components
import qs.services

// 03 Media. Music gets a square cover and big type; video gets a wide
// picture. With several players, chips along the top pick one. The position
// is read once a second only while this page shows and something plays.
Item {
    id: root

    readonly property bool music: Media.kind === "music"
    readonly property int coverSize: music ? 200 : 0

    implicitWidth: !Media.active ? 420 : music ? 640 : 700
    implicitHeight: col.implicitHeight

    function time(s) {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        running: Media.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: Media.readPosition()
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Players, when there is more than one
        Row {
            visible: Media.players.length > 1
            spacing: 6
            Repeater {
                model: Media.players
                Tap {
                    required property var modelData
                    width: chipText.implicitWidth + 24
                    height: 30
                    outlined: true
                    active: modelData === Media.player
                    onClicked: Media.chosen = modelData
                    Txt {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.parent.modelData?.identity ?? ""
                        caps: true
                        color: parent.fg
                    }
                }
            }
        }

        Txt {
            visible: !Media.active
            text: "Nothing is playing"
            caps: true
            color: Theme.ink.mute
            topPadding: 20
            bottomPadding: 20
        }

        Row {
            visible: Media.active
            spacing: 24

            // Cover (music) or picture (video)
            Rectangle {
                width: root.music ? root.coverSize : 300
                height: root.music ? root.coverSize : 169
                radius: 16
                color: Theme.ink.raised
                clip: true
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: Media.art === ""
                    name: root.music ? "album" : "movie"
                    size: 48
                    color: Theme.ink.mute
                }
            }

            Column {
                width: (root.music ? 640 - root.coverSize : 700 - 300) - 24
                spacing: 6

                Txt {
                    width: parent.width
                    text: (Media.playing ? "Now playing" : "Paused") + "  ·  " + Media.source
                    caps: true
                    color: Theme.ink.mute
                }
                Txt {
                    width: parent.width
                    text: Media.title
                    size: root.music ? 30 : 24
                    face: Theme.font.bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    lineHeight: 1.05
                }
                Txt {
                    width: parent.width
                    text: [Media.artist, Media.album].filter(Boolean).join("  ·  ")
                    caps: true
                    color: Theme.ink.fg
                }

                // Progress
                Item {
                    width: parent.width
                    height: 42
                    visible: Media.length > 0
                    BarSlider {
                        width: parent.width
                        height: 12
                        y: 8
                        bars: 48
                        fill: Theme.ink.accent
                        value: Media.length > 0 ? Media.position / Media.length : 0
                        onMoved: v => Media.seek(v * Media.length)
                    }
                    Txt {
                        anchors.bottom: parent.bottom
                        text: root.time(Media.position)
                        caps: true
                        color: Theme.ink.mute
                    }
                    Txt {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: root.time(Media.length)
                        caps: true
                        color: Theme.ink.mute
                    }
                }

                Row {
                    spacing: 8
                    topPadding: 4
                    Repeater {
                        model: root.music
                            ? [{ icon: "skip_previous", run: () => Media.previous() }, { icon: Media.playing ? "pause" : "play_arrow", run: () => Media.toggle(), main: true }, { icon: "skip_next", run: () => Media.next() }]
                            : [{ icon: "replay_10", run: () => Media.seek(Media.position - 10) }, { icon: Media.playing ? "pause" : "play_arrow", run: () => Media.toggle(), main: true }, { icon: "forward_10", run: () => Media.seek(Media.position + 10) }]
                        Tap {
                            required property var modelData
                            width: modelData.main ? 56 : 40
                            height: 40
                            radius: 20
                            outlined: true
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

                    // Like on the site (YouTube Music, through the extension)
                    Tap {
                        visible: root.music && Media.liked !== null
                        width: 40
                        height: 40
                        radius: 20
                        outlined: true
                        onClicked: Media.like()
                        Icon {
                            anchors.centerIn: parent
                            name: "favorite"
                            filled: Media.liked === true
                            color: Media.liked === true ? Theme.ink.accent : parent.fg
                        }
                    }
                }
            }
        }
    }
}
