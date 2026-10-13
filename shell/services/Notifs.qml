pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.core

// Notification daemon. Kept in memory only (no history file to rewrite on
// every event); the newest Config.notifications.keep survive.
Singleton {
    id: root

    readonly property list<Notification> list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length
    property Notification peeked: null
    readonly property bool dnd: Config.notifications.dnd || (Streamer.active && Config.streamer.silence)
    // Streamer mode: text shown in the island (which screen shares capture) is masked
    readonly property bool masked: Streamer.active

    function toggleDnd() {
        Config.notifications.dnd = !Config.notifications.dnd;
    }
    function dismiss(n) {
        n?.dismiss();
    }
    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        peeked = null;
    }
    function title(n) {
        if (!n)
            return "";
        return masked ? (n.appName || "Notification") : (n.summary || n.appName);
    }
    function text(n) {
        if (!n)
            return "";
        return masked ? (n.body !== "" ? "Hidden while streaming" : "") : n.body;
    }

    // Image for a notification: its own image, else the app icon. Masked: the
    // app icon only (images are often screenshots or avatars).
    // `unmasked` is for surfaces left out of screen shares.
    function icon(n, unmasked) {
        if (!n)
            return "";
        if (n.image && (!masked || unmasked))
            return n.image;
        const a = n.appIcon;
        if (a.startsWith("/"))
            return "file://" + a;
        if (a.includes("://"))
            return a;
        return Quickshell.iconPath(a || n.desktopEntry || n.appName.toLowerCase(), true);
    }
    function invoke(n, action) {
        action.invoke();
        // Many senders close the notification themselves once an action is
        // taken (notify-send -A does); dismiss only what is still there
        if (!n.resident)
            Qt.callLater(() => {
                if (server.trackedNotifications.values.includes(n))
                    n.dismiss();
            });
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const all = trackedNotifications.values;
            if (all.length > Config.notifications.keep)
                all[0].expire();
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                root.peeked = n;
                peekTimer.restart();
            }
        }
    }

    Connections {
        target: root.peeked
        function onClosed() {
            root.peeked = null;
        }
    }

    Timer {
        id: peekTimer
        interval: root.peeked?.urgency === NotificationUrgency.Critical ? Config.island.peekMs * 2 : Config.island.peekMs
        onTriggered: root.peeked = null
    }
}
