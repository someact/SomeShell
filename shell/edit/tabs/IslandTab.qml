import QtQuick
import QtQuick.Shapes
import qs.core
import qs.components
import qs.services

// Island: the style (Notch, Plain, Dock) as three small pictures, and its color.
Item {
    id: root
    property string tab

    readonly property var styles: [
        { id: "notch", label: "Notch", sub: "A tab glued to the top edge" },
        { id: "plain", label: "Plain", sub: "A pill floating below the top" },
        { id: "dock", label: "Dock", sub: "One bar at the bottom with the apps" }
    ]

    Row {
        id: cards
        spacing: 14
        Repeater {
            model: root.styles
            Tap {
                id: card
                required property var modelData
                width: 196
                height: 160
                radius: 18
                outlined: true
                active: Desktop.style === modelData.id
                onClicked: if (!active) { Editor.record(); Desktop.island.style = modelData.id; }

                // A tiny screen with the island drawn in this style
                Rectangle {
                    id: mini
                    x: 14
                    y: 14
                    width: parent.width - 28
                    height: 72
                    radius: 8
                    color: card.active ? Qt.alpha(Theme.ink.onAccent, 0.18) : Theme.ink.raised
                    clip: true
                    readonly property color shape: card.active ? Theme.ink.onAccent : Theme.ink.fg
                    // Notch
                    Rectangle {
                        visible: card.modelData.id === "notch"
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 56
                        height: 12
                        color: mini.shape
                        bottomLeftRadius: 6
                        bottomRightRadius: 6
                    }
                    // Plain
                    Rectangle {
                        visible: card.modelData.id === "plain"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 5
                        width: 56
                        height: 12
                        radius: 6
                        color: mini.shape
                    }
                    // Dock
                    Rectangle {
                        visible: card.modelData.id === "dock"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        width: 104
                        height: 14
                        radius: 7
                        color: mini.shape
                    }
                }
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: mini.bottom
                    anchors.topMargin: 10
                    Txt {
                        text: card.modelData.label
                        face: Theme.font.bold
                        color: card.fg
                    }
                    Txt {
                        width: parent.width
                        text: card.modelData.sub
                        size: Theme.font.small
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        color: card.pressed ? card.fg : card.active ? Theme.ink.onAccent : Theme.ink.mute
                    }
                }
            }
        }
    }

    // Color
    Column {
        anchors.left: cards.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        spacing: 10
        Txt {
            text: "Color"
            caps: true
            color: Theme.ink.mute
        }

        Chip {
            icon: "contrast"
            label: "Always dark"
            active: Desktop.island.color !== "inverse"
            onClicked: if (!active) { Editor.record(); Desktop.island.color = "ink"; }
        }
        Chip {
            icon: "invert_colors"
            label: "Opposite"
            active: Desktop.island.color === "inverse"
            onClicked: if (!active) { Editor.record(); Desktop.island.color = "inverse"; }
        }
        Txt {
            text: "Opposite: light on a dark desktop, dark on a light one"
            width: parent.width
            size: Theme.font.small
            color: Theme.ink.mute
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
    }
}
