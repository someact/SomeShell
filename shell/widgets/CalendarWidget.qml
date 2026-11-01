import QtQuick
import Quickshell
import qs.core
import qs.components

// Month grid, today marked; ‹ › change month, the title goes back to today.
// The day rolls over on the minute clock.
DesktopWidget {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date today: clock.date
    property int offset: 0          // months from today's
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7    // 0 = Sunday
    readonly property int lead: (month.getDay() - firstDay + 7) % 7
    readonly property int daysIn: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property int cell: 36

    Column {
        spacing: 8
        Item {
            width: root.cell * 7
            height: 32
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                text: Qt.formatDate(root.month, "MMMM yyyy")
                color: root.fg
                font.pixelSize: Theme.font.large
                font.styleName: Theme.font.styleTitle
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.offset = 0
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    width: 30
                    height: 30
                    icon: "chevron_left"
                    iconColor: root.fg
                    hoverColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                    onClicked: root.offset--
                }
                IconButton {
                    width: 30
                    height: 30
                    icon: "chevron_right"
                    iconColor: root.fg
                    hoverColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                    onClicked: root.offset++
                }
            }
        }
        Grid {
            columns: 7
            Repeater {
                model: 7
                Label {
                    required property int index
                    width: root.cell
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                    color: root.fgDim
                    font.pixelSize: Theme.font.small
                }
            }
            Repeater {
                model: 42
                Item {
                    id: day
                    required property int index
                    readonly property int n: index - root.lead + 1
                    readonly property bool inMonth: n >= 1 && n <= root.daysIn
                    readonly property bool isToday: inMonth && root.offset === 0 && n === root.today.getDate()
                    // Hide a trailing empty week
                    visible: index < Math.ceil((root.lead + root.daysIn) / 7) * 7
                    width: root.cell
                    height: root.cell
                    MaterialShape {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: day.isToday
                        shape: "cookie7Sided"
                        color: Theme.primary
                    }
                    Label {
                        anchors.centerIn: parent
                        text: day.inMonth ? day.n : ""
                        color: day.isToday ? Theme.fgPrimary : root.fg
                        font.styleName: day.isToday ? Theme.font.styleTitle : Theme.font.style
                    }
                }
            }
        }
    }
}
