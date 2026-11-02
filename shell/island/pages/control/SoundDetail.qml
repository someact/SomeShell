import QtQuick
import qs.core
import qs.components
import qs.services

// Sound: where sound goes (click a device to use it), the microphone, and
// a volume for every app that is playing.
Column {
    id: root
    spacing: 6

    BackRow {
        title: "Sound"
        Tap {
            id: micTap
            width: 96
            height: 34
            outlined: true
            active: !Audio.micMuted
            onClicked: Audio.toggleMic()
            Row {
                anchors.centerIn: parent
                spacing: 6
                Icon {
                    name: Audio.micMuted ? "mic_off" : "mic"
                    size: 18
                    filled: !Audio.micMuted
                    color: micTap.fg
                }
                Txt {
                    text: "Mic"
                    caps: true
                    color: micTap.fg
                }
            }
        }
    }

    Txt {
        text: "Output"
        caps: true
        color: Theme.ink.mute
        topPadding: 4
    }
    Repeater {
        model: Audio.outputs
        ListRow {
            required property var modelData
            readonly property bool current: modelData === Audio.sink
            icon: /headphone|headset/i.test(Audio.name(modelData)) ? "headphones" : /hdmi|displayport/i.test(Audio.name(modelData)) ? "tv" : "speaker"
            iconFilled: current
            title: Audio.name(modelData)
            onClicked: Audio.setOutput(modelData)
            Tag {
                visible: parent.parent.current
                text: "In use"
            }
        }
    }

    Txt {
        text: Audio.streams.length ? "Apps" : "No app is playing sound"
        caps: true
        color: Theme.ink.mute
        topPadding: 8
    }
    Repeater {
        model: Audio.streams
        ListRow {
            id: app
            required property var modelData
            icon: "graphic_eq"
            title: Audio.appName(modelData)
            clickable: false
            BarSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                height: 14
                bars: 24
                value: Math.min(1, app.modelData.audio?.volume ?? 0)
                onMoved: v => { if (app.modelData.audio) app.modelData.audio.volume = v; }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round((app.modelData.audio?.volume ?? 0) * 100)
                caps: true
                color: Theme.ink.mute
            }
        }
    }
}
