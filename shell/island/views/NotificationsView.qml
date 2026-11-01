import QtQuick
import Quickshell.Services.Notifications
import qs.core
import qs.components
import qs.services

// Notification list. ↑/↓ select, Enter runs the default action, Delete dismisses.
FocusScope {
    id: root

    implicitWidth: 560
    implicitHeight: header.height + 8 + (Notifs.count > 0 ? list.height : empty.height)

    function handleKey(event) {
        const n = Notifs.list[list.currentIndex];
        switch (event.key) {
        case Qt.Key_Up:
            list.up();
            return true;
        case Qt.Key_Down:
            list.down();
            return true;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            Notifs.dismiss(n);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (n?.actions.length > 0)
                Notifs.invoke(n, n.actions.find(a => a.identifier === "default") ?? n.actions[0]);
            return true;
        }
        return UiState.navKey(event);
    }

    Item {
        id: header
        width: parent.width
        height: 32
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.count > 0 ? Notifs.count + " notifications" : "Notifications"
            font.styleName: Theme.font.styleTitle
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            IconButton {
                icon: "do_not_disturb_on"
                active: Notifs.dnd
                width: 32
                height: 32
                iconSize: 18
                onClicked: Notifs.toggleDnd()
            }
            IconButton {
                icon: "clear_all"
                visible: Notifs.count > 0
                width: 32
                height: 32
                iconSize: 18
                onClicked: Notifs.clear()
            }
        }
    }

    Label {
        id: empty
        visible: Notifs.count === 0
        anchors.top: header.bottom
        anchors.topMargin: 8
        height: 60
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "All caught up"
        color: Theme.fgIslandDim
    }

    KeyNavList {
        id: list
        visible: Notifs.count > 0
        anchors.top: header.bottom
        anchors.topMargin: 8
        width: parent.width
        height: Math.min(contentHeight, 420)
        spacing: 4
        model: Notifs.list

        delegate: Item {
            id: card
            required property Notification modelData
            width: ListView.view.width
            height: body.implicitHeight + 20

            Row {
                id: body
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 12
                Cover {
                    width: 36
                    height: 36
                    radius: Theme.radius.normal
                    source: Notifs.icon(card.modelData)
                    fallbackIcon: "notifications"
                }
                Column {
                    width: parent.width - 48 - 32
                    spacing: 2
                    Label {
                        width: parent.width
                        text: Notifs.title(card.modelData)
                        font.styleName: Theme.font.styleTitle
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: Notifs.text(card.modelData)
                        color: Theme.fgIslandDim
                        font.pixelSize: Theme.font.small
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                    }
                    Row {
                        spacing: 6
                        visible: card.modelData.actions.length > 0
                        topPadding: 4
                        Repeater {
                            model: card.modelData.actions
                            PressButton {
                                id: actionButton
                                required property NotificationAction modelData
                                width: actionLabel.implicitWidth + 20
                                height: 26
                                color: Theme.islandRaised
                                onClicked: Notifs.invoke(card.modelData, modelData)
                                Label {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionButton.modelData.text
                                    font.pixelSize: Theme.font.small
                                }
                            }
                        }
                    }
                }
                IconButton {
                    icon: "close"
                    width: 28
                    height: 28
                    iconSize: 16
                    onClicked: Notifs.dismiss(card.modelData)
                }
            }
        }
    }
}
