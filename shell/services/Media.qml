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
    readonly property real length: player?.length ?? 0
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

    // Position is not pushed by MPRIS: it is read once a second while
    // something plays and a view that shows it is on screen (`watchers`),
    // and at once on a seek, a pause or a new track
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    property int watchers: 0
    // When `position` was read (ms), to estimate it in between
    property real positionAt: 0
    function readPosition() {
        position = player?.position ?? 0;
        positionAt = Date.now();
    }
    // The position now, between reads
    function positionNow() {
        return playing ? position + (Date.now() - positionAt) / 1000 * (player?.rate || 1) : position;
    }
    Timer {
        running: root.playing && root.watchers > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readPosition()
    }
    onPlayerChanged: readPosition()
    onTitleChanged: readPosition()
    onPlayingChanged: readPosition()
    Connections {
        target: root.player
        function onPositionChanged() { root.readPosition(); }
    }

    function toggle() { player?.togglePlaying(); }
    function next() { player?.next(); }
    function previous() { player?.previous(); }
    function like() { Browser.command(tab, "like"); }
    function seek(seconds) {
        if (player?.canSeek)
            player.position = Math.max(0, Math.min(length, seconds));
    }
}
