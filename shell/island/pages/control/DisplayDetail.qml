import QtQuick
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// Displays (the Brightness tile's page): a brightness slider for every
// monitor that has one, each monitor on or off, and Extend / Mirror. A
// monitor change goes through Displays with its countdown: Keep, or it goes
// back after 15 s. Layout, modes and the rest stay in Settings → Displays.
Column {
    id: root
    spacing: 6

    readonly property bool several: Displays.live.length > 1
    // Mirror shows the monitor the island is on
    readonly property string mirrorSource: Hyprland.focusedMonitor?.name ?? (Displays.live.find(m => m.on)?.name ?? "")

    Component.onCompleted: {
        Displays.refresh();
        // A monitor that is on with no brightness control: look again (DDC
        // can miss one while monitors change)
        if (Displays.live.some(m => m.on && !m.mirror && !Brightness.forMonitor(m.name)))
            Brightness.detect();
    }

    BackRow {
        title: "Displays"
        Tap {
            id: more
            width: moreRow.implicitWidth + 24
            height: 34
            outlined: true
            onClicked: {
                Ui.close();
                Ui.openSettings("displays");
            }
            Row {
                id: moreRow
                anchors.centerIn: parent
                spacing: 6
                Icon {
                    name: "settings"
                    size: 18
                    color: more.fg
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    caps: true
                    color: more.fg
                }
            }
        }
    }

    // After a monitor change: keep it, or it goes back by itself
    Rectangle {
        visible: Displays.waiting
        width: parent.width
        height: 52
        radius: 12
        color: Theme.ink.raised
        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Keep these displays?  ·  back in " + Displays.left + " s"
            color: Theme.ink.fg
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                label: "Back"
                icon: "undo"
                onClicked: Displays.revert()
            }
            Chip {
                label: "Keep"
                icon: "check"
                active: true
                onClicked: Displays.keep()
            }
        }
    }

    // How the monitors are used together
    Row {
        visible: root.several
        spacing: 6
        Chip {
            icon: "splitscreen_right"
            label: "Extend"
            active: Displays.arrangement === "extend"
            enabled: !Displays.waiting
            onClicked: Displays.quick("extend")
        }
        Chip {
            icon: "screen_share"
            label: "Mirror " + root.mirrorSource
            active: Displays.arrangement === "mirror"
            enabled: !Displays.waiting && root.mirrorSource !== ""
            onClicked: Displays.quick("mirror", root.mirrorSource)
        }
    }

    Repeater {
        model: Displays.live

        ListRow {
            id: row
            required property var modelData
            required property int index
            readonly property var screen: Brightness.forMonitor(modelData.name)
            readonly property bool lastOn: modelData.on && Displays.live.filter(m => m.on).length <= 1
            icon: !modelData.on ? "desktop_access_disabled" : modelData.mirror ? "screen_share" : "monitor"
            iconFilled: modelData.on
            title: modelData.name + (modelData.model ? "  ·  " + modelData.model : "")
            sub: !modelData.on ? "Off"
                : modelData.mirror ? "Shows " + modelData.mirror
                : screen ? screen.value + "%" : "No brightness control"
            clickable: false
            line: index < Displays.live.length - 1

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                BarSlider {
                    visible: !!row.screen && row.modelData.on
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.several ? 220 : 300
                    height: 16
                    bars: root.several ? 21 : 28
                    value: (row.screen?.value ?? 0) / 100
                    onMoved: v => Brightness.setScreen(row.screen.name, v * 100)
                }
                Tap {
                    visible: root.several
                    width: 64
                    height: 34
                    outlined: true
                    active: row.modelData.on
                    // The last monitor on stays on
                    enabled: !Displays.waiting && !row.lastOn
                    opacity: enabled ? 1 : 0.4
                    onClicked: Displays.quick("toggle", row.modelData.desc)
                    Txt {
                        anchors.centerIn: parent
                        text: row.modelData.on ? "On" : "Off"
                        caps: true
                        color: parent.fg
                    }
                }
            }
        }
    }
}
