import QtQuick
import qs.core

// Single-line text input. `committed(text)` on Enter or when focus leaves.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder
    property bool mono: false
    property bool secret: false     // dots unless it is being edited (API keys)
    signal committed(string text)

    implicitWidth: 300
    implicitHeight: 36
    radius: Theme.radius.small
    color: Theme.surfaceHigh
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.primary : Theme.outlineVariant

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.fgSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.fgPrimary
        font.family: field.mono ? Theme.font.mono : Theme.font.ui
        font.pixelSize: Theme.font.normal
        selectByMouse: true
        echoMode: field.secret ? TextInput.PasswordEchoOnEdit : TextInput.Normal
        onAccepted: field.committed(text)
        onActiveFocusChanged: if (!activeFocus) field.committed(text)
    }
    SText {
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        visible: input.text === "" && !input.activeFocus
        text: field.placeholder
        dim: true
    }
}
