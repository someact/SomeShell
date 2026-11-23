import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core
import qs.services
import "../widgets"

// The wallpaper on one monitor, with its desktop widgets on top. Decoded at
// the monitor's size (sourceSize), so a big image does not stay in memory at
// full size. A new wallpaper fades in over the old one.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    // Always transparent so Qt Wayland allocates an ARGB surface from start;
    // the black backdrop lives in a child Rectangle hidden while somewall runs.
    color: "transparent"

    WlrLayershell.namespace: "someshell:wallpaper"
    WlrLayershell.layer: Wallpaper.live ? WlrLayer.Bottom : WlrLayer.Background

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !Wallpaper.live
    }

    // Two images: `a` lies on top of `b`. A new wallpaper loads into the hidden
    // one; once it is decoded, `a` fades in or out to reveal it.
    property bool showA: true
    readonly property string source: Wallpaper.stillPath ? "file://" + Wallpaper.stillPath : ""
    onSourceChanged: {
        const hidden = showA ? b : a;
        // Back to the picture the hidden image already holds (A → B → A):
        // its source does not change, so no Ready comes; show it at once
        if (hidden.source == source && hidden.status === Image.Ready)
            showA = !showA;
        else
            hidden.source = source;
    }
    Component.onCompleted: a.source = source

    // A right click or a long press on the empty desktop opens edit mode
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: 700
        onClicked: mouse => { if (mouse.button === Qt.RightButton) Ui.edit(); }
        onPressAndHold: Ui.edit()
    }

    Image {
        id: b
        visible: !Wallpaper.live
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.modelData.width, win.modelData.height)
        asynchronous: true
        cache: false
        onStatusChanged: if (status === Image.Ready && source == win.source) win.showA = false
    }
    Image {
        id: a
        visible: !Wallpaper.live
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.modelData.width, win.modelData.height)
        asynchronous: true
        cache: false
        opacity: win.showA ? 1 : 0
        onStatusChanged: if (status === Image.Ready && source == win.source) win.showA = true
        Behavior on opacity {
            NumberAnimation { duration: 400 }
        }
    }

    // Desktop widgets: drawn here (no extra full-screen surface), unloaded
    // while a game or a fullscreen window is on this monitor
    readonly property bool covered: GameMode.active
        || (Hyprland.monitors.values.find(m => m.name === win.modelData.name)?.activeWorkspace?.hasFullscreen ?? false)
    Loader {
        active: Desktop.widgets.length > 0 && !win.covered
        sourceComponent: WidgetLayer {
            screen: win.modelData
        }
    }
}
