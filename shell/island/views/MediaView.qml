import QtQuick
import Quickshell.Services.Mpris
import qs.core
import qs.components
import qs.services

// Now playing, the player's own volume and synced lyrics. Enter/Space play-pause,
// ↑/↓ previous/next, +/− volume, L shows or hides lyrics, click a player chip to switch.
FocusScope {
    id: root

    readonly property bool showLyrics: Media.player !== null && Config.media.lyrics && Config.media.lyricsPane
    readonly property int topHeight: Media.hasVolume ? 190 : 156

    implicitWidth: 520
    implicitHeight: !Media.player ? 80 : topHeight + (showLyrics ? 14 + 184 : 0)

    Component.onCompleted: {
        Media.watchers++;
        syncWatch();
    }
    Component.onDestruction: {
        Media.watchers--;
        if (following)
            Lyrics.watchers--;
    }

    // The lyric line follows the playhead only while the pane is up
    property bool following: false
    function syncWatch() {
        const want = showLyrics;
        if (want !== following) {
            Lyrics.watchers += want ? 1 : -1;
            following = want;
            Lyrics.sync();
        }
    }
    onShowLyricsChanged: syncWatch()

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            Media.toggle();
            return true;
        case Qt.Key_Up:
            Media.previous();
            return true;
        case Qt.Key_Down:
            Media.next();
            return true;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            Media.setVolume(Media.volume + 0.05);
            return true;
        case Qt.Key_Minus:
            Media.setVolume(Media.volume - 0.05);
            return true;
        case Qt.Key_L:
            if (Config.media.lyrics)
                Config.media.lyricsPane = !Config.media.lyricsPane;
            return true;
        }
        return UiState.navKey(event);
    }

    Label {
        anchors.centerIn: parent
        visible: !Media.player
        text: "Nothing playing"
        color: Theme.fgIslandDim
    }

    Row {
        visible: Media.player !== null
        width: parent.width
        height: root.topHeight
        spacing: 16

        Cover {
            width: 148
            height: 148
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radius.large
            source: Media.art
        }

        Column {
            width: parent.width - 164
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Title, then the player chips and the lyrics button in what is left
            Item {
                width: parent.width
                height: Math.max(titleLabel.implicitHeight, tools.height)
                Label {
                    id: titleLabel
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (tools.width > 0 ? tools.width + 10 : 0)
                    text: Media.title
                    font.pixelSize: Theme.font.large
                    font.styleName: Theme.font.styleTitle
                }
                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Player switcher, when there is more than one
                    Repeater {
                        model: Media.players.length > 1 ? Media.players : []
                        PressButton {
                            required property MprisPlayer modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(chip.implicitWidth, 84) + 16
                            height: 24
                            color: Theme.islandRaised
                            active: Media.player === modelData
                            onClicked: Media.last = modelData
                            Label {
                                id: chip
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, 84)
                                text: modelData.identity
                                font.pixelSize: Theme.font.small
                                color: parent.active ? Theme.fgPrimary : Theme.fgIsland
                            }
                        }
                    }
                    IconButton {
                        visible: Config.media.lyrics
                        width: 30
                        height: 30
                        icon: "lyrics"
                        iconSize: 18
                        active: Config.media.lyricsPane
                        onClicked: Config.media.lyricsPane = !Config.media.lyricsPane
                    }
                }
            }
            Label {
                width: parent.width
                text: Media.artist
                color: Theme.fgIslandDim
            }

            // progress
            Item {
                width: parent.width
                height: 22
                Rectangle {
                    id: bar
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.islandRaised
                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: Theme.fgIsland
                        width: parent.width * Media.progress
                        Behavior on width {
                            Spring { preset: "gentle" }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: Media.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => Media.seek(event.x / width)
                }
            }
            Row {
                width: parent.width
                Label {
                    width: parent.width / 2
                    mono: true
                    font.pixelSize: Theme.font.small
                    color: Theme.fgIslandDim
                    text: root.fmt(Media.player?.position ?? 0)
                }
                Label {
                    width: parent.width / 2
                    mono: true
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Theme.font.small
                    color: Theme.fgIslandDim
                    text: root.fmt(Media.length)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                IconButton {
                    icon: "skip_previous"
                    iconSize: 26
                    width: 40
                    height: 40
                    onClicked: Media.previous()
                }
                IconButton {
                    icon: Media.isPlaying ? "pause" : "play_arrow"
                    iconSize: 30
                    width: 48
                    height: 48
                    color: Theme.islandRaised
                    onClicked: Media.toggle()
                }
                IconButton {
                    icon: "skip_next"
                    iconSize: 26
                    width: 40
                    height: 40
                    onClicked: Media.next()
                }
            }

            // This player's volume (its Pipewire stream, or MPRIS)
            Slider {
                visible: Media.hasVolume
                width: parent.width
                height: 30
                icon: Media.muted || Media.volume <= 0.01 ? "volume_off" : Media.volume < 0.5 ? "volume_down" : "volume_up"
                value: Media.volume
                onMoved: v => Media.setVolume(v)
                onIconClicked: Media.toggleMute()
            }
        }
    }


    Loader {
        active: root.showLyrics
        y: root.topHeight + 14
        width: parent.width
        height: 184
        sourceComponent: LyricsPane {
            lines: Lyrics.lines
            index: Lyrics.index
            plain: Lyrics.plain
            synced: Lyrics.synced
            seekable: Media.player?.canSeek ?? false
            message: Lyrics.status === "loading" ? "Looking for lyrics…"
                : Lyrics.status === "none" ? "No lyrics for this track"
                : Lyrics.status === "error" ? "Couldn't reach lrclib.net · click to retry"
                : Lyrics.has ? "" : "…"
            onSeek: time => {
                Media.player.position = time;
                Lyrics.sync();
            }
            onMessageClicked: Lyrics.retry()
        }
    }


    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        const m = Math.floor(s / 60);
        return m + ":" + String(s % 60).padStart(2, "0");
    }
}
