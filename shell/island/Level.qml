import QtQuick
import qs.core
import qs.components
import qs.services

// A level a key just changed (Ui.level): sound, mic or brightness. One row:
// icon, label, thin bars, the percent rolling. Dragging or scrolling the bars
// sets the level and keeps the row up.
Item {
    id: root

    readonly property string kind: Ui.level
    readonly property bool sound: kind === "volume"
    readonly property bool mic: kind === "mic"
    readonly property bool muted: sound ? Audio.muted : mic ? Audio.micMuted : false

    // 0..1.5 for sound, 0..1 for brightness
    readonly property real value: sound ? Audio.volume : Brightness.value / 100
    readonly property int percent: Math.round(value * 100)

    readonly property string icon: mic ? (muted ? "mic_off" : "mic")
        : sound ? (muted || percent === 0 ? "volume_off" : percent < 34 ? "volume_mute" : percent < 67 ? "volume_down" : "volume_up")
        : percent < 34 ? "brightness_low" : percent < 67 ? "brightness_medium" : "brightness_high"
    readonly property string label: mic ? (muted ? "Mic off" : "Mic on")
        : sound ? (muted ? "Muted" : "Sound")
        : "Brightness"
    readonly property string detail: sound ? Audio.name(Audio.sink) : mic ? Audio.name(Audio.source) : Brightness.label
    readonly property color tone: muted ? Theme.ink.mute : Theme.ink.fg

    implicitWidth: row.implicitWidth + 44
    implicitHeight: 56

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            filled: true
            size: 22
            color: root.muted ? Theme.ink.mute : Theme.ink.accent
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 112
            spacing: 1
            Txt {
                width: parent.width
                text: root.label
                caps: true
                color: root.tone
            }
            Txt {
                width: parent.width
                visible: text !== ""
                text: root.detail
                size: Theme.font.small
                color: Theme.ink.mute
                elide: Text.ElideRight
            }
        }

        BarSlider {
            visible: !root.mic
            opacity: root.muted ? 0.35 : 1
            anchors.verticalCenter: parent.verticalCenter
            width: 168
            height: 14
            bars: 28
            fill: root.muted ? Theme.ink.mute : Theme.ink.accent
            value: Math.min(1, root.value)
            onMoved: v => {
                Ui.keepLevel();
                if (root.sound)
                    Audio.setVolume(v);
                else
                    Brightness.set(v * 100);
            }
        }

        // Fixed width so the row never shifts as the number grows
        Item {
            visible: !root.mic
            opacity: root.muted ? 0.35 : 1
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: digits.height
            Digits {
                id: digits
                anchors.right: parent.right
                text: String(root.percent)
                size: Theme.font.title
                face: Theme.font.bold
                color: root.tone
            }
        }
    }
}
