import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// What one screen shows while locked: blurred wallpaper, a large clock, the
// password field, now playing and power buttons. Every screen gets one; they
// share the typed text through services/Lock.qml, and only the focused one
// has keyboard focus.
//
// Hyprland keeps drawing the desktop under the lock (misc:session_lock_xray), so
// fading this in and out reveals the real desktop instead of a black frame.
Item {
    id: root

    property bool hasFocus: true
    readonly property bool leaving: Lock.unlocking
    property real shown: 0          // 0 → 1 on entry, back to 0 on unlock

    Component.onCompleted: {
        shown = 1;
        field.forceActiveFocus();
    }
    onLeavingChanged: if (leaving) shown = 0

    Behavior on shown {
        enabled: !Motion.reduced
        NumberAnimation {
            duration: root.leaving ? 340 : 420
            easing.type: root.leaving ? Easing.InCubic : Easing.OutCubic
        }
    }

    Connections {
        target: Lock
        function onRefocus() {
            field.forceActiveFocus();
        }
        function onFailed() {
            shake.restart();
        }
        // A wrong password clears the text while PAM is still finishing: keep
        // the shapes through the shake, then let them all spring out together
        function onTextChanged() {
            if (Lock.text === "" && Lock.busy)
                clearAfterShake.restart();
            else if (!clearAfterShake.running)
                root.dotCount = Math.min(Lock.text.length, 22);
        }
    }
    property int dotCount: 0
    Timer {
        id: clearAfterShake
        interval: Motion.reduced ? 0 : 360
        onTriggered: root.dotCount = Math.min(Lock.text.length, 22)
    }
    // A shuffled set of shapes per lock, so the password reads as a playful string
    readonly property var passShapes: {
        const s = ["cookie4Sided", "clover4Leaf", "sunny", "cookie7Sided", "heart", "softBurst", "pentagon", "clover8Leaf", "gem", "cookie12Sided", "flower", "puffy", "triangle", "diamond"];
        for (let i = s.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [s[i], s[j]] = [s[j], s[i]];
        }
        return s;
    }

    // ── Backdrop ────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: root.shown

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
        }
        Image {
            // Sharp wallpaper, only until the blurred one is ready
            anchors.fill: parent
            visible: blurred.status !== Image.Ready
            source: Wallpaper.path === "" ? "" : Paths.url(Wallpaper.isVideo ? Paths.videoFrame : Wallpaper.path)
            sourceSize: Qt.size(root.width, root.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
        Image {
            id: blurred
            anchors.fill: parent
            source: Config.lock.blur && Lock.backdropReady ? Paths.url(Paths.lockBlur) : ""
            sourceSize: Qt.size(root.width, root.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }
        // Darken toward the bottom so the field and controls read on any wallpaper
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.28) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }
    }

    // Clicking anywhere gives the keyboard back to the field
    MouseArea {
        anchors.fill: parent
        onClicked: field.forceActiveFocus()
    }

    // ── Clock ───────────────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.12) - (1 - root.shown) * 40
        opacity: root.shown
        spacing: -6

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.pixelSize: 24
            font.styleName: "Medium"
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, Config.clock.format)
            color: "white"
            font.pixelSize: Math.round(Math.min(root.height * 0.17, 180))
            font.styleName: Theme.font.styleTitle
            font.features: ({ "tnum": 1 })
            style: Text.Normal
        }
    }

    // ── Password ────────────────────────────────────────────────────────────
    Column {
        id: auth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.62) + (1 - root.shown) * 30
        opacity: root.shown
        spacing: 14

        // Avatar: ~/.face if there is one, else the initial
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            radius: 36
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Label {
                anchors.centerIn: parent
                visible: Lock.face === ""
                text: Lock.userName.charAt(0).toUpperCase()
                color: "white"
                font.pixelSize: 30
                font.styleName: Theme.font.styleTitle
            }
            Image {
                anchors.fill: parent
                visible: Lock.face !== ""
                source: Lock.face === "" ? "" : Paths.url(Lock.face)
                sourceSize: Qt.size(144, 144)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lock.userName
            color: "white"
            font.pixelSize: Theme.font.large
            font.styleName: Theme.font.styleTitle
        }

        // The field: a glass pill with dots for typed characters
        Item {
            id: fieldBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46

            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 5; duration: 60 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.2 : 0.14)
                border.width: 1
                border.color: Lock.error !== "" ? Theme.error : Qt.rgba(1, 1, 1, field.activeFocus ? 0.35 : 0.18)
                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
            }

            TextInput {
                id: field
                // Invisible: the dots below draw the text
                anchors.fill: parent
                opacity: 0
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                text: Lock.text
                onTextChanged: if (Lock.text !== text) Lock.text = text
                focus: root.hasFocus
                enabled: !Lock.busy && !Lock.unlocking
                onAccepted: Lock.tryUnlock()
                Keys.onPressed: e => {
                    // Caps Lock: letters arriving in the other case than Shift asks for
                    if (e.text.length === 1 && e.text.toLowerCase() !== e.text.toUpperCase()) {
                        const upper = e.text === e.text.toUpperCase();
                        root.capsLock = upper !== ((e.modifiers & Qt.ShiftModifier) !== 0);
                    }
                    if (e.key === Qt.Key_Escape) {
                        if (Lock.preview && Lock.text === "")
                            Lock.finish();
                        Lock.text = "";
                        e.accepted = true;
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                // Fades in as the last shapes spring out
                opacity: root.dotCount === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Motion.normal }
                }
                text: Lock.busy ? "Checking…" : Lock.preview ? "Preview · Esc closes" : "Enter password"
                color: Qt.rgba(1, 1, 1, 0.6)
            }

            // Typed characters as Material shapes (ii's lock look). A fixed pool of
            // 22: typing only changes which are shown, so only the added or deleted
            // shape animates, and the row slides to stay centered.
            Row {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -12
                Repeater {
                    model: 22
                    Item {
                        id: dot
                        required property int index
                        readonly property bool on: index < root.dotCount
                        width: on ? 17 : 0
                        height: 17
                        Behavior on width {
                            Spring { preset: "snappy" }
                        }
                        MaterialShape {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            shape: root.passShapes[dot.index % root.passShapes.length]
                            color: "white"
                            opacity: Lock.busy ? 0.5 : 1
                            scale: dot.on ? 1 : 0
                            rotation: dot.on ? 0 : -60
                            Behavior on scale {
                                Spring { preset: "bouncy" }
                            }
                            Behavior on rotation {
                                Spring { preset: "smooth" }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: Motion.fast }
                            }
                        }
                    }
                }
            }

            // Submit / busy
            PressButton {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                visible: Lock.text !== "" || Lock.busy
                color: Qt.rgba(1, 1, 1, 0.2)
                hoverColor: Qt.rgba(1, 1, 1, 0.3)
                onClicked: Lock.tryUnlock()
                Icon {
                    anchors.centerIn: parent
                    name: Lock.busy ? "progress_activity" : "arrow_forward"
                    color: "white"
                    size: 20
                    RotationAnimation on rotation {
                        running: Lock.busy
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }
        }

        // Status line: error, caps lock and the keyboard layout (a Thai password
        // typed on the US layout fails, so the layout is always visible)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            height: 28

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Lock.error !== ""
                text: Lock.error
                color: "#ffb4ab"
                font.styleName: "Medium"
            }
            Chip {
                visible: root.capsLock
                icon: "keyboard_capslock"
                text: "Caps Lock"
            }
            Chip {
                icon: "language"
                text: KbLayout.code || "US"
                clickable: true
                onClicked: {
                    KbLayout.next();
                    field.forceActiveFocus();
                }
            }
        }
    }

    property bool capsLock: false

    component Chip: PressButton {
        id: chip
        property string icon
        property string text
        property bool clickable: false
        enabled: true
        width: chipRow.implicitWidth + 20
        height: 28
        color: Qt.rgba(1, 1, 1, 0.14)
        hoverColor: clickable ? Qt.rgba(1, 1, 1, 0.24) : color
        anchors.verticalCenter: parent?.verticalCenter
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 15
                color: "white"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: "white"
                font.pixelSize: Theme.font.small
                font.styleName: Theme.font.styleTitle
            }
        }
    }

    // ── Bottom bar: notifications · now playing · power ─────────────────────
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        height: 64
        opacity: root.shown

        // Count only; notification text never shows on the lock screen
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: Config.lock.showNotifications && Notifs.count > 0
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "notifications"
                fill: 1
                color: "white"
                size: 20
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.count === 1 ? "1 notification" : `${Notifs.count} notifications`
                color: "white"
            }
        }

        // Now playing
        Rectangle {
            anchors.centerIn: parent
            visible: Config.lock.showMedia && Media.active
            width: Math.min(420, mediaRow.implicitWidth + 24)
            height: 64
            radius: 20
            color: Qt.rgba(0, 0, 0, 0.32)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 12
                Cover {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 10
                    source: Media.art
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(220, Math.max(titleText.implicitWidth, artistText.implicitWidth))
                    Label {
                        id: titleText
                        width: parent.width
                        text: Media.title
                        color: "white"
                        font.styleName: Theme.font.styleTitle
                    }
                    Label {
                        id: artistText
                        width: parent.width
                        text: Media.artist
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: Theme.font.small
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    LockButton { icon: "skip_previous"; onClicked: Media.previous() }
                    LockButton { icon: Media.isPlaying ? "pause" : "play_arrow"; filled: true; onClicked: Media.toggle() }
                    LockButton { icon: "skip_next"; onClicked: Media.next() }
                }
            }
        }

        // Power: suspend at once; restart and shut down ask for a second click
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.armed !== ""
                text: root.armed === "reboot" ? "Click again to restart" : "Click again to shut down"
                color: "white"
                font.pixelSize: Theme.font.small
                rightPadding: 6
            }
            LockButton {
                icon: "bedtime"
                onClicked: if (!Lock.preview) Session.suspend()
            }
            LockButton {
                icon: "restart_alt"
                armed: root.armed === "reboot"
                onClicked: root.arm("reboot")
            }
            LockButton {
                icon: "power_settings_new"
                armed: root.armed === "poweroff"
                onClicked: root.arm("poweroff")
            }
        }
    }

    property string armed: ""
    function arm(action) {
        if (armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }
        armed = "";
        if (Lock.preview)
            return;
        if (action === "reboot")
            Session.reboot();
        else
            Session.poweroff();
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    component LockButton: PressButton {
        id: lb
        property string icon
        property bool filled: false
        property bool armed: false
        width: 44
        height: 44
        color: armed ? Theme.error : filled ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        hoverColor: armed ? Theme.error : Qt.rgba(1, 1, 1, 0.2)
        Icon {
            anchors.centerIn: parent
            name: lb.icon
            size: 22
            fill: 1
            color: lb.armed ? Theme.fgPrimary : "white"
        }
    }
}
