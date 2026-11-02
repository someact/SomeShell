import QtQuick
import qs.core
import qs.components
import qs.services

// System: CPU, memory and (where there is one) the battery, each a label, a
// big rolling number and a bar. Samples come from SysSample (lib/sysmon.sh
// every 2 s while a desktop copy is shown; edit mode's copies read the same).
// A click opens the island's System page.
Item {
    id: root

    property var widget: null
    property bool live: true
    property real cell: 80
    property bool card: false
    // The colors: the desktop set on a card, the wallpaper's on bare type
    property var c: Theme.paper

    readonly property var s: SysSample.s
    property bool counted: false
    onLiveChanged: count()
    Component.onCompleted: count()
    Component.onDestruction: if (counted) SysSample.users--
    function count() {
        if (live && !counted) {
            SysSample.users++;
            counted = true;
        } else if (!live && counted) {
            SysSample.users--;
            counted = false;
        }
    }
    readonly property bool hasBattery: Battery.available || Battery.testing
    readonly property var stats: {
        const out = [
            { label: "CPU", value: s ? s.cpu : -1 },
            { label: "Memory", value: s && s.memTotal ? Math.round(s.memUsed / s.memTotal * 100) : -1 }
        ];
        if (hasBattery)
            out.push({ label: "Battery", value: Battery.percent, warn: Battery.low });
        return out;
    }
    readonly property real colW: width / stats.length
    readonly property int big: Math.max(14, Math.round(Math.min(height * 0.42, colW * 0.42)))

    MouseArea {
        anchors.fill: parent
        enabled: root.live
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openPage("system")
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            // A count, so a new sample keeps the columns (and their motion)
            model: root.stats.length
            Column {
                id: stat
                required property int index
                readonly property var modelData: root.stats[index] ?? { label: "", value: -1 }
                width: root.colW
                rightPadding: Math.round(root.cell * 0.2)
                spacing: Math.round(root.big * 0.08)
                Txt {
                    text: stat.modelData.label
                    caps: true
                    size: Math.max(10, Math.round(root.big * 0.24))
                    color: root.c.mute
                }
                Row {
                    Digits {
                        text: stat.modelData.value < 0 ? "–" : String(stat.modelData.value)
                        size: root.big
                        face: Theme.font.medium
                        color: stat.modelData.warn ? root.c.error : root.c.fg
                    }
                    Txt {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.big * 0.2
                        text: "%"
                        size: Math.round(root.big * 0.4)
                        color: root.c.mute
                    }
                }
                Item {
                    width: stat.width - stat.rightPadding
                    height: Math.max(3, Math.round(root.big * 0.08))
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.c.line
                    }
                    Rectangle {
                        width: parent.width * Math.max(0, stat.modelData.value) / 100
                        height: parent.height
                        radius: height / 2
                        color: stat.modelData.warn ? root.c.error : root.c.fg
                        Behavior on width {
                            NumberAnimation { duration: Motion.slow; easing.type: Motion.easing }
                        }
                    }
                }
            }
        }
    }
}
