import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services
import "layout.js" as Layout

// Super+K on-screen keyboard. It never takes keyboard focus, so keys go to the
// focused window; they are typed through ydotool (services/VirtualKeys.qml).
// Labels follow the active layout (US/TH). Pinned, it reserves space so windows
// sit above it. The window exists only while open.
Scope {
    id: root

    property ShellScreen screen: Quickshell.screens[0]

    Connections {
        target: UiState
        function onOskChanged() {
            if (UiState.osk)
                root.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
            else {
                VirtualKeys.reset();
                unload.restart();
            }
        }
    }
    Timer {
        id: unload
        interval: 400
    }

    LazyLoader {
        active: UiState.osk || unload.running

        PanelWindow {
            id: win
            screen: root.screen

            readonly property real unit: Math.round(46 * Config.osk.scale)
            readonly property bool thai: KbLayout.code === "TH"

            WlrLayershell.namespace: "someshell:osk"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            implicitHeight: board.height + 24
            exclusiveZone: Config.osk.pinned && UiState.osk ? board.height + 12 : 0
            color: "transparent"

            mask: Region {
                item: board
            }
            GlassRegion {
                id: blurArea
                target: board
            }
            BackgroundEffect.blurRegion: Theme.blur && board.y < win.height - 4 ? blurArea : null

            Glass {
                id: board
                anchors.horizontalCenter: parent.horizontalCenter
                y: UiState.osk ? 12 : win.height + 4
                Behavior on y {
                    Spring { preset: "snappy" }
                }
                width: content.implicitWidth + 24
                height: content.implicitHeight + 24
                radius: Theme.radius.large
                tint: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.blur ? Math.max(0.6, Theme.glassAlpha) : 0.97)

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 12

                    // Side bar: pin, layout, close
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        IconButton {
                            width: 40
                            height: 40
                            radius: Theme.radius.small + 2
                            icon: "keep"
                            active: Config.osk.pinned
                            iconColor: active ? Theme.fgPrimary : Theme.fgSurface
                            hoverColor: Theme.surfaceHighest
                            onClicked: Config.osk.pinned = !Config.osk.pinned
                        }
                        PressButton {
                            width: 40
                            height: 40
                            radius: Theme.radius.small + 2
                            hoverColor: Theme.surfaceHighest
                            onClicked: KbLayout.next()
                            Label {
                                anchors.centerIn: parent
                                text: KbLayout.code || "US"
                                color: Theme.primary
                                font.weight: Theme.font.weightTitle
                            }
                        }
                        IconButton {
                            width: 40
                            height: 40
                            radius: Theme.radius.small + 2
                            icon: "keyboard_hide"
                            iconColor: Theme.fgSurface
                            hoverColor: Theme.surfaceHighest
                            onClicked: UiState.osk = false
                        }
                    }

                    Column {
                        spacing: 6
                        Repeater {
                            model: Layout.rows
                            Row {
                                id: row
                                required property var modelData
                                spacing: 6
                                Repeater {
                                    model: row.modelData.keys
                                    OskKey {
                                        required property var modelData
                                        keyData: modelData
                                        unit: win.unit
                                        thai: win.thai
                                        height: Math.round(win.unit * row.modelData.h)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
