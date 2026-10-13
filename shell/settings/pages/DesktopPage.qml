import QtQuick
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

Page {
    title: "Desktop"
    subtitle: "Widgets on the wallpaper, the lock screen and the on-screen keyboard."

    readonly property var widgetList: [
        { id: "clock", icon: "schedule", name: "Clock", note: "Large time and date" },
        { id: "media", icon: "music_note", name: "Now playing", note: "Shown only while something plays" },
        { id: "system", icon: "monitoring", name: "System", note: "CPU, GPU, RAM, VRAM; updates only while the desktop is uncovered" },
        { id: "notes", icon: "sticky_note_2", name: "Notes", note: "Same notes as the game overlay" },
        { id: "calendar", icon: "calendar_month", name: "Calendar", note: "This month; ‹ › to look around, the title goes back to today" },
        { id: "weather", icon: "partly_cloudy_day", name: "Weather", note: "Open-Meteo, refreshed every 30 minutes while shown" },
        { id: "wallpaper", icon: "wallpaper", name: "Wallpaper", note: "Current wallpaper; shuffle, light/dark, picker" },
        { id: "gallery", icon: "photo_library", name: "Gallery", note: "Slideshow of a folder; changes only while the desktop is visible" },
        { id: "lyrics", icon: "lyrics", name: "Lyrics", note: "Synced lyrics of what is playing" },
        { id: "launch", icon: "apps", name: "Quick launch", note: "Your most used apps, then the dock's pinned ones" }
    ]
    function toggleWidget(id, on) {
        const list = Config.widgets.enabled.filter(w => w !== id);
        Config.widgets.enabled = on ? [...list, id] : list;
    }

    Section {
        title: "Desktop widgets"
        note: "Right-click a widget (or /widgets) to move them: drag to place, ✕ to remove, Esc when done. Game mode hides them."
        Repeater {
            model: widgetList
            SettingRow {
                required property var modelData
                icon: modelData.icon
                title: modelData.name
                subtitle: modelData.note
                Switch {
                    checked: Config.widgets.enabled.includes(modelData.id)
                    onToggled: on => toggleWidget(modelData.id, on)
                }
            }
        }
        SettingRow {
            visible: Config.widgets.enabled.includes("media") && Config.media.lyrics
            icon: "lyrics"
            title: "Lyrics in Now playing"
            subtitle: "Three synced lines under the controls (lyrics are turned on in Island)"
            Switch {
                checked: Config.media.widgetLyrics
                onToggled: on => Config.media.widgetLyrics = on
            }
        }
        SettingRow {
            visible: Config.widgets.enabled.includes("weather")
            icon: "location_on"
            title: "Weather place"
            subtitle: "A city name; empty uses a rough location from your IP (ipwho.is)"
            Row {
                spacing: 8
                Field {
                    implicitWidth: 200
                    placeholder: "Automatic"
                    text: Config.widgets.weatherCity
                    onCommitted: t => Config.widgets.weatherCity = t.trim()
                }
                Choice {
                    value: Config.widgets.fahrenheit
                    model: [{ value: false, label: "°C" }, { value: true, label: "°F" }]
                    onPicked: v => Config.widgets.fahrenheit = v
                }
            }
        }
        SettingRow {
            visible: Config.widgets.enabled.includes("gallery")
            icon: "folder_open"
            title: "Gallery folder"
            subtitle: "Pictures directly in this folder (not its subfolders)"
            Field {
                implicitWidth: 260
                placeholder: Paths.home + "/Pictures"
                text: Config.widgets.galleryDir
                onCommitted: t => Config.widgets.galleryDir = t.trim()
            }
        }
        SettingRow {
            visible: Config.widgets.enabled.includes("gallery")
            icon: "timer"
            title: "Gallery speed"
            changed: Config.widgets.galleryInterval !== 60
            onReset: Config.widgets.galleryInterval = 60
            ValueSlider {
                from: 5
                to: 600
                stepSize: 5
                suffix: " s"
                value: Config.widgets.galleryInterval
                onMoved: v => Config.widgets.galleryInterval = v
            }
        }
        SettingRow {
            icon: "texture"
            title: "Frosted cards"
            subtitle: "Blurred card behind media, system and notes; off draws them straight on the wallpaper"
            Switch {
                checked: Config.widgets.glass
                onToggled: on => Config.widgets.glass = on
            }
        }
        SettingRow {
            icon: "drag_pan"
            title: "Arrange"
            subtitle: "Move widgets on the desktop"
            Row {
                spacing: 8
                SButton {
                    kind: "text"
                    text: "Reset positions"
                    onClicked: Config.widgets.positions = {}
                }
                SButton {
                    kind: "filled"
                    icon: "edit"
                    text: "Edit layout"
                    onClicked: ShellIpc.call("widgets", "edit")
                }
            }
        }
    }

    Section {
        title: "Lock screen"
        note: "Super+L, and after 5 minutes idle. If the shell is not running, hyprlock locks instead."
        SettingRow {
            icon: "lock"
            title: "Use hyprlock"
            subtitle: "Hand every lock to hyprlock instead of the shell's lock screen"
            Switch {
                checked: Config.lock.useHyprlock
                onToggled: on => Config.lock.useHyprlock = on
            }
        }
        SettingRow {
            icon: "blur_on"
            title: "Blurred wallpaper"
            subtitle: "Made once per wallpaper and cached"
            enabled: !Config.lock.useHyprlock
            Switch {
                checked: Config.lock.blur
                onToggled: on => Config.lock.blur = on
            }
        }
        SettingRow {
            icon: "music_note"
            title: "Media controls"
            subtitle: "What is playing, with play/pause and skip"
            enabled: !Config.lock.useHyprlock
            Switch {
                checked: Config.lock.showMedia
                onToggled: on => Config.lock.showMedia = on
            }
        }
        SettingRow {
            icon: "notifications"
            title: "Notification count"
            subtitle: "Only the number; their text never shows while locked"
            enabled: !Config.lock.useHyprlock
            Switch {
                checked: Config.lock.showNotifications
                onToggled: on => Config.lock.showNotifications = on
            }
        }
        SettingRow {
            icon: "preview"
            title: "Try it"
            subtitle: "Preview does not lock: Esc or Enter closes it"
            Row {
                spacing: 8
                SButton {
                    kind: "text"
                    text: "Preview"
                    enabled: !Config.lock.useHyprlock
                    onClicked: ShellIpc.call("lock", "preview")
                }
                SButton {
                    kind: "filled"
                    icon: "lock"
                    text: "Lock now"
                    onClicked: ShellIpc.call("lock", "lock")
                }
            }
        }
    }

    Section {
        title: "On-screen keyboard"
        note: "Super+K or /osk. Keys go to the focused window through ydotool; labels follow the US/TH layout. Shift, Ctrl, Alt and Super latch for one key, a double tap locks them."
        SettingRow {
            icon: "keep"
            title: "Pinned"
            subtitle: "Reserve space at the bottom so windows sit above the keyboard"
            Switch {
                checked: Config.osk.pinned
                onToggled: on => Config.osk.pinned = on
            }
        }
        SettingRow {
            icon: "format_size"
            title: "Key size"
            ValueSlider {
                from: 0.7
                to: 1.4
                stepSize: 0.05
                suffix: "×"
                value: Config.osk.scale
                onMoved: v => Config.osk.scale = v
            }
        }
        SettingRow {
            icon: "keyboard"
            title: "Open the keyboard"
            SButton {
                kind: "filled"
                text: "Open"
                onClicked: ShellIpc.call("osk", "open")
            }
        }
    }
}
