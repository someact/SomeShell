pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core

// The notification server. A new notification shows as an alert on the
// island (not with do not disturb); every one goes to the history, saved in
// ~/.local/state/someshell/notifications.json (the last 100).
Singleton {
    id: root

    property bool dnd: false
    // { id, app, icon, summary, body, time, actions: [{id, text}] } newest first
    property var history: []
    // The live server objects, for actions and replies
    property var live: ({})
    property int nextId: 1

    readonly property var groups: {
        const map = {};
        const order = [];
        for (const n of history) {
            if (!map[n.app]) {
                map[n.app] = [];
                order.push(n.app);
            }
            map[n.app].push(n);
        }
        return order.map(app => ({ app: app, items: map[app] }));
    }

    function dismiss(id) {
        history = history.filter(n => n.id !== id);
        live[id]?.dismiss();
        delete live[id];
        save();
    }
    function clear() {
        for (const id in live)
            live[id]?.dismiss();
        live = {};
        history = [];
        save();
    }
    function invoke(id, actionId) {
        const n = live[id];
        const a = n?.actions.find(x => x.identifier === actionId);
        if (a)
            a.invoke();
        dismiss(id);
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const id = root.nextId++;
            root.live[id] = n;
            const entry = {
                id: id,
                app: n.appName || "System",
                icon: n.image || n.appIcon || "",
                summary: n.summary,
                body: n.body.replace(/<[^>]+>/g, ""),
                time: Date.now(),
                actions: n.actions.map(a => ({ id: a.identifier, text: a.text }))
            };
            root.history = [entry].concat(root.history).slice(0, 100);
            root.save();
            n.closed.connect(() => delete root.live[id]);
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                Ui.showAlert(entry.summary, entry.body, entry.app, "notifications");
        }
    }

    function save() {
        file.setText(JSON.stringify(history.map(n => ({ id: n.id, app: n.app, icon: n.icon, summary: n.summary, body: n.body, time: n.time, actions: [] }))));
    }
    FileView {
        id: file
        path: Paths.state + "/notifications.json"
        onLoaded: {
            try {
                const old = JSON.parse(text());
                root.history = old.concat(root.history.filter(n => !old.some(o => o.id === n.id)));
                root.nextId = Math.max(1, ...root.history.map(n => n.id + 1));
            } catch (e) {}
        }
    }
}
