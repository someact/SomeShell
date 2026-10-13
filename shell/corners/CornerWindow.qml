import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components

// One pill zone: a top corner, or beside the island (`zone`: left, right,
// islandLeft, islandRight). It shows the parts Config.pills.layout lists for
// the zone, in order (corners/PillParts.qml). Each run of neighboring glass
// parts sits in one frosted pill (thin dividers between its parts); floating
// parts have no background. The window is fixed-size so content changes never
// resize the surface; only the parts take input and only the glass runs blur.
PanelWindow {
    id: win

    required property ShellScreen modelData
    required property string zone
    readonly property bool left: zone === "left" || zone === "islandLeft"
    readonly property var partIds: Config.pills.layout[zone] ?? []
    property alias bar: bar

    screen: modelData
    WlrLayershell.namespace: "someshell:pill"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.left: left
    anchors.right: !left
    // Beside the island: the window reaches the screen center so the bar can
    // follow the island's live width (and clear a notch's ears)
    readonly property bool satellite: zone === "islandLeft" || zone === "islandRight"
    readonly property real islandEdge: UiState.islandWidth / 2 + (Config.island.style === "notch" ? 12 : 0) + gap
    implicitWidth: satellite ? Math.floor(modelData.width / 2) : 640
    implicitHeight: Theme.barHeight + 8
    color: "transparent"

    readonly property int pad: 8          // inside a glass pill, at its ends
    readonly property int gap: 6          // between pills / floating parts

    // Layout of the visible parts: x of each part, the glass runs and the
    // dividers inside them, and the total width
    readonly property var geo: {
        const ps = parts.children.filter(c => c.isPartSlot && c.item && c.item.visible && c.item.implicitWidth > 0);
        const xs = [], runs = [], seps = [];
        let x = 0, prev = null;
        for (const p of ps) {
            const glass = !p.item.floating;
            if (prev === null) {
                if (glass) {
                    runs.push({ x: 0 });
                    x = pad;
                }
            } else if (glass && !prev.item.floating) {
                seps.push(x + pad);
                x += pad * 2 + 1;
            } else {
                if (!prev.item.floating) {
                    x += pad;
                    runs[runs.length - 1].w = x - runs[runs.length - 1].x;
                }
                x += gap;
                if (glass) {
                    runs.push({ x: x });
                    x += pad;
                }
            }
            xs.push(x);
            x += p.item.implicitWidth;
            prev = p;
        }
        if (prev && !prev.item.floating) {
            x += pad;
            runs[runs.length - 1].w = x - runs[runs.length - 1].x;
        }
        return { parts: ps, xs: xs, runs: runs, seps: seps, width: x };
    }

    mask: Region {
        item: bar
    }
    Region {
        id: blurArea
        RunRegion { glass: run0 }
        RunRegion { glass: run1 }
    }
    // Only with a glass run on the surface: an empty region blurs the whole window
    BackgroundEffect.blurRegion: Theme.blur && win.geo.runs.length > 0 && bar.y + bar.height > 4 ? blurArea : null

    Item {
        id: bar
        x: win.satellite ? (win.left ? win.width - win.islandEdge - width : win.islandEdge) : (win.left ? 6 : win.width - width - 6)
        y: UiState.hidden ? -height - 4 : 3
        height: Theme.barHeight - 6
        width: win.geo.width
        Behavior on width {
            Spring { preset: "snappy" }
        }
        Behavior on y {
            Spring { preset: "snappy" }
        }

        RunGlass {
            id: run0
            run: win.geo.runs[0] ?? null
        }
        RunGlass {
            id: run1
            run: win.geo.runs[1] ?? null
        }
        Repeater {
            model: win.geo.seps
            Rectangle {
                required property real modelData
                x: modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Theme.outlineVariant
                Behavior on x {
                    Spring { preset: "snappy" }
                }
            }
        }

        PillParts {
            id: registry
            win: win
        }

        // The parts, one slot per id in this zone
        Item {
            id: parts
            anchors.fill: parent
            function xOf(item) {
                const i = win.geo.parts.indexOf(item);
                return i >= 0 ? win.geo.xs[i] : 0;
            }
            Repeater {
                model: win.partIds
                Loader {
                    id: slot
                    required property string modelData
                    readonly property bool isPartSlot: true
                    sourceComponent: registry[modelData] ?? null
                    x: parts.xOf(slot)
                    width: item ? item.implicitWidth : 0
                    height: parent.height
                    Behavior on x {
                        Spring { preset: "snappy" }
                    }
                }
            }
        }
    }

    // A run's frost in window coordinates, inset 1 px like Glass.frost. Bound to
    // the run's own x: a Region following `item` updates only when that item's
    // geometry changes, so a run sliding at a fixed width (the title, when the
    // workspaces before it shrink) left its blur behind.
    component RunRegion: Region {
        required property RunGlass glass
        readonly property int inset: 1
        x: Math.ceil(bar.x + glass.x) + inset
        y: Math.ceil(bar.y + glass.y) + inset
        width: glass.visible ? Math.max(0, Math.floor(glass.width) - inset * 2) : 0
        height: glass.visible ? Math.max(0, Math.floor(glass.height) - inset * 2) : 0
        radius: glass.frostRadius
    }

    component RunGlass: Glass {
        property var run: null
        visible: run !== null
        x: run?.x ?? 0
        width: run?.w ?? 0
        height: parent.height
        Behavior on x {
            Spring { preset: "snappy" }
        }
        Behavior on width {
            Spring { preset: "snappy" }
        }
    }
}
