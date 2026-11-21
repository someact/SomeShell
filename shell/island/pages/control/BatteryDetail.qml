import QtQuick
import qs.core
import qs.components
import qs.services

// Battery: the power mode (power-profiles-daemon) and the charge limit
// (stop at, start again at), whichever way this machine can do it.
Column {
    id: root
    spacing: 6

    readonly property var stops: [60, 70, 80, 90]
    // Below the stop; never under 20
    readonly property var starts: [5, 10, 20, 30].map(d => ChargeLimit.limit - d).filter(v => v >= 20)

    BackRow {
        title: "Battery"
        Digits {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.percent + "%"
            size: 24
            color: Theme.ink.fg
        }
    }

    ListRow {
        icon: Battery.icon
        iconFilled: true
        title: Battery.held ? "Plugged in, not charging"
            : Battery.full ? "Full"
            : Battery.charging ? "Charging" : "On battery"
        sub: Battery.held ? "Held by the charge limit until " + ChargeLimit.start + "%"
            : Battery.minutes > 0 ? (Math.floor(Battery.minutes / 60) > 0 ? Math.floor(Battery.minutes / 60) + " h " : "") + Battery.minutes % 60 + " min " + (Battery.charging ? "to full" : "left")
            : ""
        clickable: false
    }

    // Mode
    Txt {
        x: 12
        topPadding: 6
        text: "Mode"
        caps: true
        color: Theme.ink.mute
    }
    Row {
        x: 12
        spacing: 6
        visible: PowerMode.available
        Repeater {
            model: PowerMode.modes
            Chip {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                active: PowerMode.current.id === modelData.id
                onClicked: PowerMode.set(modelData.id)
            }
        }
    }
    Txt {
        x: 12
        visible: !PowerMode.available
        text: "No power modes here (power-profiles-daemon is not running)"
        color: Theme.ink.mute
    }

    // Charge limit
    Txt {
        x: 12
        topPadding: 10
        text: "Charge limit"
        caps: true
        color: Theme.ink.mute
    }

    // Thresholds (kernel) or the shell's own hold (software)
    Column {
        visible: ChargeLimit.method === "kernel" || ChargeLimit.method === "software"
        width: parent.width
        spacing: 6

        Txt {
            x: 12
            text: "Stop at"
            color: Theme.ink.fg
        }
        Row {
            x: 12
            spacing: 6
            Repeater {
                model: root.stops
                Chip {
                    required property int modelData
                    label: modelData + "%"
                    active: ChargeLimit.limit === modelData
                    onClicked: ChargeLimit.set(modelData)
                }
            }
            Chip {
                label: "Off"
                active: !ChargeLimit.on
                onClicked: ChargeLimit.set(100)
            }
        }

        Txt {
            x: 12
            topPadding: 4
            visible: ChargeLimit.on && ChargeLimit.hasStart
            text: "Start again at"
            color: Theme.ink.fg
        }
        Row {
            x: 12
            spacing: 6
            visible: ChargeLimit.on && ChargeLimit.hasStart
            Repeater {
                model: root.starts
                Chip {
                    required property int modelData
                    label: modelData + "%"
                    active: ChargeLimit.start === modelData
                    onClicked: ChargeLimit.set(ChargeLimit.limit, modelData)
                }
            }
        }
        Txt {
            x: 12
            width: parent.width - 24
            topPadding: 4
            visible: ChargeLimit.method === "software"
            text: "Set by the shell: it stops the charger while it runs."
            wrapMode: Text.WordWrap
            color: Theme.ink.mute
        }
    }

    // Lenovo: the laptop picks the level
    ListRow {
        visible: ChargeLimit.method === "conservation"
        icon: "battery_saver"
        iconFilled: ChargeLimit.on
        title: "Conservation mode"
        sub: "Stops charging at a level the laptop sets (about 60–80%)"
        line: false
        onClicked: ChargeLimit.setConservation(!ChargeLimit.on)
        Tag {
            visible: ChargeLimit.on
            text: "On"
        }
    }

    ListRow {
        visible: ChargeLimit.method === "none"
        icon: "block"
        title: "Not supported on this machine"
        sub: "No charge thresholds or charger control found"
        clickable: false
        line: false
    }
    ListRow {
        visible: ChargeLimit.denied
        icon: "lock"
        title: "No permission to change it"
        sub: "Run once: sudo scripts/charge-access.sh"
        clickable: false
        line: false
    }
}
