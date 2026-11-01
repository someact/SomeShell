import QtQuick
import qs.core
import qs.components
import qs.settings

// Shows a combo as key caps; click to record a new one. While recording,
// Hyprland sits in an empty submap so even bound combos arrive here.
// Esc cancels; recording also ends by itself after 10 s.
FocusScope {
    id: rec

    property string keys: ""            // current combo, e.g. "SUPER + SHIFT + S"
    property bool recording: false
    signal recorded(string keys)

    implicitWidth: Math.max(140, caps.implicitWidth + 24)
    implicitHeight: 36

    function start() {
        recording = true;
        KeybindStore.recordMode(true);
        catcher.forceActiveFocus();
        timeout.restart();
    }
    function stop() {
        if (!recording)
            return;
        recording = false;
        timeout.stop();
        KeybindStore.recordMode(false);
    }
    Component.onDestruction: stop()

    Timer {
        id: timeout
        interval: 10000
        onTriggered: rec.stop()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: rec.recording ? Theme.primaryContainer : mouse.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
        border.width: rec.recording ? 2 : 0
        border.color: Theme.primary
    }

    Row {
        id: caps
        anchors.centerIn: parent
        spacing: 4
        visible: !rec.recording
        Repeater {
            model: rec.keys === "" ? [] : KeybindStore.pretty(rec.keys).split(" + ")
            Rectangle {
                required property string modelData
                width: Math.max(24, capLabel.implicitWidth + 12)
                height: 24
                radius: 6
                color: Theme.surface
                border.width: 1
                border.color: Theme.outlineVariant
                SText {
                    id: capLabel
                    anchors.centerIn: parent
                    text: parent.modelData
                    mono: true
                    font.pixelSize: Theme.font.small
                }
            }
        }
        SText {
            visible: rec.keys === ""
            text: "Not set"
            dim: true
        }
    }
    SText {
        anchors.centerIn: parent
        visible: rec.recording
        text: "Press keys…"
        color: Theme.fgPrimaryContainer
        font.styleName: Theme.font.styleTitle
    }

    Item {
        id: catcher
        focus: true
        Keys.onPressed: event => {
            if (!rec.recording)
                return;
            event.accepted = true;
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                rec.stop();
                return;
            }
            const combo = KeybindStore.comboFromEvent(event);
            if (combo === "")
                return;   // a lone modifier: wait for the key
            rec.stop();
            rec.recorded(combo);
        }
        onActiveFocusChanged: if (!activeFocus) rec.stop()
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rec.recording ? rec.stop() : rec.start()
    }
}
