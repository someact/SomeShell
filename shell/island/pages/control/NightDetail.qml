import QtQuick
import qs.core
import qs.components
import qs.services

// Night light: on or off, how warm, and the schedule.
Column {
    id: root
    spacing: 6

    // 2500 K (warm) .. 6000 K (neutral); the slider runs warm on the right
    function toSlider(k) { return (6000 - k) / 3500; }
    function fromSlider(v) { return Math.round((6000 - v * 3500) / 100) * 100; }

    BackRow {
        title: "Night light"
        Tap {
            width: 70
            height: 34
            outlined: true
            active: NightLight.on
            onClicked: NightLight.toggle()
            Txt {
                anchors.centerIn: parent
                text: NightLight.on ? "On" : "Off"
                caps: true
                color: parent.fg
            }
        }
    }

    ListRow {
        icon: "thermostat"
        title: "Warmth"
        sub: NightLight.temperature + " K"
        clickable: false
        BarSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: 300
            height: 16
            bars: 28
            value: root.toSlider(NightLight.temperature)
            onMoved: v => Config.nightLight.temperature = root.fromSlider(v)
        }
    }
    ListRow {
        icon: "schedule"
        iconFilled: Config.nightLight.auto
        title: "Turn on by itself"
        sub: Config.nightLight.from + " to " + Config.nightLight.to
        line: false
        onClicked: Config.nightLight.auto = !Config.nightLight.auto
        Tag {
            visible: Config.nightLight.auto
            text: "On"
        }
    }
}
