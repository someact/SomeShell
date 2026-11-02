import QtQuick
import qs.core
import qs.components

// A workspace's name for a moment after switching to it (Spaces.flash), set
// big like a poster headline: the number, then the name in spaced capitals.
Item {
    id: root

    // { slot, name }; the edit card passes its own preview
    property var f: Spaces.flash
    readonly property int size: 30

    implicitWidth: row.implicitWidth + 60
    implicitHeight: 64

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 18

        Digits {
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.f?.slot ?? 0).padStart(2, "0")
            size: root.size
            face: Theme.font.bold
            color: Theme.ink.mute
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.f?.name ?? ""
            caps: true
            size: root.size
            face: Theme.font.bold
            font.letterSpacing: root.size * 0.12
        }
    }
}
