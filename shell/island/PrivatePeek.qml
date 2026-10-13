import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// Streamer mode notification peek. It sits just under the island on a layer
// Hyprland leaves out of screen shares (`someshell:private`, no_screen_share in
// hypr/rules/layers.lua), so only you see the text. Exists only while peeking.
Scope {
    LazyLoader {
        active: Streamer.active && Notifs.peeked !== null

        PanelWindow {
            id: win

            readonly property var n: Notifs.peeked

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.namespace: "someshell:private"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            margins.top: Theme.barHeight + 10
            implicitWidth: 440
            implicitHeight: card.height
            color: "transparent"

            Rectangle {
                id: card
                width: parent.width
                height: row.implicitHeight + 24
                radius: Theme.radius.large
                color: Qt.rgba(0, 0, 0, 0.88)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                property real shown: 0
                Component.onCompleted: shown = 1
                opacity: shown
                transform: Translate {
                    y: (1 - card.shown) * -12
                }
                Behavior on shown {
                    Spring { preset: "snappy" }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.peeked = null
                }

                Row {
                    id: row
                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 12
                    Cover {
                        width: 40
                        height: 40
                        radius: Theme.radius.normal
                        source: Notifs.icon(win.n, true)
                        fallbackIcon: "notifications"
                    }
                    Column {
                        width: parent.width - 52
                        spacing: 2
                        Row {
                            spacing: 6
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "visibility_off"
                                size: 14
                                color: Theme.fgIslandDim
                            }
                            Label {
                                text: (win.n?.appName ?? "") + " · only visible to you"
                                color: Theme.fgIslandDim
                                font.pixelSize: Theme.font.small
                            }
                        }
                        Label {
                            width: parent.width
                            text: win.n?.summary || win.n?.appName || ""
                            font.weight: Theme.font.weightTitle
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: win.n?.body ?? ""
                            color: Theme.fgIslandDim
                            font.pixelSize: Theme.font.small
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                        }
                    }
                }
            }
        }
    }
}
