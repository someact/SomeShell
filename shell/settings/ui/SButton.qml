import QtQuick
import qs.core
import qs.components

// Text button. kind: "filled" | "tonal" | "text"
PressButton {
    id: b

    property string text
    property string icon
    property string kind: "tonal"
    property bool danger: false

    readonly property color fg: kind === "filled" ? Theme.fgPrimary : danger ? Theme.error : kind === "tonal" ? Theme.fgSecondaryContainer : Theme.primary

    implicitWidth: content.implicitWidth + 32
    implicitHeight: 36
    radius: 18
    color: kind === "filled" ? Theme.primary : kind === "tonal" ? Theme.secondaryContainer : "transparent"
    hoverColor: kind === "filled" ? Qt.lighter(Theme.primary, 1.1) : kind === "tonal" ? Qt.lighter(Theme.secondaryContainer, 1.15) : Theme.surfaceHigh

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: b.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: b.icon
            size: 18
            color: b.fg
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: b.text
            color: b.fg
            font.styleName: Theme.font.styleTitle
        }
    }
}
