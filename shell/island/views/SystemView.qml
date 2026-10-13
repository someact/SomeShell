import QtQuick
import qs.core
import qs.components
import qs.services

// Resource usage. Polling (1 s) runs only while this view exists.
FocusScope {
    id: root

    implicitWidth: 520
    implicitHeight: grid.implicitHeight

    Component.onCompleted: SysStats.watchers++
    Component.onDestruction: SysStats.watchers--

    function handleKey(event) {
        return UiState.navKey(event);
    }

    Grid {
        id: grid
        columns: 2
        spacing: 10
        width: parent.width

        Meter {
            icon: "memory"
            title: "CPU"
            value: SysStats.cpu
            detail: SysStats.cpuTemp > 0 ? Math.round(SysStats.cpuTemp) + " °C" : ""
        }
        Meter {
            icon: "memory_alt"
            title: "Memory"
            value: SysStats.mem
            detail: SysStats.memUsedGb.toFixed(1) + " / " + SysStats.memTotalGb.toFixed(1) + " GB"
        }
        Meter {
            visible: SysStats.hasGpu
            icon: "developer_board"
            title: "GPU"
            value: SysStats.gpu
            detail: SysStats.gpuTemp > 0 ? Math.round(SysStats.gpuTemp) + " °C" : ""
        }
        Meter {
            visible: SysStats.hasGpu
            icon: "sd_card"
            title: "VRAM"
            value: SysStats.vram
            detail: ""
        }
    }

    component Meter: Rectangle {
        id: meter
        property string icon
        property string title
        property real value
        property string detail

        width: (grid.width - 10) / 2
        height: 76
        radius: Theme.radius.large
        color: Theme.islandRaised

        Row {
            x: 14
            y: 12
            spacing: 8
            Icon {
                name: meter.icon
                size: 18
                color: Theme.fgIslandDim
            }
            Label {
                text: meter.title
                color: Theme.fgIslandDim
            }
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 12
            text: meter.detail
            mono: true
            font.pixelSize: Theme.font.small
            color: Theme.fgIslandDim
        }
        Label {
            x: 14
            y: 34
            mono: true
            text: Math.round(meter.value * 100) + "%"
            font.pixelSize: Theme.font.title
            font.weight: Theme.font.weightTitle
        }
        Rectangle {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: parent.width - 28
            height: 4
            radius: 2
            color: Theme.islandRaised
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.min(1, meter.value)
                color: meter.value > 0.85 ? Theme.error : Theme.accentIsland
                Behavior on width {
                    Spring { preset: "gentle" }
                }
            }
        }
    }
}
