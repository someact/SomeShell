import QtQuick
import qs.core

// The red "live" dot of recording and microphone / screen-share use. It pulses
// unless `live` is false (the island is under a fullscreen window) or game mode is on.
Rectangle {
    id: root

    property bool live: true
    property real size: 8

    width: size
    height: size
    radius: size / 2
    color: "#ff453a"
    SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: !GameMode.active && root.live
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
    }
}
