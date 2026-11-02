import QtQuick
import qs.core
import qs.components
import qs.services

// 04 Notify. Grouped by app, newest first. Click one to run its action and
// dismiss it, or use the x. Do not disturb and Clear all at the top.
Item {
    id: root

    readonly property int shown: 8

    implicitWidth: 500
    implicitHeight: col.implicitHeight

    function ago(t) {
        const m = Math.round((Clock.now - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + " m" : m < 1440 ? Math.round(m / 60) + " h" : Math.round(m / 1440) + " d";
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 34
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifications.history.length + (Notifications.history.length === 1 ? " notification" : " notifications")
                caps: true
                color: Theme.ink.mute
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Tap {
                    width: 132
                    height: 34
                    outlined: true
                    active: Notifications.dnd
                    onClicked: Notifications.dnd = !Notifications.dnd
                    Txt {
                        anchors.centerIn: parent
                        text: "Do not disturb"
                        caps: true
                        size: 10
                        color: parent.fg
                    }
                }
                Tap {
                    visible: Notifications.history.length > 0
                    width: 90
                    height: 34
                    outlined: true
                    onClicked: Notifications.clear()
                    Txt {
                        anchors.centerIn: parent
                        text: "Clear all"
                        caps: true
                        size: 10
                        color: parent.fg
                    }
                }
            }
        }

        Txt {
            visible: Notifications.history.length === 0
            text: "Nothing new"
            caps: true
            color: Theme.ink.mute
            topPadding: 16
            bottomPadding: 16
        }

        Repeater {
            // Only as many groups as fit the shown count
            model: Notifications.groups.slice(0, 4)

            Column {
                id: group
                required property var modelData
                width: col.width
                spacing: 0

                Item {
                    width: parent.width
                    height: 26
                    Txt {
                        text: group.modelData.app
                        caps: true
                        color: Theme.ink.fg
                    }
                    Txt {
                        anchors.right: parent.right
                        text: group.modelData.items.length
                        caps: true
                        color: Theme.ink.mute
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.ink.line
                    }
                }

                Repeater {
                    model: group.modelData.items.slice(0, 3)
                    Item {
                        id: item
                        required property var modelData
                        width: group.width
                        height: Math.max(54, text.implicitHeight + 18)

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 1
                            radius: 10
                            color: hover.containsMouse ? Theme.ink.raised : "transparent"
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.invoke(item.modelData.id, "default")
                        }
                        Column {
                            id: text
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 90
                            Txt {
                                width: parent.width
                                text: item.modelData.summary
                                face: Theme.font.medium
                            }
                            Txt {
                                width: parent.width
                                visible: text !== ""
                                text: item.modelData.body.replace(/\s+/g, " ")
                                size: Theme.font.small
                                color: Theme.ink.mute
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }
                        }
                        Txt {
                            anchors.right: close.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ago(item.modelData.time)
                            caps: true
                            color: Theme.ink.mute
                        }
                        Tap {
                            id: close
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 15
                            onClicked: Notifications.dismiss(item.modelData.id)
                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 18
                                color: parent.fg
                            }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.ink.line
                        }
                    }
                }
            }
        }
    }
}
