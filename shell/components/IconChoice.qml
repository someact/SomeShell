import QtQuick
import qs.core

// A few choices as a row of icons (or short text), the chosen one filled with
// ink; the name of the chosen or hovered one is written left of the row, so the
// icons are learnt as you go.
//   IconChoice {
//       options: [{ value: "light", icon: "light_mode", label: "Light" }, ...]
//       value: Config.theme.mode
//       onPicked: v => Config.theme.mode = v
//   }
// An option can have `text` instead of `icon`, and `enabled: false`.
Row {
    id: root

    property var options: []
    property var value
    property bool showLabel: true
    readonly property var c: Theme.paper
    property int hovered: -1
    signal picked(var value)

    spacing: 12
    // The label sits left of the icons, so a longer name never moves them
    layoutDirection: Qt.RightToLeft

    Rectangle {
        implicitWidth: segs.implicitWidth + 6
        implicitHeight: 38
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.c.line

        Row {
            id: segs
            x: 3
            y: 3
            spacing: 2
            Repeater {
                model: root.options
                Rectangle {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.value === modelData.value
                    readonly property bool usable: modelData.enabled !== false
                    width: modelData.text ? Math.max(40, label.implicitWidth + 20) : 40
                    height: 32
                    radius: 9
                    opacity: usable ? 1 : 0.35
                    color: chosen ? root.c.fg : segMouse.containsMouse && usable ? root.c.raised : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Icon {
                        visible: !seg.modelData.text
                        anchors.centerIn: parent
                        name: seg.modelData.icon ?? ""
                        size: 20
                        filled: seg.chosen
                        color: seg.chosen ? root.c.bg : root.c.fg
                    }
                    Txt {
                        id: label
                        visible: !!seg.modelData.text
                        anchors.centerIn: parent
                        text: seg.modelData.text ?? ""
                        size: Theme.font.small
                        face: Theme.font.medium
                        color: seg.chosen ? root.c.bg : root.c.fg
                    }
                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: seg.usable
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.hovered = containsMouse ? seg.index : (root.hovered === seg.index ? -1 : root.hovered)
                        onClicked: root.picked(seg.modelData.value)
                    }
                }
            }
        }
    }

    Txt {
        visible: root.showLabel
        anchors.verticalCenter: parent.verticalCenter
        caps: true
        color: root.hovered >= 0 ? root.c.fg : root.c.mute
        text: {
            const o = root.hovered >= 0 ? root.options[root.hovered] : root.options.find(o => o.value === root.value);
            return o ? (o.label ?? "") + (o.enabled === false ? " · later" : "") : "";
        }
    }
}
