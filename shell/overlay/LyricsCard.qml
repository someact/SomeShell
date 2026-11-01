import QtQuick
import qs.core
import qs.components
import qs.services

// Lyrics of the playing track over the game. Open: the track, play controls and
// five lines (click one to seek). Pinned and click-through: three lines, the
// current one in the middle.
OverlayCard {
    id: root
    icon: "lyrics"
    title: "Lyrics"
    implicitWidth: 380

    // The line follows the playhead only while this card exists
    Component.onCompleted: {
        Lyrics.watchers++;
        Lyrics.sync();
    }
    Component.onDestruction: Lyrics.watchers--

    Column {
        width: parent.width
        spacing: 8

        // Track and controls, only while the overlay is open
        Row {
            visible: root.interactive && Media.player !== null
            width: parent.width
            spacing: 10
            Cover {
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                source: Media.art
            }
            Column {
                width: parent.width - 36 - 10 - controls.width - 10
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: Media.title
                    font.styleName: Theme.font.styleTitle
                }
                Label {
                    width: parent.width
                    text: Media.artist
                    color: Theme.fgIslandDim
                    font.pixelSize: Theme.font.small
                }
            }
            Row {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    width: 30
                    height: 30
                    iconSize: 18
                    icon: "skip_previous"
                    onClicked: Media.previous()
                }
                IconButton {
                    width: 30
                    height: 30
                    iconSize: 18
                    icon: Media.isPlaying ? "pause" : "play_arrow"
                    onClicked: Media.toggle()
                }
                IconButton {
                    width: 30
                    height: 30
                    iconSize: 18
                    icon: "skip_next"
                    onClicked: Media.next()
                }
            }
        }

        LyricsPane {
            width: parent.width
            height: root.interactive ? 172 : 100
            lines: Lyrics.lines
            index: Lyrics.index
            plain: Lyrics.plain
            synced: Lyrics.synced
            fontSize: root.interactive ? Theme.font.normal : Theme.font.large
            outline: !root.interactive
            fgDim: root.interactive ? Theme.fgIslandDim : "#d8d6e0"
            seekable: root.interactive && (Media.player?.canSeek ?? false)
            message: !Config.media.lyrics ? "Lyrics are off (Settings → Island → Lyrics)"
                : !Media.active ? "Nothing playing"
                : Lyrics.status === "loading" ? "Looking for lyrics…"
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
}
