import QtQuick
import qs.core

// Thick pill slider with the icon inside the track (phone control-center style).
// `value` is 0..1; `moved(v)` fires while dragging or scrolling.
Item {
    id: root

    property real value: 0
    property string icon
    property string label
    property color fillColor: Theme.accentIsland
    property color trackColor: Theme.islandRaised
    property color contentColor: Theme.fgIsland     // icon (and dimmed value) over the track
    property color contentDim: Theme.fgIslandDim
    property color contentOnFill: Theme.fgAccentIsland   // the same over the fill (a fixed tone: the island stays dark in both modes)
    property real step: 0.05
    readonly property bool dragging: mouse.pressed
    // The fill springs only after the first real width, so a slider that is
    // created (a view opening) shows its value at once instead of growing to it
    property bool settled: false
    onWidthChanged: if (width > 0 && !settled)
        Qt.callLater(() => root.settled = true)

    signal moved(real value)
    signal iconClicked
    signal rightClicked

    implicitWidth: 260
    implicitHeight: 40

    function set(v) {
        root.moved(Math.max(0, Math.min(1, v)));
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        clip: true

        Rectangle {
            id: fillBar
            height: parent.height
            radius: height / 2
            color: root.fillColor
            width: Math.max(height, parent.width * Math.min(1, root.value))
            Behavior on width {
                enabled: root.settled && !root.dragging
                Spring { preset: "snappy" }
            }
        }
    }

    Icon {
        id: iconItem
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 20
        fill: 1
        color: fillBar.width > 34 ? root.contentOnFill : root.contentColor
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        mono: true
        text: root.label !== "" ? root.label : Math.round(root.value * 100)
        color: fillBar.width > parent.width - 40 ? root.contentOnFill : root.contentDim
        font.pixelSize: Theme.font.small
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        function at(x) {
            root.set(x / width);
        }
        onPressed: event => {
            if (event.button === Qt.RightButton || event.x < 40)
                return;
            at(event.x);
        }
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (event.x < 40)
                root.iconClicked();
        }
        onPositionChanged: event => {
            if (pressed && pressedButtons & Qt.LeftButton && event.x >= 0)
                at(event.x);
        }
        onWheel: event => root.set(root.value + (event.angleDelta.y > 0 ? root.step : -root.step))
    }
}
