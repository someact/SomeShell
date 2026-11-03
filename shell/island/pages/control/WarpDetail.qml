import QtQuick
import qs.core
import qs.components
import qs.services

// WARP: on or off, the status, and the mode (a click switches it; the
// tunnel reconnects by itself in the new mode).
Column {
    id: root
    spacing: 6
    Component.onCompleted: Warp.refresh()

    BackRow {
        title: "WARP"
        Tap {
            width: 70
            height: 34
            outlined: true
            active: Warp.on
            enabled: Warp.installed && Warp.status !== ""
            onClicked: Warp.toggle()
            Txt {
                anchors.centerIn: parent
                text: Warp.on ? "On" : "Off"
                caps: true
                color: parent.fg
            }
        }
    }

    ListRow {
        icon: Warp.connected ? "vpn_lock" : "vpn_key_off"
        iconFilled: Warp.connected
        title: Warp.status === "" ? "The WARP service is not running" : Warp.status
        sub: Warp.status === "" ? "systemctl enable --now warp-svc"
            : Warp.reason !== "" ? Warp.reason
            : Warp.mode === "proxy" ? "SOCKS5 on 127.0.0.1:" + Warp.proxyPort
            : Warp.modeInfo(Warp.mode).sub
        clickable: false
    }

    Txt {
        topPadding: 8
        bottomPadding: 2
        leftPadding: 4
        text: "Mode"
        caps: true
        color: Theme.ink.mute
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: 6

        Repeater {
            model: Warp.modes

            ListRow {
                required property var modelData
                width: (root.width - 6) / 2
                icon: modelData.icon
                iconFilled: Warp.mode === modelData.id
                title: modelData.label
                sub: modelData.id === "proxy" ? "SOCKS5 on port " + Warp.proxyPort : modelData.sub
                onClicked: Warp.setMode(modelData.id)
                Tag {
                    visible: Warp.mode === modelData.id
                    text: "In use"
                }
            }
        }
    }
}
