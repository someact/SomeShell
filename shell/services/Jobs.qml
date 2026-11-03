pragma Singleton
import QtQuick
import Quickshell

// Long jobs the island shows while they run: video downloads and Bluetooth
// transfers. Each service adds its job, updates its progress and finishes
// it; Rest shows the first running one on the right (a ring and the
// percent), Peek lists them with a Cancel.
//   { id, kind: "download"|"send"|"receive", icon, title, progress: 0..1 (-1: not known yet) }
Singleton {
    id: root

    property var list: []
    readonly property var current: list.length > 0 ? list[0] : null
    // Cancel callbacks by id (kept out of `list`, which is copied on change)
    property var cancels: ({})
    property int next: 1

    function add(kind, icon, title, cancel) {
        const id = next++;
        list = list.concat([{ id: id, kind: kind, icon: icon, title: title, progress: -1 }]);
        if (cancel)
            cancels[id] = cancel;
        return id;
    }
    function update(id, changes) {
        list = list.map(j => j.id === id ? Object.assign({}, j, changes) : j);
    }
    // Progress in whole percents, so a chatty tool does not rebuild the list
    // on every line
    function progress(id, p) {
        const j = list.find(x => x.id === id);
        if (j && Math.floor(j.progress * 100) !== Math.floor(p * 100))
            update(id, { progress: p });
    }
    function finish(id) {
        list = list.filter(j => j.id !== id);
        delete cancels[id];
    }
    function cancel(id) {
        const c = cancels[id];
        if (c)
            c();
    }
}
