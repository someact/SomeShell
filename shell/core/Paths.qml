pragma Singleton

import QtQuick
import Quickshell

// Every file the shell reads or writes, in one place.
Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"

    // User choices (settings app owns this from Phase 5)
    readonly property string configDir: configHome + "/someshell"
    readonly property string config: configDir + "/config.json"
    readonly property string hyprSettings: configDir + "/hypr.json"   // read by hypr/lib/util.lua (SETTINGS)
    readonly property string keybinds: configDir + "/keybinds.json"   // read by hypr/binds/user.lua

    // Machine state: frecency, notification history
    readonly property string stateDir: stateHome + "/someshell"
    readonly property string frecency: stateDir + "/frecency.json"
    readonly property string notifications: stateDir + "/notifications.json"
    readonly property string wallpaperState: stateDir + "/wallpaper.json"   // { path, phase }
    readonly property string videoFrame: stateDir + "/video-frame.jpg"     // matugen input for video wallpapers

    readonly property string notes: stateDir + "/notes.md"                 // overlay notes (desktop widget too, Phase 7)
    readonly property string emojiState: stateDir + "/emoji.json"            // recent picks and skin tone

    // Capture scratch files (tmpfs)
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string freeze: runtime + "/someshell-freeze.png"       // frozen screen while selecting
    readonly property string crop: runtime + "/someshell-crop.png"
    readonly property string screenshots: home + "/Pictures/Screenshots"
    readonly property string videos: home + "/Videos"
    readonly property string mangohud: configHome + "/MangoHud/MangoHud.conf"

    // matugen outputs (matugen/config.toml)
    readonly property string colors: stateDir + "/colors.json"

    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"
    readonly property string thumbs: cacheHome + "/someshell/thumbs"
    readonly property string lyrics: cacheHome + "/someshell/lyrics"         // LRCLIB answers, one file per track
    readonly property string clipboardCache: cacheHome + "/someshell/clipboard"   // decoded clipboard images, <cliphist id>.<ext>
    readonly property string lockBlur: cacheHome + "/someshell/lock-blur.jpg"   // blurred wallpaper for the lock screen
    readonly property string mpvSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/someshell-mpvpaper.sock"
    readonly property string mpvPid: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/someshell-mpvpaper.pid"

    // Built by scripts/quickshare.sh; SOMESHELL_QUICKSHARE points tests at a stand-in
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
    readonly property string quickshare: Quickshell.env("SOMESHELL_QUICKSHARE") || dataHome + "/someshell/bin/someshell-quickshare"

    readonly property string hyprDir: configHome + "/hypr"
    readonly property string monitors: hyprDir + "/generated/monitors.lua"   // written by the Displays page (per machine, gitignored)
    readonly property string scripts: hyprDir + "/scripts"
    readonly property string wallpapers: home + "/Pictures/Wallpapers"

    function url(path) {
        return path.startsWith("file://") ? path : "file://" + path;
    }
}
