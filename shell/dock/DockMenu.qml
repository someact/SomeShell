import QtQuick
import qs.core
import qs.components
import qs.services

// Right-click menu for a dock app: its windows, desktop actions, new window,
// pin/unpin and close. Drawn inside the dock window, above the icon.
Rectangle {
    id: menu

    property bool open: false
    property string key: ""
    property real centerX: 0
    required property real dockTop
    required property real maxX

    readonly property var entry: key !== "" ? Taskbar.entry(key) : null
    readonly property var windows: Taskbar.windowsOf(key)

    function show(appKey, cx) {
        key = appKey;
        centerX = cx;
        open = true;
    }
    function close() {
        open = false;
    }
    function act(fn) {
        fn();
        close();
    }

    x: Math.round(Math.max(8, Math.min(maxX - width - 8, centerX - width / 2)))
    y: dockTop - height - 10
    width: 248
    height: column.implicitHeight + 12
    radius: Theme.radius.normal
    color: Theme.island
    border.width: 1
    border.color: Theme.glassRim

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.Bottom
    Behavior on opacity {
        NumberAnimation { duration: Motion.fast }
    }
    Behavior on scale {
        Spring { preset: "snappy" }
    }

    Column {
        id: column
        x: 6
        y: 6
        width: menu.width - 12

        Label {
            width: parent.width
            leftPadding: 10
            height: 28
            text: menu.entry?.name ?? menu.key
            font.pixelSize: Theme.font.small
            font.styleName: Theme.font.styleTitle
            color: Theme.fgIslandDim
        }

        // Windows, when there is more than one to choose from
        Repeater {
            model: menu.windows.length > 1 ? menu.windows : []
            MenuRow {
                required property var modelData
                icon: modelData.activated ? "radio_button_checked" : "web_asset"
                text: modelData.title || menu.key
                onClicked: menu.act(() => modelData.activate())
            }
        }
        Divider {
            visible: menu.windows.length > 1
        }

        Repeater {
            model: menu.entry?.actions ?? []
            MenuRow {
                required property var modelData
                icon: "arrow_outward"
                text: modelData.name
                onClicked: menu.act(() => modelData.execute())
            }
        }
        MenuRow {
            icon: "add"
            text: menu.windows.length > 0 ? "New window" : "Open"
            onClicked: menu.act(() => Taskbar.launch(menu.key))
        }
        MenuRow {
            readonly property bool pinned: Taskbar.isPinned(menu.key)
            icon: pinned ? "keep_off" : "keep"
            text: pinned ? "Unpin from dock" : "Pin to dock"
            onClicked: menu.act(() => Taskbar.togglePin(menu.key))
        }
        MenuRow {
            visible: menu.windows.length > 0
            icon: "close"
            text: menu.windows.length > 1 ? `Close ${menu.windows.length} windows` : "Close"
            danger: true
            onClicked: menu.act(() => Taskbar.closeAll(menu.key))
        }
    }

    component Divider: Rectangle {
        width: parent.width
        height: 9
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 16
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
    }

    component MenuRow: PressButton {
        id: row
        property string icon
        property string text
        property bool danger: false

        width: parent.width
        height: 32
        radius: Theme.radius.small
        hoverColor: Theme.islandRaisedHover

        Row {
            id: rowContent
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: row.icon
                size: 18
                color: row.danger ? Theme.error : Theme.fgIsland
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, row.width - 48)
                text: row.text
                color: row.danger ? Theme.error : Theme.fgIsland
            }
        }
    }
}
