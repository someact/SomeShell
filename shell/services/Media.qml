pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media players (MPRIS). The active player is the one picked on the media
// page, else the one playing, else the first. When the browser extension
// knows the tab (Browser), its site, full-size cover and music or video win;
// otherwise they are guessed from the player and the address it reports.
Singleton {
    id: root

    // Some apps register twice (VLC: `vlc` and `vlc.instance<pid>`): the same
    // app with the same track in the same state counts once
    readonly property var players: {
        const out = [];
        for (const p of Mpris.players.values) {
            if (!out.some(q => q.identity === p.identity && q.trackTitle === p.trackTitle && q.playbackState === p.playbackState))
                out.push(p);
        }
        return out;
    }
    // Picked by hand on the media page; otherwise the one playing, or the first
    property var chosen: null
    readonly property var player: (chosen && players.includes(chosen)) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool active: player !== null && player.trackTitle !== ""
    readonly property bool playing: player?.isPlaying ?? false

    // The browser tab this player shows, when the extension tells us
    readonly property var tab: Browser.match(player)

    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist || tab?.artist || ""
    readonly property string album: player?.trackAlbum || tab?.album || ""
    readonly property string art: tab?.cover || player?.trackArtUrl || ""
    // Liked on the site (YouTube Music); null where the site has no like
    readonly property var liked: tab?.canLike ? tab.liked === true : null
    // A browser tab's own duration (the extension reads the media element);
    // else the player's, only when it sent one: Zen drops the length after a
    // seek, and Quickshell then reports about the position as the length
    readonly property real length: (tab?.duration > 0 ? tab.duration : 0) || (player?.lengthSupported ? (player.length || 0) : 0)
    readonly property string url: tab?.url || player?.metadata?.["xesam:url"] || ""
    readonly property string source: {
        if (tab)
            return tab.site;
        const m = /^https?:\/\/(?:www\.)?([^/]+)/.exec(url);
        return m ? m[1] : (player?.identity ?? "");
    }

    // "music" or "video"
    readonly property string kind: {
        if (tab)
            return tab.kind === "music" ? "music" : "video";
        const id = ((player?.identity ?? "") + " " + (player?.desktopEntry ?? "")).toLowerCase();
        if (/music\.youtube|spotify|soundcloud|bandcamp|tidal|deezer|music\.apple/.test(url) || /\.(mp3|flac|ogg|opus|m4a|wav|aac)(\?|$)/i.test(url) || /spotify|rhythmbox|elisa|strawberry|amberol|cider|tauon|mpd/.test(id))
            return "music";
        return "video";
    }

    // Position: MPRIS does not push it. It is read at once on a seek, a pause
    // or a new track, and then on each whole second of the track while
    // something plays and a view shows it (`watchers`), so the shown second
    // turns when the track's does.
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    property int watchers: 0
    // When `position` was set (ms), to estimate it in between
    property real positionAt: 0
    // After a seek from here, reports far from the target are the player's
    // old position (Zen sends one while a new track loads): skipped for a
    // moment, until it confirms
    property real seekTo: -1
    property real seekUntil: 0
    function readPosition() {
        const p = player?.position ?? 0;
        if (seekTo >= 0) {
            if (Date.now() < seekUntil && Math.abs(p - seekTo) > 2)
                return scheduleTick();
            seekTo = -1;
        }
        setPosition(p);
    }
    function setPosition(seconds) {
        position = Math.max(0, seconds);
        positionAt = Date.now();
        scheduleTick();
    }
    // The position now, between reads
    function positionNow() {
        return playing ? position + (Date.now() - positionAt) / 1000 * (player?.rate || 1) : position;
    }
    function scheduleTick() {
        if (!playing || watchers <= 0) {
            tick.stop();
            return;
        }
        const now = positionNow();
        tick.interval = Math.max(50, (Math.floor(now) + 1 - now) * 1000 / (player?.rate || 1) + 20);
        tick.restart();
    }
    Timer {
        id: tick
        onTriggered: root.readPosition()
    }
    onWatchersChanged: readPosition()
    onPlayerChanged: readPosition()
    onPlayingChanged: readPosition()
    // A new track starts at 0; players report its position a moment later
    onTitleChanged: {
        setPosition(0);
        settle.restart();
    }
    Timer {
        id: settle
        interval: 400
        onTriggered: root.readPosition()
    }
    Connections {
        target: root.player
        // Sent on a seek (here or in the player)
        function onPositionChanged() { root.readPosition(); }
    }


    function toggle() { player?.togglePlaying(); }
    function next() { player?.next(); }
    function previous() { player?.previous(); }
    function like() { Browser.command(tab, "like"); }
    // Shown at once; the player confirms with a seek signal. Without a known
    // length (a new track) the seek is not clamped to it
    function seek(seconds) {
        if (!player?.canSeek)
            return;
        const to = Math.max(0, length > 0 ? Math.min(length - 1, seconds) : seconds);
        seekTo = to;
        seekUntil = Date.now() + 1500;
        player.position = to;
        setPosition(to);
    }
}
