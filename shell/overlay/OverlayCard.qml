import QtQuick
import qs.core
import qs.components

// A game overlay widget: dark glass card with a title bar to drag it by, a pin
// (stay on screen, click-through, while the overlay is closed) and a close
// button. Positions and pins are saved in config.json under `overlay`.
Item {
    id: root

    required property string widgetId
    property string icon
    property string title
    property bool interactive: true       // false while the overlay is closed
    property point defaultPos: Qt.point(80, 120)
    default property alias content: body.data

    readonly property bool pinned: Config.overlay.pinned.includes(widgetId)
    // Look (overlay.style): glass | solid | minimal, tint opacity, accent, radius, compact
    readonly property var style: Config.overlay.style
    readonly property bool minimal: style.look === "minimal"
    readonly property bool compact: style.compact
    readonly property color accent: style.accent !== "" ? style.accent : Theme.accentIsland
    readonly property color onAccent: style.accent !== "" ? "#101014" : Theme.fgAccentIsland
    // GameOverlay blurs behind the card (open: overlay.blur, pinned: overlay.pinnedBlur)
    readonly property bool frosted: Theme.glass && style.look === "glass" && (interactive ? Config.overlay.blur : Config.overlay.pinnedBlur)
    readonly property var saved: Config.overlay.positions?.[widgetId] ?? null

    implicitWidth: 300
    implicitHeight: header.height + body.childrenRect.height + (compact ? 12 : 24)
    x: saved?.x ?? defaultPos.x
    y: saved?.y ?? defaultPos.y

    function close() {
        Config.overlay.open = Config.overlay.open.filter(w => w !== widgetId);
        Config.overlay.pinned = Config.overlay.pinned.filter(w => w !== widgetId);
    }
    function togglePin() {
        Config.overlay.pinned = pinned ? Config.overlay.pinned.filter(w => w !== widgetId) : [...Config.overlay.pinned, widgetId];
    }
    function savePos() {
        const p = Object.assign({}, Config.overlay.positions ?? {});
        p[widgetId] = { x: Math.round(x), y: Math.round(y) };
        Config.overlay.positions = p;
    }

    // Pop in
    property real shown: 0
    Component.onCompleted: shown = 1
    opacity: shown * (interactive ? 1 : 0.85)
    scale: 0.94 + shown * 0.06
    Behavior on shown {
        Spring { preset: "snappy" }
    }

    // Frosted while the overlay is open (GameOverlay blurs the cards then);
    // pinned and click-through over a game, a plain dark card
    readonly property alias card: card
    Glass {
        id: card
        anchors.fill: parent
        radius: root.style.radius
        // Without frost a glass card needs more tint to stay readable; minimal is
        // only a faint backing (no rim)
        tint: Qt.rgba(0, 0, 0, root.minimal ? (root.interactive ? 0.25 : 0.15) : root.frosted || root.style.look === "solid" ? root.style.opacity : Math.min(0.9, root.style.opacity + 0.25))
        highlight: root.interactive && Config.glass.rim && root.style.look === "glass"
        border.width: root.minimal && !root.interactive ? 0 : 1
        border.color: root.interactive && root.style.look === "glass" ? Theme.glassRim : Qt.rgba(1, 1, 1, 0.05)
    }

    Item {
        id: header
        width: parent.width
        height: root.interactive ? (root.compact ? 32 : 40) : (root.compact ? 24 : 30)
        Row {
            anchors.left: parent.left
            anchors.leftMargin: root.compact ? 10 : 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: root.compact ? 15 : 17
                fill: 1
                color: root.accent
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.styleName: Theme.font.styleTitle
                font.pixelSize: root.compact ? Theme.font.small : Theme.font.normal
                style: root.minimal ? Text.Outline : Text.Normal
                styleColor: Qt.rgba(0, 0, 0, 0.7)
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: root
            drag.threshold: 2
            onReleased: root.savePos()
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.interactive
            IconButton {
                width: 28
                height: 28
                iconSize: 16
                icon: "keep"
                active: root.pinned
                activeColor: root.accent
                iconColor: active ? root.onAccent : Theme.fgIsland
                onClicked: root.togglePin()
            }
            IconButton {
                width: 28
                height: 28
                iconSize: 16
                icon: "close"
                onClicked: root.close()
            }
        }
    }

    Item {
        id: body
        x: root.compact ? 10 : 14
        y: header.height
        width: parent.width - (root.compact ? 20 : 28)
        height: childrenRect.height
        enabled: root.interactive
    }
}
