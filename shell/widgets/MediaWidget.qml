import QtQuick
import qs.core
import qs.components
import qs.services

// Now playing: art, title, progress, controls, the player's volume and three
// synced lyric lines (media.widgetLyrics). Hidden while nothing plays (shown as
// a placeholder in edit mode so it can still be placed).
DesktopWidget {
    id: root

    property bool live: true        // false while windows cover the desktop: no progress updates
    visible: Media.active || editing

    // Progress ticks only while someone can see it
    readonly property bool watching: live && Media.active
    property bool counted: false
    function sync() {
        if (watching !== counted) {
            Media.watchers += watching ? 1 : -1;
            counted = watching;
        }
    }
    onWatchingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (counted)
            Media.watchers--;
        if (lyricsCounted)
            Lyrics.watchers--;
    }

    // Lyrics: shown when on and found; the line follows only while visible
    readonly property bool lyricsOn: Config.media.lyrics && Config.media.widgetLyrics
    readonly property bool showLyrics: lyricsOn && Media.active && Lyrics.has
    readonly property bool lyricsWatching: lyricsOn && watching
    property bool lyricsCounted: false
    onLyricsWatchingChanged: {
        if (lyricsWatching !== lyricsCounted) {
            Lyrics.watchers += lyricsWatching ? 1 : -1;
            lyricsCounted = lyricsWatching;
            Lyrics.sync();
        }
    }

    Column {
        spacing: 14
        Row {
            spacing: 16
            Cover {
                width: 88
                height: 88
                radius: Theme.radius.normal
                source: Media.art
            }
            Column {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label {
                    width: parent.width
                    text: Media.active ? Media.title : "Nothing playing"
                    color: root.fg
                    font.pixelSize: Theme.font.large
                    font.styleName: Theme.font.styleTitle
                }
                Label {
                    width: parent.width
                    text: Media.artist
                    color: root.fgDim
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                    Rectangle {
                        height: parent.height
                        radius: 2
                        width: parent.width * Media.progress
                        color: Theme.primary
                    }
                }
                Row {
                    topPadding: 4
                    spacing: 4
                    IconButton {
                        icon: "skip_previous"
                        iconColor: root.fg
                        hoverColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                        onClicked: Media.previous()
                    }
                    IconButton {
                        icon: Media.isPlaying ? "pause" : "play_arrow"
                        active: true
                        onClicked: Media.toggle()
                    }
                    IconButton {
                        icon: "skip_next"
                        iconColor: root.fg
                        hoverColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                        onClicked: Media.next()
                    }
                }
                Slider {
                    visible: Media.active && Media.hasVolume
                    width: parent.width
                    height: 26
                    icon: Media.muted || Media.volume <= 0.01 ? "volume_off" : Media.volume < 0.5 ? "volume_down" : "volume_up"
                    value: Media.volume
                    fillColor: root.fg
                    trackColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                    contentColor: root.fg
                    contentDim: root.fgDim
                    contentOnFill: root.framed ? Theme.surface : Qt.rgba(0, 0, 0, 0.8)
                    onMoved: v => Media.setVolume(v)
                    onIconClicked: Media.toggleMute()
                }
            }
        }

        Loader {
            active: root.showLyrics
            visible: active
            width: 324
            height: active ? 96 : 0
            sourceComponent: LyricsPane {
                lines: Lyrics.lines
                index: Lyrics.index
                plain: Lyrics.plain
                synced: Lyrics.synced
                fg: root.fg
                fgDim: root.fgDim
                fontSize: Theme.font.small
                seekable: Media.player?.canSeek ?? false
                onSeek: time => {
                    Media.player.position = time;
                    Lyrics.sync();
                }
            }
        }
    }
}
