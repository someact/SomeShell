import QtQuick
import qs.core

// Material Symbol on an expressive shape (ii's look, adapted to glass).
// Inactive: the icon floats with no background, kept readable over glass or a
// busy wallpaper by a thin dark halo (a glyph outline, no extra layer).
// Active: the tinted shape springs in behind it and the icon fills.
//
//   ShapeIcon { icon: "wifi"; active: Network.connected; shape: "cookie7Sided" }
Item {
    id: root

    property string icon
    property real size: 20                  // icon size; the shape adds `padding` around it
    property real padding: Math.round(size * 0.45)
    property string shape: "cookie7Sided"
    property bool active: false
    property bool halo: true                // outline the floating (inactive) icon
    property color shapeColor: Theme.primary
    property color iconColor: Theme.fgIsland
    property color activeIconColor: Theme.fgPrimary

    implicitWidth: size + padding * 2
    implicitHeight: size + padding * 2

    MaterialShape {
        anchors.fill: parent
        shape: root.shape
        color: root.shapeColor
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.55
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }
        Behavior on scale {
            Spring { preset: "bouncy" }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.size
        fill: 1
        color: root.active ? root.activeIconColor : root.iconColor
        style: root.halo && !root.active ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.35)
        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }
}
