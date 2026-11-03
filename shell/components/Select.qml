import QtQuick
import QtQuick.Controls
import qs.core

// A dropdown for a long list of values. Options are strings, or objects
// { value, label, enabled }. Up/Down change the value while it has focus.
//   Select { options: ["1920x1080", "1280x720"]; value: mode; onPicked: v => mode = v }
Item {
    id: root

    property var options: []
    property var value
    property string placeholder: "Choose"
    readonly property var c: Theme.paper
    signal picked(var value)

    function valueOf(o) { return typeof o === "object" ? o.value : o; }
    function labelOf(o) { return typeof o === "object" ? (o.label ?? String(o.value)) : String(o); }
    function usable(o) { return typeof o !== "object" || o.enabled !== false; }
    readonly property int current: {
        for (let i = 0; i < options.length; i++)
            if (valueOf(options[i]) === value)
                return i;
        return -1;
    }

    implicitWidth: 240
    implicitHeight: 38
    activeFocusOnTab: true

    Keys.onUpPressed: step(-1)
    Keys.onDownPressed: step(1)
    Keys.onSpacePressed: popup.open()
    Keys.onReturnPressed: popup.open()
    function step(d) {
        let i = current;
        for (let n = 0; n < options.length; n++) {
            i = Math.max(0, Math.min(options.length - 1, i + d));
            if (usable(options[i]))
                break;
        }
        if (i >= 0 && i !== current)
            picked(valueOf(options[i]));
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: mouse.containsMouse || popup.opened ? root.c.raised : "transparent"
        border.width: 1
        border.color: root.activeFocus || popup.opened ? root.c.fg : root.c.line
    }
    Txt {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: arrow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.current >= 0 ? root.labelOf(root.options[root.current]) : root.placeholder
        face: Theme.font.regular
        color: root.current >= 0 ? root.c.fg : root.c.mute
    }
    Icon {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: "expand_more"
        size: 20
        color: root.c.mute
        rotation: popup.opened ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Motion.fast } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            popup.opened ? popup.close() : popup.open();
        }
    }

    Popup {
        id: popup
        width: Math.max(root.width, 180)
        height: Math.min(list.contentHeight + 12, 320)
        padding: 6
        // Below the field, or above it when the window has no room below
        onAboutToShow: {
            const win = root.Window.window;
            const bottom = root.mapToItem(null, 0, root.height).y;
            y = win && bottom + 6 + height > win.height - 8 && root.mapToItem(null, 0, 0).y - 6 - height > 8
                ? -height - 6 : root.height + 6;
        }
        onOpened: list.positionViewAtIndex(Math.max(0, root.current), ListView.Center)

        background: Rectangle {
            radius: 14
            color: root.c.bg
            border.width: 1
            border.color: root.c.fg
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool chosen: index === root.current
                readonly property bool ok: root.usable(modelData)
                width: list.width
                height: 34
                radius: 9
                color: itemMouse.containsMouse && ok ? root.c.raised : "transparent"
                opacity: ok ? 1 : 0.35
                Txt {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: check.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labelOf(item.modelData) + (item.ok ? "" : " · later")
                    face: item.chosen ? Theme.font.medium : Theme.font.light
                    color: root.c.fg
                }
                Icon {
                    id: check
                    visible: item.chosen
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 18
                    color: root.c.fg
                }
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: item.ok
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        popup.close();
                        if (!item.chosen)
                            root.picked(root.valueOf(item.modelData));
                    }
                }
            }
        }
    }
}
