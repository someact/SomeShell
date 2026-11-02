import QtQuick
import qs.core
import qs.components
import qs.services

// Calendar: the month name, weekday initials and the days, today circled, a
// dot under days with events. ‹ › change the month; a click on a day opens
// the island's Calendar page. Events are read when the widget starts and
// when the day changes (lib/calendar.sh keeps a 15-minute copy of each link).
Item {
    id: root

    property var widget: null
    property bool live: true
    property real cell: 80
    property bool card: false
    // The colors: the desktop set on a card, the wallpaper's on bare type
    property var c: Theme.paper

    readonly property date today: Clock.now
    readonly property string todayKey: today.toDateString()
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    onTodayKeyChanged: {
        month = new Date(today.getFullYear(), today.getMonth(), 1);
        if (live)
            Calendar.refresh();
    }
    Component.onCompleted: if (live) Calendar.refresh()

    readonly property var names: Calendar.sundayFirst ? ["S", "M", "T", "W", "T", "F", "S"] : ["M", "T", "W", "T", "F", "S", "S"]
    readonly property date gridStart: {
        const lead = (month.getDay() - (Calendar.sundayFirst ? 0 : 1) + 7) % 7;
        return new Date(month.getFullYear(), month.getMonth(), 1 - lead);
    }
    readonly property var shown: Calendar.between(gridStart, new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + 42))

    // The grid takes what the header leaves; cells are as wide as fits
    readonly property real head: Math.round(Math.min(height * 0.16, cell * 0.55))
    readonly property real cw: width / 7
    readonly property real ch: (height - head) / 7
    readonly property int num: Math.max(10, Math.round(Math.min(cw, ch) * 0.42))

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function shift(months) {
        month = new Date(month.getFullYear(), month.getMonth() + months, 1);
    }

    Item {
        id: header
        width: parent.width
        height: root.head
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Txt {
                id: monthName
                text: Qt.locale("en_US").toString(root.month, "MMMM")
                caps: true
                size: Math.max(11, Math.round(root.head * 0.42))
                face: Theme.font.bold
                color: root.c.fg
            }
            Txt {
                anchors.baseline: monthName.baseline
                visible: root.month.getFullYear() !== root.today.getFullYear()
                text: root.month.getFullYear()
                caps: true
                size: Math.max(10, Math.round(root.head * 0.32))
                color: root.c.mute
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.live
            Repeater {
                model: [-1, 1]
                WidgetButton {
                    c: root.c
                    required property int modelData
                    icon: modelData < 0 ? "chevron_left" : "chevron_right"
                    size: Math.round(root.head * 0.8)
                    onClicked: root.shift(modelData)
                }
            }
        }
    }

    Grid {
        y: root.head
        columns: 7

        Repeater {
            model: root.names
            Txt {
                required property string modelData
                width: root.cw
                height: root.ch
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                caps: true
                size: Math.max(9, Math.round(root.num * 0.7))
                color: root.c.mute
            }
        }

        Repeater {
            model: 42
            Item {
                id: day
                required property int index
                readonly property date date: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                readonly property bool inMonth: date.getMonth() === root.month.getMonth()
                readonly property bool isToday: root.sameDay(date, root.today)
                readonly property bool busy: Calendar.onDay(root.shown, date).length > 0
                width: root.cw
                height: root.ch

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.86
                    height: width
                    radius: width / 2
                    color: day.isToday ? root.c.fg : mouse.containsMouse ? root.c.raised : "transparent"
                }
                Txt {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    size: root.num
                    face: day.isToday ? Theme.font.medium : Theme.font.light
                    color: day.isToday ? root.c.bg : day.inMonth ? root.c.fg : root.c.line
                }
                Rectangle {
                    visible: day.busy
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: Math.round(root.num * 0.72)
                    width: Math.max(3, Math.round(root.num * 0.18))
                    height: width
                    radius: width / 2
                    color: day.isToday ? root.c.bg : day.inMonth ? root.c.accent : root.c.line
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: root.live
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.openPage("calendar")
                }
            }
        }
    }

    // The wheel changes the month
    WheelHandler {
        enabled: root.live
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
