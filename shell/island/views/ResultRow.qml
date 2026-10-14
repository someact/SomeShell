import QtQuick
import Quickshell.Widgets
import qs.core
import qs.components

// One row in a KeyNavList: app/file icon or Material icon, title, subtitle, hint.
Item {
    id: root

    property string icon            // Material Symbols name
    property string iconSource      // image path/url (app icons)
    property string glyph           // plain text instead of an icon (emoji)
    property string thumb           // image url shown as a small cropped picture (clipboard)
    property string title
    property string subtitle
    property string hint
    property bool current: ListView.isCurrentItem
    property bool monoTitle: false
    property bool showHint: current

    signal clicked
    signal rightClicked

    width: ListView.view ? ListView.view.width : 400
    height: subtitle !== "" ? 48 : 40

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.normal
        color: mouse.containsMouse && !root.current ? Theme.islandRaised : "transparent"
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 12

        Item {
            id: lead
            width: root.thumb !== "" ? 48 : 28
            height: root.thumb !== "" ? 36 : 28
            anchors.verticalCenter: parent.verticalCenter
            ClippingRectangle {
                anchors.fill: parent
                visible: root.thumb !== ""
                radius: 6
                color: Theme.islandRaised
                Image {
                    anchors.fill: parent
                    source: root.thumb
                    sourceSize: Qt.size(96, 72)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            IconImage {
                anchors.fill: parent
                visible: root.iconSource !== ""
                source: root.iconSource
            }
            Icon {
                anchors.centerIn: parent
                visible: root.iconSource === "" && root.glyph === "" && root.thumb === ""
                name: root.icon
                size: 22
                color: root.current ? Theme.accentIsland : Theme.fgIsland
            }
            Text {
                anchors.centerIn: parent
                visible: root.glyph !== ""
                text: root.glyph
                font.pixelSize: 22
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - lead.width - 12 - (hintLabel.visible ? hintLabel.implicitWidth + 12 : 0)
            Label {
                width: parent.width
                text: root.title
                mono: root.monoTitle
                font.weight: root.current ? Theme.font.weightTitle : Theme.font.weight
            }
            Label {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }

        Label {
            id: hintLabel
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hint !== "" && root.showHint
            text: root.hint
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
