import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Dock: on/off and auto-hide for the separate dock (Notch and Plain; the
// Dock style always has its bar), and the pinned apps: a click on one
// removes it, the search adds one.
Item {
    id: root
    property string tab
    readonly property bool docked: Desktop.style === "dock"

    function setPinned(list) {
        Editor.record();
        Desktop.dock.pinned = list;
    }

    Column {
        id: left
        width: 250
        spacing: 10
        Txt {
            width: parent.width
            text: root.docked ? "Dock style has its own bar" : "Separate dock"
            caps: true
            color: Theme.ink.mute
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
        Row {
            spacing: 6
            Chip {
                icon: "dock_to_bottom"
                label: Desktop.dock.enabled ? "On" : "Off"
                active: Desktop.dock.enabled
                enabled: !root.docked
                onClicked: { Editor.record(); Desktop.dock.enabled = !Desktop.dock.enabled; }
            }
            Chip {
                icon: "unfold_less"
                label: "Auto-hide"
                active: Desktop.dock.autoHide
                enabled: !root.docked && Desktop.dock.enabled
                onClicked: { Editor.record(); Desktop.dock.autoHide = !Desktop.dock.autoHide; }
            }
        }
        Txt {
            width: parent.width
            text: root.docked ? "These are for the separate dock with the Notch and Plain styles" : "Auto-hide: touch the bottom edge to show it"
            size: Theme.font.small
            color: Theme.ink.mute
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }

    Column {
        anchors.left: left.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        spacing: 10

        Txt {
            text: "Pinned  ·  click one to unpin"
            caps: true
            color: Theme.ink.mute
        }
        // Pinned apps
        Row {
            spacing: 6
            height: 44
            Repeater {
                model: Desktop.dock.pinned
                Tap {
                    id: pin
                    required property string modelData
                    required property int index
                    readonly property var entry: DesktopEntries.byId(modelData)
                    width: 44
                    height: 44
                    radius: 12
                    outlined: true
                    onClicked: {
                        const p = Desktop.dock.pinned.slice();
                        p.splice(index, 1);
                        root.setPinned(p);
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: Quickshell.iconPath(pin.entry?.icon ?? "", true)
                        sourceSize: Qt.size(56, 56)
                        opacity: pin.hovered ? 0.35 : 1
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: pin.hovered
                        name: "close"
                        color: pin.fg
                    }
                }
            }
            Txt {
                visible: Desktop.dock.pinned.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Nothing pinned yet"
                color: Theme.ink.mute
            }
        }
        // Add: search the apps
        Row {
            spacing: 8
            Field {
                id: find
                width: 220
                placeholder: "Add an app…"
            }
            Repeater {
                model: find.text.trim() ? Apps.search(find.text, 5).filter(e => !Desktop.dock.pinned.includes(e.id)) : []
                Tap {
                    id: hit
                    required property var modelData
                    width: 34
                    height: 34
                    radius: 10
                    onClicked: {
                        root.setPinned(Desktop.dock.pinned.concat([modelData.id]));
                        find.text = "";
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: Quickshell.iconPath(hit.modelData.icon ?? "", true)
                        sourceSize: Qt.size(48, 48)
                    }
                }
            }
        }
    }
}
