import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Idle: the time, plus small badges for DND and unread notifications.
Item {
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.dnd
            name: "do_not_disturb_on"
            size: 15
            color: Theme.fgIslandDim
        }
        Digits {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, Config.clock.format)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.count > 0 && !Notifs.dnd
            width: 6
            height: 6
            radius: 3
            color: Theme.accentIsland
        }
    }
}
