import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// The settings window (SomeShell.md section 5): a normal window, loaded only
// while open (shell.qml). Pages on the left, the page on the right, in the
// desktop's paper and ink. Pages are loaded by URL from pages/, so their
// shared types live in components/ (Select, IconChoice, Switch, SetRow).
FloatingWindow {
    id: win

    readonly property var c: Theme.paper
    readonly property var pages: [
        { id: "general", name: "General", icon: "tune" },
        { id: "displays", name: "Displays", icon: "desktop_windows" }
    ]
    readonly property int index: Math.max(0, pages.findIndex(p => p.id === Ui.settingsPage))
    readonly property var page: pages[index]

    title: "SomeShell Settings"
    implicitWidth: 1080
    implicitHeight: 740
    minimumSize: Qt.size(820, 560)
    color: c.bg
    visible: true
    // Closed by the window manager (Super+Q, the close button)
    onVisibleChanged: if (!visible) Ui.settings = false

    // ── Page list ──
    Rectangle {
        id: side
        width: 232
        height: parent.height
        color: win.c.bg

        Column {
            x: 16
            y: 26
            width: parent.width - 32
            spacing: 4

            Column {
                leftPadding: 10
                bottomPadding: 22
                spacing: 2
                Txt {
                    caps: true
                    text: "SomeShell"
                    color: win.c.mute
                }
                Txt {
                    text: "Settings"
                    size: 26
                    face: Theme.font.bold
                    color: win.c.fg
                }
            }

            Repeater {
                model: win.pages
                Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === win.index
                    width: parent.width
                    height: 42
                    radius: 12
                    color: chosen ? win.c.fg : itemMouse.containsMouse ? win.c.raised : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Txt {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(item.index + 1).padStart(2, "0")
                        size: Theme.font.caption
                        color: item.chosen ? win.c.bg : win.c.mute
                        opacity: item.chosen ? 0.7 : 1
                    }
                    Icon {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        name: item.modelData.icon
                        size: 20
                        filled: item.chosen
                        color: item.chosen ? win.c.bg : win.c.fg
                    }
                    Txt {
                        x: 70
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.modelData.name
                        face: item.chosen ? Theme.font.regular : Theme.font.light
                        color: item.chosen ? win.c.bg : win.c.fg
                    }
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.settingsPage = item.modelData.id
                    }
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: win.c.line
        }
    }

    // ── The page ──
    Item {
        id: content
        anchors.left: side.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.rightMargin: 36

        Item {
            id: head
            width: parent.width
            height: 96
            Txt {
                y: 26
                caps: true
                text: String(win.index + 1).padStart(2, "0") + " / " + String(win.pages.length).padStart(2, "0")
                color: win.c.mute
            }
            Txt {
                y: 40
                text: win.page.name
                size: 38
                face: Theme.font.bold
                color: win.c.fg
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: win.c.fg
            }
        }

        // One page at a time; the source is set by hand (CLAUDE.md: never
        // bind both source and sourceComponent)
        Loader {
            id: loader
            anchors.top: head.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            focus: true
            Component.onCompleted: load()
            function load() {
                const p = win.page;
                source = Qt.resolvedUrl("pages/" + p.name + "Page.qml");
            }
            Connections {
                target: win
                function onIndexChanged() { loader.load(); }
            }
        }
    }

    // Identify (Displays): each monitor's number, big, on its own screen
    Variants {
        model: Displays.identifying ? Quickshell.screens : []
        PanelWindow {
            id: tag
            required property var modelData
            readonly property var ordered: Displays.draft.slice().sort((a, b) => a.x - b.x || a.y - b.y)
            readonly property int number: ordered.findIndex(m => m.name === modelData.name) + 1
            screen: modelData
            anchors.top: true
            anchors.left: true
            margins.top: 40
            margins.left: 40
            implicitWidth: 260
            implicitHeight: 220
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "someshell:identify"
            WlrLayershell.layer: WlrLayer.Overlay
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: win.c.fg
                Column {
                    anchors.centerIn: parent
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tag.number > 0 ? tag.number : "?"
                        size: 120
                        face: Theme.font.bold
                        color: win.c.bg
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        caps: true
                        text: tag.modelData.name
                        color: win.c.bg
                    }
                }
            }
        }
    }
}
