import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Settings 02 Displays: the monitors drawn to scale (drag to arrange, edges
// snap), the chosen one's settings below, and Apply with a 15 s way back
// (services/Displays.qml does the work).
Item {
    id: root

    readonly property var c: Theme.paper
    // Left to right, then top to bottom: the numbers Identify shows
    readonly property var ordered: Displays.draft.slice().sort((a, b) => a.x - b.x || a.y - b.y)
    property string chosen: ""
    readonly property var mon: ordered.find(m => m.desc === chosen) ?? ordered[0] ?? null
    readonly property int onCount: Displays.draft.filter(m => m.on).length

    Component.onCompleted: Displays.refresh()

    Flickable {
        id: flick
        anchors.top: parent.top
        anchors.bottom: bar.top
        width: parent.width
        contentHeight: col.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Wheel and touch scroll; a mouse drag never does (it is for the controls)
        acceptedButtons: Qt.NoButton

        Column {
            id: col
            width: flick.width

            // ── The layout ──
            Item {
                width: parent.width
                height: 64
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    caps: true
                    color: root.c.mute
                    text: (Displays.saved ? "Kept for these monitors" : "Not kept yet") + "  ·  " + root.onCount + " on"
                }
                SetButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "tag"
                    text: "Identify"
                    onClicked: Displays.identify()
                }
            }

            Rectangle {
                id: stage
                width: parent.width
                height: 300
                radius: 16
                color: "transparent"
                border.width: 1
                border.color: root.c.line
                clip: true

                // Fit the whole layout with room around it
                readonly property var bounds: {
                    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                    for (const m of Displays.draft) {
                        const L = Displays.logical(m);
                        x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y);
                        x1 = Math.max(x1, m.x + L.w); y1 = Math.max(y1, m.y + L.h);
                    }
                    return x0 > x1 ? { x0: 0, y0: 0, w: 1920, h: 1080 } : { x0: x0, y0: y0, w: x1 - x0, h: y1 - y0 };
                }
                readonly property real k: Math.min((width - 80) / (bounds.w + 400), (height - 60) / (bounds.h + 160))
                readonly property real ox: (width - bounds.w * k) / 2 - bounds.x0 * k
                readonly property real oy: (height - bounds.h * k) / 2 - bounds.y0 * k

                // Snap lines while dragging
                Rectangle { id: vGuide; visible: false; width: 1; height: stage.height; color: root.c.fg; opacity: 0.6 }
                Rectangle { id: hGuide; visible: false; height: 1; width: stage.width; color: root.c.fg; opacity: 0.6 }

                Repeater {
                    model: root.ordered
                    Rectangle {
                        id: box
                        required property var modelData
                        required property int index
                        readonly property var logi: Displays.logical(modelData)
                        readonly property bool isChosen: root.mon && modelData.desc === root.mon.desc
                        property bool dragging: false
                        property real dragX: 0
                        property real dragY: 0
                        readonly property real lx: dragging ? dragX : modelData.x
                        readonly property real ly: dragging ? dragY : modelData.y

                        x: stage.ox + lx * stage.k
                        y: stage.oy + ly * stage.k
                        width: logi.w * stage.k
                        height: logi.h * stage.k
                        z: dragging ? 2 : 1
                        radius: 8
                        color: isChosen ? root.c.raised : root.c.bg
                        border.width: isChosen ? 2 : 1
                        border.color: isChosen ? root.c.fg : root.c.mute
                        opacity: modelData.on ? 1 : 0.4

                        // Small boxes show only the number and the name
                        readonly property bool roomy: height >= 130
                        Txt {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: box.roomy ? 8 : 0
                            text: box.index + 1
                            size: Math.min(48, parent.height * (box.roomy ? 0.4 : 0.32))
                            face: Theme.font.bold
                            color: root.c.fg
                        }
                        Column {
                            x: 10
                            y: 8
                            width: parent.width - 20
                            Txt {
                                width: parent.width
                                text: box.modelData.name
                                size: Theme.font.small
                                face: Theme.font.medium
                                color: root.c.fg
                            }
                            Txt {
                                visible: box.roomy
                                width: parent.width
                                caps: true
                                size: 10
                                color: root.c.mute
                                text: box.modelData.mirror ? "Mirrors " + box.modelData.mirror
                                    : box.modelData.mode.split("@")[0].replace("x", " × ") + " · " + Math.round(+box.modelData.mode.split("@")[1]) + " Hz"
                            }
                        }
                        Txt {
                            visible: box.modelData.main && box.roomy
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            caps: true
                            size: 10
                            color: root.c.mute
                            text: "Main"
                        }
                        Txt {
                            visible: box.roomy || box.dragging
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            size: 10
                            color: root.c.mute
                            text: Math.round(box.lx) + ", " + Math.round(box.ly)
                        }

                        MouseArea {
                            anchors.fill: parent
                            // The page must not scroll while a monitor is dragged
                            preventStealing: true
                            hoverEnabled: true
                            cursorShape: box.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property point start
                            property real mx
                            property real my
                            property bool pressing: false
                            onPressed: mouse => {
                                root.chosen = box.modelData.desc;
                                if (Displays.waiting)
                                    return;
                                const p = mapToItem(stage, mouse.x, mouse.y);
                                start = Qt.point(p.x, p.y);
                                mx = box.modelData.x;
                                my = box.modelData.y;
                                box.dragX = mx;
                                box.dragY = my;
                                pressing = true;
                            }
                            onPositionChanged: mouse => {
                                if (!pressing)
                                    return;
                                const p = mapToItem(stage, mouse.x, mouse.y);
                                // A click only chooses; moving 4 px starts the drag
                                if (!box.dragging && Math.hypot(p.x - start.x, p.y - start.y) < 4)
                                    return;
                                box.dragging = true;
                                let nx = mx + (p.x - start.x) / stage.k;
                                let ny = my + (p.y - start.y) / stage.k;
                                // Snap to the other monitors' edges
                                const t = 12 / stage.k;
                                let bx = null, by = null;
                                for (const o of Displays.draft) {
                                    if (o.desc === box.modelData.desc)
                                        continue;
                                    const O = Displays.logical(o);
                                    for (const v of [o.x + O.w, o.x - box.logi.w, o.x, o.x + O.w - box.logi.w])
                                        if (Math.abs(nx - v) < t && (bx === null || Math.abs(nx - v) < Math.abs(nx - bx)))
                                            bx = v;
                                    for (const v of [o.y, o.y + O.h - box.logi.h, o.y + O.h, o.y - box.logi.h])
                                        if (Math.abs(ny - v) < t && (by === null || Math.abs(ny - v) < Math.abs(ny - by)))
                                            by = v;
                                }
                                if (bx !== null)
                                    nx = bx;
                                if (by !== null)
                                    ny = by;
                                box.dragX = Math.round(nx);
                                box.dragY = Math.round(ny);
                                vGuide.visible = bx !== null;
                                hGuide.visible = by !== null;
                                if (bx !== null)
                                    vGuide.x = stage.ox + root.edgeX(bx, box.logi.w) * stage.k;
                                if (by !== null)
                                    hGuide.y = stage.oy + root.edgeY(by, box.logi.h) * stage.k;
                            }
                            onCanceled: {
                                pressing = false;
                                box.dragging = false;
                                vGuide.visible = false;
                                hGuide.visible = false;
                            }
                            onReleased: {
                                pressing = false;
                                if (!box.dragging)
                                    return;
                                vGuide.visible = false;
                                hGuide.visible = false;
                                const x = box.dragX, y = box.dragY;
                                box.dragging = false;
                                if (x !== box.modelData.x || y !== box.modelData.y)
                                    Displays.place(box.modelData.desc, x, y);
                            }
                        }
                    }
                }

                Txt {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    caps: true
                    size: 10
                    color: root.c.mute
                    text: "Drag to arrange · edges snap"
                }
            }

            // ── The chosen monitor ──
            Item {
                visible: root.mon !== null
                width: parent.width
                height: 84
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 8
                    spacing: 2
                    Txt {
                        text: root.mon ? (root.ordered.indexOf(root.mon) + 1) + "  ·  " + root.mon.name : ""
                        size: Theme.font.title + 3
                        face: Theme.font.medium
                        color: root.c.fg
                    }
                    Txt {
                        caps: true
                        color: root.c.mute
                        text: root.mon ? [root.mon.make, root.mon.model].filter(s => s).join(" ") + root.inches(root.mon) : ""
                    }
                }
                Switch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 8
                    checked: root.mon?.on ?? false
                    // The last monitor that is on stays on
                    enabled: !Displays.waiting && !(root.mon?.on && root.onCount === 1)
                    onToggled: on => Displays.set(root.mon.desc, "on", on)
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: root.c.line
            }

            Column {
                visible: root.mon !== null && root.mon.on
                width: parent.width

                SetRow {
                    label: "Resolution"
                    Select {
                        width: 260
                        options: {
                            const seen = [];
                            for (const s of root.mon?.modes ?? []) {
                                const r = s.split("@")[0];
                                if (!seen.includes(r))
                                    seen.push(r);
                            }
                            return seen.map(r => ({ value: r, label: r.replace("x", " × ") }));
                        }
                        value: root.mon?.mode.split("@")[0] ?? ""
                        onPicked: v => Displays.set(root.mon.desc, "res", v)
                    }
                }
                SetRow {
                    label: "Refresh rate"
                    Select {
                        width: 260
                        options: {
                            const res = root.mon?.mode.split("@")[0] ?? "";
                            return (root.mon?.modes ?? []).filter(s => s.startsWith(res + "@"))
                                .sort((a, b) => +b.split("@")[1] - +a.split("@")[1])
                                .map(s => {
                                    const hz = +s.split("@")[1];
                                    return { value: s, label: (Math.abs(hz - Math.round(hz)) < 0.02 ? Math.round(hz) : hz.toFixed(2)) + " Hz" };
                                });
                        }
                        value: root.mon?.mode ?? ""
                        onPicked: v => Displays.set(root.mon.desc, "mode", v)
                    }
                }
                SetRow {
                    label: "Scale"
                    Select {
                        width: 260
                        options: root.mon ? Displays.scales(root.mon) : []
                        value: root.mon?.scale ?? 1
                        onPicked: v => Displays.set(root.mon.desc, "scale", v)
                    }
                }
                SetRow {
                    label: "Rotation"
                    IconChoice {
                        options: [
                            { value: 0, icon: "north", label: "Normal" },
                            { value: 1, icon: "east", label: "90°" },
                            { value: 2, icon: "south", label: "180°" },
                            { value: 3, icon: "west", label: "270°" }
                        ]
                        value: root.mon?.transform ?? 0
                        onPicked: v => Displays.set(root.mon.desc, "transform", v)
                    }
                }
                SetRow {
                    visible: root.onCount > 1
                    label: "Mirror"
                    Select {
                        width: 260
                        options: [{ value: "", label: "Off" }].concat(Displays.draft
                            .filter(m => root.mon && m.desc !== root.mon.desc && m.on && !m.mirror)
                            .map(m => ({ value: m.name, label: "Show " + m.name })))
                        value: root.mon?.mirror ?? ""
                        onPicked: v => Displays.set(root.mon.desc, "mirror", v)
                    }
                }
                SetRow {
                    label: "Adaptive sync"
                    IconChoice {
                        options: [
                            { value: 0, icon: "block", label: "Off" },
                            { value: 2, icon: "sports_esports", label: "Games only" },
                            { value: 1, icon: "all_inclusive", label: "Always" }
                        ]
                        value: root.mon?.vrr ?? 2
                        onPicked: v => Displays.set(root.mon.desc, "vrr", v)
                    }
                }
                SetRow {
                    label: "Color depth"
                    IconChoice {
                        options: [
                            { value: 8, text: "8", label: "8-bit" },
                            { value: 10, text: "10", label: "10-bit" }
                        ]
                        value: root.mon?.bits ?? 8
                        onPicked: v => Displays.set(root.mon.desc, "bits", v)
                    }
                }
                SetRow {
                    visible: root.onCount > 1
                    label: "Main display"
                    hint: "The cursor starts here."
                    Switch {
                        checked: root.mon?.main ?? false
                        enabled: !Displays.waiting
                        onToggled: on => Displays.set(root.mon.desc, "main", on)
                    }
                }
            }
        }
    }

    // The edge a snapped position touches (for the guide line): the other
    // monitor's edge it lines up with
    function edgeX(x, w) {
        for (const o of Displays.draft) {
            const O = Displays.logical(o);
            for (const e of [o.x, o.x + O.w])
                if (e === x || e === x + w)
                    return e;
        }
        return x;
    }
    function edgeY(y, h) {
        for (const o of Displays.draft) {
            const O = Displays.logical(o);
            for (const e of [o.y, o.y + O.h])
                if (e === y || e === y + h)
                    return e;
        }
        return y;
    }

    function inches(m) {
        const [w, h] = m.mm ?? [0, 0];
        return w > 0 && h > 0 ? "  ·  " + Math.round(Math.hypot(w, h) / 25.4) + " in" : "";
    }

    // ── Apply, and the way back ──
    Rectangle {
        id: bar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 76
        color: root.c.bg
        Rectangle {
            width: parent.width
            height: 1
            color: root.c.line
        }
        Column {
            anchors.left: parent.left
            anchors.right: buttons.left
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Txt {
                caps: true
                color: Displays.waiting ? root.c.fg : root.c.mute
                text: Displays.waiting ? "Keep these settings? Going back in " + Displays.left
                    : Displays.changes === 0 ? "Nothing changed"
                    : Displays.changes + (Displays.changes === 1 ? " change, not applied" : " changes, not applied")
            }
            Item {
                visible: Displays.waiting
                width: parent.width
                height: 2
                Rectangle {
                    anchors.fill: parent
                    color: root.c.line
                }
                Rectangle {
                    height: parent.height
                    width: parent.width * Displays.left / Displays.timeout
                    color: root.c.fg
                    Behavior on width { NumberAnimation { duration: 1000 } }
                }
            }
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            SetButton {
                visible: !Displays.waiting
                text: "Undo"
                enabled: Displays.changes > 0
                onClicked: Displays.undo()
            }
            SetButton {
                visible: !Displays.waiting
                text: "Apply"
                primary: true
                enabled: Displays.changes > 0
                onClicked: Displays.apply()
            }
            SetButton {
                visible: Displays.waiting
                text: "Go back"
                onClicked: Displays.revert()
            }
            SetButton {
                visible: Displays.waiting
                text: "Keep"
                primary: true
                onClicked: Displays.keep()
            }
        }
    }
}
