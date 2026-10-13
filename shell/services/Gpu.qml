pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which GPU tools this machine has, read once at start, so nothing assumes a
// vendor: NVENC and nvidia-smi need the NVIDIA driver, and an AMD card has its
// usage counters in sysfs.
Singleton {
    id: root

    property bool nvidia: false     // the NVIDIA driver is loaded
    property string amd: ""         // /sys/class/drm/cardN/device of a card with gpu_busy_percent

    Process {
        running: true
        command: ["sh", "-c", '[ -e /proc/driver/nvidia/version ] && echo nvidia; for d in /sys/class/drm/card[0-9]/device; do [ -r "$d/gpu_busy_percent" ] && echo "amd $d" && break; done; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.nvidia = lines.includes("nvidia");
                root.amd = (lines.find(l => l.startsWith("amd ")) ?? "").slice(4);
            }
        }
    }
}
