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
        clipboard: () => Ui.toggle("clipboard"),
        emoji: () => Ui.openPage("search", false, "/emoji "),
        islandHide: () => Ui.hidden = !Ui.hidden,
        lightDark: () => Config.theme.mode = Config.theme.mode === "dark" ? "light" : "dark",
        brightnessUp: () => root.brightnessStep(5),
        brightnessDown: () => root.brightnessStep(-5),
        // Raising unmutes (a muted speaker would hide the change)
        volumeUp: () => { if (Audio.muted) Audio.toggleMute(); root.volumeStep(0.05); },
        volumeDown: () => root.volumeStep(-0.05),
        mute: () => { Audio.toggleMute(); Ui.showLevel("volume"); },
        micMute: () => { Audio.toggleMic(); Ui.showLevel("mic"); },
        overview: () => later("Overview", 7),
        keys: () => later("Keybind list", 7),
        osk: () => later("On-screen keyboard", 8),
        overlay: () => later("Game overlay", 8),
        wallpaper: () => Ui.openPage("search", false, "/wall "),
        wallpaperRandom: () => Wallpapers.random(),
        screenshot: () => Capture.start("shot"),
        lens: () => later("Google Lens", 8),
        ocr: () => Capture.start("text"),
        translate: () => later("Translate", 8),
        recordRegion: () => later("Recording", 8),
        recordScreen: () => later("Recording", 8),
        recordScreenSound: () => later("Recording", 8)
    })

    Variants {
        model: Object.keys(root.actions)
        GlobalShortcut {
            required property string modelData
            property real pressedAt: 0
            appid: "someshell"
            name: modelData
            onPressed: {
                pressedAt = Date.now();
                root.actions[modelData]();
            }
            // The Super tap is a release bind, which only sends "released"
            onReleased: if (modelData === "island" && Date.now() - pressedAt > 400) root.actions[modelData]()
        }
    }

    // Steps land on whole multiples (37% + 5% → 40%), so the number stays round
    function volumeStep(by) {
        const size = Math.abs(by);
        const at = Audio.volume / size;
        const steps = by > 0 ? Math.floor(at + 0.01) + 1 : Math.ceil(at - 0.01) - 1;
        Audio.setVolume(Math.max(0, steps * size));
        Ui.showLevel("volume");
    }
    function brightnessStep(by) {
        if (!Brightness.available) {
            brightness.run(by > 0 ? "+" : "-");
            return;
        }
        Brightness.step(by);
        Ui.showLevel("brightness");
    }

    // Brightness keys go through the Brightness service (the tile stays right);
    // this is only used while it is still finding the screens at start
    Process {
        id: brightness
        function run(dir) {
            command = ["brightnessctl", "s", "5%" + dir];
            running = true;
        }
    }
}
