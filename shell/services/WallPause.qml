pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.core

// Whether the animated wallpaper should stand still on each monitor, from the
// rules in Config.wallpaper.pause: a fullscreen window or a game (on by
// default), windows covering the desktop, on battery, while locked.
// `paused` maps a monitor's name to true/false; Wallpaper sends the changes.
Singleton {
    id: root

    readonly property var rules: Config.wallpaper.pause
    readonly property bool onBattery: UPower.onBattery

    readonly property var paused: {
        const out = {};
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++)
            out[mons[i].name] = pausedOn(mons[i]);
        return out;
    }

    function pausedOn(m) {
        if (rules.locked && Locker.locked)
            return true;
        if (rules.battery && onBattery)
            return true;
        const ws = m.activeWorkspace;
        if (rules.fullscreen && (GameMode.active || fullscreenOn(ws)))
            return true;
        if (rules.covered && ws && coveredBy(ws, m))
            return true;
        return false;
    }

    // Real fullscreen only: Hyprland's hasFullscreen is also true for a
    // maximized window (mode bit 1), which counts as covering instead. The
    // modes are reread on each fullscreen event (Ui.fullscreenEvents).
    function fullscreenOn(ws) {
        if (!ws?.hasFullscreen)
            return false;
        const wins = ws.toplevels?.values ?? [];
        for (let i = 0; i < wins.length; i++)
            if ((wins[i].lastIpcObject?.fullscreen ?? 0) & 2)
                return true;
        return false;
    }

    // Windows cover the desktop: a tiled window (tiles fill the screen), or a
    // floating one over nearly all of it
    function coveredBy(ws, m) {
        const wins = ws.toplevels?.values ?? [];
        const area = Math.max(1, m.width * m.height / (m.scale || 1) / (m.scale || 1));
        for (let i = 0; i < wins.length; i++) {
            const o = wins[i].lastIpcObject;
            if (!o || o.hidden || o.mapped === false)
                continue;
            if (!o.floating)
                return true;
            const size = o.size ?? [0, 0];
            if (size[0] * size[1] >= area * 0.9)
                return true;
        }
        return false;
    }

    // A window's floating state and size are only in its IPC object, which
    // Quickshell does not reread by itself: ask again after window events,
    // and only while the rule is on
    Connections {
        target: Hyprland
        enabled: root.rules.covered
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "workspacev2":
            case "focusedmonv2":
            case "moveworkspacev2":
                refresh.restart();
            }
        }
    }
    Timer {
        id: refresh
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: root.rules
        function onCoveredChanged() {
            if (root.rules.covered)
                Hyprland.refreshToplevels();
        }
    }
}
