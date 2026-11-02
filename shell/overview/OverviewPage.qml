import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// One workspace in the overview: its number and design name, the monitor
// showing it, the page (the wallpaper dimmed, windows as boxes at their real
// place with the app icon, name and title) and a caption. It only draws;
// Overview.qml handles the mouse and asks this page what is under a point.
Item {
    id: root

    required property int n
    property var wins: []            // [{ address, rx, ry, rw, rh, name, icon, title }]
    property string shownOn: ""      // the monitor showing it, "" when hidden
    property bool onHere: false      // shown on the overview's monitor
    property bool current: false     // the workspace you are on
    property bool selected: false    // the page the keys are on
    property bool hovered: false
    property string hoverWin: ""     // the window under the pointer (address)
    property string dragWin: ""      // the window being dragged (address)
    property bool dropTarget: false  // a window is dragged over this page
    property var zones: []           // monitor names, a drop spot each
    property string hotZone: ""      // the spot under the pointer
    property real fw: 320            // page size
    property real fh: 180
    property real u: 1               // size factor of the overview
    property size wallSize: Qt.size(1920, 1080)  // the overview's one wallpaper decode
    readonly property var pal: Theme.paper
    readonly property string name: Spaces.design(n)?.name ?? ""
    readonly property alias frame: frame
    // The name row: a handle to drag the whole page (its windows may fill it)
    readonly property alias label: label

    implicitWidth: fw
    implicitHeight: label.height + 12 * u + fh + 12 * u + caption.height

    // Number, design name, the monitor showing it
    Item {
        id: label
        width: root.fw
        height: 30 * root.u
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.u
            Txt {
                anchors.baseline: nameText.baseline
                text: String(root.n).padStart(2, "0")
                size: Math.round(22 * root.u)
                face: Theme.font.medium
                color: root.current ? root.pal.fg : root.pal.mute
            }
            Txt {
                id: nameText
                width: Math.min(implicitWidth, root.fw - 150 * root.u)
                text: root.name || "—"
                size: Math.round(20 * root.u)
                face: Theme.font.bold
                font.letterSpacing: size * 0.14
                color: root.name ? root.pal.fg : root.pal.line
            }
        }
        Rectangle {
            visible: root.shownOn !== ""
            anchors.right: parent.right
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
                    name: "desktop_windows"
                    filled: true
                    size: Math.round(14 * root.u)
                    color: root.onHere ? root.pal.onAccent : root.pal.mute
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shownOn
                    caps: true
                    size: Math.round(10 * root.u)
                    color: root.onHere ? root.pal.onAccent : root.pal.mute
                }
            }
        }
    }

    // The page
    ClippingRectangle {
        id: frame
        y: label.height + 12 * root.u
        width: root.fw
        height: root.fh
        radius: 12 * root.u
        color: root.pal.bg

        Image {
            anchors.fill: parent
            source: Wallpaper.path ? "file://" + Wallpaper.path : ""
            sourceSize: root.wallSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: root.pal.bg
            opacity: root.wins.length ? 0.55 : 0.72
        }

        // Windows, the most recent on top
        Repeater {
            model: root.wins
            Rectangle {
                id: box
                required property var modelData
                readonly property bool inverted: root.hoverWin === modelData.address && root.dragWin === ""
                readonly property bool lifted: root.dragWin === modelData.address
                x: modelData.rx * root.fw
                y: modelData.ry * root.fh
                width: Math.max(8, modelData.rw * root.fw)
                height: Math.max(8, modelData.rh * root.fh)
                radius: 7 * root.u
                color: lifted ? "transparent" : inverted ? root.pal.fg : root.pal.raised
                border.width: 1
                border.color: lifted ? root.pal.mute : inverted ? root.pal.fg : root.pal.line
                opacity: lifted ? 0.6 : 1
                clip: true
                Column {
                    visible: !box.lifted && box.width > 46 * root.u && box.height > 30 * root.u
                    x: 9 * root.u
                    y: 8 * root.u
                    width: box.width - 18 * root.u
                    spacing: 4 * root.u
                    Row {
                        spacing: 6 * root.u
                        Rectangle {
                            width: 20 * root.u
                            height: 20 * root.u
                            radius: 6 * root.u
                            color: root.pal.bg
                            IconImage {
                                anchors.centerIn: parent
                                visible: box.modelData.icon !== ""
                                implicitSize: Math.round(14 * root.u)
                                source: box.modelData.icon ? Quickshell.iconPath(box.modelData.icon, true) : ""
                            }
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, box.width - 44 * root.u)
                            text: box.modelData.name
                            size: Math.round(11 * root.u)
                            face: Theme.font.medium
                            color: box.lifted ? root.pal.mute : box.inverted ? root.pal.bg : root.pal.fg
                        }
                    }
                    Txt {
                        visible: box.height > 48 * root.u
                        width: parent.width
                        text: box.modelData.title
                        size: Math.round(10 * root.u)
                        opacity: 0.7
                        color: box.inverted ? root.pal.bg : root.pal.fg
                    }
                }
            }
        }

        // Empty
        Column {
            visible: root.wins.length === 0 && !root.dropTarget
            anchors.centerIn: parent
            spacing: 6 * root.u
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "+"
                size: Math.round(22 * root.u)
                color: root.pal.mute
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Empty"
                caps: true
                size: Math.round(10 * root.u)
                color: root.pal.mute
            }
        }

        // A window dragged over this page: the page moves it, a monitor spot
        // also shows the workspace on that monitor
        Item {
            anchors.fill: parent
            visible: root.dropTarget
            Rectangle {
                anchors.fill: parent
                color: root.pal.bg
                opacity: 0.55
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.22
                text: root.hotZone ? "Drop: show on " + root.hotZone : "Drop: move here"
                caps: true
                size: Math.round(10 * root.u)
                color: root.pal.fg
            }
            Repeater {
                model: root.zones
                Rectangle {
                    id: zone
                    required property string modelData
                    required property int index
                    readonly property rect r: root.zoneRect(index)
                    readonly property bool hot: root.hotZone === modelData
                    x: r.x
                    y: r.y
                    width: r.width
                    height: r.height
                    radius: height / 2
                    color: hot ? root.pal.accent : root.pal.bg
                    border.width: hot ? 0 : 1
                    border.color: root.pal.mute
                    Row {
                        anchors.centerIn: parent
                        spacing: 5 * root.u
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "desktop_windows"
                            filled: true
                            size: Math.round(13 * root.u)
                            color: zone.hot ? root.pal.onAccent : root.pal.fg
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: zone.hot ? "Show on " + zone.modelData : zone.modelData
                            caps: true
                            size: Math.round(9 * root.u)
                            color: zone.hot ? root.pal.onAccent : root.pal.fg
                        }
                    }
                }
            }
        }

        // Corner marks: hovered, or the page the keys are on
        CornerMarks {
            anchors.fill: parent
            visible: (root.hovered || root.selected) && !root.dropTarget
            u: root.u
            color: root.selected ? root.pal.accent : root.pal.mute
        }
    }

    // The outline: current 2 px, hovered lighter, a drop target dashed
    Shape {
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        // The default renderer: the curve renderer crashed with a dashed stroke
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.current || root.dropTarget ? 2 : 1
            strokeColor: root.dropTarget ? root.pal.mute : root.current ? root.pal.accent : root.hovered ? root.pal.mute : root.pal.line
            strokeStyle: root.dropTarget ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [4, 3]
            PathRectangle {
                x: 0.5
                y: 0.5
                width: frame.width - 1
                height: frame.height - 1
                radius: frame.radius
            }
        }
    }
    // The keys' page: an outline a little outside
    Rectangle {
        visible: root.selected && !root.current
        x: frame.x - 6 * root.u
        y: frame.y - 6 * root.u
        width: frame.width + 12 * root.u
        height: frame.height + 12 * root.u
        radius: frame.radius + 6 * root.u
        color: "transparent"
        border.width: 1
        border.color: root.pal.mute
    }

    // Caption: a short rule and what this page is
    Row {
        id: caption
        y: frame.y + frame.height + 12 * root.u
        height: 14 * root.u
        spacing: 10 * root.u
        readonly property bool strong: root.current || root.selected
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: (caption.strong ? 28 : 14) * root.u
            height: 1
            color: caption.strong ? root.pal.fg : root.pal.line
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? "You are here" : root.selected ? "Enter: go" : root.wins.length ? root.wins.length + (root.wins.length > 1 ? " windows" : " window") : ""
            caps: true
            size: Math.round(10 * root.u)
            color: root.pal.mute
        }
    }

    // What is under a point given in the page's own coordinates
    function windowAt(px, py) {
        for (let i = wins.length - 1; i >= 0; i--) {
            const w = wins[i];
            const x = w.rx * fw, y = w.ry * fh;
            if (px >= x && py >= y && px <= x + Math.max(8, w.rw * fw) && py <= y + Math.max(8, w.rh * fh))
                return w;
        }
        return null;
    }
    function zoneRect(i) {
        const pad = 8 * u, gap = 6 * u, h = 26 * u;
        const w = (fw - 2 * pad - gap * (zones.length - 1)) / Math.max(1, zones.length);
        return Qt.rect(pad + i * (w + gap), fh - pad - h, w, h);
    }
    function zoneAt(px, py) {
        for (let i = 0; i < zones.length; i++) {
            const r = zoneRect(i);
            if (px >= r.x && py >= r.y && px <= r.x + r.width && py <= r.y + r.height)
                return zones[i];
        }
        return "";
    }
}
