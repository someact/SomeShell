import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services
import "../island"
import "../top"

// The desktop as a live card in edit mode: the real wallpaper, the island in
// its style (the real resting content), the dock. Drawn at the screen's own
// size and scaled down, so it looks exactly like the desktop. A click on a
// part opens its tab; the chosen part has an outline (still: nothing moves
// while editing).
Item {
    id: root

    required property var screen         // ShellScreen
    property bool interactive: true
    // Off while a thumbnail is taken
    property bool showChoice: true
    readonly property real sw: screen.width
    readonly property real sh: screen.height
    readonly property real s: width / sw
    readonly property string style: Desktop.style
    readonly property bool sepDock: Desktop.dock.enabled && style !== "dock"
    // The part the open tab edits, outlined on the card
    readonly property Item chosen: !showChoice ? null : Ui.editTab === "island" ? (style === "dock" ? dockBar : islandShape)
        : Ui.editTab === "dock" ? (style === "dock" ? dockBar : sepDock ? dockAlone : null)
        : null

    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: 22
        color: "black"

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

            // Notch / Plain: badge left, tray right, island in the middle
            Rectangle {
                visible: root.style !== "dock"
                x: 16
                y: (Theme.shape.band - 34) / 2
                width: 34
                height: 34
                radius: 17
                color: Theme.ink.bg
                Digits {
                    anchors.centerIn: parent
                    text: "1"
                    size: 16
                }
            }
            Rectangle {
                visible: root.style !== "dock"
                anchors.right: parent.right
                width: trayRow.implicitWidth + 34
                height: Theme.shape.band
                color: Theme.ink.bg
                bottomLeftRadius: Theme.shape.restRadius
                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 12
                    Repeater {
                        model: ["wifi", "bluetooth", "battery_5_bar"]
                        Icon {
                            required property string modelData
                            name: modelData
                            size: 18
                        }
                    }
                }
            }

            Rectangle {
                id: islandShape
                visible: root.style !== "dock"
                x: (root.sw - width) / 2
                y: root.style === "plain" ? Theme.shape.floatGap : 0
                width: rest.implicitWidth
                height: rest.implicitHeight
                color: Theme.ink.bg
                topLeftRadius: root.style === "plain" ? height / 2 : 0
                topRightRadius: root.style === "plain" ? height / 2 : 0
                bottomLeftRadius: root.style === "plain" ? height / 2 : Theme.shape.restRadius
                bottomRightRadius: root.style === "plain" ? height / 2 : Theme.shape.restRadius
                Rest {
                    id: rest
                    anchors.fill: parent
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
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        Digits {
                            anchors.centerIn: parent
                            text: "1"
                            size: 16
                        }
                    }
                    DockApps {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: false
                    }
                    Rest {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        rightPadding: 8
                        Repeater {
                            model: ["wifi", "bluetooth", "battery_5_bar"]
                            Icon {
                                required property string modelData
                                name: modelData
                                size: 18
                            }
                        }
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
            else
                Ui.editTab = "wallpaper";
        }
    }
}
