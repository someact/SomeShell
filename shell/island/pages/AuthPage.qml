import QtQuick
import qs.core
import qs.components
import qs.services

// An app asks for the admin password (services/Auth.qml, polkit): its
// message, the action, who signs in (‹ › with several), the password,
// Unlock / Cancel. Enter unlocks, Esc cancels; a wrong password shakes.
Item {
    id: root

    readonly property var flow: Auth.flow
    readonly property var ids: flow?.identities ?? []
    readonly property var who: flow?.selectedIdentity ?? null
    readonly property string whoName: who ? (who.displayName || who.name || "") : ""

    implicitWidth: 560
    implicitHeight: col.implicitHeight

    function unlock() {
        if (pass.text === "" || !(root.flow?.isResponseRequired ?? false))
            return;
        Auth.error = "";
        Auth.submit(pass.text);
        pass.text = "";
    }

    Component.onCompleted: pass.focusField()
    // A new try after a wrong password: type again
    Connections {
        target: Auth
        function onWrongTickChanged() {
            shake.restart();
            pass.focusField();
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 16

        Row {
            width: parent.width
            spacing: 16
            Rectangle {
                width: 56
                height: 56
                radius: Theme.shape.small
                color: Theme.ink.raised
                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    filled: true
                    size: 26
                    color: Theme.ink.fg
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 72
                spacing: 2
                Txt {
                    width: parent.width
                    text: root.flow?.message || "An app asks for your password"
                    face: Theme.font.medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Txt {
                    width: parent.width
                    text: root.flow?.actionId ?? ""
                    caps: true
                    color: Theme.ink.mute
                    elide: Text.ElideMiddle
                }
            }
        }

        // The password, and who it is for
        Item {
            id: form
            width: parent.width
            height: formCol.implicitHeight
            property real shake: 0
            transform: Translate { x: form.shake }

            Column {
                id: formCol
                width: parent.width
                spacing: 8

                Row {
                    spacing: 6
                    visible: root.whoName !== ""
                    Tap {
                        visible: root.ids.length > 1
                        width: 34
                        height: 34
                        outlined: true
                        onClicked: Auth.nextUser(-1)
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron_left"
                            size: 20
                            color: parent.fg
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "person"
                            size: 18
                            color: Theme.ink.mute
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.whoName
                            caps: true
                            color: Theme.ink.mute
                        }
                    }
                    Tap {
                        visible: root.ids.length > 1
                        width: 34
                        height: 34
                        outlined: true
                        onClicked: Auth.nextUser(1)
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron_right"
                            size: 20
                            color: parent.fg
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    Field {
                        id: pass
                        width: parent.width - unlockChip.width - cancelChip.width - 16
                        height: 40
                        secret: !(root.flow?.responseVisible ?? false)
                        placeholder: {
                            const p = (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "");
                            return p || "Password";
                        }
                        enabled: root.flow?.isResponseRequired ?? false
                        onAccepted: root.unlock()
                        onEdited: Auth.error = ""
                    }
                    Chip {
                        id: unlockChip
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "lock_open"
                        label: "Unlock"
                        active: true
                        onClicked: root.unlock()
                    }
                    Chip {
                        id: cancelChip
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        label: "Cancel"
                        onClicked: Auth.cancel()
                    }
                }

                Txt {
                    visible: text !== ""
                    width: parent.width
                    text: Auth.error || (root.flow && !root.flow.isResponseRequired ? "Checking…" : "")
                    caps: true
                    color: Auth.error ? Theme.ink.error : Theme.ink.mute
                }
            }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: form; property: "shake"; to: -10; duration: 60 }
        NumberAnimation { target: form; property: "shake"; to: 10; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: -10; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: 6; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: 0; duration: 100; easing.type: Easing.OutCubic }
    }
}
