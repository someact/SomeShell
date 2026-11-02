pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media players (MPRIS). The active player is the one picked on the media
// page, else the one playing, else the first. Music or video is guessed from the player and the page
// address it reports; the browser extension (step 5) will say it exactly.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // Picked by hand on the media page; otherwise the one playing, or the first
    property var chosen: null
    readonly property var player: (chosen && players.includes(chosen)) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool active: player !== null && player.trackTitle !== ""
    readonly property bool playing: player?.isPlaying ?? false

    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0
    readonly property string url: player?.metadata?.["xesam:url"] ?? ""
    readonly property string source: {
        const m = /^https?:\/\/(?:www\.)?([^/]+)/.exec(url);
        return m ? m[1] : (player?.identity ?? "");
    }

    // "music" or "video"
    readonly property string kind: {
        const id = ((player?.identity ?? "") + " " + (player?.desktopEntry ?? "")).toLowerCase();
        if (/music\.youtube|spotify|soundcloud|bandcamp|tidal|deezer|music\.apple/.test(url) || /\.(mp3|flac|ogg|opus|m4a|wav|aac)(\?|$)/i.test(url) || /spotify|rhythmbox|elisa|strawberry|amberol|cider|tauon|mpd/.test(id))
            return "music";
        return "video";
    }

    // Position is not pushed by MPRIS: it is read while a page shows it
    property real position: 0
    function readPosition() {
        position = player?.position ?? 0;
    }

    function toggle() { player?.togglePlaying(); }
    function next() { player?.next(); }
    function previous() { player?.previous(); }
    function seek(seconds) {
        if (player?.canSeek)
            player.position = Math.max(0, Math.min(length, seconds));
    }
}
