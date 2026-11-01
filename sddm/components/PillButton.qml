import QtQuick
import QtQuick.Controls

Button {
    id: root
    property string symbol: ""
    property string symbolFont: "Material Symbols Rounded"
    property bool spinning: false
    property bool armed: false
    property bool reducedMotion: false
    implicitWidth: symbol === "" ? Math.max(64, label.implicitWidth + 28) : 40
    implicitHeight: 40
    hoverEnabled: true
    font.family: "Mitr"
    font.pixelSize: 13
    Accessible.name: text
    background: Rectangle {
        radius: height / 2
        color: root.armed ? "#55ffb4ab" : root.down ? "#66ffffff" : root.hovered ? "#44ffffff" : "#24ffffff"
        border.width: 1
        border.color: root.activeFocus ? "#bbffffff" : "#30ffffff"
        Behavior on color { enabled: !root.reducedMotion; ColorAnimation { duration: 120 } }
    }
    contentItem: Text {
        id: label
        text: root.symbol || root.text
        color: root.enabled ? "white" : "#77ffffff"
        font.family: root.symbol ? root.symbolFont : root.font.family
        font.pixelSize: root.symbol ? 20 : root.font.pixelSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        RotationAnimation on rotation { running: root.spinning; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    }
    ToolTip.visible: hovered && symbol !== ""
    ToolTip.text: text
    ToolTip.delay: 700
}
