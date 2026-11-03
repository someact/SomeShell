import QtQuick
import qs.core

// The keyboard mark: an accent outline around `target` while it is the
// thing marked in the open island (Ui.kbItem). Put one inside anything that
// sets `kbNav` (see Open.qml for the rest of the keyboard contract).
Rectangle {
    id: ring
    required property Item target
    property real radiusOf: 10
    anchors.fill: parent
    anchors.margins: -3
    visible: Ui.kbItem === target
    radius: radiusOf + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.ink.accent
    z: 10
}
