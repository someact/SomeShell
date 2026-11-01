pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland


// What the island is doing. One island, shown on one monitor at a time.
Singleton {
    id: root

    readonly property var pages: [
        { id: "search", label: "Search", icon: "search" },
        { id: "control", label: "Control", icon: "tune" },
        { id: "media", label: "Media", icon: "music_note" },
        { id: "notify", label: "Notify", icon: "notifications" },
        { id: "calendar", label: "Calendar", icon: "calendar_month" },
        { id: "system", label: "System", icon: "monitoring" },
        { id: "power", label: "Power", icon: "power_settings_new" }
    ]

    property bool open: false
    property int page: 0
    // Opened by a click after a hover: it closes when the mouse leaves.
    // Opened by Super, a shortcut or IPC: it stays until Esc or a click outside.
    property bool openedByHover: false
    // Hidden by Super+J until shown again
    property bool hidden: false
    // Text for the search box when it opens (Super+V opens it on "/clip ")
    property string query: ""

    // The monitor the island is on. It follows the mouse only while closed,
    // so it never jumps away while you use it.
    readonly property string followed: Hyprland.focusedMonitor?.name ?? ""
    property string monitor: ""
    readonly property string wantedMonitor: Config.island.follow || !Config.island.monitor
        ? followed : Config.island.monitor
    onWantedMonitorChanged: if (!open) monitor = wantedMonitor
    onOpenChanged: if (!open && monitor !== wantedMonitor) monitor = wantedMonitor
    Component.onCompleted: monitor = wantedMonitor

    // Quiet: a game is playing, or a window is fullscreen on the island's monitor
    readonly property var monitorObject: Hyprland.monitors.values.find(m => m.name === monitor) ?? null
    readonly property bool fullscreen: monitorObject?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool quiet: !open && (GameMode.active || fullscreen)

    // A short alert shown over everything else, then gone
    property var alert: null
    function showAlert(title, body, app, icon) {
        alert = { title: title ?? "", body: body ?? "", app: app ?? "", icon: icon || "notifications" };
        alertTimer.restart();
    }
    Timer {
        id: alertTimer
        interval: 4500
        onTriggered: root.alert = null
    }

    function pageIndex(id) {
        const i = pages.findIndex(p => p.id === id);
        return i < 0 ? 0 : i;
    }

    function openPage(id, byHover, query) {
        root.query = query ?? "";
        page = pageIndex(id);
        openedByHover = byHover === true;
        hidden = false;
        open = true;
    }
    function close() {
        open = false;
        openedByHover = false;
    }
    // Super tap: open on search, or close
    function toggle(id) {
        if (open && (id === undefined || pages[page].id === id))
            close();
        else
            openPage(id ?? "search");
    }
    function nextPage(step) {
        page = (page + step + pages.length) % pages.length;
    }
}
