import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.core

// Touch screen edges (SomeShell.md section 5, "Touch"), loaded only while a
// touch screen exists, on the monitor it maps to (services/Touch.qml). Two
// thin strips; a finger that starts on one keeps it (Wayland gives the touch
// to the surface it began on), so the drag can go far beyond the strip.
//   top     pull down: the island opens on Control and follows the finger;
//           past a third of its height it stays open, else it closes
//   bottom  swipe up: a short swipe shows the dock (Notch and Plain), a long
//           one opens the overview. The mouse on it shows the dock as well
//           (the strip covers the dock's own edge)
// Left and right edges are Hyprland's own workspace swipe (input.lua).
Scope {
    id: root

    required property ShellScreen modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property string name: monitor?.name ?? ""
    readonly property bool docked: Desktop.style === "dock"
    readonly property bool separateDock: Desktop.dock.enabled && !docked

    // Top: inside the band the top bar keeps free of windows, under the bar
    // (Bottom layer), so the badge, tray and island keep their own touches.
    // Dock style has no bar up there: above the windows instead.
    PanelWindow {
        screen: root.modelData
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 12
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "someshell:edge"
        WlrLayershell.layer: root.docked ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        DragHandler {
            id: pull
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            yAxis.minimum: 0
            onActiveChanged: {
                if (active)
                    Ui.pullStart(root.name);
                else if (Ui.pull >= 0)
                    Ui.pullEnd();
            }
            onTranslationChanged: if (active && Ui.pull >= 0) Ui.pull = Math.max(0, translation.y)
        }
    }

    // Bottom: above the windows (a thin strip, like a phone's gesture bar)
    PanelWindow {
        id: bottomEdge
        screen: root.modelData
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        implicitHeight: Theme.shape.floatGap
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "someshell:edge"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property real overviewAt: root.modelData.height * 0.25
        property bool revealed: false

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            onHoveredChanged: if (hovered && root.separateDock) Ui.dockReveal(root.name, false)
        }
        // How far up the finger went (translation reads 0 again by the time
        // the handler ends, so it is kept here)
        property real rise: 0
        DragHandler {
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            onActiveChanged: {
                if (active) {
                    bottomEdge.revealed = false;
                    bottomEdge.rise = 0;
                    return;
                }
                if (bottomEdge.rise >= bottomEdge.overviewAt)
                    Ui.openOverview(root.name);
            }
            onTranslationChanged: {
                if (!active)
                    return;
                bottomEdge.rise = -translation.y;
                if (!bottomEdge.revealed && bottomEdge.rise >= 24 && bottomEdge.rise < bottomEdge.overviewAt) {
                    bottomEdge.revealed = true;
                    if (root.separateDock)
                        Ui.dockReveal(root.name, true);
                }
            }
        }
    }
}
