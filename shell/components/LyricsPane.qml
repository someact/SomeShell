import QtQuick
import qs.core

// Lyrics as a list: synced lines scroll so the current one sits in the middle
// (it brightens and grows), plain lyrics scroll freely, anything else shows
// `message`. Pure view: the owner passes Lyrics.* in and handles `seek`.
Item {
    id: root

    property var lines: []          // [{ time, text }]
    property int index: -1
    property string plain: ""
    property bool synced: false
    property string message: ""     // shown instead of lyrics when set
    property color fg: Theme.fgIsland
    property color fgDim: Theme.fgIslandDim
    property int fontSize: Theme.font.normal
    property bool seekable: false
    property bool outline: false    // dark glyph outline, for text over busy backgrounds (a game)
    signal seek(real time)
    signal messageClicked

    clip: true

    Label {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: root.message !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.message
        color: root.fgDim
        MouseArea {
            anchors.fill: parent
            onClicked: root.messageClicked()
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: root.message === "" && root.synced
        model: visible ? root.lines : []
        boundsBehavior: Flickable.StopAtBounds
        // Keep the current line centered; follow it smoothly, but let a flick
        // look around (the next line change pulls it back)
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height / 2 - 18
        preferredHighlightEnd: height / 2 + 18
        highlightMoveDuration: 420
        highlightMoveVelocity: -1
        header: Item { height: list.height / 2 - 18 }
        footer: Item { height: list.height / 2 - 18 }
        // A new model resets currentIndex: jump straight to the line, then follow it
        onCountChanged: {
            currentIndex = root.index;
            if (root.index >= 0)
                positionViewAtIndex(root.index, ListView.Center);
            else
                positionViewAtBeginning();
        }
        Connections {
            target: root
            function onIndexChanged() {
                list.currentIndex = root.index;
            }
        }

        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: index === root.index
            width: list.width
            height: text.implicitHeight + 10

            Label {
                id: text
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: line.modelData.text === "" ? "♪" : line.modelData.text
                font.pixelSize: root.fontSize
                font.styleName: line.current ? Theme.font.styleTitle : Theme.font.style
                color: line.current ? root.fg : root.fgDim
                style: root.outline ? Text.Outline : Text.Normal
                styleColor: Qt.rgba(0, 0, 0, 0.7)
                opacity: line.current ? 1 : line.index < root.index ? (root.outline ? 0.75 : 0.55) : (root.outline ? 0.9 : 0.8)
                scale: line.current ? 1.06 : 1
                Behavior on scale {
                    Spring { preset: "smooth" }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Motion.normal }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.seekable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.seek(line.modelData.time)
            }
        }
    }

    Flickable {
        anchors.fill: parent
        visible: root.message === "" && !root.synced
        contentHeight: plainText.implicitHeight + 16
        boundsBehavior: Flickable.StopAtBounds
        Label {
            id: plainText
            y: 8
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            lineHeight: 1.25
            text: root.plain
            font.pixelSize: root.fontSize
            color: root.fgDim
        }
    }
}
