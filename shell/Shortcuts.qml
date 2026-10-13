import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.services
import qs.commands

// Global shortcuts under appid "someshell". hypr/binds/shell.lua maps keys to
// these names, so the keybinds stay identical when switching shells.
Scope {
    id: root

    // Any other shell shortcut (Super+V, ...) cancels a pending Super tap.
    // Instances add their own onPressed; both handlers run.
    component Shortcut: GlobalShortcut {
        appid: "someshell"
        onPressed: if (name !== "superKey") UiState.superMightTrigger = false
    }

    // Super tap toggles the island (search). Hyprland only delivers the release
    // half of the `SUPER + SUPER_L` bind, so the tap is armed by `superKey`
    // (bare Super_L/R, fires on press) and decided on that release. It counts
    // as a tap if Super was alone, held < 500 ms, and nothing happened in
    // between (Super+1, Super+arrows, a Super shortcut...).
    property real superPressedAt: 0
    Shortcut {
        name: "superKey"
        description: "Super key pressed/released"
        onPressed: {
            UiState.superHeld = true;
            UiState.superMightTrigger = true;
            root.superPressedAt = Date.now();
        }
        onReleased: UiState.superHeld = false
    }
    Shortcut {
        name: "searchToggleRelease"
        description: "Toggle search on Super tap"
        onReleased: {
            const tap = UiState.superMightTrigger && Date.now() - root.superPressedAt < 500;
            UiState.superMightTrigger = false;
            if (tap && UiState.peeking)
                UiState.promote();
            else if (tap)
                UiState.toggle("search");
        }
    }
    Shortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Cancel the pending Super tap"
        onPressed: UiState.superMightTrigger = false
    }
    Connections {
        target: Hyprland
        enabled: UiState.superMightTrigger
        function onRawEvent(event) {
            if (["workspace", "workspacev2", "activewindow", "activewindowv2", "movewindow", "movewindowv2", "openwindow", "closewindow", "fullscreen", "changefloatingmode", "activespecial"].includes(event.name))
                UiState.superMightTrigger = false;
        }
    }

    Shortcut {
        name: "overviewToggle"
        description: "Workspace overview"
        onPressed: UiState.toggleOverview()
    }
    Shortcut {
        name: "clipboardToggle"
        description: "Clipboard history"
        onPressed: UiState.toggle("clipboard")
    }
    Shortcut {
        name: "emojiToggle"
        description: "Emoji picker"
        onPressed: UiState.toggle("emoji")
    }
    Shortcut {
        name: "controlToggle"
        description: "Quick controls"
        onPressed: UiState.toggle("control")
    }
    Shortcut {
        name: "mediaToggle"
        description: "Media controls"
        onPressed: UiState.toggle("media")
    }
    Shortcut {
        name: "keysToggle"
        description: "Keyboard shortcuts"
        onPressed: UiState.toggle("keys")
    }
    Shortcut {
        name: "powerToggle"
        description: "Session menu"
        onPressed: UiState.toggle("power")
    }
    Shortcut {
        name: "islandHideToggle"
        description: "Hide the island and corner pills"
        onPressed: UiState.hidden = !UiState.hidden
    }
    Shortcut {
        name: "wallpaperToggle"
        description: "Change wallpaper"
        onPressed: UiState.toggle("wallpaper")
    }
    Shortcut {
        name: "wallpaperRandom"
        description: "Random wallpaper"
        onPressed: Wallpaper.random()
    }
    // Region tools (capture/RegionSelector.qml)
    Shortcut {
        name: "regionScreenshot"
        description: "Screenshot a region"
        onPressed: Capture.start("shot")
    }
    Shortcut {
        name: "regionOcr"
        description: "Copy text from a region"
        onPressed: Capture.start("ocr")
    }
    Shortcut {
        name: "regionSearch"
        description: "Search a region with Google Lens"
        onPressed: Capture.start("lens")
    }
    Shortcut {
        name: "screenTranslate"
        description: "Translate text in a region"
        onPressed: Capture.start("translate")
    }
    // Pressed again while recording: stop
    Shortcut {
        name: "regionRecord"
        description: "Record a region"
        onPressed: Capture.start("record")
    }
    Shortcut {
        name: "screenRecord"
        description: "Record the screen"
        onPressed: Recorder.toggleScreen(false)
    }
    Shortcut {
        name: "screenRecordSound"
        description: "Record the screen with sound"
        onPressed: Recorder.toggleScreen(true)
    }
    Shortcut {
        name: "overlayToggle"
        description: "Game overlay"
        onPressed: UiState.overlay = !UiState.overlay
    }

    Shortcut {
        name: "oskToggle"
        description: "On-screen keyboard"
        onPressed: UiState.osk = !UiState.osk
    }

    Shortcut {
        name: "toggleLightDark"
        description: "Toggle light/dark colors"
        onPressed: Wallpaper.toggleLightDark()
    }
}
