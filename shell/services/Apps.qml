pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Installed apps (desktop entries), searched by name, keywords and generic
// name. Apps you open often and recently rank first: each launch is counted
// in ~/.local/state/someshell/launches.json.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // How well `q` matches `text`: 0 = no match, higher is better
    function score(text, q) {
        if (!text)
            return 0;
        const t = text.toLowerCase();
        if (t === q) return 100;
        if (t.startsWith(q)) return 80;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 60;
        if (t.includes(q)) return 40;
        // Letters in order (zbr -> Zen Browser)
        let i = 0;
        for (const c of t)
            if (c === q[i]) i++;
        return i === q.length ? 15 : 0;
    }

    // Launch history bonus: more and more recent launches rank higher
    function used(id) {
        const u = history.apps[id];
        if (!u)
            return 0;
        const days = (Date.now() - u.last) / 86400000;
        return Math.min(30, u.count * 3) * (days < 1 ? 1 : days < 7 ? 0.7 : 0.4);
    }

    // Up to `limit` entries for a query; the most used ones when it is empty
    function search(query, limit) {
        const q = query.trim().toLowerCase();
        const list = [];
        for (const e of all) {
            let s;
            if (!q) {
                // Empty search: only apps you have opened, most used first
                s = used(e.id);
                if (s === 0)
                    continue;
            } else {
                s = Math.max(score(e.name, q),
                    score(e.genericName, q) * 0.7,
                    ...(e.keywords ?? []).map(k => score(k, q) * 0.6));
                if (s === 0)
                    continue;
                s += used(e.id);
            }
            list.push({ entry: e, score: s });
        }
        list.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return list.slice(0, limit ?? 6).map(x => x.entry);
    }

    function launch(entry) {
        const apps = Object.assign({}, history.apps);
        const u = apps[entry.id] ?? { count: 0, last: 0 };
        apps[entry.id] = { count: u.count + 1, last: Date.now() };
        history.apps = apps;
        file.writeAdapter();
        entry.execute();
    }

    FileView {
        id: file
        path: Paths.state + "/launches.json"
        JsonAdapter {
            id: history
            property var apps: ({})
        }
    }
}
