import QtQuick
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

Page {
    title: "Capture"
    subtitle: "Region tools (Super+Shift+S / X / A / T) and screen recording (Super+Shift+R, Ctrl+Alt+R)."

    Section {
        title: "Region tools"
        note: "Drag to select, click a window to take all of it, Enter for the whole screen. Right-drag a screenshot to annotate it in swappy. Tab or 1–6 switch the tool."
        SettingRow {
            icon: "select_window"
            title: "Click selects a window"
            subtitle: "Hover highlights the window under the cursor"
            Switch {
                checked: Config.capture.snapWindows
                onToggled: on => Config.capture.snapWindows = on
            }
        }
        SettingRow {
            icon: "save"
            title: "Save screenshots"
            subtitle: "Screenshots are always copied; this also keeps a file"
            Switch {
                checked: Config.capture.saveShots
                onToggled: on => Config.capture.saveShots = on
            }
        }
        SettingRow {
            enabled: Config.capture.saveShots
            icon: "folder"
            title: "Screenshot folder"
            changed: Config.capture.shotDir !== ""
            onReset: Config.capture.shotDir = ""
            Field {
                implicitWidth: 260
                placeholder: Paths.screenshots
                text: Config.capture.shotDir
                onCommitted: t => Config.capture.shotDir = t.trim()
            }
        }
        SettingRow {
            icon: "translate"
            title: "Translate to"
            subtitle: "translate-shell (online). Text recognition reads the languages tesseract has installed"
            Choice {
                model: [{ value: "th", label: "ไทย" }, { value: "en", label: "English" }, { value: "ja", label: "日本語" }]
                value: Config.capture.translateTo
                onPicked: v => Config.capture.translateTo = v
            }
        }
    }

    Section {
        title: "Recording"
        note: "The island shows a timer while recording; click it to stop. Sound is what plays through your speakers."
        SettingRow {
            icon: "memory"
            title: "Encoder"
            subtitle: Config.capture.encoder === "h264_nvenc" ? "NVIDIA hardware encoder: almost no CPU, fine for games" : Config.capture.encoder === "libx264" ? "Software x264: smaller files, uses the CPU" : "NVENC with an NVIDIA GPU, x264 otherwise"
            Choice {
                model: [{ value: "auto", label: "Auto" }, { value: "h264_nvenc", label: "NVENC" }, { value: "libx264", label: "x264" }]
                value: Config.capture.encoder
                onPicked: v => Config.capture.encoder = v
            }
        }
        SettingRow {
            icon: "video_library"
            title: "Recordings folder"
            changed: Config.capture.recordDir !== ""
            onReset: Config.capture.recordDir = ""
            Field {
                implicitWidth: 260
                placeholder: Paths.videos
                text: Config.capture.recordDir
                onCommitted: t => Config.capture.recordDir = t.trim()
            }
        }
    }
}
