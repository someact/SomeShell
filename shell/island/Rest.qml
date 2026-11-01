import QtQuick
import qs.core
import qs.components

// Resting island: the clock and the day. Live things (music, recording) are
// added beside the clock in step 4, each in a smaller version.
Item {
    implicitWidth: row.implicitWidth + 36
    implicitHeight: Theme.shape.band

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Digits {
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.time
            size: Theme.font.title
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.day
            caps: true
            color: Theme.ink.mute
        }
    }
}
