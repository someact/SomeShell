import QtQuick
import qs.core
import qs.components
import qs.services

// CPU, GPU, RAM and VRAM. SysStats polls only while the desktop is uncovered.
DesktopWidget {
    id: root

    property bool live: true
    property bool counted: false
    function sync() {
        if (live !== counted) {
            SysStats.watchers += live ? 1 : -1;
            counted = live;
        }
    }
    onLiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) SysStats.watchers--

    component Ring: Item {
        id: ring
        property string name
        property real value
        property string detail
        width: 64
        height: 92
        Canvas {
            id: canvas
            width: 64
            height: 64
            property real value: ring.value
            Behavior on value {
                Spring { preset: "smooth" }
            }
            onValueChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 6;
                ctx.lineCap = "round";
                ctx.strokeStyle = Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15);
                ctx.beginPath();
                ctx.arc(32, 32, 27, 0, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = value > 0.9 ? Theme.error : Theme.primary;
                ctx.beginPath();
                ctx.arc(32, 32, 27, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, Math.min(1, value)));
                ctx.stroke();
            }
            Label {
                anchors.centerIn: parent
                mono: true
                text: Math.round(ring.value * 100)
                color: root.fg
                font.pixelSize: Theme.font.large
                font.weight: Theme.font.weightTitle
            }
        }
        Column {
            anchors.top: canvas.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ring.name
                color: root.fg
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ring.detail
                mono: true
                color: root.fgDim
                font.pixelSize: 10
            }
        }
    }

    Row {
        spacing: 14
        Ring {
            name: "CPU"
            value: SysStats.cpu
            detail: SysStats.cpuTemp > 0 ? `${Math.round(SysStats.cpuTemp)}°C` : " "
        }
        Ring {
            visible: SysStats.hasGpu
            name: "GPU"
            value: SysStats.gpu
            detail: SysStats.gpuTemp > 0 ? `${Math.round(SysStats.gpuTemp)}°C` : " "
        }
        Ring {
            name: "RAM"
            value: SysStats.mem
            detail: `${SysStats.memUsedGb.toFixed(1)} GB`
        }
        Ring {
            visible: SysStats.hasGpu
            name: "VRAM"
            value: SysStats.vram
            detail: " "
        }
    }
}
