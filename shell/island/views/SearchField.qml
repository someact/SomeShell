import QtQuick
import qs.core
import qs.components

// Text input with a leading icon. Keys go to `keyHandler(event)` first, so
// views can steal ↑/↓/Enter/Tab and ←/→ on an empty field.
Item {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string icon: "search"
    property string placeholder: "Search"
    property var keyHandler: null

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitWidth: 400
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.islandRaised
    }

    Icon {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 20
        color: Theme.fgIslandDim
    }

    TextInput {
        id: input
        // Typing turns a hover-opened island into a normal one: it no longer
        // closes when the pointer leaves (a password half typed)
        onTextChanged: if (text !== "") UiState.hoverOpened = false
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        color: Theme.fgIsland
        selectionColor: Theme.primary
        selectedTextColor: Theme.fgPrimary
        font.family: Theme.font.ui
        font.pixelSize: Theme.font.large
        clip: true

        Keys.onPressed: event => {
            if (root.keyHandler && root.keyHandler(event))
                event.accepted = true;
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.large
        }
    }
}
