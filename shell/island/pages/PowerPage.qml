import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.components

// 07 Power. Hold a button to confirm: a line draws itself around its edge,
// then the button inverts and the action runs; letting go early cancels. SOMESHELL_DRY_POWER=1 only says what would run
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
                    // 0..1 while held; at 1 the button inverts and the action runs
                    property real progress: 0
                    property bool done: false
                    readonly property bool holding: mouse.pressed && !done
                    readonly property color ink: done ? Theme.ink.bg : Theme.ink.fg
                    width: 132
                    height: 168

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: button.done ? Theme.ink.fg : mouse.containsMouse ? Theme.ink.raised : "transparent"
                        border.width: 1
                        border.color: button.done ? Theme.ink.fg : Theme.ink.line
                    }

                    // The line drawing the edge: from the top left, clockwise,
                    // as far as the hold has come (a dash as long as the progress)
                    Shape {
                        id: edge
                        anchors.fill: parent
                        visible: button.progress > 0.002 && !button.done
                        readonly property real sw: 2
                        readonly property real o: sw / 2
                        readonly property real w: width - sw
                        readonly property real h: height - sw
                        readonly property real r: 20 - o
                        readonly property real perimeter: 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Theme.ink.fg
                            strokeWidth: edge.sw
                            capStyle: ShapePath.FlatCap
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [edge.perimeter * button.progress / edge.sw, edge.perimeter / edge.sw + 1]
                            startX: edge.o + edge.r
                            startY: edge.o
                            PathLine { x: edge.o + edge.w - edge.r; y: edge.o }
                            PathArc { x: edge.o + edge.w; y: edge.o + edge.r; radiusX: edge.r; radiusY: edge.r }
                            PathLine { x: edge.o + edge.w; y: edge.o + edge.h - edge.r }
                            PathArc { x: edge.o + edge.w - edge.r; y: edge.o + edge.h; radiusX: edge.r; radiusY: edge.r }
                            PathLine { x: edge.o + edge.r; y: edge.o + edge.h }
                            PathArc { x: edge.o; y: edge.o + edge.h - edge.r; radiusX: edge.r; radiusY: edge.r }
                            PathLine { x: edge.o; y: edge.o + edge.r }
                            PathArc { x: edge.o + edge.r; y: edge.o; radiusX: edge.r; radiusY: edge.r }
                        }
                    }

                    // Corner marks close in while held: from just outside the
                    // card onto its corners (never over the caption)
                    CornerMarks {
                        anchors.fill: parent
                        visible: button.progress > 0 && !button.done
                        inset: -10 + 14 * button.progress
                        opacity: Math.min(1, button.progress * 4)
                        color: Theme.ink.fg
                    }

                    Icon {
                        x: 18
                        y: 18
                        name: button.modelData.icon
                        size: 30
                        filled: button.progress > 0 || button.done
                        color: button.ink
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
                            color: button.ink
                        }
                        Row {
                            spacing: 6
                            height: caption.implicitHeight
                            Txt {
                                id: caption
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.done ? "Going" : button.holding ? "Release ·" : (button.modelData.hint || "Hold")
                                caps: true
                                color: button.done ? Theme.ink.bg : button.holding ? Theme.ink.fg : Theme.ink.mute
                            }
                            // 3, 2, 1 while held (rolling)
                            Digits {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: button.holding
                                text: String(Math.max(1, Math.ceil(3 * (1 - button.progress))))
                                size: Theme.font.caption
                                face: Theme.font.medium
                                color: Theme.ink.fg
                            }
                        }
                    }

                    NumberAnimation {
                        id: fill
                        target: button
                        property: "progress"
                        to: 1
                        duration: 800
                        onFinished: if (button.progress >= 1) {
                            // The whole button inverts in one snap, then the action runs
                            button.done = true;
                            go.restart();
                        }
                    }
                    NumberAnimation {
                        id: drain
                        target: button
                        property: "progress"
                        to: 0
                        duration: Motion.fast
                        easing.type: Easing.OutCubic
                    }
                    Timer {
                        id: go
                        interval: 140
                        onTriggered: root.run(button.modelData)
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            if (button.done)
                                return;
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
