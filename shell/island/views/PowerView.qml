import QtQuick
import qs.core
import qs.components
import qs.services

// Session actions. Destructive ones need a hold (mouse) or a second Enter.
FocusScope {
    id: root

    implicitWidth: actions.length * 84 + (actions.length - 1) * 10
    implicitHeight: 100

    property int selected: 0
    property int armed: -1
    property int firing: -1
    property bool holdDone: false
    readonly property int holdTime: 650
    readonly property var actions: [
        { icon: "lock", title: "Lock", confirm: false, run: () => Session.lock() },
        { icon: "bedtime", title: "Suspend", confirm: false, run: () => Session.suspend() },
        { icon: "logout", title: "Log out", confirm: true, run: () => Session.logout() },
        { icon: "restart_alt", title: "Restart", confirm: true, run: () => Session.reboot() },
        { icon: "power_settings_new", title: "Shut down", confirm: true, run: () => Session.poweroff() }
    ]

    function trigger(i) {
        if (firing >= 0)
            return;
        const a = actions[i];
        if (a.confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        armed = -1;
        if (!a.confirm) {
            UiState.close();
            a.run();
            return;
        }
        // Confirmed: a short beat on the solid button before the island closes
        firing = i;
        fire.restart();
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selected = (selected - 1 + actions.length) % actions.length;
            armed = -1;
            return true;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selected = (selected + 1) % actions.length;
            armed = -1;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            trigger(selected);
            return true;
        }
        return UiState.navKey(event);
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = -1
    }

    Timer {
        id: fire
        interval: 240
        onTriggered: {
            const a = root.actions[root.firing];
            UiState.close();
            a.run();
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10
        Repeater {
            model: root.actions
            PressButton {
                id: btn
                required property var modelData
                required property int index
                width: 84
                height: 96
                radius: Theme.radius.large
                color: Theme.islandRaised
                highlighted: root.selected === index
                activeColor: Theme.error
                active: root.armed === index || root.firing === index
                progress: hold

                // Hold to confirm: the fill rises while pressed and drains on release
                property real hold: 0
                onPressedChanged: {
                    if (!modelData.confirm || root.firing >= 0 || root.armed === index)
                        return;
                    if (pressed) {
                        drain.stop();
                        rise.duration = Math.max(1, (1 - hold) * root.holdTime);
                        rise.restart();
                    } else if (hold < 1) {
                        rise.stop();
                        drain.duration = Math.max(1, hold * 360);
                        drain.restart();
                    }
                }
                NumberAnimation {
                    id: rise
                    target: btn
                    property: "hold"
                    to: 1
                    easing.type: Easing.InOutSine
                    onFinished: if (btn.pressed) {
                        root.holdDone = true;
                        root.armed = btn.index;
                        root.trigger(btn.index);
                    }
                }
                NumberAnimation {
                    id: drain
                    target: btn
                    property: "hold"
                    to: 0
                    easing.type: Easing.OutCubic
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: btn.modelData.icon
                        size: 28
                        // Swells with the fill, pops when the action fires
                        scale: root.firing === btn.index ? 1.18 : 1 + 0.1 * btn.hold
                        Behavior on scale {
                            Spring { preset: "bouncy" }
                        }
                        fill: 1
                        color: btn.active ? Theme.fgPrimary : Theme.fgIsland
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.armed === btn.index ? "Again" : btn.modelData.title
                        font.pixelSize: Theme.font.small
                        color: btn.active ? Theme.fgPrimary : Theme.fgIsland
                    }
                }

                // A finished hold already ran the action; a plain click arms it
                onClicked: {
                    if (!root.holdDone)
                        root.trigger(index);
                    root.holdDone = false;
                }
            }
        }
    }
}
