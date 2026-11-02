pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace designs (SomeShell.md 3.3): a name and what the resting island
// shows, per workspace number 1-10 (shared by every monitor). Stored in Desktop.workspaces as [{ slot, name, rest }], only for
// numbers that have a design. A switch to a named workspace on the island's
// monitor flashes its name in the island.
Singleton {
    id: root

    // What rest can show
    readonly property var rests: [
        { id: "clock", label: "Clock", icon: "schedule" },
        { id: "media", label: "Media large", icon: "music_note" }
    ]

    // The workspace number on the island's monitor (0 for a special one)
    readonly property int wsId: Ui.monitorObject?.activeWorkspace?.id ?? 0
    readonly property int slot: slotOf(wsId)
    readonly property var current: design(slot)
    // What the resting island shows here: "clock" or "media"
    readonly property string rest: current?.rest ?? "clock"

    // Workspaces are shared by every monitor: the number is the id
    function slotOf(id) {
        return id >= 1 && id <= 10 ? id : 0;
    }
    function design(n) {
        return (Desktop.workspaces ?? []).find(w => w.slot === n) ?? null;
    }
    // Change a number's design; an empty name with the clock removes it
    function set(n, name, rest) {
        if (n < 1 || n > 10)
            return;
        const clean = String(name ?? "").trim().slice(0, 12);
        const kind = rests.some(r => r.id === rest) ? rest : "clock";
        const list = (Desktop.workspaces ?? []).filter(w => w.slot !== n);
        if (clean !== "" || kind !== "clock")
            list.push({ slot: n, name: clean, rest: kind });
        list.sort((a, b) => a.slot - b.slot);
        Desktop.workspaces = list;
    }
    function clear(n) {
        Desktop.workspaces = (Desktop.workspaces ?? []).filter(w => w.slot !== n);
    }

    // The flash: { slot, name } while it shows, else null
    property var flash: null
    function flashNow(n) {
        const d = design(n);
        if (!d || d.name === "" || Ui.open || Ui.quiet) {
            flash = null;
            return;
        }
        flash = { slot: n, name: d.name };
        flashTimer.restart();
    }
    Timer {
        id: flashTimer
        interval: 1200
        onTriggered: root.flash = null
    }

    // A workspace change on the same monitor flashes; the island only moving
    // to another monitor with the mouse does not. The monitor and its
    // workspace are read from one object at one moment (Ui.monitor alone can
    // change before the workspace number follows, which looked like a switch).
    property string lastMonitor: ""
    property int lastWs: 0
    readonly property string where: (Ui.monitorObject?.name ?? "") + ":" + (Ui.monitorObject?.activeWorkspace?.id ?? 0)
    onWhereChanged: {
        const m = Ui.monitorObject;
        const name = m?.name ?? "";
        const ws = m?.activeWorkspace?.id ?? 0;
        const same = name === lastMonitor;
        const changed = ws !== lastWs;
        lastMonitor = name;
        lastWs = ws;
        if (same && changed && ws > 0)
            flashNow(slotOf(ws));
        else if (!same)
            flash = null;
    }
    Component.onCompleted: {
        lastMonitor = Ui.monitorObject?.name ?? "";
        lastWs = Ui.monitorObject?.activeWorkspace?.id ?? 0;
    }

    // Opening the island ends a flash at once
    Connections {
        target: Ui
        function onOpenChanged() {
            if (Ui.open)
                root.flash = null;
        }
    }

    // The number chosen in edit mode's Workspaces tab, and its flash played
    // on the card (the edit overlay covers the real island)
    property int editSlot: 1
    property var cardFlash: null
    function previewFlash(n) {
        const d = design(n);
        cardFlash = d && d.name !== "" ? { slot: n, name: d.name } : null;
        cardTimer.restart();
    }
    Timer {
        id: cardTimer
        interval: 1200
        onTriggered: root.cardFlash = null
    }
}
