import QtQuick
import qs.core
import qs.components
import qs.services
import "../../widgets"

// Widgets. Nothing chosen: the drawer, a live preview of each kind; drag one
// onto the card, or click it to add it at the first free place. A widget
// chosen (a click on the card): its options, card on/off and remove.
Item {
    id: root
    property string tab

    readonly property var scr: Widgets.screenNamed(Ui.monitor)
    readonly property var g: scr ? Widgets.grid(scr.width, scr.height) : Widgets.grid(1920, 1080)
    readonly property var entry: Widgets.find(Ui.editWidget)
    readonly property var kind: entry ? Widgets.kind(entry.kind) : null

    function opt(key, value) {
        Editor.record();
        Widgets.setOpt(entry.id, key, value);
    }

    // --- the drawer ---
    Flickable {
        id: drawer
        visible: root.entry === null
        anchors.fill: parent
        contentWidth: kinds.implicitWidth
        flickableDirection: Flickable.HorizontalFlick
        clip: true
        interactive: Ui.drawerDrag === null

        Row {
            id: kinds
            spacing: 12
            Repeater {
                model: Widgets.kinds
                Item {
                    id: tile
                    required property var modelData
                    width: 150
                    height: drawer.height

                    Rectangle {
                        id: box
                        width: parent.width
                        height: parent.height - name.height - 6
                        radius: 14
                        color: mouse.containsMouse ? Theme.ink.raised : "transparent"
                        border.width: 1
                        border.color: Theme.ink.line
                        clip: true

                        // The kind at its first size, scaled to the box
                        Item {
                            readonly property real fw: tile.modelData.size[0] * root.g.cell
                            readonly property real fh: tile.modelData.size[1] * root.g.cell
                            anchors.centerIn: parent
                            width: fw
                            height: fh
                            scale: Math.min((box.width - 20) / fw, (box.height - 20) / fh)
                            WidgetFrame {
                                anchors.fill: parent
                                live: false
                                cell: root.g.cell
                                widget: ({ id: "", kind: tile.modelData.id, card: tile.modelData.card, opts: tile.modelData.opts })
                            }
                        }
                    }
                    Row {
                        id: name
                        anchors.top: box.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tile.modelData.icon
                            size: 16
                            color: Theme.ink.mute
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.modelData.label
                            caps: true
                            color: Theme.ink.fg
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.modelData.size[0] + "×" + tile.modelData.size[1]
                            caps: true
                            color: Theme.ink.mute
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Ui.drawerDrag ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        property point start
                        property bool dragging: false
                        onPressed: m => {
                            start = Qt.point(m.x, m.y);
                            dragging = false;
                        }
                        onPositionChanged: m => {
                            if (!pressed)
                                return;
                            if (!dragging && Math.abs(m.x - start.x) + Math.abs(m.y - start.y) < 8)
                                return;
                            dragging = true;
                            const p = mapToItem(null, m.x, m.y);
                            Ui.drawerDrag = { kind: tile.modelData.id, x: p.x, y: p.y };
                        }
                        onReleased: m => {
                            if (dragging) {
                                const p = mapToItem(null, m.x, m.y);
                                Ui.drawerDrag = null;
                                Ui.drawerDropped(tile.modelData.id, p.x, p.y);
                            } else if (root.scr) {
                                Editor.record();
                                const id = Widgets.addOn(tile.modelData.id, root.scr);
                                if (id)
                                    Ui.editWidget = id;
                            }
                            dragging = false;
                        }
                        onCanceled: {
                            Ui.drawerDrag = null;
                            dragging = false;
                        }
                    }
                }
            }
            Txt {
                width: 160
                anchors.verticalCenter: parent.verticalCenter
                text: "Drag one onto the desktop, or click to add it"
                size: Theme.font.small
                color: Theme.ink.mute
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }

    // --- the chosen widget ---
    Item {
        visible: root.entry !== null
        anchors.fill: parent

        Column {
            id: left
            width: 230
            spacing: 10
            Row {
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.kind?.icon ?? "widgets"
                    size: 20
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kind?.label ?? ""
                    caps: true
                    size: Theme.font.title
                    face: Theme.font.bold
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry ? root.entry.w + "×" + root.entry.h : ""
                    caps: true
                    color: Theme.ink.mute
                }
            }
            Row {
                spacing: 6
                Chip {
                    icon: "crop_square"
                    label: "Card"
                    active: root.entry?.card === true
                    onClicked: { Editor.record(); Widgets.change(root.entry.id, { card: !root.entry.card }); }
                }
                Chip {
                    icon: "delete"
                    label: "Remove"
                    onClicked: {
                        Editor.record();
                        Widgets.remove(root.entry.id);
                        Ui.editWidget = "";
                    }
                }
            }
            Chip {
                icon: "add"
                label: "Add widgets"
                onClicked: Ui.editWidget = ""
            }
            Txt {
                width: parent.width
                text: "Drag to move, the corner to resize, Delete removes"
                size: Theme.font.small
                color: Theme.ink.mute
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        // The kind's own options
        Column {
            anchors.left: left.right
            anchors.leftMargin: 30
            anchors.right: parent.right
            spacing: 10

            // Clock and text: alignment
            Row {
                visible: root.kind?.id === "clock" || root.kind?.id === "text"
                spacing: 6
                Repeater {
                    model: [["left", "format_align_left"], ["center", "format_align_center"], ["right", "format_align_right"]]
                    Chip {
                        required property var modelData
                        icon: modelData[1]
                        label: modelData[0] === "center" ? "Centre" : modelData[0] === "left" ? "Left" : "Right"
                        active: (root.entry?.opts?.align ?? "left") === modelData[0]
                        onClicked: root.opt("align", modelData[0])
                    }
                }
            }
            Chip {
                visible: root.kind?.id === "clock"
                icon: "event"
                label: "Date"
                active: root.entry?.opts?.date !== false
                onClicked: root.opt("date", root.entry?.opts?.date === false)
            }

            // Text: the words and the face
            Field {
                id: words
                visible: root.kind?.id === "text"
                width: Math.min(parent.width, 380)
                placeholder: "Text, Enter"
                readonly property string current: root.entry?.opts?.text ?? ""
                onCurrentChanged: if (text !== current) text = current
                Component.onCompleted: text = current
                onAccepted: t => { if (t !== current) root.opt("text", t); }
            }
            Row {
                visible: root.kind?.id === "text"
                spacing: 6
                Repeater {
                    model: [["light", "Light"], ["regular", "Regular"], ["bold", "Bold"]]
                    Chip {
                        required property var modelData
                        label: modelData[1]
                        active: (root.entry?.opts?.face ?? "bold") === modelData[0]
                        onClicked: root.opt("face", modelData[0])
                    }
                }
            }

            Txt {
                visible: ["media", "calendar", "system"].includes(root.kind?.id ?? "")
                width: parent.width
                text: root.kind?.id === "media" ? "Its buttons control the player; a click elsewhere opens Media"
                    : root.kind?.id === "calendar" ? "‹ › and the wheel change the month; a click on a day opens Calendar"
                    : "A click opens the System page"
                size: Theme.font.small
                color: Theme.ink.mute
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
    }
}
