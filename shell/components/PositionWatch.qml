import QtQuick
import qs.services

// Keeps Media's position ticking while `active` (a view that shows it is on
// screen). Media reads the position once a second while any watch is active.
//   PositionWatch { active: root.visible }
QtObject {
    id: root

    property bool active: false
    property bool counted: false

    function sync() {
        if (active && !counted) {
            Media.watchers++;
            counted = true;
        } else if (!active && counted) {
            Media.watchers--;
            counted = false;
        }
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Media.watchers--
}
