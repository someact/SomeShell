import QtQuick
import qs.core

// A small filled label: CONNECTED, DEFAULT...
Rectangle {
    property alias text: label.text
    implicitWidth: label.implicitWidth + 16
    implicitHeight: 22
    radius: 11
    color: Theme.ink.accent
    Txt {
        id: label
        anchors.centerIn: parent
        caps: true
        size: 10
        color: Theme.ink.onAccent
    }
}
