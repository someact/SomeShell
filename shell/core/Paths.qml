pragma Singleton
import QtQuick
import Quickshell

// Where the shell keeps its files. XDG directories, never a fixed home path.
Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/someshell"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/someshell"
    // Hyprland's config (a link to the repo's hypr/); generated/ is per machine
    readonly property string hypr: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/hypr"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/someshell"

    // matugen's config: the installed one, or another for testing
    // (SOMESHELL_MATUGEN_CONFIG=<repo>/matugen/config.toml)
    readonly property string matugenConfig: Quickshell.env("SOMESHELL_MATUGEN_CONFIG")
        || (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/matugen/config.toml"
}
