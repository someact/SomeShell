import QtQuick
import qs.core
import qs.components

// The open island: page tabs along the top (icons; the active one shows its
// number and name, the clock sits at the end), the page title, then the page.
// The island takes the size of this content, so each page sets its own size.
FocusScope {
    id: root

    readonly property var current: Ui.pages[Ui.page]

    implicitWidth: Math.max(tabs.implicitWidth, page.implicitWidth) + 52
    implicitHeight: tabs.implicitHeight + head.implicitHeight + 1 + page.implicitHeight + 30

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Ui.close();
        } else if (event.key === Qt.Key_Tab) {
            Ui.nextPage(1);
        } else if (event.key === Qt.Key_Backtab) {
            Ui.nextPage(-1);
        } else if (event.key === Qt.Key_Left && !(event.modifiers & Qt.ShiftModifier)) {
            Ui.nextPage(-1);
        } else if (event.key === Qt.Key_Right && !(event.modifiers & Qt.ShiftModifier)) {
            Ui.nextPage(1);
        } else {
            return;
        }
        event.accepted = true;
    }

    // Tabs
    Row {
        id: tabs
        x: 14
        y: 6
        spacing: 2

        Repeater {
            model: Ui.pages

            Tap {
                id: tab
                required property var modelData
                required property int index
                readonly property bool on: index === Ui.page
                implicitHeight: 36
                implicitWidth: tabRow.implicitWidth + 20
                radius: Theme.shape.small
                onClicked: Ui.page = index

                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: tab.modelData.icon
                        filled: tab.on
                        size: 19
                        color: tab.pressed ? tab.fg : tab.on ? Theme.ink.fg : Theme.ink.mute
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.on
                        text: String(tab.index + 1).padStart(2, "0") + "  " + tab.modelData.label
                        caps: true
                        color: tab.fg
                    }
                }
                Rectangle {
                    visible: tab.on
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 20
                    height: 2
                    color: Theme.ink.accent
                }
            }
        }
    }

    Digits {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: tabs.verticalCenter
        text: Clock.time
        size: Theme.font.body
    }

    Rectangle {
        id: tabLine
        anchors.top: tabs.bottom
        width: parent.width
        height: 1
        color: Theme.ink.line
    }

    // Page number and title
    Row {
        id: head
        anchors.top: tabLine.bottom
        anchors.topMargin: 14
        x: 26
        spacing: 14
        Txt {
            anchors.baseline: title.baseline
            text: String(Ui.page + 1).padStart(2, "0") + " / " + String(Ui.pages.length).padStart(2, "0")
            caps: true
            color: Theme.ink.accent
        }
        Txt {
            id: title
            text: root.current.label
            caps: true
            size: Theme.font.headline
            face: Theme.font.bold
            font.letterSpacing: 1
        }
    }

    Loader {
        id: page
        anchors.top: head.bottom
        anchors.topMargin: 16
        x: 26
        // Each page is its own file from step 3 on; until then a placeholder
        sourceComponent: placeholder
    }

    Component {
        id: placeholder
        Item {
            // Sizes from the approved mockup, so the island already reshapes per page
            readonly property var sizes: ({
                search: [588, 400], control: [768, 420], media: [868, 270], notify: [488, 430],
                calendar: [728, 330], system: [928, 250], power: [748, 250]
            })
            readonly property var size: sizes[root.current.id] ?? [500, 300]
            implicitWidth: size[0]
            implicitHeight: size[1]

            Rectangle {
                anchors.fill: parent
                radius: Theme.shape.tile
                color: "transparent"
                border.width: 1
                border.color: Theme.ink.line
            }
            Txt {
                anchors.centerIn: parent
                text: root.current.label + " page comes in step " + (["search", "power"].includes(root.current.id) ? 3 : root.current.id === "calendar" || root.current.id === "system" ? 5 : 4)
                caps: true
                color: Theme.ink.mute
            }
        }
    }

    // The open island wipes in, once, when it opens
    opacity: 0
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: Motion.normal
        easing.type: Motion.easing
    }
}
