import QtQuick
import qs.core
import qs.components

// The editing panel under the card: tabs along the top, the open tab below.
// Each tab is its own file, loaded only while it shows.
Rectangle {
    id: root

    readonly property var tabs: [
        { id: "wallpaper", label: "Wallpaper", icon: "wallpaper" },
        { id: "island", label: "Island", icon: "toast" },
        { id: "dock", label: "Dock", icon: "dock_to_bottom" },
        { id: "widgets", label: "Widgets", icon: "widgets" },
        { id: "workspaces", label: "Workspaces", icon: "view_carousel" },
        { id: "presets", label: "Presets", icon: "dashboard_customize" }
    ]
    readonly property var files: ({
        wallpaper: "tabs/WallpaperTab.qml", island: "tabs/IslandTab.qml", dock: "tabs/DockTab.qml",
        presets: "tabs/PresetsTab.qml", widgets: "tabs/LaterTab.qml", workspaces: "tabs/LaterTab.qml"
    })

    radius: 24
    color: "transparent"
    border.width: 1
    border.color: Theme.ink.line

    Row {
        id: tabRow
        x: 14
        y: 8
        spacing: 2
        Repeater {
            model: root.tabs
            Tap {
                id: tab
                required property var modelData
                readonly property bool on: Ui.editTab === modelData.id
                implicitWidth: tr.implicitWidth + 22
                implicitHeight: 38
                radius: Theme.shape.small
                onClicked: Ui.editTab = modelData.id
                Row {
                    id: tr
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
                        text: tab.modelData.label
                        caps: true
                        color: tab.pressed ? tab.fg : tab.on ? Theme.ink.fg : Theme.ink.mute
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
    Rectangle {
        id: line
        anchors.top: tabRow.bottom
        anchors.topMargin: 4
        width: parent.width
        height: 1
        color: Theme.ink.line
    }

    // Set imperatively (never bind both source and sourceComponent)
    Loader {
        id: page
        anchors.top: line.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        readonly property string tab: Ui.editTab
        onTabChanged: if (tab) setSource(root.files[tab] ?? "", { tab: tab })
        Component.onCompleted: setSource(root.files[Ui.editTab] ?? "tabs/WallpaperTab.qml", { tab: Ui.editTab })
    }
}
