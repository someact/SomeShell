pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors, type and shapes. Colors come from matugen's palette
// (~/.local/state/someshell/palette.json), which holds every role in a dark
// and a light version.
//   Desktop surfaces (settings window, widgets) follow the mode: Theme.bg, fg...
//   The island and its tabs use the ink set: Theme.ink.bg, Theme.ink.fg...
Singleton {
    id: root

    readonly property bool dark: palette.mode !== "light"

    // The island's colors: always the dark set, or the opposite of the desktop
    readonly property bool inkDark: Config.island.color === "inverse" ? !dark : true
    readonly property var ink: roles(inkDark ? palette.dark : palette.light, inkDark)

    // Desktop surfaces
    readonly property var paper: roles(dark ? palette.dark : palette.light, dark)
    readonly property color bg: paper.bg
    readonly property color fg: paper.fg

    // The roles the shell uses, from one palette set. `raised` is a step
    // lighter (or darker) than bg for hovered rows and pressed states.
    function roles(set, isDark) {
        const p = set || {};
        const pick = (k, d) => p[k] || d;
        return {
            bg: pick("surface_container_lowest", isDark ? "#0e0f11" : "#ffffff"),
            raised: pick(isDark ? "surface_container_high" : "surface_container", isDark ? "#25262a" : "#ececef"),
            fg: pick("on_surface", isDark ? "#e8e8ec" : "#16171a"),
            mute: pick("on_surface_variant", isDark ? "#a0a2a8" : "#5c5e64"),
            line: pick("outline_variant", isDark ? "#3a3b40" : "#c8c9ce"),
            accent: pick("primary", isDark ? "#c4c6cc" : "#4a4c52"),
            onAccent: pick("on_primary", isDark ? "#16171a" : "#ffffff"),
            error: pick("error", isDark ? "#ffb4ab" : "#ba1a1a")
        };
    }

    // One face, Mitr. Qt maps every numeric weight of it to SemiBold, so faces
    // are picked by style name, never font.weight.
    readonly property QtObject font: QtObject {
        readonly property string family: "Mitr"
        readonly property string light: "Light"
        readonly property string regular: "Regular"
        readonly property string medium: "Medium"
        readonly property string bold: "SemiBold"
        readonly property string icons: "Material Symbols Rounded"
        // Sizes in px
        readonly property int caption: 11  // spaced capitals
        readonly property int small: 13
        readonly property int body: 15
        readonly property int title: 19
        readonly property int headline: 34
    }

    readonly property QtObject shape: QtObject {
        readonly property int band: 40       // the top strip windows keep clear of
        readonly property int ear: 16        // the curve where a tab meets the edge
        readonly property int restRadius: 18
        readonly property int openRadius: 28
        readonly property int floatGap: 8    // gap above a floating island
        readonly property int small: 10
        readonly property int tile: 16
    }

    FileView {
        path: Paths.state + "/palette.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: palette
            property string mode: "dark"
            property string image: ""
            property var dark: ({})
            property var light: ({})
        }
    }
}
