import QtQuick
import qs.core
import qs.components
import qs.services

// Wallpaper: a row of thumbnails (a click applies it and recolors), light or
// dark, the color scheme, and the palette it made.
Item {
    id: root
    property string tab

    Component.onCompleted: Wallpapers.refresh()

    readonly property var schemes: [
        ["scheme-smart", "Smart"], ["scheme-tonal-spot", "Tonal"], ["scheme-content", "Content"], ["scheme-expressive", "Expressive"],
        ["scheme-fidelity", "Fidelity"], ["scheme-fruit-salad", "Fruit salad"], ["scheme-monochrome", "Mono"],
        ["scheme-neutral", "Neutral"], ["scheme-rainbow", "Rainbow"]
    ]

    ListView {
        id: walls
        width: parent.width
        height: 104
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Wallpapers.files
        // The wheel scrolls sideways
        WheelHandler {
            onWheel: event => walls.flick(event.angleDelta.y * 8, 0)
        }

        delegate: Tap {
            id: cell
            required property var modelData
            readonly property bool current: modelData.path === Wallpaper.path
            width: 168
            height: 104
            radius: 14
            onClicked: if (!current) { Editor.record(); Wallpaper.set(modelData.path); }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 11
                color: Theme.ink.raised
                clip: true
                border.width: cell.current ? 2 : 0
                border.color: Theme.ink.accent
                Image {
                    anchors.fill: parent
                    anchors.margins: cell.current ? 2 : 0
                    source: Wallpapers.ready[cell.modelData.thumb] ? "file://" + cell.modelData.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }

        Txt {
            visible: Wallpapers.files.length === 0
            anchors.centerIn: parent
            text: "No images in " + Wallpapers.folder
            caps: true
            color: Theme.ink.mute
        }
    }

    Row {
        id: modes
        anchors.top: walls.bottom
        anchors.topMargin: 16
        spacing: 22

        // Light / dark
        Row {
            spacing: 4
            Repeater {
                model: [["dark", "dark_mode", "Dark"], ["light", "light_mode", "Light"]]
                Chip {
                    required property var modelData
                    icon: modelData[1]
                    label: modelData[2]
                    active: Config.theme.mode === modelData[0]
                    onClicked: if (!active) { Editor.record(); Config.theme.mode = modelData[0]; }
                }
            }
        }

    }

    // Scheme: a row that scrolls sideways, between light/dark and the palette
    ListView {
        id: schemes
        anchors.left: modes.right
        anchors.leftMargin: 22
        anchors.right: palette.left
        anchors.rightMargin: 16
        anchors.verticalCenter: modes.verticalCenter
        height: 34
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.schemes
        WheelHandler {
            onWheel: event => schemes.flick(event.angleDelta.y * 8, 0)
        }
        delegate: Chip {
            required property var modelData
            label: modelData[1]
            active: Config.theme.scheme === modelData[0]
            onClicked: if (!active) { Editor.record(); Config.theme.scheme = modelData[0]; }
        }
    }

    // The palette
    Row {
        id: palette
        anchors.right: parent.right
        anchors.verticalCenter: modes.verticalCenter
        spacing: 6
        Repeater {
            model: [Theme.paper.accent, Theme.paper.fg, Theme.paper.mute, Theme.paper.raised, Theme.paper.bg]
            Rectangle {
                required property color modelData
                width: 22
                height: 22
                radius: 11
                color: modelData
                border.width: 1
                border.color: Theme.ink.line
            }
        }
    }
}
