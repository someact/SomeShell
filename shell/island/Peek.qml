import QtQuick
import qs.core
import qs.components

// The pointer is on the island: a bigger clock and a preview of what a
// click opens. Workspace designs fill this in later (step 6).
Item {
    implicitWidth: Math.max(col.implicitWidth + 44, 360)
    implicitHeight: col.implicitHeight + 30

    Column {
        id: col
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Digits {
            text: Clock.time
            size: Theme.font.headline
        }
        Txt {
            text: Clock.date
            caps: true
            color: Theme.ink.mute
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        text: "Click to open"
        caps: true
        color: Theme.ink.mute
    }
}
