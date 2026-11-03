import QtQuick

// A thin crosshair, the print mark from the posters.
Item {
    id: root
    property real size: 20
    property color color: "white"
    width: size
    height: size
    Rectangle { x: Math.round(root.size / 2); width: 1; height: root.size; color: root.color }
    Rectangle { y: Math.round(root.size / 2); height: 1; width: root.size; color: root.color }
}
