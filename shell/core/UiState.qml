pragma Singleton

import QtQuick
import Quickshell

// What the island is showing. Every view, shortcut and IPC call goes through here.
Singleton {
    id: root

    // Views reachable with ←/→ while the island is open, in order
    readonly property list<string> mainViews: ["search", "control", "media", "notifications", "system", "power"]
    // Views opened by commands/shortcuts only
    readonly property list<string> extraViews: ["clipboard", "emoji", "keys", "polkit", "wallpaper", "translate", "mixer"]

    property bool expanded: false
    // Hover peek: the island shows a view on one screen without keyboard focus;
    // a click or a Super tap promotes it to the full view (expanded)
    property bool peeking: false
    property string peekScreen: ""
    property string view: "search"
    property string searchText: ""       // seed text for the search view, e.g. "/"
    property string controlDetail: ""    // Control view page (wifi bluetooth warp nightlight audio), "" = tiles
    property bool hidden: false          // Super+J hides the island and pills
    property bool caffeine: false        // block idle (screen off / lock)
    property string ambient: "clock"     // what the collapsed island shows (set by Island)
    property real islandWidth: 160       // live island width (satellite pills sit beside it)
    property bool overview: false        // Super+Tab workspace overview (never open together with the island)
    property bool overlay: false         // Super+G game overlay
    property bool osk: false             // Super+K on-screen keyboard
    property bool widgetEdit: false      // desktop widgets: drag to move, add/remove

    // Super tap: press arms it, any other key while held disarms it
    property bool superMightTrigger: false
    property bool superHeld: false

    // One shared delay for every workspace pill. A release or disabling the
    // setting cancels the pending preview and hides it immediately.
    property bool superPeek: false
    readonly property bool superPeekPending: superHeld && Config.pills.superPeek
    onSuperPeekPendingChanged: {
        superPeek = false;
        if (superPeekPending)
            superPeekDelay.restart();
        else
            superPeekDelay.stop();
    }
    Timer {
        id: superPeekDelay
        interval: 1000
        onTriggered: root.superPeek = root.superPeekPending
    }

    signal searchReset

    function open(name, text) {
        if (!mainViews.includes(name) && !extraViews.includes(name)) {
            console.warn("UiState: unknown view", name);
            return;
        }
        view = name;
        if (name === "search") {
            searchText = text ?? "";
            searchReset();
        }
        overview = false;
        peeking = false;
        controlDetail = "";
        expanded = true;
    }

    // Control view straight on a detail page (status pill right-click)
    function openControl(detail) {
        open("control");
        controlDetail = detail ?? "";
    }

    function close() {
        peeking = false;
        controlDetail = "";
        expanded = false;
    }

    function peek(name, screen) {
        if (expanded || overview)
            return;
        view = name;
        peekScreen = screen;
        peeking = true;
    }

    function unpeek() {
        peeking = false;
    }

    // Keeps the peeked view (no reload), now with focus
    function promote() {
        if (!peeking)
            return;
        peeking = false;
        expanded = true;
    }

    function toggle(name, text) {
        if (expanded && view === name)
            close();
        else
            open(name, text);
    }

    function toggleOverview() {
        overview = !overview;
        if (overview)
            close();
    }

    // Shared keys for views: Esc closes, ←/→ switch views
    function navKey(event) {
        if (event.key === Qt.Key_Escape) {
            close();
            return true;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            step(event.key === Qt.Key_Left ? -1 : 1);
            return true;
        }
        return false;
    }

    function step(delta) {
        let i = mainViews.indexOf(view);
        if (i < 0)
            i = 0;
        view = mainViews[(i + delta + mainViews.length) % mainViews.length];
    }
}
