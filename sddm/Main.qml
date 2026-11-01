import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Effects
import "components"

// Standalone SDDM port of shell/lock/LockSurface.qml. No Quickshell, PAM
// helpers, user-session services or compositor-specific imports are needed.
Rectangle {
    id: root
    width: 1280
    height: 720
    anchors.fill: parent
    color: config.BackgroundColor || "#131318"
    property bool busy: false
    property string error: ""
    property string armed: ""
    property real shown: 0
    readonly property bool reduced: config.ReducedMotion === "true"
    readonly property bool preview: config.PreviewMode === "true"
    readonly property string uiFont: uiFontLoader.status === FontLoader.Ready ? uiFontLoader.name : (config.Font || "Mitr")
    readonly property string iconFont: iconFontLoader.status === FontLoader.Ready ? iconFontLoader.name : "Material Symbols Rounded"
    readonly property bool haveSymbols: iconFontLoader.status === FontLoader.Ready || Qt.fontFamilies().includes("Material Symbols Rounded")
    readonly property string buttonFont: haveSymbols ? iconFont : uiFont
    readonly property real uiScale: Math.min(1, height / 900, width / 1100)
    readonly property string userName: users.editText.trim()
    readonly property var passShapes: {
        const shapes = ["cookie4Sided", "clover4Leaf", "sunny", "cookie7Sided", "heart", "softBurst", "pentagon", "clover8Leaf", "gem", "cookie12Sided", "flower", "puffy", "triangle", "diamond"];
        for (let i = shapes.length - 1; i > 0; --i) {
            const j = Math.floor(Math.random() * (i + 1));
            [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
        }
        return shapes;
    }
    FontLoader { id: uiFontLoader; source: config.FontFile ? Qt.resolvedUrl(config.FontFile) : "" }
    FontLoader { id: iconFontLoader; source: config.IconFontFile ? Qt.resolvedUrl(config.IconFontFile) : "" }
    // Request an alpha-capable surface before the greeter is shown. Some
    // EGL configurations otherwise choose RGB565 and band the blurred image.
    Binding { target: root.Window.window; property: "color"; value: "transparent"; when: root.Window.window !== null }
    Component.onCompleted: { shown = 1; password.forceActiveFocus(); }
    Behavior on shown { enabled: !root.reduced; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    function login() {
        if (busy || !userName || sessions.currentIndex < 0)
            return;
        error = "";
        busy = true;
        if (preview) { previewResult.restart(); return; }
        sddm.login(userName, password.text, sessions.currentIndex);
    }
    function icon(name, fallback) { return haveSymbols ? name : fallback; }
    function arm(action) {
        if (armed !== action) { armed = action; disarm.restart(); return; }
        armed = "";
        if (preview) { error = qsTr("Preview · power actions are disabled"); return; }
        if (action === "reboot") sddm.reboot();
        else sddm.powerOff();
    }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = "" }
    Timer {
        id: previewResult
        interval: 800
        onTriggered: {
            root.busy = false;
            root.error = qsTr("Preview · authentication is disabled");
            password.clear();
            password.forceActiveFocus();
            if (!root.reduced) shake.restart();
        }
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.error = qsTr("Login failed. Check your password and keyboard layout.");
            password.clear();
            password.forceActiveFocus();
            if (!root.reduced) shake.restart();
        }
        function onLoginSucceeded() { password.clear(); root.shown = 0; }
    }

    Image {
        anchors.fill: parent
        source: config.Background ? Qt.resolvedUrl(config.Background) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#2e000000" }
            GradientStop { position: 0.55; color: "#47000000" }
            GradientStop { position: 1; color: "#8c000000" }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.12 - (1 - root.shown) * 40
        spacing: -6 * root.uiScale
        opacity: root.shown
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: "#e6ffffff"
            font { family: root.uiFont; pixelSize: Math.max(16, 24 * root.uiScale); weight: Font.Medium }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, config.ClockFormat || "HH:mm")
            color: "white"
            font { family: root.uiFont; pixelSize: Math.min(root.height * 0.17, 180); weight: 550; features: ({"tnum": 1}) }
        }
    }

    Column {
        id: auth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(root.height * 0.62, root.height - height - footer.height - 38) + (1 - root.shown) * 30
        spacing: 14 * root.uiScale
        opacity: root.shown
        enabled: !root.busy

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72 * root.uiScale; height: width; radius: width / 2
            color: "#29ffffff"
            border { width: 1; color: "#38ffffff" }
            Text {
                anchors.centerIn: parent
                text: root.userName.charAt(0).toUpperCase()
                color: "white"
                font { family: root.uiFont; pixelSize: 30 * root.uiScale; weight: 550 }
            }
            Image {
                id: face
                anchors.fill: parent
                source: users.currentIndex >= 0 && users.currentValue === root.userName ? users.avatar : ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(144, 144)
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: avatarMask }
            }
            Item {
                id: avatarMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle { anchors.fill: parent; radius: width / 2; color: "white" }
            }
        }

        GlassChoice {
            id: users
            objectName: "users"
            anchors.horizontalCenter: parent.horizontalCenter
            width: fieldBox.width
            model: userModel
            textRole: "name"
            valueRole: "name"
            editable: true
            currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            property string avatar: ""
            Component.onCompleted: { if (userModel.lastUser) editText = userModel.lastUser; }
            onEditTextChanged: { password.clear(); root.error = ""; }
            onActivated: password.forceActiveFocus()
            delegate: ItemDelegate {
                id: userDelegate
                width: users.width
                text: model.realName || model.name
                font.family: root.uiFont
                highlighted: users.highlightedIndex === index
                contentItem: Text { text: userDelegate.text; color: "white"; font: userDelegate.font; elide: Text.ElideRight }
                background: Rectangle { color: userDelegate.highlighted ? "#44ffffff" : "transparent"; radius: 10 }
                Component.onCompleted: { if (index === users.currentIndex) users.avatar = model.icon; }
                Connections {
                    target: users
                    function onCurrentIndexChanged() { if (index === users.currentIndex) users.avatar = model.icon; }
                }
            }
            Accessible.name: qsTr("User name")
        }

        Item {
            id: fieldBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(340, root.width - 48)
            height: 46
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: password.activeFocus ? "#33ffffff" : "#24ffffff"
                border { width: 1; color: root.error ? "#ffb4ab" : password.activeFocus ? "#99ffffff" : "#30ffffff" }
            }
            TextInput {
                id: password
                objectName: "password"
                anchors.fill: parent
                opacity: 0
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                focus: true
                enabled: !root.busy
                Accessible.name: qsTr("Password")
                Accessible.role: Accessible.EditableText
                onAccepted: root.login()
                Keys.onEscapePressed: { clear(); root.error = ""; }
                KeyNavigation.tab: submit
                KeyNavigation.backtab: users
            }
            Text {
                anchors.centerIn: parent
                visible: !password.text
                text: root.busy ? qsTr("Checking…") : qsTr("Enter password")
                color: "#99ffffff"
                font { family: root.uiFont; pixelSize: 13 }
            }
            Row {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -16
                Repeater {
                    model: 16
                    Item {
                        id: dot
                        required property int index
                        readonly property bool present: index < password.text.length
                        width: present ? 17 : 0
                        height: 17
                        Behavior on width { enabled: !root.reduced; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        PasswordShape {
                            anchors.centerIn: parent
                            width: 13; height: 13
                            shape: root.passShapes[dot.index % root.passShapes.length]
                            scale: dot.present ? 1 : 0
                            rotation: dot.present ? 0 : -60
                            opacity: root.busy ? 0.5 : 1
                            Behavior on scale { enabled: !root.reduced; SpringAnimation { spring: 4; damping: 0.3 } }
                            Behavior on rotation { enabled: !root.reduced; SpringAnimation { spring: 3; damping: 0.4 } }
                        }
                    }
                }
            }
            PillButton {
                id: submit
                anchors.right: parent.right; anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                text: qsTr("Sign in"); symbol: root.busy ? root.icon("progress_activity", "◌") : root.icon("arrow_forward", "→")
                symbolFont: root.buttonFont
                spinning: root.busy && !root.reduced
                enabled: !root.busy && root.userName !== "" && sessions.currentIndex >= 0
                onClicked: root.login()
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 5; duration: 60 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            height: 28
            PillButton {
                visible: keyboard.capsLock
                height: 28; text: qsTr("Caps Lock"); enabled: false
            }
            GlassChoice {
                id: layouts
                width: 95; height: 28
                visible: keyboard.enabled && keyboard.layouts.length > 0
                model: keyboard.layouts
                textRole: "shortName"
                currentIndex: keyboard.currentLayout
                onActivated: { keyboard.currentLayout = index; password.forceActiveFocus(); }
                Accessible.name: qsTr("Keyboard layout")
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(420, root.width - 48)
            height: 36
            text: root.error
            color: "#ffb4ab"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font { family: root.uiFont; pixelSize: 12; weight: Font.Medium }
            Accessible.role: Accessible.AlertMessage
        }
    }

    Row {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Math.max(16, 28 * root.uiScale)
        height: 40
        opacity: root.shown
        // Items positioned separately to keep the session and power at opposite edges.
        GlassChoice {
            id: sessions
            objectName: "sessions"
            width: Math.min(300, root.width * 0.44)
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
            enabled: !root.busy
            Accessible.name: qsTr("Desktop session")
        }
        Item { width: Math.max(0, footer.width - sessions.width - power.width); height: 1 }
        Row {
            id: power
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.armed !== ""
                text: root.armed === "reboot" ? qsTr("Click again to restart") : qsTr("Click again to shut down")
                color: "white"
                font { family: root.uiFont; pixelSize: 12 }
            }
            PillButton { visible: root.preview || sddm.canSuspend; text: qsTr("Suspend"); symbol: root.icon("bedtime", "☾"); symbolFont: root.buttonFont; enabled: !root.busy; onClicked: { if (!root.preview) sddm.suspend(); } }
            PillButton { visible: root.preview || sddm.canReboot; text: qsTr("Restart"); symbol: root.icon("restart_alt", "↻"); symbolFont: root.buttonFont; armed: root.armed === "reboot"; enabled: !root.busy; onClicked: root.arm("reboot") }
            PillButton { visible: root.preview || sddm.canPowerOff; text: qsTr("Shut down"); symbol: root.icon("power_settings_new", "⏻"); symbolFont: root.buttonFont; armed: root.armed === "poweroff"; enabled: !root.busy; onClicked: root.arm("poweroff") }
        }
    }

    component GlassChoice: ComboBox {
        id: choice
        implicitHeight: 36
        hoverEnabled: true
        font { family: root.uiFont; pixelSize: 13; weight: 550 }
        palette { text: "white"; buttonText: "white"; highlightedText: "white"; base: "transparent"; highlight: "#44ffffff" }
        contentItem: TextField {
            text: choice.editable ? choice.editText : choice.displayText
            font: choice.font
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            leftPadding: 28; rightPadding: 28
            readOnly: !choice.editable
            selectByMouse: choice.editable
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            background: null
            onTextEdited: choice.editText = text
            onAccepted: password.forceActiveFocus()
        }
        background: Rectangle {
            radius: height / 2
            color: choice.hovered || choice.activeFocus ? "#33ffffff" : "#24ffffff"
            border { width: 1; color: choice.activeFocus ? "#99ffffff" : "#30ffffff" }
        }
        indicator: Text { x: choice.width - width - 14; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: "white"; font.pixelSize: 18 }
        popup: Popup {
            y: choice.height + 6
            width: choice.width
            implicitHeight: Math.min(contentItem.implicitHeight + 16, root.height * 0.36)
            padding: 8
            background: Rectangle { radius: 18; color: "#ee25232e"; border { width: 1; color: "#44ffffff" } }
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
        }
        delegate: ItemDelegate {
            id: choiceDelegate
            width: choice.width - 16
            text: model[choice.textRole] || modelData[choice.textRole] || ""
            font: choice.font
            highlighted: choice.highlightedIndex === index
            contentItem: Text { text: choiceDelegate.text; font: choiceDelegate.font; color: "white"; elide: Text.ElideRight }
            background: Rectangle { radius: 10; color: choiceDelegate.highlighted ? "#44ffffff" : "transparent" }
        }
    }
}
