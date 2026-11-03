import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// The lock page, style A "Headline" (SomeShell.md section 5): a poster of
// its own in the desktop's paper and ink. The time runs up the left edge,
// the date and a barcode top left, a few lines top right, the password in
// the middle, the seconds as a big circle, status lines bottom left, the
// player bottom right. Typing goes to Locker; this page only draws it.
FocusScope {
    id: root

    readonly property var c: Theme.paper
    // One unit is 1% of a 16:9 screen; other shapes fit by the shorter side
    readonly property real u: Math.min(width / 100, height / 56.25)
    // The left edge of the text columns (right of the clock)
    readonly property real col: 20.5 * u

    focus: true
    Component.onCompleted: forceActiveFocus()

    // Lines come in one after another; unlocking takes them all away
    property real enter: 0
    NumberAnimation on enter { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    readonly property real leave: Locker.opening ? 1 : 0
    property real leaveAnim: leave
    Behavior on leaveAnim { NumberAnimation { duration: 260; easing.type: Easing.InCubic } }
    function step(i) {
        return Math.max(0, Math.min(1, (enter - i * 0.09) / 0.45)) * (1 - leaveAnim);
    }

    Rectangle {
        anchors.fill: parent
        color: root.c.bg
    }

    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Return || k === Qt.Key_Enter)
            Locker.submit();
        else if (k === Qt.Key_Backspace)
            (event.modifiers & Qt.ControlModifier) ? Locker.password = "" : Locker.erase();
        else if (k === Qt.Key_Escape)
            Locker.cancel();
        else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            Locker.add(event.text);
        event.accepted = true;
    }
    // Hyprland sends no event for Caps Lock: ask after it is pressed
    Keys.onReleased: event => {
        if (event.key === Qt.Key_CapsLock)
            Keyboard.readCaps();
    }

    SystemClock {
        id: seconds
        precision: SystemClock.Seconds
    }

    // The host name, for the line under the user's name
    FileView {
        id: hostFile
        path: "/etc/hostname"
    }
    readonly property string host: hostFile.text().trim()
    readonly property string user: Quickshell.env("USER") || ""

    // ── The time, up the left edge ──
    Item {
        id: clockBox
        readonly property real size: 15.5 * root.u
        width: clock.implicitWidth
        height: clock.implicitHeight
        rotation: -90
        // After the turn the box is `height` wide; its glyphs start ~0.2 size in
        x: 1.6 * root.u - (width - height) / 2 - 0.2 * size
        y: (root.height - height) / 2
        opacity: root.step(0)

        Digits {
            id: clock
            text: Clock.time
            size: clockBox.size
            face: Theme.font.bold
            color: root.c.fg
        }
    }

    // ── Top left: the date and a barcode ──
    Column {
        x: root.col
        y: 6.6 * root.u
        spacing: 0.8 * root.u
        opacity: root.step(1)

        Txt {
            caps: true
            size: Math.max(10, 0.78 * root.u)
            color: root.c.mute
            text: {
                const d = Clock.now;
                const roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"];
                const year = d.getFullYear();
                return Qt.locale("en_US").toString(d, "ddd") + " · " + Qt.locale("en_US").toString(d, "dd")
                    + " · " + roman[d.getMonth()] + " · " + root.romanYear(year);
            }
        }
        Barcode {
            height: 1.9 * root.u
            unit: root.u
            color: root.c.fg
        }
    }

    function romanYear(n) {
        const map = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [v, s] of map) {
            while (n >= v) {
                out += s;
                n -= v;
            }
        }
        return out;
    }

    // ── Top right: when it locked, and what waits ──
    readonly property int away: Math.max(0, Math.round((Clock.now - Locker.lockedAt) / 60000))
    readonly property int waiting: {
        const since = Locker.lockedAt.getTime();
        let n = 0;
        for (const e of Notifications.history)
            if (e.time >= since)
                n++;
        return n;
    }
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        y: 6.6 * root.u
        width: 16 * root.u
        opacity: root.step(1)

        Repeater {
            model: [
                "Locked at " + Qt.formatTime(Locker.lockedAt, "HH:mm") + ",",
                root.away < 1 ? "just now." : "away " + root.away + (root.away === 1 ? " minute." : " minutes."),
                root.waiting === 0 ? "Nothing missed." : root.waiting + (root.waiting === 1 ? " new notification." : " new notifications.")
            ]
            Txt {
                required property string modelData
                caps: true
                size: Math.max(10, 0.78 * root.u)
                color: root.c.fg
                text: modelData
                lineHeight: 1.6
            }
        }
    }

    // ── The middle: who, and the password ──
    Item {
        id: form
        x: root.col
        width: 30 * root.u
        height: formCol.implicitHeight
        y: (root.height - height) / 2
        property real shake: 0
        transform: Translate { x: form.shake }

        Column {
            id: formCol
            width: parent.width
            spacing: 2.4 * root.u

            Column {
                spacing: 0.9 * root.u
                opacity: root.step(2)
                Txt {
                    text: root.user.toUpperCase()
                    size: 2.6 * root.u
                    face: Theme.font.medium
                    color: root.c.fg
                    font.letterSpacing: size * 0.06
                }
                Txt {
                    caps: true
                    size: Math.max(10, 0.78 * root.u)
                    color: root.c.mute
                    text: root.host + " · Hyprland"
                }
            }

            Column {
                width: parent.width
                spacing: 0.9 * root.u
                opacity: root.step(3)

                Txt {
                    caps: true
                    size: Math.max(10, 0.78 * root.u)
                    color: root.c.mute
                    text: "Password"
                }

                // The dots: one per letter, each pops in
                Item {
                    width: parent.width
                    height: 2.2 * root.u
                    clip: true
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0.9 * root.u
                        Repeater {
                            model: Locker.password.length
                            Rectangle {
                                width: 0.85 * root.u
                                height: width
                                radius: width / 2
                                color: root.c.fg
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                            }
                        }
                    }
                    // While PAM checks: the dots breathe
                    SequentialAnimation on opacity {
                        running: Locker.checking
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 380 }
                        NumberAnimation { to: 1; duration: 380 }
                    }
                }

                // The hairline: draws itself when the page comes in; red after a wrong try
                Item {
                    width: parent.width
                    height: 1
                    Rectangle {
                        anchors.fill: parent
                        color: root.c.line
                    }
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, (root.enter - 0.3) / 0.6))
                        color: root.wrongNow ? root.c.error : root.c.fg
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Txt {
                    caps: true
                    size: Math.max(10, 0.78 * root.u)
                    color: root.wrongNow || Keyboard.caps ? root.c.error : root.c.mute
                    text: Locker.checking ? "Checking"
                        : Keyboard.caps ? "Caps Lock is on"
                        : Locker.fails > 0 && Locker.password === "" ? "Wrong · try again · " + String(Locker.fails).padStart(2, "0")
                        : "Enter to unlock" + (Keyboard.code ? " · " + Keyboard.code : "")
                }
            }
        }
    }
    readonly property bool wrongNow: Locker.fails > 0 && Locker.password === "" && !Locker.checking

    Connections {
        target: Locker
        function onWrongTickChanged() { shake.restart(); }
    }
    SequentialAnimation {
        id: shake
        readonly property real d: 1.1 * root.u
        NumberAnimation { target: form; property: "shake"; to: -shake.d; duration: 60 }
        NumberAnimation { target: form; property: "shake"; to: shake.d; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: -shake.d; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: shake.d * 0.6; duration: 80 }
        NumberAnimation { target: form; property: "shake"; to: 0; duration: 100; easing.type: Easing.OutCubic }
    }

    // ── Right: the seconds as a big thin circle ──
    Item {
        id: secs
        readonly property int s: seconds.date.getSeconds()
        width: 25 * root.u
        height: width
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.step(4)

        property real sweep: s * 6
        Behavior on sweep {
            enabled: secs.s !== 0
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.c.line
                strokeWidth: 1
                PathAngleArc {
                    centerX: secs.width / 2
                    centerY: secs.height / 2
                    radiusX: secs.width / 2 - 1
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.c.fg
                strokeWidth: 2
                PathAngleArc {
                    centerX: secs.width / 2
                    centerY: secs.height / 2
                    radiusX: secs.width / 2 - 1
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: secs.sweep
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 0
            Digits {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String(secs.s).padStart(2, "0")
                size: 3.8 * root.u
                face: Theme.font.bold
                color: root.c.fg
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                caps: true
                size: Math.max(9, 0.7 * root.u)
                color: root.c.mute
                text: "Seconds"
            }
        }
    }

    // ── Bottom left: status, like the poster's verses (network, battery, keyboard) ──
    Column {
        x: root.col
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6.4 * root.u
        opacity: root.step(5)

        Txt {
            caps: true
            size: Math.max(10, 0.78 * root.u)
            color: root.c.fg
            lineHeight: 1.6
            text: Network.online ? "Online · " + Network.label + "." : Network.label + "."
        }
        Txt {
            visible: Battery.available
            caps: true
            size: Math.max(10, 0.78 * root.u)
            color: Battery.low ? root.c.error : root.c.fg
            lineHeight: 1.6
            text: "Battery " + Battery.percent + "%" + (Battery.charging ? ", charging." : Battery.full ? ", full." : ".")
        }
        // A click switches the layout
        Txt {
            visible: Keyboard.code !== ""
            caps: true
            size: Math.max(10, 0.78 * root.u)
            color: layoutMouse.containsMouse ? root.c.fg : root.c.mute
            lineHeight: 1.6
            text: "Keyboard " + Keyboard.code + "."
            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Keyboard.next();
                    root.forceActiveFocus();
                }
            }
        }
    }

    // ── Bottom right: the player, while something plays ──
    Row {
        visible: Media.active
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6.4 * root.u
        spacing: 1.4 * root.u
        opacity: root.step(5)

        CoverRing {
            anchors.verticalCenter: parent.verticalCenter
            size: 4.4 * root.u
            ring: Math.max(2, 0.12 * root.u)
            gap: Math.max(2, 0.18 * root.u)
            disc: root.c.raised
            track: root.c.line
            fill: root.c.fg
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(14 * root.u, Math.max(titleTxt.implicitWidth, artistTxt.implicitWidth))
            Txt {
                id: titleTxt
                width: parent.width
                text: Media.title
                size: Math.max(12, 1.05 * root.u)
                face: Theme.font.medium
                color: root.c.fg
            }
            Txt {
                id: artistTxt
                width: parent.width
                text: Media.artist
                size: Math.max(12, 1.05 * root.u)
                color: root.c.mute
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0.5 * root.u
            LockButton {
                u: root.u
                icon: "skip_previous"
                onClicked: Media.previous()
            }
            LockButton {
                u: root.u
                icon: Media.playing ? "pause" : "play_arrow"
                on: true
                onClicked: Media.toggle()
            }
            LockButton {
                u: root.u
                icon: "skip_next"
                onClicked: Media.next()
            }
        }
    }

    // ── Print marks ──
    Plus { x: root.width - 3 * root.u - width; y: 3 * root.u; size: 1.4 * root.u; color: root.c.mute; opacity: root.step(1) }
    Plus { x: root.width - 3 * root.u - width; y: root.height - 3 * root.u - height; size: 1.4 * root.u; color: root.c.mute; opacity: root.step(5) }
    Plus { x: root.col - width / 2; y: 12.6 * root.u; size: 1.4 * root.u; color: root.c.mute; opacity: root.step(2) }
}
