import QtQuick
import "layout.js" as Layout
import qs.core
import qs.components
import qs.services

// One key. Normal keys fire on press (and repeat while held for backspace,
// space, arrows); modifiers latch/lock through VirtualKeys.
PressButton {
    id: key

    required property var keyData
    required property real unit
    property bool thai: false

    readonly property bool isMod: keyData.kind === "mod"
    readonly property bool showIcon: keyData.kind === "icon" || !!keyData.isIcon
    readonly property int modState: isMod ? VirtualKeys.state(keyData.c) : 0
    readonly property bool shifted: VirtualKeys.shift
    readonly property var thaiLabels: thai ? (Layout.thai[keyData.c] ?? null) : null
    readonly property string label: {
        if (thaiLabels)
            return thaiLabels[shifted ? 1 : 0];
        return shifted && keyData.s ? keyData.s : keyData.l;
    }

    width: Math.round(unit * keyData.w + (keyData.w - 1) * 6)
    radius: Theme.radius.small + 2
    color: isMod || keyData.kind === "icon" ? Theme.surfaceHighest : Theme.surfaceHigh
    hoverColor: Qt.lighter(color, 1.15)
    active: modState > 0
    activeColor: modState === 2 ? Theme.tertiary : Theme.primary

    // Fire on press for snappy typing; MouseArea's clicked is not used
    onPressedChanged: {
        if (!pressed) {
            repeat.stop();
            return;
        }
        if (isMod) {
            VirtualKeys.toggleMod(keyData.c);
            return;
        }
        VirtualKeys.tap(keyData.c);
        if (Layout.repeating.includes(keyData.c))
            repeat.start();
    }
    Timer {
        id: repeat
        interval: 420
        repeat: true
        onTriggered: {
            interval = 45;
            VirtualKeys.tap(key.keyData.c);
        }
        onRunningChanged: if (!running) interval = 420
    }

    Icon {
        anchors.centerIn: parent
        visible: key.showIcon
        name: key.isMod && key.modState === 2 ? "shift_lock" : key.keyData.l
        size: Math.round(key.unit * 0.45)
        fill: 1
        color: key.active ? Theme.fgPrimary : Theme.fgSurface
    }
    Label {
        anchors.centerIn: parent
        visible: !key.showIcon
        text: key.label
        color: key.active ? Theme.fgPrimary : Theme.fgSurface
        font.pixelSize: key.keyData.l.length > 1 && !key.thaiLabels ? Math.round(key.unit * 0.3) : Math.round(key.unit * 0.42)
        font.styleName: key.keyData.l.length > 1 ? "Medium" : Theme.font.style
        elide: Text.ElideNone
    }
}
