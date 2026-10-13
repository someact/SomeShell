import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.core
import qs.components
import qs.services

// Every corner-pill part, by id: workspaces, special, title, tray, status,
// clock. A CornerWindow instantiates the ones its zone lists
// (Config.pills.layout), in that order.
QtObject {
    id: root

    required property var win     // the CornerWindow (tray menus anchor to it)

    // The active workspace's shape: the one picked in Settings, or with
    // "dynamic" a fixed shape per workspace number (stable, so a workspace
    // always looks the same and switching morphs between them)
    readonly property var dynamicShapes: ["cookie4Sided", "clover4Leaf", "cookie7Sided", "sunny", "flower", "softBurst", "pentagon", "cookie9Sided", "clover8Leaf", "puffy"]
    function wsShape(id) {
        const s = Config.pills.workspaceShape;
        return s === "dynamic" ? dynamicShapes[((id - 1) % 10 + 10) % 10] : s;
    }

    property SystemClock time: SystemClock {
        precision: SystemClock.Minutes
    }

    readonly property Component workspaces: Component {
        PillPart {
            id: wsPart
            style: Config.pills.workspaces
            spacing: 0

            // Every workspace as its shape: after Super is held for one second
            // (pills.superPeek), or while the pointer rests on the part
            // (pills.hoverPeek). The hover waits a moment
            // before showing and a little longer before going, so passing over or
            // the part growing under the cursor does not flicker.
            property bool hoverPeek: false
            readonly property bool peek: UiState.superPeek || hoverPeek && Config.pills.hoverPeek

            HoverHandler {
                id: wsHover
                enabled: Config.pills.hoverPeek
                onHoveredChanged: {
                    wsHoverDelay.interval = hovered ? 150 : 300;
                    wsHoverDelay.restart();
                }
            }
            Timer {
                id: wsHoverDelay
                onTriggered: wsPart.hoverPeek = wsHover.hovered
            }

            Repeater {
                model: HyprData.groupSize
                Item {
                    id: ws
                    required property int index
                    readonly property int wsId: HyprData.groupStart + index
                    readonly property bool isActive: HyprData.activeId === wsId
                    readonly property bool isOccupied: {
                        Hyprland.workspaces.values; // re-evaluate on workspace list changes
                        return HyprData.occupied(wsId);
                    }
                    // Only workspaces with windows and the active one (unless "show empty"
                    // is on, or the part peeks). The 10 slots stay; a hidden one springs
                    // to zero width, so nothing is rebuilt and they slide in and out.
                    readonly property bool shown: isActive || isOccupied || Config.pills.showEmpty || wsPart.peek
                    width: !shown ? 0 : (wsPart.peek ? 21 : isActive ? 22 : 10) + 2
                    height: 20
                    opacity: shown ? 1 : 0
                    scale: shown ? 1 : 0.4
                    Behavior on width {
                        Spring { preset: "snappy" }
                    }
                    Behavior on scale {
                        Spring { preset: "snappy" }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast }
                    }

                    // Expressive: the active workspace morphs from a dot into a Material
                    // shape (root.wsShape) holding its number. A peek (Super held or hover)
                    // turns every slot into that shape with its number: filled when it
                    // has windows, an outline when empty.
                    readonly property bool held: wsPart.peek
                    MaterialShape {
                        anchors.centerIn: parent
                        width: ws.isActive ? 20 : ws.held ? 18 : ws.isOccupied ? 7 : 5
                        height: width
                        shape: ws.isActive || ws.held ? root.wsShape(ws.wsId) : "circle"
                        color: ws.isActive ? Theme.primary : ws.held ? (ws.isOccupied ? wsPart.fg : "transparent") : ws.isOccupied ? wsPart.fg : wsPart.floating ? wsPart.fgDim : Theme.outlineVariant
                        borderWidth: ws.held && !ws.isActive && !ws.isOccupied ? 1.5 : wsPart.outline ? 1 : 0
                        borderColor: ws.held && !ws.isActive && !ws.isOccupied ? wsPart.fgDim : wsPart.halo
                        Behavior on width {
                            Spring { preset: "snappy" }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Motion.fast }
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        opacity: ws.isActive || ws.held ? 1 : 0
                        visible: opacity > 0
                        text: (ws.wsId - 1) % 10 + 1
                        font.pixelSize: 10
                        font.weight: Theme.font.weightTitle
                        color: ws.isActive ? Theme.fgPrimary : ws.isOccupied ? Theme.surface : wsPart.fgDim
                        style: !ws.isActive && !ws.isOccupied ? wsPart.textStyle : Text.Normal
                        styleColor: wsPart.halo
                        Behavior on opacity {
                            NumberAnimation { duration: Motion.fast }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: ws.shown
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprData.focusWorkspace(ws.wsId)
                    }
                }
            }

            WheelHandler {
                onWheel: event => HyprData.focusWorkspace(event.angleDelta.y > 0 ? "r-1" : "r+1")
            }
        }
    }

    readonly property Component special: Component {
        PillPart {
            id: specialPart
            // Special workspaces (scratchpads) that hold windows: a star chip each,
            // its shape lit while open on this monitor; click opens or closes it
            readonly property var specials: Hyprland.workspaces.values.filter(w => w.id < 0 && w.toplevels.values.length > 0)
            style: Config.pills.workspaces
            shown: specials.length > 0
            spacing: 2

            Repeater {
                model: specialPart.specials
                Row {
                    id: sp
                    required property HyprlandWorkspace modelData
                    readonly property string label: modelData.name.replace(/^special:/, "")
                    readonly property bool open: (HyprData.special[root.win.modelData.name] ?? "") === modelData.name
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    ShapeIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "star"
                        size: 13
                        padding: 3
                        shape: Config.pills.workspaceShape === "dynamic" ? "cookie12Sided" : Config.pills.workspaceShape
                        active: sp.open
                        halo: specialPart.outline
                        iconColor: specialPart.fg
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sp.label !== "special"
                        text: sp.label
                        font.pixelSize: Theme.font.small
                        color: specialPart.fg
                        style: specialPart.textStyle
                        styleColor: specialPart.halo
                    }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: HyprData.toggleSpecial(sp.label)
                    }
                }
            }
        }
    }

    readonly property Component title: Component {
        PillPart {
            id: titlePart
            style: Config.pills.title
            shown: HyprData.activeTitle !== ""
            spacing: 6

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: HyprData.activeAppId !== "" ? HyprData.appIcon(HyprData.activeAppId) : ""
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                text: HyprData.activeTitle
                color: titlePart.fg
                style: titlePart.textStyle
                styleColor: titlePart.halo
                font.pixelSize: Theme.font.small
            }
        }
    }

    readonly property Component tray: Component {
        PillPart {
            id: trayPart
            style: Config.pills.tray
            shown: Tray.items.length > 0

            Repeater {
                model: Tray.items
                MouseArea {
                    id: trayItem
                    required property SystemTrayItem modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (event.button === Qt.RightButton || modelData.onlyMenu) {
                            if (modelData.hasMenu) {
                                const p = mapToItem(root.win.contentItem, 0, height + 6);
                                modelData.display(root.win, p.x, p.y);
                            }
                        } else {
                            modelData.activate();
                        }
                    }
                    onWheel: event => modelData.scroll(event.angleDelta.y / 120, false)
                    IconImage {
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                    }
                }
            }
        }
    }

    readonly property Component status: Component {
        PillPart {
            id: statusPart
            style: Config.pills.status

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: KbLayout.code
                visible: text !== ""
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
                color: statusPart.fg
                style: statusPart.textStyle
                styleColor: statusPart.halo
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: KbLayout.next()
                }
            }
            StatusIcon {
                part: statusPart
                name: Network.icon
                detail: "wifi"
            }
            StatusIcon {
                part: statusPart
                name: BluetoothState.icon
                visible: BluetoothState.available
                dim: !BluetoothState.enabled
                detail: "bluetooth"
            }
            // Only while WARP is connected (or connecting, dimmed)
            StatusIcon {
                part: statusPart
                name: "vpn_lock"
                visible: Warp.connected || Warp.connecting
                dim: Warp.connecting
                detail: "warp"
            }
            StatusIcon {
                part: statusPart
                name: Audio.icon
                detail: "mixer"
                onWheel: up => Audio.setVolume(Audio.volume + (up ? 0.02 : -0.02))
                onMiddle: Audio.toggleMute()
            }
            // Laptops only (Battery.available): icon and percent; right-click
            // opens the Power page of the settings app
            Row {
                visible: Battery.available
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                StatusIcon {
                    part: statusPart
                    name: Battery.icon
                    settings: "power"
                    color: Battery.low ? Theme.error : statusPart.fg
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.percent + "%"
                    font.pixelSize: Theme.font.small
                    font.weight: Theme.font.weightTitle
                    color: Battery.low ? Theme.error : statusPart.fg
                    style: statusPart.textStyle
                    styleColor: statusPart.halo
                }
            }
        }
    }

    readonly property Component clock: Component {
        PillPart {
            id: clockPart
            style: Config.pills.clock

            Label {
                anchors.verticalCenter: parent.verticalCenter
                // The island shows the time while idle; don't repeat it here
                text: UiState.ambient === "clock" ? Qt.formatDateTime(root.time.date, Config.clock.dateFormat) : Qt.formatDateTime(root.time.date, Config.clock.dateFormat + "  " + Config.clock.format)
                font.pixelSize: Theme.font.small
                font.weight: Theme.font.weightTitle
                color: clockPart.fg
                style: clockPart.textStyle
                styleColor: clockPart.halo
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggle("notifications")
                }
            }
        }
    }

    component StatusIcon: Icon {
        id: si
        required property PillPart part
        property bool dim: false
        signal wheel(bool up)
        signal middle
        property string detail                // right-click: this Control page ("mixer" opens the mixer)
        property string settings              // right-click: this settings app page instead
        anchors.verticalCenter: parent.verticalCenter
        size: 16
        color: dim ? part.fgDim : part.fg
        style: part.textStyle
        styleColor: part.halo
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.MiddleButton)
                    si.middle();
                else if (event.button === Qt.RightButton && si.settings !== "")
                    Session.openSettings(si.settings);
                else if (event.button === Qt.RightButton && si.detail === "mixer")
                    UiState.toggle("mixer");
                else if (event.button === Qt.RightButton && si.detail !== "")
                    UiState.openControl(si.detail);
                else
                    UiState.toggle("control");
            }
            onWheel: event => si.wheel(event.angleDelta.y > 0)
        }
    }
}
