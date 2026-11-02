import QtQuick
import qs.core

// A one-line text field on the island. Enter calls `accepted`.
//   Field { placeholder: "Password"; secret: true; onAccepted: ... }
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property bool secret: false
    signal accepted(string text)

    function focusField() { input.forceActiveFocus(); }

    implicitWidth: 220
    implicitHeight: 34
    radius: 10
    color: "transparent"
    border.width: 1
    border.color: input.activeFocus ? Theme.ink.accent : Theme.ink.line

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.ink.fg
        selectionColor: Theme.ink.accent
        selectedTextColor: Theme.ink.onAccent
        font.family: Theme.font.family
        font.styleName: Theme.font.regular
        font.pixelSize: Theme.font.small
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: root.accepted(text)
        Keys.onEscapePressed: event => { event.accepted = false; }

        Txt {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            size: Theme.font.small
            color: Theme.ink.mute
        }
    }
}
