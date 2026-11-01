import QtQuick
import qs.core
import qs.components
import qs.services

// Volume / brightness / layout feedback.
Item {
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Osd.icon
            size: 18
            fill: 1
        }
        Rectangle {
            visible: Osd.value >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 6
            radius: 3
            color: Theme.islandRaised
            Rectangle {
                height: parent.height
                radius: 3
                color: Theme.fgIsland
                width: parent.width * Math.min(1, Math.max(0, Osd.value))
                Behavior on width {
                    Spring { preset: "snappy" }
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            mono: Osd.value >= 0
            text: Osd.value >= 0 ? Math.round(Osd.value * 100) : Osd.text
            font.styleName: Theme.font.styleTitle
            width: Osd.value >= 0 ? 28 : implicitWidth
            horizontalAlignment: Text.AlignRight
        }
    }
}
