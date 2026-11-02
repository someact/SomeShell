import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// The wallpaper on one monitor. Decoded at the monitor's size (sourceSize),
// so a big image does not stay in memory at full size. A new wallpaper
// fades in over the old one.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "black"

    WlrLayershell.namespace: "someshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    // Two images: `a` lies on top of `b`. A new wallpaper loads into the hidden
    // one; once it is decoded, `a` fades in or out to reveal it.
    property bool showA: true
    readonly property string source: Wallpaper.path ? "file://" + Wallpaper.path : ""
    onSourceChanged: (showA ? b : a).source = source
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
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.modelData.width, win.modelData.height)
        asynchronous: true
        cache: false
        onStatusChanged: if (status === Image.Ready && source == win.source) win.showA = false
    }
    Image {
        id: a
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
}
