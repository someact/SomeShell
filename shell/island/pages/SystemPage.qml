import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// 06 System. One row of columns: CPU, Memory, GPU, Network, Disk, Battery.
// Each column: a label, a big number, a thin line of the last minute (Disk:
// a bar) and one line of detail. lib/sysmon.sh samples once a second and runs
// only while this page exists. A column without a source is left out.
Item {
    id: root

    // The latest sample, and the last 60 values of each line
    property var s: null
    readonly property int keep: 60
    property var cpuLine: []
    property var memLine: []
    property var gpuLine: []
    property var netLine: []
    property real netPeak: 1

    readonly property bool hasGpu: s !== null && s.gpuKind !== "none" && s.gpu !== null
    readonly property bool hasBattery: Battery.available || Battery.testing

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function push(list, v) {
        const out = list.length >= keep ? list.slice(list.length - keep + 1) : list.slice();
        out.push(v);
        return out;
    }
    function bytes(n) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < units.length - 1) {
            n /= 1000;
            i++;
        }
        return { value: i === 0 ? String(Math.round(n)) : n.toFixed(n < 10 ? 1 : 0), unit: units[i] };
    }

    Process {
        running: true
        command: [Quickshell.shellPath("lib/sysmon.sh")]
        stdout: SplitParser {
            onRead: line => {
                let v;
                try {
                    v = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.s = v;
                root.cpuLine = root.push(root.cpuLine, v.cpu);
                root.memLine = root.push(root.memLine, v.memTotal ? v.memUsed / v.memTotal * 100 : 0);
                if (v.gpu !== null)
                    root.gpuLine = root.push(root.gpuLine, v.gpu);
                root.netLine = root.push(root.netLine, v.rx);
                root.netPeak = Math.max(1024, ...root.netLine);
            }
        }
    }

    // A column: label, big number with its unit, a line or a bar, detail
    component Stat: Column {
        id: stat
        property string label
        property string value: "–"
        property string unit
        property var points: []
        property real ceiling: 100
        property real bar: -1          // 0..1 shows a bar instead of a line
        property string detail
        property bool warn: false

        width: 132
        spacing: 6

        Txt {
            text: stat.label
            caps: true
            color: Theme.ink.mute
        }
        Row {
            spacing: 4
            Digits {
                id: big
                text: stat.value
                size: Theme.font.headline
                color: stat.warn ? Theme.ink.error : Theme.ink.fg
            }
            Txt {
                anchors.baseline: big.bottom
                anchors.baselineOffset: -8
                text: stat.unit
                size: Theme.font.small
                face: Theme.font.regular
                color: Theme.ink.mute
            }
        }
        // The last minute as a thin line, newest on the right
        Item {
            width: parent.width
            height: 34
            visible: stat.bar < 0
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.ink.line
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: stat.points.length > 1
                ShapePath {
                    strokeColor: stat.warn ? Theme.ink.error : Theme.ink.fg
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline {
                        path: {
                            const pts = stat.points;
                            const w = stat.width, h = 34;
                            const step = w / (root.keep - 1);
                            const x0 = w - (pts.length - 1) * step;
                            const out = [];
                            for (let i = 0; i < pts.length; i++) {
                                const y = h - 1 - Math.max(0, Math.min(1, pts[i] / stat.ceiling)) * (h - 3);
                                out.push(Qt.point(x0 + i * step, y));
                            }
                            return out;
                        }
                    }
                }
            }
        }
        // Or a bar (disk)
        Item {
            width: parent.width
            height: 34
            visible: stat.bar >= 0
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.ink.line
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, stat.bar))
                    height: parent.height
                    radius: 2
                    color: stat.warn ? Theme.ink.error : Theme.ink.fg
                }
            }
        }
        Txt {
            width: parent.width
            text: stat.detail
            caps: true
            color: Theme.ink.mute
        }
    }

    Row {
        id: row
        spacing: 26

        Stat {
            label: "CPU"
            value: root.s ? String(root.s.cpu) : "–"
            unit: "%"
            points: root.cpuLine
            detail: root.s ? (root.s.cpuTemp > 0 ? root.s.cpuTemp + "°C  ·  " : "") + root.s.cores + " cores" : ""
            warn: (root.s?.cpuTemp ?? 0) >= 85
        }
        Stat {
            readonly property real gb: root.s ? root.s.memUsed / 1048576 : 0
            label: "Memory"
            value: root.s ? gb.toFixed(1) : "–"
            unit: "GB"
            points: root.memLine
            detail: root.s ? "of " + (root.s.memTotal / 1048576).toFixed(1) + " GB" : ""
            warn: root.s ? root.s.memUsed / root.s.memTotal > 0.9 : false
        }
        Stat {
            visible: root.hasGpu
            label: root.s?.gpuKind === "clock" ? "GPU clock" : "GPU"
            value: root.s && root.s.gpu !== null ? String(root.s.gpu) : "–"
            unit: "%"
            points: root.gpuLine
            detail: root.s ? [root.s.gpuMHz > 0 ? root.s.gpuMHz + " MHz" : "", root.s.gpuTemp > 0 ? root.s.gpuTemp + "°C" : ""].filter(Boolean).join("  ·  ") : ""
        }
        Stat {
            readonly property var down: root.bytes(root.s?.rx ?? 0)
            readonly property var up: root.bytes(root.s?.tx ?? 0)
            label: "Network"
            value: root.s ? down.value : "–"
            unit: root.s ? down.unit + "/s" : ""
            points: root.netLine
            ceiling: root.netPeak
            detail: root.s ? "up " + up.value + " " + up.unit + "/s" : ""
        }
        Stat {
            readonly property var used: root.bytes(root.s?.diskUsed ?? 0)
            readonly property var free: root.bytes((root.s?.diskTotal ?? 0) - (root.s?.diskUsed ?? 0))
            label: "Disk"
            value: root.s ? used.value : "–"
            unit: root.s ? used.unit : ""
            bar: root.s && root.s.diskTotal ? root.s.diskUsed / root.s.diskTotal : 0
            detail: root.s ? free.value + " " + free.unit + " free" : ""
            warn: root.s ? root.s.diskUsed / root.s.diskTotal > 0.9 : false
        }
        Stat {
            visible: root.hasBattery
            // UPower's power draw when it has one, else the battery's own files
            readonly property real watts: (Battery.device?.changeRate ?? 0) > 0 ? Battery.device.changeRate : (root.s?.batW ?? 0) / 10
            readonly property real health: Battery.device?.healthPercentage ?? 0
            label: Battery.charging ? "Charging" : Battery.full ? "Battery full" : "Battery"
            value: String(Battery.percent)
            unit: "%"
            bar: Battery.percent / 100
            warn: Battery.low
            detail: [
                watts > 0 ? watts.toFixed(1) + " W" : "",
                Battery.minutes > 0 ? Math.floor(Battery.minutes / 60) + "h " + Battery.minutes % 60 + "m" : "",
                health > 0 ? Math.round(health) + "% health" : (root.s?.batTemp ?? 0) > 0 ? (root.s.batTemp / 10).toFixed(0) + "°C" : ""
            ].filter(Boolean).join("  ·  ")
        }
    }
}
