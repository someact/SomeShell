import QtQuick
import Quickshell
import qs.core
import qs.components

// Large time and date, straight on the wallpaper. Ticks once a minute.
DesktopWidget {
    id: root
    framed: false
    padding: 8

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        spacing: -8
        Label {
            text: Qt.formatTime(clock.date, Config.clock.format)
            color: root.fg
            font.pixelSize: 96
            font.styleName: Theme.font.styleDisplay
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
        Label {
            leftPadding: 4
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: root.fgDim
            font.pixelSize: 22
            font.styleName: "Medium"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
    }
}
