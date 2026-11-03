import QtQuick
import qs.core

// A section title in the settings window: small spaced capitals with room above.
Item {
    property string text
    width: parent ? parent.width : 400
    implicitHeight: 52
    Txt {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        caps: true
        text: parent.text
        color: Theme.paper.mute
    }
}
