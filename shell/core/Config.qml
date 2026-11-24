pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's settings (~/.config/someshell/shell.json). Missing keys take the
// defaults below; a change from anywhere (here, the settings window, an
// editor) is picked up live. `Config.theme.mode = "light"` saves at once.
Singleton {
    id: root

    property alias island: adapter.island
    property alias theme: adapter.theme
    property alias wallpaper: adapter.wallpaper
    property alias nightLight: adapter.nightLight
    property alias calendar: adapter.calendar
    property alias share: adapter.share
    property alias lock: adapter.lock
    property alias idle: adapter.idle
    property alias capture: adapter.capture
    property alias keepAwake: adapter.keepAwake
    property alias battery: adapter.battery
    readonly property bool loaded: file.loaded

    FileView {
        id: file
        path: Paths.config + "/shell.json"
        watchChanges: true
        // Our own write also changes the file: ignore that echo for a moment,
        // or several settings changed in one handler would undo each other
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onAdapterUpdated: {
            lastWrite = Date.now();
            writeAdapter();
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                lastWrite = Date.now();
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                // Follow the mouse to the monitor it is on (while closed), or
                // stay on `monitor` (a monitor name; empty = the first one)
                property bool follow: true
                property string monitor: ""
                // The island's style and color are part of the look: desktop.json (Desktop)
            }

            property JsonObject lock: JsonObject {
                // Lock screen style: headline (A); island (B) and contents
                // (C) come later (SomeShell.md section 5)
                property string style: "headline"
            }

            property JsonObject idle: JsonObject {
                // Minutes of no input before each step; 0 = never
                // (services/Idle.qml writes hypr/generated/hypridle.conf)
                property int lock: 10
                property int screenOff: 15
                property int sleep: 30
            }

            property JsonObject keepAwake: JsonObject {
                // Keep awake stays on, also after a reboot (a session's
                // keep awake lives in services/KeepAwake.qml)
                property bool always: false
            }

            property JsonObject battery: JsonObject {
                // Charge limit (services/ChargeLimit.qml): stop charging at
                // `limit` percent (100 = no limit), start again at `start`
                property int limit: 100
                property int start: 75
            }

            property JsonObject capture: JsonObject {
                // Screenshots include the mouse cursor (the picker's Cursor
                // switch, C; PrtSc follows it too)
                property bool cursor: false
            }

            property JsonObject theme: JsonObject {
                property string mode: "dark"          // dark or light
                property string scheme: "scheme-smart" // matugen scheme
            }

            property JsonObject wallpaper: JsonObject {
                // Where /wall looks for images (empty = ~/Pictures/Wallpapers)
                property string folder: ""
                // Wallpaper Engine's assets/ folder for scenes (empty = the
                // usual Steam paths; wall/install.sh --assets writes it)
                property string assets: ""
                // Animated wallpapers (somewall): frame rate cap for scenes
                // (videos play at their own rate), render scale 0.25..1 (the
                // compositor stretches it), video decoding (auto, none, cuda,
                // vaapi, vulkan, v4l2m2m). A wallpaper's own settings win.
                property int fps: 60
                property real scale: 1
                // Texture resolution for scenes: 1 full, 2 half, 4 quarter
                // (large pictures kept smaller in memory)
                property int texres: 1
                property string hwdec: "auto"
                // When an animated wallpaper stops (per monitor)
                property JsonObject pause: JsonObject {
                    property bool fullscreen: true   // a fullscreen window or a game
                    property bool covered: false     // windows cover the desktop
                    property bool battery: false     // running on battery
                    property bool locked: true       // the lock screen is up (it shows no wallpaper)
                }
            }

            property JsonObject share: JsonObject {
                // Quick Share receiving (visible, phones can send here)
                property bool receive: true
                // Where received files go (empty = ~/Downloads)
                property string folder: ""
            }

            property JsonObject calendar: JsonObject {
                // Private iCal (ICS) links of online calendars (Google,
                // Outlook, Apple); .ics files in ~/.config/someshell/calendar
                // are read as well
                property var feeds: []
                property string weekStart: "sunday"  // sunday or monday
            }

            property JsonObject nightLight: JsonObject {
                property bool auto: true          // on between `from` and `to`
                property string from: "20:00"
                property string to: "07:00"
                property int temperature: 4200    // kelvin; lower is warmer
            }
        }
    }
}
