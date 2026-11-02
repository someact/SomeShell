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
    // Pages with no tab: only their shortcut opens them, and Tab or a tab
    // click leaves them for the tab row
    readonly property var extraPages: [
        { id: "clipboard", label: "Clipboard", icon: "content_paste", keys: "Super+V" }
    ]

    property bool open: false
    property int page: 0
    // The tabless page shown instead of `page` ("" for none)
    property string extra: ""
    readonly property string pageId: extra || pages[page].id
    readonly property var pageInfo: extraPages.find(p => p.id === extra) ?? pages[page]
    // A tile's own page on the control page ("net", "bt", "sound", "night")
    property string detail: ""
    // Quick edit of the control page's tiles
    property bool controlEdit: false
    // Which way the last switch went (1: right, -1: left), for the page
    // motion. Tab wraps around but still counts as its own direction.
    property int direction: 1
    property int previousPage: 0
    property int step: 0
    onPageChanged: {
        detail = "";
        controlEdit = false;
        direction = step !== 0 ? step : page >= previousPage ? 1 : -1;
        step = 0;
        previousPage = page;
    }
    // Opened by a click after a hover: it closes when the mouse leaves.
    // Opened by Super, a shortcut or IPC: it stays until Esc or a click outside.
    property bool openedByHover: false
    // Hidden by Super+J until shown again
    property bool hidden: false
    // Text for the search box when it opens (Super+. opens it on "/emoji ")
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

    // Edit mode (edit/EditWindow.qml): the desktop as a card with the
    // editing panel below. `editTab`: wallpaper, island, dock, widgets,
    // workspaces, presets.
    property bool editing: false
    property string editTab: "wallpaper"
    // Closing: the card zooms back to the full desktop, then edit mode ends
    property bool editClosing: false
    // Widgets tab: the chosen widget's id ("" for none: the drawer shows),
    // and a widget being dragged from the drawer: { kind, x, y } in the
    // edit window's coordinates, null when none
    property string editWidget: ""
    property var drawerDrag: null
    signal drawerDropped(string kind, real x, real y)
    function edit(tab, widget) {
        close();
        alert = null;
        if (tab)
            editTab = tab;
        editWidget = widget ?? "";
        drawerDrag = null;
        editClosing = false;
        editing = true;
    }
    function endEdit() {
        if (!editing || editClosing)
            return;
        editClosing = true;
        editTimer.restart();
    }
    Timer {
        id: editTimer
        interval: Motion.slow
        onTriggered: {
            root.editing = false;
            root.editClosing = false;
        }
    }

    // The overview (overview/Overview.qml, Super+Tab): all ten workspaces on
    // the monitor the mouse was on when it opened
    property bool overview: false
    property string overviewMonitor: ""
    function openOverview() {
        if (editing)
            return;
        close();
        overviewMonitor = followed || monitor;
        overview = true;
    }
    function closeOverview() {
        overview = false;
    }
    function toggleOverview() {
        overview ? closeOverview() : openOverview();
    }

    // A short alert shown over everything else, then gone
    property var alert: null
    // extra: { image: a picture shown instead of the icon, open: a file a click opens }
    function showAlert(title, body, app, icon, extra) {
        alert = { title: title ?? "", body: body ?? "", app: app ?? "", icon: icon || "notifications", image: extra?.image ?? "", open: extra?.open ?? "" };
        alertTimer.restart();
    }
    Timer {
        id: alertTimer
        interval: 4500
        onTriggered: root.alert = null
    }

    // A level a key just changed: "volume", "mic" or "brightness". Shown for
    // a moment after the last press; touching its bars keeps it up.
    property string level: ""
    function showLevel(kind) {
        level = kind;
        levelTimer.restart();
    }
    function keepLevel() {
        if (level !== "")
            levelTimer.restart();
    }
    Timer {
        id: levelTimer
        interval: 1600
        onTriggered: root.level = ""
    }

    function pageIndex(id) {
        const i = pages.findIndex(p => p.id === id);
        return i < 0 ? 0 : i;
    }

    function openPage(id, byHover, query) {
        root.query = query ?? "";
        if (extraPages.some(p => p.id === id)) {
            direction = 1;
            extra = id;
        } else {
            extra = "";
            page = pageIndex(id);
        }
        openedByHover = byHover === true;
        hidden = false;
        open = true;
    }
    function close() {
        open = false;
        extra = "";
        detail = "";
        controlEdit = false;
        openedByHover = false;
    }
    // Super tap: open on search, or close
    function toggle(id) {
        if (open && (id === undefined || pageId === id))
            close();
        else
            openPage(id ?? "search");
    }
    function nextPage(by) {
        step = by > 0 ? 1 : -1;
        // From a tabless page, Tab goes back to the tab you were on
        if (extra !== "") {
            direction = step;
            step = 0;
            extra = "";
            return;
        }
        page = (page + by + pages.length) % pages.length;
    }
    function goTo(index) {
        if (extra !== "" && index === page)
            direction = -1;
        extra = "";
        page = index;
    }
}
