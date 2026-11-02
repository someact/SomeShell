import QtQuick
import qs.core
import qs.components
import qs.services

// 05 Calendar. The month as a printed grid (month name big, weekday initials,
// today circled, a dot under days with events) and the chosen day's events
// beside it. Events come from the Calendar service (calendar links and .ics
// files), read when the page opens. The wheel or ‹ › change the month.
Item {
    id: root

    readonly property date today: Clock.now
    // The month shown, as its first day; the chosen day
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    property date chosen: new Date(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property int cell: 44
    readonly property var names: Calendar.sundayFirst ? ["S", "M", "T", "W", "T", "F", "S"] : ["M", "T", "W", "T", "F", "S", "S"]
    // The 42 days on the grid, from the week the month starts in
    readonly property date gridStart: {
        const lead = (month.getDay() - (Calendar.sundayFirst ? 0 : 1) + 7) % 7;
        return new Date(month.getFullYear(), month.getMonth(), 1 - lead);
    }
    // Events on the grid (repeats expanded), and those of the chosen day
    readonly property var shown: Calendar.between(gridStart, new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + 42))
    readonly property var dayEvents: Calendar.onDay(shown, chosen)

    implicitWidth: grid.width + 36 + list.width
    implicitHeight: Math.max(left.implicitHeight, list.implicitHeight)

    Component.onCompleted: Calendar.refresh()

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function shift(months) {
        month = new Date(month.getFullYear(), month.getMonth() + months, 1);
        // Keep the chosen day in view: today in this month, else the first
        chosen = month.getMonth() === today.getMonth() && month.getFullYear() === today.getFullYear()
            ? new Date(today.getFullYear(), today.getMonth(), today.getDate()) : month;
    }
    function time(d) {
        return Qt.formatTime(d, "HH:mm");
    }

    Column {
        id: left
        spacing: 10

        // Month name big, the year small, ‹ ›
        Item {
            width: grid.width
            height: monthName.implicitHeight
            Row {
                spacing: 10
                Txt {
                    id: monthName
                    text: Qt.locale("en_US").monthName(root.month.getMonth())
                    caps: true
                    size: Theme.font.title
                    face: Theme.font.bold
                }
                Txt {
                    anchors.baseline: monthName.baseline
                    text: root.month.getFullYear()
                    caps: true
                    color: Theme.ink.mute
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [-1, 1]
                    Tap {
                        id: arrow
                        required property int modelData
                        width: 30
                        height: 28
                        onClicked: root.shift(modelData)
                        Icon {
                            anchors.centerIn: parent
                            name: arrow.modelData < 0 ? "chevron_left" : "chevron_right"
                            size: 20
                            color: arrow.fg
                        }
                    }
                }
            }
        }

        Row {
            Repeater {
                model: root.names
                Txt {
                    required property string modelData
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    caps: true
                    color: Theme.ink.mute
                }
            }
        }

        Grid {
            id: grid
            columns: 7

            Repeater {
                model: 42
                Item {
                    id: day
                    required property int index
                    readonly property date date: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                    readonly property bool inMonth: date.getMonth() === root.month.getMonth()
                    readonly property bool isToday: root.sameDay(date, root.today)
                    readonly property bool isChosen: root.sameDay(date, root.chosen)
                    readonly property bool busy: Calendar.onDay(root.shown, date).length > 0
                    width: root.cell
                    height: root.cell - 4

                    // Chosen: filled (press-invert look); today: circled
                    Rectangle {
                        anchors.centerIn: num
                        width: 32
                        height: 32
                        radius: 16
                        color: day.isChosen ? Theme.ink.fg : mouse.containsMouse ? Theme.ink.raised : "transparent"
                        border.width: day.isToday && !day.isChosen ? 1.5 : 0
                        border.color: Theme.ink.accent
                    }
                    Txt {
                        id: num
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        text: day.date.getDate()
                        face: day.isToday || day.isChosen ? Theme.font.medium : Theme.font.light
                        color: day.isChosen ? Theme.ink.bg : day.inMonth ? Theme.ink.fg : Theme.ink.line
                    }
                    Rectangle {
                        visible: day.busy
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 4
                        height: 4
                        radius: 2
                        color: day.inMonth ? Theme.ink.accent : Theme.ink.line
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.chosen = day.date;
                            if (!day.inMonth)
                                root.month = new Date(day.date.getFullYear(), day.date.getMonth(), 1);
                        }
                    }
                }
            }

            // The wheel changes the month
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0
                onWheel: event => {
                    acc += event.angleDelta.y;
                    if (Math.abs(acc) >= 120) {
                        root.shift(acc > 0 ? -1 : 1);
                        acc = 0;
                    }
                }
            }
        }
    }

    // The chosen day's events
    Column {
        id: list
        x: grid.width + 36
        width: 300
        spacing: 2

        Txt {
            width: parent.width
            bottomPadding: 8
            text: (root.sameDay(root.chosen, root.today) ? "Today  ·  " : "") + Qt.locale("en_US").toString(root.chosen, "dddd d MMMM")
            caps: true
            color: Theme.ink.accent
        }

        Repeater {
            model: root.dayEvents.slice(0, 6)
            Row {
                required property var modelData
                width: list.width
                spacing: 12
                topPadding: 6
                bottomPadding: 6
                Txt {
                    width: 64
                    text: modelData.allDay ? "All day" : root.time(modelData.start)
                    caps: modelData.allDay
                    size: modelData.allDay ? Theme.font.caption : Theme.font.small
                    face: Theme.font.regular
                    color: Theme.ink.mute
                }
                Column {
                    width: list.width - 76
                    Txt {
                        width: parent.width
                        text: modelData.title
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: [modelData.allDay ? "" : root.time(modelData.start) + " – " + root.time(modelData.end), modelData.place].filter(Boolean).join("  ·  ")
                        size: Theme.font.small
                        color: Theme.ink.mute
                    }
                }
            }
        }
        Txt {
            visible: root.dayEvents.length > 6
            topPadding: 4
            text: "+ " + (root.dayEvents.length - 6) + " more"
            caps: true
            color: Theme.ink.mute
        }
        Txt {
            visible: root.dayEvents.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            text: Calendar.loading && !Calendar.loaded ? "Reading calendars…"
                : Calendar.hasSources ? "Nothing on this day"
                : "No calendars yet. Add a calendar link (Google, Outlook, Apple: the private iCal address) to calendar.feeds in shell.json."
            color: Theme.ink.mute
        }
        Txt {
            visible: Calendar.failed > 0
            topPadding: 10
            text: "Offline  ·  showing the saved copy"
            caps: true
            color: Theme.ink.error
        }
    }
}
