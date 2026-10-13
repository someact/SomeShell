import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

Page {
    id: page
    title: "Appearance"
    subtitle: "How the island looks, glass, motion and colors."

    Section {
        title: "Island"
        SettingRow {
            icon: "toast"
            title: "Style"
            subtitle: "Notch hangs from the top edge. Floating is a free pill. Pills can sit beside either (Island → Pill layout)."
            Choice {
                model: [{ value: "notch", label: "Notch" }, { value: "floating", label: "Floating" }]
                value: Config.island.style
                onPicked: v => Config.island.style = v
            }
        }
        SettingRow {
            icon: "blur_on"
            title: "Glass"
            subtitle: "Frosted compositor blur behind the island, pills and dock"
            Switch {
                checked: Config.island.glass
                onToggled: on => Config.island.glass = on
            }
        }
        SettingRow {
            icon: "toast"
            title: "Island glass"
            subtitle: "Off keeps only the island solid black, like a hardware notch. Pills, dock and cards stay glass."
            enabled: Config.island.glass
            Switch {
                checked: Config.glass.island
                onToggled: on => Config.glass.island = on
            }
        }
        SettingRow {
            icon: "opacity"
            title: "Glass tint"
            subtitle: "How much color covers the frost on pills, dock and cards. Lower is clearer."
            enabled: Config.island.glass
            changed: Math.abs(Config.glass.tint - 0.4) > 0.001
            onReset: Config.glass.tint = 0.4
            ValueSlider {
                from: 0.1
                to: 0.9
                stepSize: 0.05
                value: Config.glass.tint
                onMoved: v => Config.glass.tint = v
            }
        }
        SettingRow {
            icon: "toast"
            title: "Island tint"
            subtitle: "Darkness of the island glass. Higher reads more like a hardware notch."
            enabled: Config.island.glass && Config.glass.island
            changed: Math.abs(Config.glass.islandTint - 0.55) > 0.001
            onReset: Config.glass.islandTint = 0.55
            ValueSlider {
                from: 0.2
                to: 0.95
                stepSize: 0.05
                value: Config.glass.islandTint
                onMoved: v => Config.glass.islandTint = v
            }
        }
        SettingRow {
            icon: "border_outer"
            title: "Rim light"
            subtitle: "A thin light edge and a soft top highlight on glass surfaces"
            Switch {
                checked: Config.glass.rim
                onToggled: on => Config.glass.rim = on
            }
        }
    }

    // hyprglass plugin (hypr/core/liquidglass.lua): built per Hyprland version
    property bool pluginBuilt: false
    property bool building: false
    property string buildError: ""
    Process {
        id: checkBuilt
        running: true
        command: ["sh", "-c", 'test -f "$("$1" --path)"', "sh", Paths.scripts + "/hyprglass.sh"]
        onExited: code => page.pluginBuilt = code === 0
    }
    Process {
        id: build
        command: [Paths.scripts + "/hyprglass.sh"]
        stderr: StdioCollector {
            id: buildErr
        }
        onExited: code => {
            page.building = false;
            page.buildError = code === 0 ? "" : (buildErr.text.trim().split("\n").pop() || "build failed");
            checkBuilt.running = true;
        }
    }

    Section {
        title: "Liquid glass"
        note: "Refraction, an edge light and a soft lens on the island, pills, dock and keyboard (hyprglass plugin). No measurable GPU or CPU cost on this machine, about 40 MB more VRAM."
        SettingRow {
            icon: "water_drop"
            title: "Liquid glass"
            subtitle: page.building ? "Building the plugin… (about 20 s)" : page.buildError !== "" ? "Build failed: " + page.buildError : page.pluginBuilt ? "Bends the light at the edges of the glass. Applies with the next Hyprland reload, right away." : "The plugin is not built for this Hyprland version yet"
            changed: HyprSettings.isSet("liquidGlass")
            onReset: HyprSettings.unset("liquidGlass")
            SButton {
                visible: !page.pluginBuilt
                enabled: !page.building
                icon: "build"
                text: page.building ? "Building…" : "Build"
                onClicked: {
                    page.building = true;
                    page.buildError = "";
                    build.running = true;
                }
            }
            Switch {
                visible: page.pluginBuilt
                checked: HyprSettings.get("liquidGlass", false)
                onToggled: on => HyprSettings.set("liquidGlass", on)
            }
        }
        SettingRow {
            icon: "style"
            title: "Look"
            subtitle: "Pomme is closest to Apple's liquid glass"
            enabled: page.pluginBuilt && HyprSettings.get("liquidGlass", false)
            changed: HyprSettings.isSet("liquidGlassPreset")
            onReset: HyprSettings.unset("liquidGlassPreset")
            Choice {
                model: [{ value: "pomme", label: "Pomme" }, { value: "clear", label: "Clear" }, { value: "subtle", label: "Subtle" }, { value: "glass", label: "Glass" }]
                value: HyprSettings.get("liquidGlassPreset", "pomme")
                onPicked: v => HyprSettings.set("liquidGlassPreset", v)
            }
        }
        SettingRow {
            icon: "select_window"
            title: "On windows too"
            subtitle: "Also on translucent windows (needs Glass windows below)"
            enabled: page.pluginBuilt && HyprSettings.get("liquidGlass", false)
            changed: HyprSettings.isSet("liquidGlassWindows")
            onReset: HyprSettings.unset("liquidGlassWindows")
            Switch {
                checked: HyprSettings.get("liquidGlassWindows", false)
                onToggled: on => HyprSettings.set("liquidGlassWindows", on)
            }
        }
    }

    Section {
        title: "Windows"
        note: "Applies on the next Hyprland reload, which happens right away."
        SettingRow {
            icon: "window"
            title: "Glass windows"
            subtitle: "Translucent terminals, chat and editors with stronger frost. Off keeps every window opaque."
            changed: HyprSettings.isSet("glass")
            onReset: HyprSettings.unset("glass")
            Switch {
                checked: HyprSettings.get("glass", false)
                onToggled: on => HyprSettings.set("glass", on)
            }
        }
        SettingRow {
            icon: "bolt"
            title: "Fast glass"
            subtitle: "Window blur shows only the wallpaper, so it is cached and costs less GPU. Tiled windows look the same; a floating glass window over another window shows the wallpaper behind it."
            enabled: HyprSettings.get("glass", false)
            changed: HyprSettings.isSet("fastGlass")
            onReset: HyprSettings.unset("fastGlass")
            Switch {
                checked: HyprSettings.get("fastGlass", false)
                onToggled: on => HyprSettings.set("fastGlass", on)
            }
        }
    }

    Section {
        title: "Motion"
        SettingRow {
            icon: "speed"
            title: "Speed"
            subtitle: "Scales every spring in the shell"
            changed: Config.motion.speed !== 1
            onReset: Config.motion.speed = 1
            ValueSlider {
                from: 0.5
                to: 2
                stepSize: 0.1
                suffix: "×"
                value: Config.motion.speed
                onMoved: v => Config.motion.speed = v
            }
        }
        SettingRow {
            icon: "motion_photos_off"
            title: "Reduce motion"
            subtitle: "Short fades instead of springs (game mode does this too)"
            Switch {
                checked: Config.motion.reduce
                onToggled: on => Config.motion.reduce = on
            }
        }
    }

    Section {
        title: "Colors"
        note: "Colors come from the wallpaper (matugen) and recolor the shell, terminals, GTK, KDE, Zen and Vesktop."
        SettingRow {
            icon: "dark_mode"
            title: "Mode"
            Choice {
                model: [{ value: "dark", label: "Dark", icon: "dark_mode" }, { value: "light", label: "Light", icon: "light_mode" }]
                value: Config.theme.mode
                onPicked: v => ShellIpc.call("wallpaper", "mode", v)
            }
        }
        SettingRow {
            icon: "palette"
            title: "Scheme"
            subtitle: "How colors are drawn from the wallpaper"
        }
        Flow {
            x: 16
            width: parent.width - 32
            spacing: 8
            bottomPadding: 12
            Repeater {
                model: [["tonal-spot", "Tonal spot"], ["content", "Content"], ["expressive", "Expressive"], ["fidelity", "Fidelity"], ["fruit-salad", "Fruit salad"], ["monochrome", "Monochrome"], ["neutral", "Neutral"], ["rainbow", "Rainbow"], ["vibrant", "Vibrant"]]
                SButton {
                    required property var modelData
                    readonly property string scheme: "scheme-" + modelData[0]
                    text: modelData[1]
                    kind: Config.theme.scheme === scheme ? "filled" : "tonal"
                    onClicked: ShellIpc.call("wallpaper", "scheme", scheme)
                }
            }
        }
    }
}
