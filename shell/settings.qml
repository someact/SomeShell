//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// SomeShell settings app: `qs -p ~/.config/quickshell/someshell/settings.qml`
// (or `qs -c someshell ipc call settings open`). Its own process, so it costs
// nothing while closed. Pages load one at a time.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services
import qs.settings
import qs.settings.ui

ShellRoot {
    id: app

    readonly property var pages: [
        { id: "appearance", name: "Appearance", icon: "palette" },
        { id: "island", name: "Island", icon: "toast" },
        { id: "dock", name: "Dock", icon: "dock_to_bottom" },
        { id: "wallpaper", name: "Wallpaper", icon: "wallpaper" },
        { id: "desktop", name: "Desktop", icon: "widgets" },
        { id: "keybinds", name: "Keybinds", icon: "keyboard" },
        { id: "hyprland", name: "Hyprland", icon: "tune" },
        { id: "displays", name: "Displays", icon: "desktop_windows" },
        { id: "power", name: "Power", icon: "battery_full", laptop: true },
        { id: "apps", name: "Apps & Autostart", icon: "apps" },
        { id: "capture", name: "Capture", icon: "screenshot_region" },
        { id: "modes", name: "Modes", icon: "sports_esports" }
    ]
    property string page: pageOrDefault(Quickshell.env("SOMESHELL_SETTINGS_PAGE"))

    function pageOrDefault(id) {
        return pages.some(p => p.id === id) ? id : "appearance";
    }
    function fileFor(id) {
        return "settings/pages/" + id.charAt(0).toUpperCase() + id.slice(1) + "Page.qml";
    }

    IpcHandler {
        target: "settingsApp"
        function focus(page: string): void {
            if (page !== "")
                app.page = app.pageOrDefault(page);
            Hyprland.dispatch(`hl.dsp.focus({ window = "title:^(SomeShell Settings)$" })`);
        }
    }

    FloatingWindow {
        id: win
        title: "SomeShell Settings"
        implicitWidth: 1080
        implicitHeight: 740
        minimumSize: Qt.size(760, 480)
        color: Theme.surface
        onClosed: Qt.quit()

        // Navigation rail
        Rectangle {
            id: rail
            width: 232
            height: parent.height
            color: Theme.surfaceContainer

            Column {
                x: 12
                y: 20
                width: parent.width - 24
                spacing: 2

                SText {
                    leftPadding: 12
                    bottomPadding: 14
                    text: "Settings"
                    font.pixelSize: Theme.font.title
                    font.weight: Theme.font.weightTitle
                }

                Repeater {
                    // Laptop pages (Power) are listed only while a battery is present
                    model: app.pages.filter(p => !p.laptop || Battery.available)
                    PressButton {
                        id: nav
                        required property var modelData
                        readonly property bool current: app.page === modelData.id
                        width: parent.width
                        height: 44
                        radius: 22
                        color: current ? Theme.secondaryContainer : "transparent"
                        hoverColor: current ? Theme.secondaryContainer : Theme.surfaceHigh
                        onClicked: app.page = modelData.id

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 16
                            spacing: 14
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: nav.modelData.icon
                                size: 22
                                fill: nav.current ? 1 : 0
                                color: nav.current ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                            }
                            SText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: nav.modelData.name
                                color: nav.current ? Theme.fgSecondaryContainer : Theme.fgSurface
                                font.weight: nav.current ? Theme.font.weightTitle : Theme.font.weight
                            }
                        }
                    }
                }
            }

            SText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                x: 24
                width: parent.width - 48
                text: HyprSettings.reloading ? "Applying…" : "Changes apply as you make them"
                dim: true
                font.pixelSize: Theme.font.small
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }

        Loader {
            id: pageLoader
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: errorBar.top
            source: app.fileFor(app.page)
            onLoaded: fadeIn.play()
            Reveal {
                id: fadeIn
                target: pageLoader.item
                fromScale: 1
                delay: 0
            }
        }

        // Hyprland config errors after the last change
        Rectangle {
            id: errorBar
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: visible ? errText.implicitHeight + 24 : 0
            visible: HyprSettings.errors !== ""
            color: Theme.error
            Icon {
                id: errIcon
                x: 20
                y: 12
                name: "error"
                size: 20
                color: Theme.surface
            }
            SText {
                id: errText
                x: 52
                y: 12
                width: parent.width - 72
                text: "Hyprland reported a problem:\n" + HyprSettings.errors
                color: Theme.surface
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                maximumLineCount: 8
            }
        }
    }
}
