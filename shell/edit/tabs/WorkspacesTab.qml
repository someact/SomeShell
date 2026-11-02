import QtQuick
import qs.core
import qs.components
import qs.services

// Workspaces: a design per workspace number (SomeShell.md 3.3). The numbers
// 01-10 as a row (the current one marked, named ones show their name); the
// chosen number gets a name and what its resting island shows. The card's
// island previews it; Flash plays the name there.
Item {
    id: root
    property string tab

    readonly property int n: Spaces.editSlot
    readonly property var d: Spaces.design(n)

    // One Undo step per number edited, not one per letter
    property int recordedFor: 0
    function record() {
        if (recordedFor !== n) {
            Editor.record();
            recordedFor = n;
        }
    }
    // (read the store itself: `d` is stale inside this handler)
    onNChanged: {
        recordedFor = 0;
        nameField.text = Spaces.design(Spaces.editSlot)?.name ?? "";
    }
    Component.onCompleted: {
        Spaces.editSlot = Spaces.slot > 0 ? Spaces.slot : 1;
        nameField.text = Spaces.design(Spaces.editSlot)?.name ?? "";
    }
    // Undo or a preset changes the list under the field
    Connections {
        target: Desktop
        function onWorkspacesChanged() {
            const name = Spaces.design(root.n)?.name ?? "";
            if (nameField.text.trim() !== name)
                nameField.text = name;
        }
    }

    // The numbers
    Row {
        id: numbers
        spacing: 8
        Repeater {
            model: 10
            Tap {
                id: num
                required property int index
                readonly property int slot: index + 1
                readonly property var design: Spaces.design(slot)
                width: 96
                height: 56
                radius: 14
                outlined: true
                active: root.n === slot
                onClicked: Spaces.editSlot = slot
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Row {
                        spacing: 6
                        Digits {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(num.slot).padStart(2, "0")
                            size: Theme.font.title
                            color: num.fg
                        }
                        // The workspace you are on
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Spaces.slot === num.slot
                            width: 6
                            height: 6
                            radius: 3
                            color: num.active ? Theme.ink.onAccent : Theme.ink.accent
                        }
                    }
                    Txt {
                        width: parent.width
                        text: num.design?.name || "—"
                        caps: true
                        color: num.pressed ? num.fg : num.active ? Theme.ink.onAccent : Theme.ink.mute
                    }
                }
            }
        }
    }

    // The chosen number
    Row {
        anchors.top: numbers.bottom
        anchors.topMargin: 16
        spacing: 28

        Column {
            spacing: 10
            Txt {
                text: "Name"
                caps: true
                color: Theme.ink.mute
            }
            Field {
                id: nameField
                width: 220
                placeholder: "Workspace " + root.n
                onEdited: text => {
                    if (text.length > 12) {
                        nameField.text = text.slice(0, 12);
                        return;
                    }
                    root.record();
                    Spaces.set(root.n, text, root.d?.rest ?? "clock");
                }
                onAccepted: Spaces.previewFlash(root.n)
            }
            Row {
                spacing: 8
                Chip {
                    icon: "bolt"
                    label: "Flash"
                    enabled: (root.d?.name ?? "") !== ""
                    opacity: enabled ? 1 : 0.4
                    onClicked: Spaces.previewFlash(root.n)
                }
                Chip {
                    icon: "restart_alt"
                    label: "Clear"
                    enabled: root.d !== null
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        Editor.record();
                        Spaces.clear(root.n);
                        nameField.text = "";
                    }
                }
            }
        }

        Column {
            spacing: 10
            Txt {
                text: "Resting island"
                caps: true
                color: Theme.ink.mute
            }
            Row {
                spacing: 12
                Repeater {
                    model: Spaces.rests
                    Tap {
                        id: card
                        required property var modelData
                        width: 150
                        height: 88
                        radius: 16
                        outlined: true
                        active: (root.d?.rest ?? "clock") === modelData.id
                        onClicked: if (!active) {
                            Editor.record();
                            Spaces.set(root.n, root.d?.name ?? "", modelData.id);
                        }

                        // A tiny island in this layout
                        Rectangle {
                            id: mini
                            x: 10
                            y: 10
                            width: parent.width - 20
                            height: 40
                            radius: 8
                            color: card.active ? Qt.alpha(Theme.ink.onAccent, 0.18) : Theme.ink.raised
                            readonly property color shape: card.active ? Theme.ink.onAccent : Theme.ink.fg
                            readonly property color ink: card.active ? Theme.ink.accent : Theme.ink.bg
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: card.modelData.id === "media" ? 104 : 64
                                height: 20
                                color: mini.shape
                                bottomLeftRadius: 8
                                bottomRightRadius: 8
                                // Clock: the time and the day
                                Row {
                                    visible: card.modelData.id === "clock"
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Rectangle { width: 22; height: 5; radius: 2; color: mini.ink }
                                    Rectangle { width: 14; height: 3; radius: 1; color: mini.ink; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                                }
                                // Media large: the cover, the title and the artist
                                Row {
                                    visible: card.modelData.id === "media"
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Rectangle { width: 12; height: 12; radius: 6; color: mini.ink }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Rectangle { width: 54; height: 4; radius: 2; color: mini.ink }
                                        Rectangle { width: 34; height: 3; radius: 1; color: mini.ink; opacity: 0.6 }
                                    }
                                }
                            }
                        }
                        Txt {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.top: mini.bottom
                            anchors.topMargin: 8
                            text: card.modelData.label
                            face: Theme.font.bold
                            color: card.fg
                        }
                    }
                }
            }
        }

        Txt {
            width: 360
            text: "A switch to a named workspace shows its name on the island for a moment. Media large shows the playing track instead of the clock (the clock when nothing plays). Each number is the same on every monitor."
            size: Theme.font.small
            color: Theme.ink.mute
            wrapMode: Text.Wrap
            maximumLineCount: 7
            elide: Text.ElideNone
        }
    }
}
