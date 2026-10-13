import QtQuick
import qs.core
import qs.components
import qs.services

// CPU, GPU, RAM and VRAM. SysStats polls only while this card is on screen.
OverlayCard {
    id: root
    icon: "monitoring"
    title: "Resources"
    implicitWidth: 260

    Component.onCompleted: SysStats.watchers++
    Component.onDestruction: SysStats.watchers--

    component Meter: Column {
        id: m
        property string name
        property real value
        property string detail
        width: parent.width
        spacing: 4
        Item {
            width: parent.width
            height: 16
            Label {
                text: m.name
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
            Label {
                anchors.right: parent.right
                mono: true
                text: m.detail
                font.pixelSize: Theme.font.small
            }
        }
        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.islandRaised
            Rectangle {
                height: parent.height
                radius: 2.5
                width: parent.width * Math.min(1, Math.max(0, m.value))
                color: m.value > 0.9 ? Theme.error : Theme.accentIsland
                Behavior on width {
                    Spring { preset: "smooth" }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10
        Meter {
            name: "CPU"
            value: SysStats.cpu
            detail: `${Math.round(SysStats.cpu * 100)}%` + (SysStats.cpuTemp > 0 ? `  ${Math.round(SysStats.cpuTemp)}°` : "")
        }
        Meter {
            visible: SysStats.hasGpu
            name: "GPU"
            value: SysStats.gpu
            detail: `${Math.round(SysStats.gpu * 100)}%` + (SysStats.gpuTemp > 0 ? `  ${Math.round(SysStats.gpuTemp)}°` : "")
        }
        Meter {
            name: "RAM"
            value: SysStats.mem
            detail: `${SysStats.memUsedGb.toFixed(1)} / ${SysStats.memTotalGb.toFixed(0)} GB`
        }
        Meter {
            visible: SysStats.hasGpu
            name: "VRAM"
            value: SysStats.vram
            detail: `${Math.round(SysStats.vram * 100)}%`
        }
    }
}
