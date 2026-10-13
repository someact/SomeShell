import QtQuick
import qs.core
import qs.components
import qs.services

// Control → right-click WARP: on/off, what the client says, and the mode.
Column {
    id: root

    spacing: 10

    // "NetworkHealthy" → "network healthy"
    readonly property string reason: Warp.reason.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase()

    Item {
        width: parent.width
        height: 34
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            Label {
                text: "Cloudflare WARP"
                font.weight: Theme.font.weightTitle
            }
            Label {
                text: Warp.connected ? "Connected" + (root.reason !== "" ? " · " + root.reason : "") : Warp.summary
                color: Warp.connected ? Theme.accentIsland : Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }
        PillSwitch {
            visible: Warp.registered
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: Warp.connected || Warp.connecting
            onToggled: Warp.toggle()
        }
    }

    Label {
        visible: !Warp.registered
        x: 12
        width: parent.width - 24
        wrapMode: Text.Wrap
        text: Warp.service ? "This device is not registered with WARP yet. Run  warp-cli registration new  in a terminal once." : "The WARP service is not running. Start it with  systemctl enable --now warp-svc"
        color: Theme.fgIslandDim
        font.pixelSize: Theme.font.small
    }

    Column {
        visible: Warp.registered
        width: parent.width
        spacing: 2
        Label {
            x: 12
            height: 24
            text: "Mode"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Repeater {
            model: Warp.modes
            DetailRow {
                required property var modelData
                icon: modelData.icon
                title: modelData.name
                subtitle: modelData.note
                current: Warp.mode === modelData.id
                onClicked: Warp.setMode(modelData.id)
            }
        }
    }
}
