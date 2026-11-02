import QtQuick
import qs.core
import qs.components
import qs.services

// Presets: a card per saved look (its thumbnail and name). A click applies
// it; on hover, rename and delete (delete asks with a second click).
Item {
    id: root
    property string tab
    property string renaming: ""
    property string deleting: ""

    Component.onCompleted: Presets.refresh()

    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Presets.list
        WheelHandler {
            onWheel: event => list.flick(event.angleDelta.y * 8, 0)
        }

        delegate: Tap {
            id: card
            required property var modelData
            readonly property bool current: modelData.name === Desktop.preset
            width: 220
            height: list.height
            radius: 18
            outlined: true
            highlighted: current
            onClicked: if (root.renaming !== modelData.slug) { Editor.record(); Presets.apply(modelData.slug); }

            Rectangle {
                id: shot
                x: 10
                y: 10
                width: parent.width - 20
                height: width * 10 / 16
                radius: 10
                color: Theme.ink.raised
                clip: true
                Image {
                    anchors.fill: parent
                    source: card.modelData.thumb ? "file://" + card.modelData.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }
            Txt {
                visible: root.renaming !== card.modelData.slug
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: tools.left
                anchors.top: shot.bottom
                anchors.topMargin: 10
                text: card.modelData.name
                face: Theme.font.bold
                color: card.pressed ? card.fg : Theme.ink.fg
            }
            Txt {
                visible: card.current
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: "In use"
                caps: true
                color: Theme.ink.accent
            }
            Field {
                visible: root.renaming === card.modelData.slug
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: shot.bottom
                anchors.topMargin: 6
                text: card.modelData.name
                onVisibleChanged: if (visible) focusField()
                onAccepted: t => {
                    if (t.trim() && t.trim() !== card.modelData.name)
                        Presets.rename(card.modelData.slug, t.trim());
                    root.renaming = "";
                }
            }
            Row {
                id: tools
                visible: card.hovered || root.deleting === card.modelData.slug
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: shot.bottom
                anchors.topMargin: 4
                Tap {
                    width: 30
                    height: 30
                    radius: 15
                    onClicked: root.renaming = card.modelData.slug
                    Icon { anchors.centerIn: parent; name: "edit"; size: 17; color: parent.fg }
                }
                Tap {
                    width: root.deleting === card.modelData.slug ? 74 : 30
                    height: 30
                    radius: 15
                    active: root.deleting === card.modelData.slug
                    onClicked: {
                        if (root.deleting === card.modelData.slug) {
                            Presets.remove(card.modelData.slug);
                            root.deleting = "";
                        } else {
                            root.deleting = card.modelData.slug;
                        }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "delete"; size: 17; color: parent.parent.fg }
                        Txt { visible: root.deleting === card.modelData.slug; anchors.verticalCenter: parent.verticalCenter; text: "Sure?"; caps: true; color: parent.parent.fg }
                    }
                }
            }
        }

        footer: Item {
            visible: Presets.list.length === 0
            width: visible ? list.width : 0
            height: list.height
            Txt {
                anchors.centerIn: parent
                text: "No presets yet: Save as new keeps this look"
                caps: true
                color: Theme.ink.mute
            }
        }
    }
}
