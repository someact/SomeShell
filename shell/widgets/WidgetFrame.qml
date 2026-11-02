import QtQuick
import qs.core

// One widget: its card (when it has one) and its kind's file, loaded once
// (a widget never changes kind). The kind file gets `widget` (the entry),
// `live`, `cell` (the grid's cell size, for type sizes) and `c` (its
// colors: the desktop set on a card, Theme.onWall for bare type).
Item {
    id: frame

    property var widget: null
    property bool live: true
    property real cell: 80
    readonly property bool card: widget?.card === true
    readonly property real pad: card ? Math.round(cell * 0.24) : 0

    // A right click opens edit mode with this widget chosen (left clicks
    // the widget does not use fall through to the desktop)
    MouseArea {
        anchors.fill: parent
        enabled: frame.live
        acceptedButtons: Qt.RightButton
        onClicked: Ui.edit("widgets", frame.widget?.id ?? "")
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.card
        radius: Math.min(30, Math.round(frame.cell * 0.32))
        color: Theme.paper.bg
    }

    readonly property var files: ({
        clock: "ClockWidget.qml", text: "TextWidget.qml", media: "MediaWidget.qml",
        calendar: "CalendarWidget.qml", system: "SystemWidget.qml"
    })
    // Set imperatively (never bind both source and sourceComponent)
    Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: frame.pad
        Component.onCompleted: {
            const f = frame.files[frame.widget?.kind ?? ""];
            if (f)
                setSource(f);
        }
    }
    Binding { target: loader.item; property: "widget"; value: frame.widget; when: loader.item !== null }
    Binding { target: loader.item; property: "live"; value: frame.live; when: loader.item !== null }
    Binding { target: loader.item; property: "cell"; value: frame.cell; when: loader.item !== null }
    Binding { target: loader.item; property: "card"; value: frame.card; when: loader.item !== null }
    Binding { target: loader.item; property: "c"; value: frame.card ? Theme.paper : Theme.onWall; when: loader.item !== null }
}
