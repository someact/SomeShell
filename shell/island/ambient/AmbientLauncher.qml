import QtQuick
import qs.core
import qs.components
import qs.services

// SomeLauncher (services/Launcher.qml): a download's progress, else the game
// being played and for how long ("Waiting for Steam" while it starts).
// A click opens the launcher (see Island.qml).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    property bool live: true    // false under a fullscreen window

    readonly property var dl: Launcher.download
    readonly property var game: Launcher.playing
    Component.onCompleted: Launcher.clockWatchers++
    Component.onDestruction: Launcher.clockWatchers--

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.dl ? "download" : "stadia_controller"
            size: 18
            fill: 1
            color: Theme.accentIsland
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 220)
            elide: Text.ElideRight
            text: root.dl ? root.dl.label : root.game ? root.game.name : ""
            font.weight: Theme.font.weightTitle
        }
        // A download: a bar and its percent (and how many more run)
        Rectangle {
            visible: !!root.dl
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            height: 6
            radius: 3
            color: Theme.islandRaised
            Rectangle {
                height: parent.height
                radius: 3
                color: Theme.accentIsland
                width: parent.width * (root.dl ? Math.min(1, root.dl.fraction) : 0)
                Behavior on width {
                    Spring { preset: "snappy" }
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            mono: !!root.dl || (!!root.game && root.game.state === "running")
            color: Theme.fgIslandDim
            text: {
                if (root.dl)
                    return Math.round(root.dl.fraction * 100) + "%" + (root.dl.count > 1 ? ` +${root.dl.count - 1}` : "");
                if (!root.game)
                    return "";
                if (root.game.state !== "running")
                    return root.game.step === "steam" ? "Waiting for Steam" : "Starting";
                return Launcher.duration(Launcher.now - root.game.since);
            }
        }
    }
}
