import QtQuick
import qs.core
import qs.components

// Segmented buttons. model: [{ value, label, icon? }]; `picked(value)` on click.
Row {
    id: choice

    property var model: []
    property var value
    signal picked(var value)

    spacing: 2

    Repeater {
        model: choice.model
        PressButton {
            id: seg
            required property var modelData
            required property int index
            readonly property bool on: choice.value === modelData.value
            width: label.implicitWidth + (modelData.icon ? 46 : 28)
            height: 34
            color: "transparent"
            hoverColor: "transparent"
            onClicked: choice.picked(modelData.value)

            // Outer ends rounded, inner edges square
            Rectangle {
                anchors.fill: parent
                topLeftRadius: seg.index === 0 ? 17 : 4
                bottomLeftRadius: seg.index === 0 ? 17 : 4
                topRightRadius: seg.index === choice.model.length - 1 ? 17 : 4
                bottomRightRadius: seg.index === choice.model.length - 1 ? 17 : 4
                color: seg.on ? Theme.secondaryContainer : seg.hovered ? Theme.surfaceHighest : Theme.surfaceHigh
            }
            Row {
                anchors.centerIn: parent
                spacing: 6
                Icon {
                    visible: !!seg.modelData.icon
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.modelData.icon ?? ""
                    size: 18
                    fill: 1
                    color: seg.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                }
                SText {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    color: seg.on ? Theme.fgSecondaryContainer : Theme.fgSurface
                    font.styleName: seg.on ? Theme.font.styleTitle : Theme.font.style
                }
            }
        }
    }
}
