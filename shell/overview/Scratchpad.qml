import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components

// The scratchpad (special workspace, Super+S) in the overview: a drawer
// under the ten pages, on their grid. The label sits where column 1 is, the
// band spans the other columns and holds the scratchpad's windows as chips.
// It only draws; Overview.qml handles the mouse and asks what is under a point.
Item {
    id: root

    property var wins: []            // [{ address, name, icon, title }], most recent first
    property string shownOn: ""      // the monitor showing it, "" when hidden
    property bool onHere: false
    property bool selected: false
    property bool hovered: false
    property string hoverWin: ""
    property string dragWin: ""
    property bool dropTarget: false
    property real labelW: 320        // one page's width (column 1)
    property real gap: 32
    property real u: 1
    readonly property var pal: Theme.paper
    readonly property alias band: band

    implicitHeight: 56 * u

    // ---- Label, where column 1 sits ------------------------------------
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelW
        spacing: 8 * root.u
        Row {
            spacing: 12 * root.u
            Txt {
                anchors.baseline: spName.baseline
                text: "SP"
                size: Math.round(22 * root.u)
                face: Theme.font.medium
                color: root.onHere || root.selected ? root.pal.fg : root.pal.mute
            }
            Txt {
                id: spName
                text: "Scratchpad"
                caps: true
                size: Math.round(20 * root.u)
                face: Theme.font.bold
                font.letterSpacing: size * 0.14
                color: root.pal.fg
            }
        }
        Row {
            spacing: 10 * root.u
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: (root.selected ? 28 : 14) * root.u
                height: 1
                color: root.selected ? root.pal.fg : root.pal.line
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.selected ? "Enter: show" : "Super + S" + (root.wins.length ? "  ·  " + root.wins.length + (root.wins.length > 1 ? " windows" : " window") : "")
                caps: true
                size: Math.round(10 * root.u)
                color: root.pal.mute
            }
        }
    }

    // ---- The band ---------------------------------------------------------
    Rectangle {
        id: band
        x: root.labelW + root.gap
        width: root.width - x
        height: root.height
        radius: 12 * root.u
        color: root.pal.bg
        clip: true

        readonly property real pad: 7 * root.u
        readonly property real padX: 18 * root.u
        readonly property real chipGap: 8 * root.u
        readonly property real chipsW: pill.x - padX - pad
        readonly property real chipW: root.wins.length ? Math.max(150 * root.u, Math.min(260 * root.u, (chipsW - (root.wins.length - 1) * chipGap) / root.wins.length)) : 0

        // Windows as chips
        Repeater {
            model: root.wins
            Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool inverted: root.hoverWin === modelData.address && root.dragWin === ""
                readonly property bool lifted: root.dragWin === modelData.address
                readonly property rect r: root.chipRect(index)
                visible: r.x + r.width <= band.pill.x - band.pad + 1
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                radius: 7 * root.u
                color: lifted ? "transparent" : inverted ? root.pal.fg : root.pal.raised
                border.width: 1
                border.color: lifted ? root.pal.mute : inverted ? root.pal.fg : root.pal.line
                opacity: lifted ? 0.6 : 1
                Row {
                    visible: !chip.lifted
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8 * root.u
                    spacing: 8 * root.u
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28 * root.u
                        height: 28 * root.u
                        radius: 7 * root.u
                        color: root.pal.bg
                        IconImage {
                            anchors.centerIn: parent
                            visible: chip.modelData.icon !== ""
                            implicitSize: Math.round(18 * root.u)
                            source: chip.modelData.icon ? Quickshell.iconPath(chip.modelData.icon, true) : ""
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: chip.width - 52 * root.u
                        spacing: 2 * root.u
                        Txt {
                            width: parent.width
                            text: chip.modelData.name
                            size: Math.round(11 * root.u)
                            face: Theme.font.medium
                            color: chip.inverted ? root.pal.bg : root.pal.fg
                        }
                        Txt {
                            width: parent.width
                            text: chip.modelData.title
                            size: Math.round(10 * root.u)
                            opacity: 0.7
                            color: chip.inverted ? root.pal.bg : root.pal.fg
                        }
                    }
                }
            }
        }
        // More than fit: how many are left out
        Txt {
            readonly property int fit: Math.max(0, Math.floor((band.chipsW + band.chipGap) / (band.chipW + band.chipGap)))
            visible: root.wins.length > fit && !root.dropTarget
            anchors.verticalCenter: parent.verticalCenter
            x: band.padX + fit * (band.chipW + band.chipGap)
            text: "+" + (root.wins.length - fit)
            size: Math.round(12 * root.u)
            face: Theme.font.medium
            color: root.pal.mute
        }

        // Empty: how to fill it
        Row {
            visible: root.wins.length === 0 && !root.dropTarget
            anchors.verticalCenter: parent.verticalCenter
            x: 20 * root.u
            spacing: 12 * root.u
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                size: Math.round(18 * root.u)
                color: root.pal.mute
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Empty  ·  Super + Alt + S or drag a window here"
                caps: true
                size: Math.round(10 * root.u)
                color: root.pal.mute
            }
        }

        // A window dragged over it
        Rectangle {
            anchors.fill: parent
            visible: root.dropTarget
            color: root.pal.bg
            opacity: 0.6
        }
        Txt {
            visible: root.dropTarget
            anchors.verticalCenter: parent.verticalCenter
            x: 20 * root.u
            text: "Drop: send to the scratchpad"
            caps: true
            size: Math.round(10 * root.u)
            color: root.pal.fg
        }

        // Where it is shown, like a page's monitor pill
        readonly property alias pill: pill
        Rectangle {
            id: pill
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.u
            anchors.verticalCenter: parent.verticalCenter
            width: pillRow.implicitWidth + 20 * root.u
            height: 24 * root.u
            radius: height / 2
            color: root.onHere ? root.pal.accent : "transparent"
            border.width: root.onHere ? 0 : 1
            border.color: root.pal.line
            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 6 * root.u
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.shownOn ? "desktop_windows" : "visibility_off"
                    filled: true
                    size: Math.round(14 * root.u)
                    color: root.onHere ? root.pal.onAccent : root.pal.mute
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shownOn || "Hidden"
                    caps: true
                    size: Math.round(10 * root.u)
                    color: root.onHere ? root.pal.onAccent : root.pal.mute
                }
            }
        }

        // The drawer's pull, on the top edge
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3 * root.u
            width: 36 * root.u
            height: 3 * root.u
            radius: height / 2
            color: root.hovered || root.selected ? root.pal.mute : root.pal.line
        }

        CornerMarks {
            anchors.fill: parent
            visible: (root.hovered || root.selected) && !root.dropTarget
            u: root.u
            inset: 5 * root.u
            color: root.selected ? root.pal.accent : root.pal.mute
        }
    }

    // The outline: shown here 2 px accent, hovered lighter, a drop target dashed
    Shape {
        x: band.x
        width: band.width
        height: band.height
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.onHere || root.dropTarget ? 2 : 1
            strokeColor: root.dropTarget ? root.pal.mute : root.onHere ? root.pal.accent : root.hovered ? root.pal.mute : root.pal.line
            strokeStyle: root.dropTarget ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [4, 3]
            PathRectangle {
                x: 0.5
                y: 0.5
                width: band.width - 1
                height: band.height - 1
                radius: band.radius
            }
        }
    }
    // The keys' place: an outline a little outside
    Rectangle {
        visible: root.selected && !root.onHere
        x: band.x - 6 * root.u
        y: -6 * root.u
        width: band.width + 12 * root.u
        height: band.height + 12 * root.u
        radius: band.radius + 6 * root.u
        color: "transparent"
        border.width: 1
        border.color: root.pal.mute
    }

    // Chip i in the band's coordinates
    function chipRect(i) {
        return Qt.rect(band.padX + i * (band.chipW + band.chipGap), band.pad, band.chipW, height - 2 * band.pad);
    }
    // The window under a point in the band's coordinates
    function windowAt(px, py) {
        for (let i = 0; i < wins.length; i++) {
            const r = chipRect(i);
            if (r.x + r.width > band.pill.x - band.pad + 1)
                break;
            if (px >= r.x && py >= r.y && px <= r.x + r.width && py <= r.y + r.height)
                return wins[i];
        }
        return null;
    }
}
