pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, stored in ~/.config/someshell/config.json. Missing keys take the
// defaults below; edits from the shell write back to the file, and edits to the
// file reload live.
Singleton {
    id: root

    readonly property alias island: adapter.island
    readonly property alias glass: adapter.glass
    readonly property alias pills: adapter.pills
    readonly property alias motion: adapter.motion
    readonly property alias clock: adapter.clock
    readonly property alias control: adapter.control
    readonly property alias search: adapter.search
    readonly property alias notifications: adapter.notifications
    readonly property alias theme: adapter.theme
    readonly property alias dock: adapter.dock
    readonly property alias overview: adapter.overview
    readonly property alias capture: adapter.capture
    readonly property alias overlay: adapter.overlay
    readonly property alias streamer: adapter.streamer
    readonly property alias lock: adapter.lock
    readonly property alias widgets: adapter.widgets
    readonly property alias osk: adapter.osk
    readonly property alias media: adapter.media
    property bool ready: false

    FileView {
        path: Paths.config
        watchChanges: true
        // Our own writes also fire fileChanged; reloading then would read the file
        // back while later edits from the same handler are still unwritten and
        // undo them (several Config writes in a row lost all but some). Only
        // reload for changes made by someone else.
        property real lastWrite: 0
        onFileChanged: if (Date.now() - lastWrite > 600) reload()
        onAdapterUpdated: {
            lastWrite = Date.now();
            writeAdapter();
        }
        onLoaded: root.ready = true
        onLoadFailed: error => {
            // First run: write the defaults so the file is there to edit
            if (error === FileViewError.FileNotFound) {
                Quickshell.execDetached(["mkdir", "-p", Paths.configDir]);
                writeAdapter();
            }
            root.ready = true;
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                property string style: "notch"        // notch (hangs from the edge) | floating (a free pill)
                property bool glass: true             // compositor blur behind the island
                property int peekMs: 4000             // notification peek
                property int osdMs: 1500              // volume / brightness / layout
                property bool showMedia: true
                property bool hoverPeek: true         // hovering the island (or the top edge above it) peeks a view
            }
            property JsonObject glass: JsonObject {
                property real tint: 0.4               // surface tint over the frost (pills, dock, cards)
                property real islandTint: 0.55        // the island's darker "hardware" tint
                property bool rim: true               // 1 px light rim and top highlight
                property bool island: true            // false: the island alone is solid black (no frost)
            }
            property JsonObject pills: JsonObject {
                // Each part of the corner pills: glass (frosted; neighbors share one pill)
                // or floating (no background, like a phone status bar)
                property string workspaces: "glass"
                property string title: "glass"
                property string tray: "glass"
                property string status: "glass"
                property string clock: "glass"
                property string halo: "shadow"        // floating text and icons: shadow (soft) | outline
                property string workspaceShape: "cookie7Sided"   // the active workspace (components/MaterialShape.qml names)
                property bool showEmpty: false        // also show workspaces without windows
                property bool superPeek: true         // holding Super for one second shows every workspace
                property bool hoverPeek: true         // hovering the workspaces shows them all
                // Where each part sits, in order: the top corners or beside the island.
                // A part in no list is hidden. Ids: workspaces special title tray status clock
                property var layout: ({ left: ["workspaces", "special", "title"], islandLeft: [], islandRight: [], right: ["tray", "status", "clock"] })
            }
            property JsonObject motion: JsonObject {
                property real speed: 1.0              // scales every spring
                property bool reduce: false           // short fades instead of springs
            }
            property JsonObject clock: JsonObject {
                property string format: "HH:mm"
                property string dateFormat: "ddd d MMM"
            }
            property JsonObject control: JsonObject {
                // Quick tiles shown in the Control view, in order (services/QuickTiles.qml ids);
                // the rest are hidden and can be added back in its edit mode
                property list<string> tiles: ["wifi", "bluetooth", "dnd", "game", "nightlight", "caffeine", "mic", "dark", "streamer", "record", "battery"]
                // Tiles and sliders (slider:volume, slider:mic, slider:brightness) in order;
                // empty: `tiles` followed by the three sliders (layouts saved before the sliders moved)
                property list<string> layout: []
                property string tileStyle: "full"     // default size: full (icon, title, state) | icon (icon only)
                property var sizes: ({})              // tile id -> full | icon, overrides tileStyle
            }
            property JsonObject search: JsonObject {
                property int maxResults: 8
            }
            property JsonObject notifications: JsonObject {
                property bool dnd: false
                property int keep: 50
            }
            property JsonObject dock: JsonObject {
                property bool enabled: true
                // intelli: hide while a window covers it · auto: show on hover only · never: always shown, reserves space
                property string autohide: "intelli"
                property int iconSize: 44
                property list<string> pinned: ["org.kde.dolphin", "kitty", "brave-origin", "antigravity"]
            }
            property JsonObject overview: JsonObject {
                property int rows: 2
                property int columns: 5
                property real scale: 0.17             // workspace tile size relative to the screen
                property bool showSpecial: true
            }
            property JsonObject capture: JsonObject {
                property bool saveShots: false        // also save region shots (always copied)
                property string shotDir: ""           // empty: ~/Pictures/Screenshots
                property string recordDir: ""         // empty: ~/Videos
                property string encoder: "auto"       // wf-recorder -c: auto (NVENC with an NVIDIA GPU, else x264) | h264_nvenc | libx264
                property string translateTo: "th"     // translate-shell target language
                property bool snapWindows: true       // click a window to select it
            }
            property JsonObject overlay: JsonObject {
                property list<string> open: ["resources", "mixer"]   // widgets shown while the overlay is up
                property list<string> pinned: []      // also shown (click-through) while it is closed
                property var positions: ({})          // widget id -> { x, y }
                property var translateArea: ({})      // live translator area { x, y, w, h } (layout pixels)
                property bool blur: true              // frost the bar and cards while the overlay is open
                property bool pinnedBlur: false       // also frost pinned cards after it closes (keeps Hyprland blur on in game mode)
                property JsonObject style: JsonObject {
                    property string look: "glass"     // glass (tint + rim, frosted) | solid (no blur) | minimal (no card, outlined text)
                    property real opacity: 0.5        // card tint (glass, solid)
                    property string accent: ""        // "" = theme primary, or a #rrggbb
                    property int radius: 22           // card corners
                    property bool compact: false      // slimmer title bars and padding
                }
                property JsonObject crosshair: JsonObject {
                    property bool enabled: false
                    property string color: "#00ff88"
                    property int size: 10             // arm length
                    property int gap: 4
                    property int thickness: 2
                    property bool dot: true
                    property bool outline: true
                }
            }
            property JsonObject streamer: JsonObject {
                property bool enabled: false
                property bool auto: true              // on while the screen is shared (OBS, Discord, browser)
                property bool silence: true           // do not disturb while on (critical still peeks)
            }
            property JsonObject lock: JsonObject {
                property bool useHyprlock: false      // hand locking to hyprlock instead of the shell
                property bool blur: true              // blurred wallpaper behind the clock
                property bool showMedia: true         // now playing + controls
                property bool showNotifications: true // count of unread notifications (never their text)
            }
            property JsonObject widgets: JsonObject {
                // Desktop widgets on the bottom layer, in this order; hidden in game mode
                property list<string> enabled: ["clock", "media"]
                property var positions: ({})          // widget id -> { x, y }
                property bool glass: true             // frosted card behind each widget
                property string galleryDir: ""        // gallery widget folder (empty: ~/Pictures)
                property int galleryInterval: 60      // seconds per picture
                property string weatherCity: ""       // weather widget place (empty: rough location from the IP)
                property bool fahrenheit: false
            }
            property JsonObject osk: JsonObject {
                property bool pinned: false           // reserve space so windows sit above it
                property real scale: 1.0              // key size
            }
            property JsonObject media: JsonObject {
                property bool lyrics: true            // fetch lyrics from LRCLIB (services/Lyrics.qml)
                property bool lyricsPane: true        // the media view shows them (L toggles)
                property bool ambientLyrics: false    // the collapsed island shows the current line instead of the title
                property bool widgetLyrics: true      // the desktop media widget shows three lines
            }
            property JsonObject theme: JsonObject {
                property string mode: "dark"          // dark | light (matugen -m)
                property string scheme: "scheme-tonal-spot"   // matugen -t
                property int nightLightTemp: 4500     // hyprsunset temperature (K)
                // Time-of-day schedule (services/Schedule.qml): five slots (sunrise, noon,
                // sunset, night, midnight), each { on, start, offset, source (keep | file |
                // folder | dynamic), file, folder, interval (min), mode (keep | dark |
                // light), nightLight }. Empty slots: built from the day/night keys below
                property JsonObject schedule: JsonObject {
                    property bool enabled: false
                    property var slots: ({})
                    property bool sunTimes: false     // starts from the sun (Open-Meteo, widgets.weatherCity or IP) + offset
                    // Day/night keys from before the slots (migrated to sunrise and night)
                    property string dayStart: "07:00"
                    property string nightStart: "19:00"
                    property string dayFolder: ""     // empty: keep the current wallpaper
                    property string nightFolder: ""
                    property string dayMode: "light"
                    property string nightMode: "dark"
                    property bool nightLight: true
                }
            }
        }
    }
}
