pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, RAM and GPU usage. Nothing runs unless a view raises `watchers`; then
// /proc is read every second. The GPU comes from nvidia-smi (streams once a
// second) or an AMD card's sysfs counters (services/Gpu.qml); with neither,
// `hasGpu` is false and views leave the GPU rows out.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0

    property real cpu: 0
    property real cpuTemp: 0
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real gpu: 0
    property real gpuTemp: 0
    property real vram: 0
    readonly property bool hasGpu: Gpu.nvidia || Gpu.amd !== ""
    property var _lastCpu: null
    property string _tempPath: ""

    Timer {
        running: root.active
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (root._tempPath !== "")
                temp.reload();
            if (!Gpu.nvidia && Gpu.amd !== "") {
                amdBusy.reload();
                amdVram.reload();
            }
        }
    }

    FileView {
        id: stat
        path: root.active ? "/proc/stat" : ""
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = p[3] + p[4];
            const total = p.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                const dt = total - root._lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root._lastCpu.idle) / dt : 0;
            }
            root._lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: root.active ? "/proc/meminfo" : ""
        onLoaded: {
            const t = text();
            const kb = k => parseInt(t.match(new RegExp(k + ":\\s+(\\d+)"))?.[1] ?? "0");
            const total = kb("MemTotal"), avail = kb("MemAvailable");
            root.memTotalGb = total / 1048576;
            root.memUsedGb = (total - avail) / 1048576;
            root.mem = total > 0 ? (total - avail) / total : 0;
        }
    }

    FileView {
        id: temp
        path: root.active && root._tempPath !== "" ? root._tempPath : ""
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }

    // Find the CPU sensor once: k10temp or zenpower (AMD), coretemp (Intel)
    Process {
        running: true
        command: ["sh", "-c", "for n in k10temp zenpower coretemp; do for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = $n ] && echo $h/temp1_input && exit; done; done"]
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }

    // AMD: usage in percent, VRAM in bytes (no temperature here)
    FileView {
        id: amdBusy
        path: root.active && !Gpu.nvidia && Gpu.amd !== "" ? Gpu.amd + "/gpu_busy_percent" : ""
        printErrors: false
        onLoaded: root.gpu = (parseInt(text()) || 0) / 100
    }
    FileView {
        id: amdVram
        path: root.active && !Gpu.nvidia && Gpu.amd !== "" ? Gpu.amd + "/mem_info_vram_used" : ""
        printErrors: false
        onLoaded: root.vram = amdTotal.bytes > 0 ? (parseInt(text()) || 0) / amdTotal.bytes : 0
    }
    FileView {
        id: amdTotal
        property real bytes: 0
        path: !Gpu.nvidia && Gpu.amd !== "" ? Gpu.amd + "/mem_info_vram_total" : ""
        printErrors: false
        onLoaded: bytes = parseInt(text()) || 0
    }

    Process {
        running: root.active && Gpu.nvidia
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits", "-lms", "1000"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(",").map(s => parseFloat(s));
                if (p.length < 4)
                    return;
                root.gpu = p[0] / 100;
                root.gpuTemp = p[1];
                root.vram = p[3] > 0 ? p[2] / p[3] : 0;
            }
        }
    }
}
