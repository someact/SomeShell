pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What browser tabs play, told by the SomeShell extension (`browser/`). Its
// helper connects to this socket, one per running browser, and sends one
// JSON object per line: `media` (site, address, title, artist, album, cover,
// kind, playing, liked), `gone` (a tab stopped or closed) and `reset` (the
// browser's whole list follows). Commands go back the same way.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/someshell-browser.sock"

    // [{ browser, tab, site, url, title, artist, album, cover, kind, playing, duration, liked, canLike, link }]
    property var tabs: []

    function receive(link, line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        let list = tabs;
        if (m.type === "reset") {
            list = list.filter(t => t.link !== link);
        } else if (m.type === "gone") {
            list = list.filter(t => !(t.link === link && t.tab === m.tab));
        } else if (m.type === "media") {
            m.link = link;
            list = list.filter(t => !(t.link === link && t.tab === m.tab));
            list.push(m);
        } else {
            return;
        }
        tabs = list;
    }

    function dropLink(link) {
        tabs = tabs.filter(t => t.link !== link);
    }

    // The tab an MPRIS player is showing: same title; the browser's only
    // playing tab when titles differ (some sites give MPRIS the page title)
    function match(player) {
        if (!player || tabs.length === 0)
            return null;
        const title = player.trackTitle ?? "";
        const same = tabs.filter(t => t.title === title);
        if (same.length > 0)
            return same.find(t => t.playing === player.isPlaying) ?? same[0];
        const id = ((player.identity ?? "") + " " + (player.desktopEntry ?? "")).toLowerCase();
        const fromBrowser = tabs.filter(t => t.playing === player.isPlaying && id.includes(String(t.browser).toLowerCase().split(" ")[0]));
        return fromBrowser.length === 1 ? fromBrowser[0] : null;
    }

    // like, play, pause
    function command(tab, type) {
        if (!tab?.link)
            return;
        tab.link.write(JSON.stringify({ type: type, tab: tab.tab }) + "\n");
        tab.link.flush();
    }

    SocketServer {
        active: true
        path: root.socketPath
        handler: Socket {
            id: link
            parser: SplitParser {
                onRead: line => root.receive(link, line)
            }
            onConnectedChanged: {
                if (!connected)
                    root.dropLink(link);
            }
        }
    }
}
