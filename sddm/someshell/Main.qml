import QtQuick
import QtQuick.Shapes

// SomeShell's login screen: lock style A "Headline" (SomeShell.md section 5),
// the same page as the shell's lock (shell/lock/LockPage.qml) with SDDM's
// parts: the user, the session and the power buttons where the player sits.
// SDDM gives `sddm`, `userModel`, `sessionModel`, `keyboard` and `config`.
// Colors come from theme.conf (install.sh writes the wallpaper's palette),
// Mitr from fonts/ (install.sh copies it; SDDM cannot read the user's fonts).
Rectangle {
    id: root

    // ── Look ──
    readonly property color paper: config.paper || "#0e0e0e"
    readonly property color ink: config.ink || "#e2e2e2"
    readonly property color mute: config.mute || "#c6c6c6"
    readonly property color line: config.line || "#474747"
    readonly property color raised: config.raised || "#2a2a2a"
    readonly property color error: config.error || "#ffb4ab"
    readonly property string family: "Mitr"

    // One unit is 1% of a 16:9 screen; other shapes fit by the shorter side
    readonly property real u: Math.min(width / 100, height / 56.25)
    readonly property real col: 20.5 * u
    readonly property real capSize: Math.max(10, 0.78 * u)

    color: paper

    FontLoader { source: "fonts/Mitr-Light.ttf" }
    FontLoader { source: "fonts/Mitr-Regular.ttf" }
    FontLoader { source: "fonts/Mitr-Medium.ttf" }
    FontLoader { source: "fonts/Mitr-SemiBold.ttf" }

    // ── State ──
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string password: ""
    property int fails: 0
    property bool checking: false
    property string message: ""

    // Model rows by index (SDDM's models are QAbstractListModels)
    readonly property string userName: userAt(userIndex, Qt.UserRole + 1)
    readonly property string userReal: userAt(userIndex, Qt.UserRole + 2)
    readonly property string sessionName: sessionAt(sessionIndex)
    function userAt(i, role) {
        const v = userModel.data(userModel.index(i, 0), role);
        return v === undefined || v === null ? "" : String(v);
    }
    function sessionAt(i) {
        const v = sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4);
        return v === undefined || v === null ? "" : String(v);
    }
    function cycleUser(d) {
        if (userModel.count > 1)
            userIndex = (userIndex + d + userModel.count) % userModel.count;
        password = "";
    }
    function cycleSession(d) {
        if (sessionModel.rowCount() > 1)
            sessionIndex = (sessionIndex + d + sessionModel.rowCount()) % sessionModel.rowCount();
    }
    function submit() {
        if (checking || password === "")
            return;
        checking = true;
        sddm.login(userName, password, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.checking = false;
            root.fails++;
            root.password = "";
            shake.restart();
        }
        function onLoginSucceeded() {
            root.checking = false;
            root.leaving = true;
        }
        function onInformationMessage(message) {
            root.message = message;
        }
    }

    // Lines come in one after another; logging in takes them away
    property real enter: 0
    NumberAnimation on enter { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    property bool leaving: false
    property real leaveAnim: leaving ? 1 : 0
    Behavior on leaveAnim { NumberAnimation { duration: 260; easing.type: Easing.InCubic } }
    function step(i) {
        return Math.max(0, Math.min(1, (enter - i * 0.09) / 0.45)) * (1 - leaveAnim);
    }

    // ── Keys ──
    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        MouseArea {
            anchors.fill: parent
            onPressed: keys.forceActiveFocus()
        }

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter)
                root.submit();
            else if (k === Qt.Key_Backspace)
                root.password = (event.modifiers & Qt.ControlModifier) ? "" : root.password.slice(0, -1);
            else if (k === Qt.Key_Escape)
                root.password = "";
            else if (k === Qt.Key_Up || k === Qt.Key_Down)
                root.cycleUser(k === Qt.Key_Down ? 1 : -1);
            else if (k === Qt.Key_F2 || ((k === Qt.Key_Left || k === Qt.Key_Right) && (event.modifiers & Qt.AltModifier)))
                root.cycleSession(k === Qt.Key_Left ? -1 : 1);
            else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && !root.checking)
                root.password += event.text;
            event.accepted = true;
        }
    }

    // ── Shared bits ──
    component Cap: Text {
        color: root.mute
        font.family: root.family
        font.styleName: "Regular"
        font.pixelSize: root.capSize
        font.capitalization: Font.AllUppercase
        font.letterSpacing: font.pixelSize * 0.16
        lineHeight: 1.6
        renderType: Text.NativeRendering
    }

    component Plus: Item {
        property real size: 1.4 * root.u
        width: size
        height: size
        Rectangle { x: Math.round(parent.size / 2); width: 1; height: parent.size; color: root.mute }
        Rectangle { y: Math.round(parent.size / 2); height: 1; width: parent.size; color: root.mute }
    }

    // A small ‹ or › that cycles something
    component Arrow: Text {
        id: arrow
        signal clicked
        text: "›"
        color: arrowMouse.containsMouse ? root.ink : root.mute
        font.family: root.family
        font.styleName: "Light"
        font.pixelSize: root.capSize * 1.6
        MouseArea {
            id: arrowMouse
            anchors.fill: parent
            anchors.margins: -root.u * 0.4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                arrow.clicked();
                keys.forceActiveFocus();
            }
        }
    }

    // A rounded outlined button with a caption (power); pressing inverts it
    component PowerButton: Item {
        id: pb
        property string label
        signal clicked
        readonly property bool down: pbMouse.pressed
        width: pbText.implicitWidth + 2.4 * root.u
        height: 2.6 * root.u
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: pb.down ? root.ink : pbMouse.containsMouse ? root.raised : "transparent"
            border.width: 1
            border.color: pb.down ? root.ink : root.line
        }
        Text {
            id: pbText
            anchors.centerIn: parent
            text: pb.label
            color: pb.down ? root.paper : root.ink
            font.family: root.family
            font.styleName: "Regular"
            font.pixelSize: root.capSize
            font.capitalization: Font.AllUppercase
            font.letterSpacing: font.pixelSize * 0.16
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // Rolling digits, like the shell's Digits
    component Digits: Row {
        id: dg
        property string text
        property real size: 20
        property color color: root.ink
        TextMetrics {
            id: widest
            font.family: root.family
            font.styleName: "SemiBold"
            font.pixelSize: dg.size
            text: "0"
        }
        readonly property real cell: Math.ceil(widest.advanceWidth)
        readonly property real lh: Math.ceil(dg.size * 1.25)
        Repeater {
            model: dg.text.length
            Item {
                id: slot
                required property int index
                readonly property string ch: dg.text.charAt(index)
                readonly property bool digit: ch >= "0" && ch <= "9"
                width: digit ? dg.cell : glyph.implicitWidth
                height: dg.lh
                clip: digit
                Text {
                    id: glyph
                    visible: !slot.digit
                    text: slot.ch
                    color: dg.color
                    font.family: root.family
                    font.styleName: "SemiBold"
                    font.pixelSize: dg.size
                    height: dg.lh
                    verticalAlignment: Text.AlignVCenter
                }
                Column {
                    visible: slot.digit
                    y: slot.digit ? -Number(slot.ch) * dg.lh : 0
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: 10
                        Text {
                            required property int index
                            width: dg.cell
                            height: dg.lh
                            text: index
                            color: dg.color
                            font.family: root.family
                            font.styleName: "SemiBold"
                            font.pixelSize: dg.size
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    // ── Time ──
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    readonly property string time: Qt.formatTime(now, "HH:mm")
    readonly property int sec: now.getSeconds()

    function roman(n) {
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

    // ── The time, up the left edge ──
    Item {
        id: clockBox
        readonly property real size: 15.5 * root.u
        width: clock.implicitWidth
        height: clock.implicitHeight
        rotation: -90
        x: 1.6 * root.u - (width - height) / 2 - 0.2 * size
        y: (root.height - height) / 2
        opacity: root.step(0)
        Digits {
            id: clock
            text: root.time
            size: clockBox.size
        }
    }

    // ── Top left: the date and a barcode ──
    Column {
        x: root.col
        y: 6.6 * root.u
        spacing: 0.8 * root.u
        opacity: root.step(1)

        Cap {
            lineHeight: 1
            text: Qt.locale("en_US").toString(root.now, "ddd") + " · " + Qt.locale("en_US").toString(root.now, "dd")
                + " · " + root.roman(root.now.getMonth() + 1) + " · " + root.roman(root.now.getFullYear())
        }
        Row {
            id: barcode
            height: 1.9 * root.u
            readonly property var widths: {
                let seed = 7;
                const out = [];
                for (let i = 0; i < 46; i++) {
                    seed = (seed * 9301 + 49297) % 233280;
                    const w = seed / 233280 < 0.3 ? 0.26 : 0.1;
                    seed = (seed * 9301 + 49297) % 233280;
                    out.push([w, seed / 233280 < 0.5 ? 0.12 : 0.22]);
                }
                return out;
            }
            Repeater {
                model: barcode.widths
                Item {
                    required property var modelData
                    width: Math.max(1, Math.round(modelData[0] * root.u)) + Math.max(1, Math.round(modelData[1] * root.u))
                    height: barcode.height
                    Rectangle {
                        width: Math.max(1, Math.round(parent.modelData[0] * root.u))
                        height: parent.height
                        color: root.ink
                        opacity: 0.85
                    }
                }
            }
        }
    }

    // ── Top right: a greeting ──
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        y: 6.6 * root.u
        width: 16 * root.u
        opacity: root.step(1)
        Repeater {
            model: {
                const h = root.now.getHours();
                const part = h < 5 ? "Good night," : h < 12 ? "Good morning," : h < 18 ? "Good afternoon," : "Good evening,";
                return [part, sddm.hostName ? "this is " + sddm.hostName + "." : "welcome back.", "Make it count."];
            }
            Cap {
                required property string modelData
                color: root.ink
                text: modelData
            }
        }
    }

    // ── The middle: who, the session, the password ──
    Item {
        id: form
        x: root.col
        width: 30 * root.u
        height: formCol.implicitHeight
        y: (root.height - height) / 2
        property real shakeX: 0
        transform: Translate { x: form.shakeX }

        Column {
            id: formCol
            width: parent.width
            spacing: 2.4 * root.u

            Column {
                spacing: 0.9 * root.u
                opacity: root.step(2)
                Row {
                    spacing: 1.2 * root.u
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.userName || "").toUpperCase()
                        color: root.ink
                        font.family: root.family
                        font.styleName: "Medium"
                        font.pixelSize: 2.6 * root.u
                        font.letterSpacing: font.pixelSize * 0.06
                        renderType: Text.NativeRendering
                    }
                    Row {
                        visible: userModel.count > 1
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0.8 * root.u
                        Arrow { text: "‹"; onClicked: root.cycleUser(-1) }
                        Arrow { text: "›"; onClicked: root.cycleUser(1) }
                    }
                }
                Row {
                    spacing: 1 * root.u
                    Cap {
                        anchors.verticalCenter: parent.verticalCenter
                        lineHeight: 1
                        text: (root.userReal && root.userReal.toUpperCase() !== root.userName.toUpperCase() ? root.userReal + " · " : "") + root.sessionName
                    }
                    Row {
                        visible: sessionModel.rowCount() > 1
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0.8 * root.u
                        Arrow { text: "‹"; onClicked: root.cycleSession(-1) }
                        Arrow { text: "›"; onClicked: root.cycleSession(1) }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 0.9 * root.u
                opacity: root.step(3)

                Cap {
                    lineHeight: 1
                    text: "Password"
                }

                Item {
                    width: parent.width
                    height: 2.2 * root.u
                    clip: true
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0.9 * root.u
                        Repeater {
                            model: root.password.length
                            Rectangle {
                                width: 0.85 * root.u
                                height: width
                                radius: width / 2
                                color: root.ink
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                            }
                        }
                    }
                    SequentialAnimation on opacity {
                        running: root.checking
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 380 }
                        NumberAnimation { to: 1; duration: 380 }
                    }
                }

                Item {
                    width: parent.width
                    height: 1
                    Rectangle {
                        anchors.fill: parent
                        color: root.line
                    }
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, (root.enter - 0.3) / 0.6))
                        color: root.wrongNow ? root.error : root.ink
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Cap {
                    lineHeight: 1
                    color: root.wrongNow || keyboard.capsLock ? root.error : root.mute
                    text: root.checking ? "Checking"
                        : keyboard.capsLock ? "Caps Lock is on"
                        : root.fails > 0 && root.password === "" ? "Wrong · try again · " + String(root.fails).padStart(2, "0")
                        : "Enter to sign in" + (root.layoutCode ? " · " + root.layoutCode : "")
                }
            }
        }
    }
    readonly property bool wrongNow: fails > 0 && password === "" && !checking

    SequentialAnimation {
        id: shake
        readonly property real d: 1.1 * root.u
        NumberAnimation { target: form; property: "shakeX"; to: -shake.d; duration: 60 }
        NumberAnimation { target: form; property: "shakeX"; to: shake.d; duration: 80 }
        NumberAnimation { target: form; property: "shakeX"; to: -shake.d; duration: 80 }
        NumberAnimation { target: form; property: "shakeX"; to: shake.d * 0.6; duration: 80 }
        NumberAnimation { target: form; property: "shakeX"; to: 0; duration: 100; easing.type: Easing.OutCubic }
    }

    // ── Right: the seconds as a big thin circle ──
    Item {
        id: secs
        width: 25 * root.u
        height: width
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.step(4)

        property real sweep: root.sec * 6
        Behavior on sweep {
            enabled: root.sec !== 0
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.line
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
                strokeColor: root.ink
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
            Digits {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String(root.sec).padStart(2, "0")
                size: 3.8 * root.u
            }
            Cap {
                anchors.horizontalCenter: parent.horizontalCenter
                lineHeight: 1
                font.pixelSize: Math.max(9, 0.7 * root.u)
                text: "Seconds"
            }
        }
    }

    // ── Bottom left: the machine, like the poster's verses ──
    readonly property string layoutCode: {
        const l = keyboard.layouts[keyboard.currentLayout];
        return l ? String(l.shortName).toUpperCase() : "";
    }
    Column {
        x: root.col
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6.4 * root.u
        opacity: root.step(5)

        Cap {
            visible: root.message !== ""
            color: root.ink
            text: root.message
        }
        Cap {
            visible: sddm.hostName !== ""
            color: root.ink
            text: sddm.hostName + "."
        }
        Cap {
            visible: root.layoutCode !== ""
            text: "Keyboard " + root.layoutCode + "."
            MouseArea {
                anchors.fill: parent
                enabled: keyboard.layouts.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length;
                    keys.forceActiveFocus();
                }
            }
        }
    }

    // ── Bottom right: power, where the lock has its player ──
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 7.5 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6.4 * root.u
        spacing: 0.8 * root.u
        opacity: root.step(5)

        PowerButton {
            visible: sddm.canSuspend
            label: "Sleep"
            onClicked: sddm.suspend()
        }
        PowerButton {
            visible: sddm.canReboot
            label: "Restart"
            onClicked: sddm.reboot()
        }
        PowerButton {
            visible: sddm.canPowerOff
            label: "Shut down"
            onClicked: sddm.powerOff()
        }
    }

    // ── Print marks ──
    Plus { x: root.width - 3 * root.u - width; y: 3 * root.u; opacity: root.step(1) }
    Plus { x: root.width - 3 * root.u - width; y: root.height - 3 * root.u - height; opacity: root.step(5) }
    Plus { x: root.col - width / 2; y: 12.6 * root.u; opacity: root.step(2) }
}
