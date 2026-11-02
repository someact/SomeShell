import QtQuick
import qs.core
import qs.components

// A tab whose part of step 6 is not built yet
Item {
    property string tab
    Column {
        anchors.centerIn: parent
        spacing: 8
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tab === "widgets" ? "widgets" : "view_carousel"
            size: 32
            color: Theme.ink.mute
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (tab === "widgets" ? "Widgets" : "Workspace designs") + " come next in step 6"
            caps: true
            color: Theme.ink.mute
        }
    }
}
