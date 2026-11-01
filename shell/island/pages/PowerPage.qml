import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.components

// 07 Power. Hold a button to confirm: it fills with the accent like ink, and
// letting go early cancels. SOMESHELL_DRY_POWER=1 only says what would run
// (for testing).
Item {
    id: root

    readonly property bool dry: Quickshell.env("SOMESHELL_DRY_POWER") === "1"

    readonly property var actions: [
        { name: "Lock", icon: "lock", hint: "Super+L", command: ["loginctl", "lock-session"] },
        { name: "Sleep", icon: "bedtime", hint: "Super+Shift+L", command: ["systemctl", "suspend"] },
        { name: "Log out", icon: "logout", hint: "", dispatch: "hl.dsp.exit()" },
        { name: "Restart", icon: "restart_alt", hint: "", command: ["systemctl", "reboot"] },
        { name: "Shut down", icon: "power_settings_new", hint: "", command: ["systemctl", "poweroff"] }
    ]

    function run(a) {
        Ui.close();
        if (dry) {
            Ui.showAlert(a.name, "Would run: " + (a.command ? a.command.join(" ") : a.dispatch), "Power (test)", a.icon);
            return;
        }
        if (a.dispatch)
            Hyprland.dispatch(a.dispatch);
        else
            Quickshell.execDetached(a.command);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 16

        Row {
            id: row
            spacing: 10

            Repeater {
                model: root.actions

                Item {
                    id: button
                    required property var modelData
                    property real progress: 0
                    readonly property bool holding: mouse.pressed
                    width: 132
                    height: 168

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: mouse.containsMouse ? Theme.ink.raised : "transparent"
                        border.width: 1
                        border.color: Theme.ink.line
                        clip: true

                        // The fill rises from the bottom while held, inside the
                        // rounded shape (clip only cuts square corners)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * button.progress
                            color: Theme.ink.accent
                            bottomLeftRadius: Math.min(parent.radius, height)
                            bottomRightRadius: Math.min(parent.radius, height)
                            topLeftRadius: Math.max(0, parent.radius - (parent.height - height))
                            topRightRadius: Math.max(0, parent.radius - (parent.height - height))
                        }
                    }

                    Icon {
                        x: 18
                        y: 18
                        name: button.modelData.icon
                        size: 30
                        filled: button.progress > 0.5
                        color: button.progress > 0.75 ? Theme.ink.onAccent : Theme.ink.fg
                    }
                    Column {
                        x: 18
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        spacing: 2
                        Txt {
                            text: button.modelData.name
                            size: 18
                            face: Theme.font.medium
                            color: button.progress > 0.25 ? Theme.ink.onAccent : Theme.ink.fg
                        }
                        Txt {
                            text: button.holding ? "Keep holding" : (button.modelData.hint || "Hold")
                            caps: true
                            color: button.progress > 0.1 ? Theme.ink.onAccent : Theme.ink.mute
                        }
                    }

                    NumberAnimation {
                        id: fill
                        target: button
                        property: "progress"
                        to: 1
                        duration: 800
                        onFinished: if (button.progress >= 1) root.run(button.modelData)
                    }
                    NumberAnimation {
                        id: drain
                        target: button
                        property: "progress"
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            drain.stop();
                            fill.duration = 800 * (1 - button.progress);
                            fill.restart();
                        }
                        onReleased: {
                            if (button.progress < 1) {
                                fill.stop();
                                drain.restart();
                            }
                        }
                    }
                }
            }
        }

        Txt {
            text: root.dry ? "Test mode: nothing runs" : "Hold to confirm, let go to cancel"
            caps: true
            color: Theme.ink.mute
        }
    }
}
