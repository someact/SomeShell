import QtQuick
import qs.core
import qs.components
import qs.services

// SomeLauncher (services/Launcher.qml): the game being played with this
// session and its total playtime, then the recently played games. A click on
// one opens its page in the launcher.
OverlayCard {
    id: root
    icon: "stadia_controller"
    title: "Games"
    implicitWidth: 300

    readonly property var game: Launcher.playing
    // The session time ticks once a minute while this card shows
    Component.onCompleted: Launcher.clockWatchers++
    Component.onDestruction: Launcher.clockWatchers--

    Column {
        width: parent.width
        spacing: 10

        Label {
            visible: !Launcher.available
            width: parent.width
            wrapMode: Text.Wrap
            text: "SomeLauncher is not running"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }

        // Now playing
        Rectangle {
            visible: root.game !== null
            width: parent.width
            height: now.implicitHeight + 20
            radius: Theme.radius.normal
            color: Theme.islandRaised
            Column {
                id: now
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 2
                Label {
                    text: root.game && root.game.state !== "running" ? (root.game.step === "steam" ? "Waiting for Steam" : "Starting") : "Playing"
                    color: root.accent
                    font.pixelSize: Theme.font.small
                    font.weight: Theme.font.weightTitle
                }
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.game ? root.game.name : ""
                    font.pixelSize: Theme.font.large
                    font.weight: Theme.font.weightTitle
                }
                Label {
                    visible: !!root.game && root.game.state === "running"
                    mono: true
                    color: Theme.fgIslandDim
                    font.pixelSize: Theme.font.small
                    text: root.game ? `${Launcher.duration(Launcher.now - root.game.since)} this session · ${Launcher.hours(root.game.playtime + Math.max(0, Launcher.now - root.game.since))} in all` : ""
                }
            }
        }

        // Recently played
        Label {
            visible: Launcher.available && Launcher.recent.length > 0
            text: "Recent"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
        Repeater {
            model: Launcher.available ? Launcher.recent : []
            PressButton {
                id: row
                required property var modelData
                width: parent.width
                height: 40
                radius: Theme.radius.small
                onClicked: Launcher.openGame(modelData.id)
                Label {
                    x: 10
                    width: parent.width - playtime.implicitWidth - 30
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.name
                }
                Label {
                    id: playtime
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    mono: true
                    color: Theme.fgIslandDim
                    font.pixelSize: Theme.font.small
                    text: row.modelData.playtime ? Launcher.hours(row.modelData.playtime) : ""
                }
            }
        }
        Label {
            visible: Launcher.available && Launcher.recent.length === 0 && root.game === null
            text: "Nothing played yet"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }
}
