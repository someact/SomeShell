import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services
import "../island"
import "../top"
import "../widgets"

// The desktop as a live card in edit mode: the real wallpaper, the island in
// its style (the real resting content), the dock. Drawn at the screen's own
// size and scaled down, so it looks exactly like the desktop. A click on a
// part opens its tab; the chosen part has an outline (still: nothing moves
// while editing). Widgets: the grid shows in the Widgets tab; drag a widget
// to move it, its corner to resize it, drop one from the drawer.
Item {
    id: root

    required property var screen         // ShellScreen
    readonly property var monitor: Hyprland.monitorFor(screen)
    property bool interactive: true
    // Off while a thumbnail is taken
    property bool showChoice: true
    // The rounded corners' opacity: the edit window passes its zoom, so the
    // corners fade in as the card leaves the screen's own edges
    property real corners: 1
    readonly property real sw: screen.width
    readonly property real sh: screen.height
    readonly property real s: width / sw
    readonly property string style: Desktop.style
    readonly property bool sepDock: Desktop.dock.enabled && style !== "dock"
    // The part the open tab edits, outlined on the card
    readonly property bool widgetsTab: Ui.editTab === "widgets"
    // Workspaces tab: the island shows the chosen number's design
    readonly property bool spacesTab: Ui.editTab === "workspaces"
    readonly property string restKind: spacesTab ? (Spaces.design(Spaces.editSlot)?.rest ?? "clock") : Spaces.rest
    readonly property var flash: spacesTab ? Spaces.cardFlash : null
    readonly property Item chosen: !showChoice ? null : Ui.editTab === "island" || spacesTab ? (style === "dock" ? dockBar : islandShape)
        : Ui.editTab === "dock" ? (style === "dock" ? dockBar : sepDock ? dockAlone : null)
        : null

    // A plain rectangle with a square clip. A ClippingRectangle draws the
    // whole card into a texture that is made again on every frame of the
    // zoom (the card's size changes): about 12 fps on the tablet. The round
    // corners are painted over it instead (below).
    Rectangle {
        id: frame
        anchors.fill: parent
        readonly property real radius: 22
        color: "black"
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.path ? "file://" + Wallpaper.path : ""
            // Decoded once at the screen's size: a size that follows the
            // card would decode again on every frame of the zoom
            sourceSize: Qt.size(root.sw, root.sh)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // The screen at full size, scaled down
        Item {
            id: desk
            width: root.sw
            height: root.sh
            scale: root.s
            transformOrigin: Item.TopLeft

            // The grid (Widgets tab): a dot at every cell corner
            Item {
                visible: root.widgetsTab && root.showChoice
                Repeater {
                    model: (wl.g.cols + 1) * (wl.g.rows + 1)
                    Rectangle {
                        required property int index
                        readonly property real d: 4 / root.s
                        x: wl.g.ox + (index % (wl.g.cols + 1)) * wl.g.cell - d / 2
                        y: wl.g.oy + Math.floor(index / (wl.g.cols + 1)) * wl.g.cell - d / 2
                        width: d
                        height: d
                        radius: d / 2
                        color: Theme.paper.fg
                        opacity: 0.35
                    }
                }
            }

            WidgetLayer {
                id: wl
                screen: root.screen
                live: false
            }

            // Where a moved, resized or dropped widget will land
            Rectangle {
                id: landing
                property rect r: Qt.rect(0, 0, 0, 0)
                visible: r.width > 0
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                radius: Math.min(30, wl.g.cell * 0.32)
                color: Qt.rgba(Theme.ink.accent.r, Theme.ink.accent.g, Theme.ink.accent.b, 0.18)
                border.width: 2 / root.s
                border.color: Theme.ink.accent
            }

            // The chosen widget: an outline and the resize handle
            Item {
                id: picked
                readonly property var entry: root.showChoice && root.widgetsTab && wl.moveId === "" ? wl.list.find(w => w.id === Ui.editWidget) ?? null : null
                readonly property rect r: entry ? Widgets.rect(wl.g, entry.x, entry.y, wl.sizeId ? wl.sizeW : entry.w, wl.sizeId ? wl.sizeH : entry.h) : Qt.rect(0, 0, 0, 0)
                visible: entry !== null
                x: r.x - 5 / root.s
                y: r.y - 5 / root.s
                width: r.width + 10 / root.s
                height: r.height + 10 / root.s
                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(30, wl.g.cell * 0.32) + 5 / root.s
                    color: "transparent"
                    border.width: 2 / root.s
                    border.color: Theme.ink.accent
                }
                Rectangle {
                    id: handle
                    readonly property real d: 22 / root.s
                    x: parent.width - d * 0.7
                    y: parent.height - d * 0.7
                    width: d
                    height: d
                    radius: d / 2
                    color: Theme.ink.accent
                    border.width: 2 / root.s
                    border.color: Theme.ink.onAccent
                }
            }

            // Notch / Plain: badge left, tray right, island in the middle.
            // The real ones, so the card shows this monitor's workspace and
            // only the status this machine has (clicks stay with the card)
            Badge {
                visible: root.style !== "dock"
                monitor: root.monitor
                x: 16
                y: (Theme.shape.band - height) / 2
            }
            Tray {
                visible: root.style !== "dock"
                anchors.right: parent.right
            }

            Rectangle {
                id: islandShape
                visible: root.style !== "dock"
                x: (root.sw - width) / 2
                y: root.style === "plain" ? Theme.shape.floatGap : 0
                width: root.flash ? cardFlash.implicitWidth : rest.implicitWidth
                height: root.flash ? cardFlash.implicitHeight : rest.implicitHeight
                color: Theme.ink.bg
                topLeftRadius: root.style === "plain" ? height / 2 : 0
                topRightRadius: root.style === "plain" ? height / 2 : 0
                bottomLeftRadius: root.style === "plain" ? height / 2 : Theme.shape.restRadius
                bottomRightRadius: root.style === "plain" ? height / 2 : Theme.shape.restRadius
                Rest {
                    id: rest
                    visible: !root.flash
                    anchors.fill: parent
                    kind: root.restKind
                }
                Flash {
                    id: cardFlash
                    visible: root.flash !== null
                    anchors.fill: parent
                    f: root.flash
                }
                // Notch: the tab curves into the top edge
                Repeater {
                    model: root.style === "notch" ? 2 : 0
                    Shape {
                        required property int index
                        readonly property real e: Theme.shape.ear
                        x: index === 0 ? -e : islandShape.width
                        width: e
                        height: e
                        preferredRendererType: Shape.CurveRenderer
                        transform: Scale { xScale: index === 0 ? 1 : -1; origin.x: e / 2 }
                        ShapePath {
                            fillColor: Theme.ink.bg
                            strokeWidth: -1
                            startX: 0; startY: 0
                            PathLine { x: e; y: 0 }
                            PathLine { x: e; y: e }
                            PathCubic { x: 0; y: 0; control1X: e; control1Y: e * 0.4477; control2X: e * 0.5523; control2Y: 0 }
                        }
                    }
                }
            }

            // Dock style: one bar on the bottom edge
            Rectangle {
                id: dockBar
                visible: root.style === "dock"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.shape.floatGap
                width: dockRow.implicitWidth + 16
                height: 54
                radius: height / 2
                color: Theme.ink.bg
                Row {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 8
                    Badge {
                        anchors.verticalCenter: parent.verticalCenter
                        monitor: root.monitor
                    }
                    DockApps {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: false
                    }
                    Rest {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: root.restKind
                    }
                    Tray {
                        anchors.verticalCenter: parent.verticalCenter
                        plain: true
                    }
                }
            }

            // The separate dock (Notch and Plain)
            Rectangle {
                id: dockAlone
                visible: root.sepDock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.shape.floatGap
                width: aloneApps.implicitWidth + 16
                height: 54
                radius: height / 2
                color: Theme.ink.bg
                DockApps {
                    id: aloneApps
                    anchors.centerIn: parent
                    enabled: false
                }
            }

            // Outline of the part being edited (drawn at full size, so it
            // stays a crisp 2 px line after scaling)
            Rectangle {
                visible: root.chosen !== null && root.chosen.visible
                x: (root.chosen?.x ?? 0) - 6
                y: (root.chosen?.y ?? 0) - 6
                width: (root.chosen?.width ?? 0) + 12
                height: (root.chosen?.height ?? 0) + 12
                radius: root.chosen === islandShape && root.style === "notch" ? Theme.shape.restRadius + 6 : height / 2
                color: "transparent"
                border.width: 2 / root.s
                border.color: Theme.ink.accent
            }
        }

        // The rounded corners: the outside of each corner in the edit
        // window's background color (left out of preset thumbnails)
        Repeater {
            model: root.showChoice && root.corners > 0 ? 4 : 0
            Shape {
                required property int index
                readonly property real e: frame.radius
                x: index % 2 === 0 ? 0 : frame.width - e
                y: index < 2 ? 0 : frame.height - e
                width: e
                height: e
                opacity: root.corners
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {
                    xScale: index % 2 === 0 ? 1 : -1
                    yScale: index < 2 ? 1 : -1
                    origin.x: e / 2
                    origin.y: e / 2
                }
                ShapePath {
                    fillColor: Theme.ink.bg
                    strokeWidth: -1
                    startX: 0; startY: 0
                    PathLine { x: e; y: 0 }
                    PathArc { x: 0; y: e; radiusX: e; radiusY: e; direction: PathArc.Counterclockwise }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        // Wallpaper tab: a thin accent frame around the whole card
        Rectangle {
            anchors.fill: parent
            visible: root.showChoice && Ui.editTab === "wallpaper"
            radius: frame.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.ink.accent
        }
    }

    // A click picks the part under it
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        function hit(item, p) {
            if (!item.visible)
                return false;
            const q = item.mapFromItem(root, p.x, p.y);
            return q.x >= -8 && q.y >= -8 && q.x <= item.width + 8 && q.y <= item.height + 8;
        }
        onClicked: mouse => {
            const p = Qt.point(mouse.x, mouse.y);
            if (hit(islandShape, p) || (root.style === "dock" && hit(dockBar, p)))
                Ui.editTab = hit(dockBar, p) && root.style === "dock" && mouse.x < root.width / 2 - 20 ? "dock" : "island";
            else if (hit(dockAlone, p))
                Ui.editTab = "dock";
            else if (root.widgetsTab)
                Ui.editWidget = "";
            else
                Ui.editTab = "wallpaper";
        }
    }

    // Widgets: press on one to choose it, drag to move it, drag the chosen
    // one's corner to resize it. Presses elsewhere go to the click above.
    MouseArea {
        id: wmouse
        anchors.fill: parent
        enabled: root.interactive
        property string wid: ""
        property string mode: ""         // "move" or "size"
        property bool dragging: false
        property point start
        property var orig: null
        property var target: null        // { x, y, w, h } in cells

        function deskPoint(m) {
            return desk.mapFromItem(root, m.x, m.y);
        }
        function within(r, p, pad) {
            return p.x >= r.x - pad && p.y >= r.y - pad && p.x <= r.x + r.width + pad && p.y <= r.y + r.height + pad;
        }
        onPressed: m => {
            const p = deskPoint(m);
            dragging = false;
            target = null;
            // The chosen widget's corner first
            if (picked.visible && within(handle.mapToItem(desk, 0, 0, handle.width, handle.height), p, 6 / root.s)) {
                wid = Ui.editWidget;
                mode = "size";
            } else {
                const hitW = wl.list.slice().reverse().find(w => within(Widgets.rect(wl.g, w.x, w.y, w.w, w.h), p, 0));
                if (!hitW) {
                    m.accepted = false;
                    return;
                }
                wid = hitW.id;
                mode = "move";
                Ui.editTab = "widgets";
                Ui.editWidget = wid;
            }
            orig = Widgets.find(wid);
            start = p;
        }
        onPositionChanged: m => {
            if (!orig)
                return;
            const p = deskPoint(m);
            const dx = p.x - start.x, dy = p.y - start.y;
            if (!dragging && Math.abs(dx) + Math.abs(dy) < 6 / root.s)
                return;
            dragging = true;
            const g = wl.g;
            if (mode === "move") {
                wl.moveId = wid;
                wl.moveDx = dx;
                wl.moveDy = dy;
                const c = Widgets.cellAt(g, g.ox + orig.x * g.cell + dx, g.oy + orig.y * g.cell + dy);
                const at = Widgets.nearest(g, wl.list, wid, c.x, c.y, orig.w, orig.h);
                target = at ? { x: at.x, y: at.y, w: orig.w, h: orig.h } : null;
            } else {
                const k = Widgets.kind(orig.kind);
                const w = Math.max(k.min[0], Math.min(k.max[0], Math.round(orig.w + dx / g.cell)));
                const h = Math.max(k.min[1], Math.min(k.max[1], Math.round(orig.h + dy / g.cell)));
                // Keep the last size that fits
                if (Widgets.fits(g, wl.list, wid, orig.x, orig.y, w, h))
                    target = { x: orig.x, y: orig.y, w: w, h: h };
                else if (!target)
                    target = { x: orig.x, y: orig.y, w: orig.w, h: orig.h };
                wl.sizeId = wid;
                wl.sizeW = target.w;
                wl.sizeH = target.h;
            }
            // Moving: where it lands (resizing shows on the widget itself)
            landing.r = target && mode === "move" ? Widgets.rect(g, target.x, target.y, target.w, target.h) : Qt.rect(0, 0, 0, 0);
        }
        onReleased: {
            if (dragging && target && (target.x !== orig.x || target.y !== orig.y || target.w !== orig.w || target.h !== orig.h || orig.monitor !== root.screen.name)) {
                Editor.record();
                Widgets.change(wid, { x: target.x, y: target.y, w: target.w, h: target.h, monitor: root.screen.name });
            }
            reset();
        }
        onCanceled: reset()
        function reset() {
            wl.moveId = "";
            wl.sizeId = "";
            landing.r = Qt.rect(0, 0, 0, 0);
            orig = null;
            target = null;
            dragging = false;
        }
    }

    // A widget dragged from the drawer: show where it lands, add it on drop
    function drawerTarget(d) {
        if (!d || !root.interactive)
            return null;
        const q = root.mapFromItem(null, d.x, d.y);
        if (q.x < 0 || q.y < 0 || q.x > root.width || q.y > root.height)
            return null;
        const k = Widgets.kind(d.kind);
        const g = wl.g;
        const p = desk.mapFromItem(root, q.x, q.y);
        const c = Widgets.cellAt(g, p.x - k.size[0] * g.cell / 2, p.y - k.size[1] * g.cell / 2);
        const at = Widgets.nearest(g, wl.list, "", c.x, c.y, k.size[0], k.size[1]);
        return at ? { x: at.x, y: at.y, w: k.size[0], h: k.size[1] } : null;
    }
    Connections {
        target: Ui
        enabled: root.interactive
        function onDrawerDragChanged() {
            if (wmouse.orig)
                return;
            const t = root.drawerTarget(Ui.drawerDrag);
            landing.r = t ? Widgets.rect(wl.g, t.x, t.y, t.w, t.h) : Qt.rect(0, 0, 0, 0);
        }
        function onDrawerDropped(kind, x, y) {
            landing.r = Qt.rect(0, 0, 0, 0);
            const t = root.drawerTarget({ kind: kind, x: x, y: y });
            if (!t)
                return;
            Editor.record();
            const id = Widgets.add(kind, root.screen.name, wl.g, wl.list, t.x, t.y);
            if (id)
                Ui.editWidget = id;
        }
    }
}
