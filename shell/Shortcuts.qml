import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core
import qs.services

// Global shortcuts (appid "someshell"): the names hypr/binds/keybinds.lua
// binds. Actions whose part is not built yet say which step brings it.
Scope {
    id: root

    function later(what, step) {
        Ui.showAlert(what, "Comes in step " + step + " of the rebuild.", "SomeShell", "construction");
    }

    readonly property var actions: ({
        island: () => Ui.toggle(),
        control: () => Ui.toggle("control"),
        media: () => Ui.toggle("media"),
        power: () => Ui.toggle("power"),
        clipboard: () => Ui.openPage("search"),
        emoji: () => Ui.openPage("search"),
        islandHide: () => Ui.hidden = !Ui.hidden,
        lightDark: () => Config.theme.mode = Config.theme.mode === "dark" ? "light" : "dark",
        brightnessUp: () => brightness.run("+"),
        brightnessDown: () => brightness.run("-"),
        overview: () => later("Overview", 7),
        keys: () => later("Keybind list", 7),
        osk: () => later("On-screen keyboard", 8),
        overlay: () => later("Game overlay", 8),
        wallpaper: () => later("Wallpaper picker", 3),
        wallpaperRandom: () => later("Random wallpaper", 3),
        screenshot: () => later("Screenshot", 8),
        lens: () => later("Google Lens", 8),
        ocr: () => later("Copy text", 8),
        translate: () => later("Translate", 8),
        recordRegion: () => later("Recording", 8),
        recordScreen: () => later("Recording", 8),
        recordScreenSound: () => later("Recording", 8)
    })

    Variants {
        model: Object.keys(root.actions)
        GlobalShortcut {
            required property string modelData
            appid: "someshell"
            name: modelData
            onPressed: root.actions[modelData]()
        }
    }

    // Brightness keys until the brightness service exists (step 4)
    Process {
        id: brightness
        function run(dir) {
            command = ["brightnessctl", "s", "5%" + dir];
            running = true;
        }
    }
}
