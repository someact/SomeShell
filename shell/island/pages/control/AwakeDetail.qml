import QtQuick
import qs.core
import qs.components
import qs.services

// Keep awake: on or off, for how long this time, and Always (stays on, also
// after a reboot). No lock, no screen off, no sleep while on.
Column {
    id: root
    spacing: 6

    // Minutes; 0 = until turned off
    readonly property var times: [
        { label: "30 min", minutes: 30 },
        { label: "1 h", minutes: 60 },
        { label: "2 h", minutes: 120 },
        { label: "4 h", minutes: 240 },
        { label: "Until off", minutes: 0 }
    ]
    // The time chosen last (marks its chip while it runs)
    property int chosen: -1

    BackRow {
        title: "Keep awake"
        Tap {
            width: 70
            height: 34
            outlined: true
            active: KeepAwake.on
            onClicked: KeepAwake.toggle()
            Txt {
                anchors.centerIn: parent
                text: KeepAwake.on ? "On" : "Off"
                caps: true
                color: parent.fg
            }
        }
    }

    ListRow {
        icon: "coffee"
        iconFilled: KeepAwake.on
        title: KeepAwake.always ? "Always on" : KeepAwake.session ? "On for this session" : "Off"
        sub: KeepAwake.always ? "Stays on after a restart"
            : KeepAwake.session ? (KeepAwake.until > 0 ? KeepAwake.status + ", then off" : "Until you turn it off or restart")
            : "The screen locks and sleeps as usual"
        clickable: false
    }

    // This time: how long
    Txt {
        x: 12
        topPadding: 6
        text: "This time"
        caps: true
        color: Theme.ink.mute
    }
    Row {
        x: 12
        spacing: 6
        Repeater {
            model: root.times
            Chip {
                required property var modelData
                required property int index
                label: modelData.label
                active: KeepAwake.session && !KeepAwake.always && root.chosen === index
                onClicked: {
                    root.chosen = index;
                    KeepAwake.forMinutes(modelData.minutes);
                }
            }
        }
    }

    ListRow {
        icon: "all_inclusive"
        iconFilled: KeepAwake.always
        title: "Always"
        sub: "On all the time, also after a reboot"
        line: false
        onClicked: KeepAwake.setAlways(!KeepAwake.always)
        Tag {
            visible: KeepAwake.always
            text: "On"
        }
    }

    // Which chip is lit: the running time, read back from `until`
    Component.onCompleted: {
        if (!KeepAwake.session || KeepAwake.always)
            return;
        if (KeepAwake.until === 0) {
            chosen = times.length - 1;
            return;
        }
        // The nearest time that has not run out yet
        const left = (KeepAwake.until - Date.now()) / 60000;
        let best = -1;
        for (let i = 0; i < times.length - 1; i++)
            if (times[i].minutes >= left && (best < 0 || times[i].minutes < times[best].minutes))
                best = i;
        chosen = best;
    }
}
