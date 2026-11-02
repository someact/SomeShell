import QtQuick
import qs.core

// A small rounded choice: an optional icon and a label. Outlined when off,
// filled with the accent when `active`.
//   Chip { icon: "dark_mode"; label: "Dark"; active: true; onClicked: ... }
Tap {
    id: chip
    property string icon
    property string label
    implicitWidth: chipRow.implicitWidth + 22
    implicitHeight: 34
    radius: 17
    outlined: true
    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            filled: chip.active
            size: 17
            color: chip.fg
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            caps: true
            color: chip.fg
        }
    }
}
