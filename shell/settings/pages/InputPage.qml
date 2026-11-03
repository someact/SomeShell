import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// Settings 03 Input: keyboard repeat, mouse, touchpad and pen tablet.
// A section shows only where the machine has the device (from `hyprctl
// devices`). Everything goes to hypr.json and applies live (HyprConfig).
// Fallbacks are the values in hypr/core/input.lua and Hyprland's defaults.
Flickable {
    id: root

    readonly property var c: Theme.paper

    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Wheel and touch scroll; a mouse drag never does (it is for the controls)
    acceptedButtons: Qt.NoButton

    // ── The devices this machine has ──
    property var touchpads: []
    property var tablets: []
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.touchpads = (d.mice ?? []).map(m => m.name).filter(n => /touchpad|trackpad/i.test(n));
                    root.tablets = (d.tablets ?? []).filter(t => t.name && t.type !== "tabletPad").map(t => t.name);
                } catch (e) {}
            }
        }
    }
    // The tablet the pen rows change (the first one found)
    readonly property string tablet: tablets[0] ?? ""
    readonly property var tabletEntry: HyprConfig.device(tablet) ?? {}

    function opt(keys, fallback) { return HyprConfig.get(keys, fallback); }

    Column {
        id: col
        width: root.width

        // ── Keyboard ──
        SetSection { text: "Keyboard" }
        SetRow {
            label: "Repeat delay"
            hint: "How long a key is held before it repeats."
            SetSlider {
                from: 150
                to: 800
                step: 10
                value: root.opt(["input", "repeat_delay"], 250)
                format: v => Math.round(v) + " ms"
                onChanged: v => HyprConfig.set(["input", "repeat_delay"], Math.round(v))
            }
        }
        SetRow {
            label: "Repeat speed"
            SetSlider {
                from: 10
                to: 80
                step: 1
                value: root.opt(["input", "repeat_rate"], 35)
                format: v => Math.round(v) + " / s"
                onChanged: v => HyprConfig.set(["input", "repeat_rate"], Math.round(v))
            }
        }
        SetRow {
            label: "Num Lock on at start"
            Switch {
                checked: root.opt(["input", "numlock_by_default"], true)
                onToggled: on => HyprConfig.set(["input", "numlock_by_default"], on)
            }
        }

        // ── Mouse ──
        SetSection { text: "Mouse" }
        SetRow {
            label: "Speed"
            SetSlider {
                from: -1
                to: 1
                step: 0.05
                value: root.opt(["input", "sensitivity"], 0)
                format: v => (v > 0 ? "+" : "") + Math.round(v * 100)
                onChanged: v => HyprConfig.set(["input", "sensitivity"], v)
            }
        }
        SetRow {
            label: "Acceleration"
            IconChoice {
                options: [
                    { value: "adaptive", icon: "trending_up", label: "Faster when fast" },
                    { value: "flat", icon: "trending_flat", label: "Flat" }
                ]
                value: root.opt(["input", "accel_profile"], "") === "flat" ? "flat" : "adaptive"
                onPicked: v => HyprConfig.set(["input", "accel_profile"], v)
            }
        }
        SetRow {
            label: "Scroll speed"
            SetSlider {
                from: 0.2
                to: 3
                step: 0.1
                value: root.opt(["input", "scroll_factor"], 1)
                format: v => "× " + v.toFixed(1)
                onChanged: v => HyprConfig.set(["input", "scroll_factor"], Math.round(v * 10) / 10)
            }
        }
        SetRow {
            label: "Natural scrolling"
            hint: "Content follows the wheel, like a phone."
            Switch {
                checked: root.opt(["input", "natural_scroll"], false)
                onToggled: on => HyprConfig.set(["input", "natural_scroll"], on)
            }
        }
        SetRow {
            label: "Left-handed"
            Switch {
                checked: root.opt(["input", "left_handed"], false)
                onToggled: on => HyprConfig.set(["input", "left_handed"], on)
            }
        }
        SetRow {
            label: "Focus"
            IconChoice {
                options: [
                    { value: 1, icon: "arrow_selector_tool", label: "Follows the mouse" },
                    { value: 0, icon: "ads_click", label: "On click" }
                ]
                value: root.opt(["input", "follow_mouse"], 1) === 0 ? 0 : 1
                onPicked: v => HyprConfig.set(["input", "follow_mouse"], v)
            }
        }

        // ── Touchpad (only with one) ──
        SetSection {
            visible: root.touchpads.length > 0
            text: "Touchpad"
        }
        Column {
            visible: root.touchpads.length > 0
            width: parent.width
            SetRow {
                label: "Tap to click"
                Switch {
                    checked: root.opt(["input", "touchpad", "tap_to_click"], true)
                    onToggled: on => HyprConfig.set(["input", "touchpad", "tap_to_click"], on)
                }
            }
            SetRow {
                label: "Natural scrolling"
                Switch {
                    checked: root.opt(["input", "touchpad", "natural_scroll"], true)
                    onToggled: on => HyprConfig.set(["input", "touchpad", "natural_scroll"], on)
                }
            }
            SetRow {
                label: "Off while typing"
                Switch {
                    checked: root.opt(["input", "touchpad", "disable_while_typing"], false)
                    onToggled: on => HyprConfig.set(["input", "touchpad", "disable_while_typing"], on)
                }
            }
            SetRow {
                label: "Scroll speed"
                SetSlider {
                    from: 0.2
                    to: 2
                    step: 0.1
                    value: root.opt(["input", "touchpad", "scroll_factor"], 0.7)
                    format: v => "× " + v.toFixed(1)
                    onChanged: v => HyprConfig.set(["input", "touchpad", "scroll_factor"], Math.round(v * 10) / 10)
                }
            }
        }

        // ── Pen tablet (only with one) ──
        SetSection {
            visible: root.tablet !== ""
            text: "Pen tablet"
        }
        Column {
            visible: root.tablet !== ""
            width: parent.width
            SetRow {
                label: "Monitor"
                hint: root.tablet
                Select {
                    width: 260
                    options: [{ value: "", label: "All monitors" }].concat(Quickshell.screens.map(s => ({ value: s.name, label: s.name + (s.model ? " · " + s.model : "") })))
                    value: root.tabletEntry.output ?? ""
                    onPicked: v => HyprConfig.setDevice(root.tablet, "output", v)
                }
            }
            SetRow {
                label: "Rotation"
                IconChoice {
                    options: [
                        { value: 0, icon: "north", label: "Normal" },
                        { value: 1, icon: "east", label: "90°" },
                        { value: 2, icon: "south", label: "180°" },
                        { value: 3, icon: "west", label: "270°" }
                    ]
                    value: root.tabletEntry.transform ?? 0
                    onPicked: v => HyprConfig.setDevice(root.tablet, "transform", v)
                }
            }
            SetRow {
                label: "Left-handed"
                Switch {
                    checked: root.tabletEntry.left_handed ?? false
                    onToggled: on => HyprConfig.setDevice(root.tablet, "left_handed", on)
                }
            }
        }
    }
}
