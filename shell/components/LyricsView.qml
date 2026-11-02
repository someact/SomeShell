import QtQuick
import qs.core
import qs.services

// Synced lyrics: the current line bright a third of the way down, the rest
// dimmed, scrolling up as the song plays. Line changes are timed to each
// line's start (one timer to the next line), not to the position reads.
// Plain lyrics are a still column to scroll by hand.
Item {
    id: root

    readonly property bool synced: Lyrics.status === "synced"
    property int current: -1

    function update() {
        if (!synced) {
            current = -1;
            next.stop();
            return;
        }
        // A little early, like a karaoke screen
        const now = Media.positionNow() + 0.2;
        current = Lyrics.lineAt(now);
        const following = Lyrics.lines[current + 1];
        if (following && Media.playing) {
            next.interval = Math.max(40, (following.t - now) * 1000 / (Media.player?.rate || 1));
            next.restart();
        } else {
            next.stop();
        }
    }
    Timer {
        id: next
        onTriggered: root.update()
    }
    Connections {
        target: Media
        function onPositionChanged() { root.update(); }
        function onPlayingChanged() { root.update(); }
    }
    Connections {
        target: Lyrics
        function onLinesChanged() { root.update(); }
        function onStatusChanged() { root.update(); }
    }
    Component.onCompleted: update()

    Txt {
        id: label
        visible: text !== ""
        text: Lyrics.status === "plain" ? "Not synced" : Lyrics.status === "instrumental" ? "Instrumental" : ""
        caps: true
        color: Theme.ink.mute
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: label.visible ? label.height + 8 : 0
        clip: true
        model: Lyrics.status === "synced" || Lyrics.status === "plain" ? Lyrics.lines : []
        spacing: 10
        interactive: !root.synced
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: Math.max(0, root.current)
        highlightRangeMode: root.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 3
        preferredHighlightEnd: height / 3 + 1
        highlightMoveDuration: 450
        highlightMoveVelocity: -1

        delegate: Txt {
            required property var modelData
            required property int index
            readonly property bool now: index === root.current
            width: ListView.view.width
            text: modelData.text || "♪"
            size: root.synced ? Theme.font.title : Theme.font.body
            face: now ? Theme.font.bold : Theme.font.medium
            color: now || !root.synced ? Theme.ink.fg : Theme.ink.mute
            // Sung lines fade more than the ones to come
            opacity: !root.synced || now ? 1 : index < root.current ? 0.3 : 0.6
            wrapMode: Text.Wrap
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }

    // Lines fade out at the top and bottom edges instead of being cut
    Rectangle {
        anchors.top: list.top
        width: list.width
        height: 28
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.ink.bg }
            GradientStop { position: 1; color: Qt.alpha(Theme.ink.bg, 0) }
        }
    }
    Rectangle {
        anchors.bottom: list.bottom
        width: list.width
        height: 40
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.ink.bg, 0) }
            GradientStop { position: 1; color: Theme.ink.bg }
        }
    }
}
