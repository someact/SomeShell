import QtQuick
import qs.core
import qs.components
import qs.services

// Password prompt for the native polkit agent.
FocusScope {
    id: root

    readonly property var flow: Polkit.flow

    implicitWidth: 480
    implicitHeight: col.implicitHeight

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            flow?.cancelAuthenticationRequest();
            UiState.close();
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (flow?.isResponseRequired) {
                flow.submit(field.text);
                field.text = "";
            }
            return true;
        }
        return false;
    }

    Component.onCompleted: field.focusInput()

    Connections {
        target: root.flow
        function onIsCompletedChanged() {
            if (root.flow.isCompleted && UiState.view === "polkit")
                UiState.close();
        }
    }
    Connections {
        target: Polkit
        function onActiveChanged() {
            if (!Polkit.active && UiState.view === "polkit")
                UiState.close();
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Row {
            spacing: 12
            Icon {
                name: "admin_panel_settings"
                size: 28
                fill: 1
                color: Theme.accentIsland
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication required"
                font.pixelSize: Theme.font.large
                font.styleName: Theme.font.styleTitle
            }
        }
        Label {
            width: parent.width
            text: root.flow?.message ?? ""
            wrapMode: Text.Wrap
            color: Theme.fgIslandDim
        }
        SearchField {
            id: field
            width: parent.width
            focus: true
            icon: "key"
            placeholder: root.flow?.inputPrompt || "Password"
            keyHandler: root.handleKey
            echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: root.flow?.supplementaryMessage ?? ""
            color: root.flow?.supplementaryIsError ? Theme.error : Theme.fgIslandDim
            wrapMode: Text.Wrap
        }
    }
}
