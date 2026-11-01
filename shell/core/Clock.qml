pragma Singleton
import QtQuick
import Quickshell

// The time, ticking once a minute. Day and month names are English, as the
// rest of the interface (dates never follow the Thai Buddhist calendar here).
Singleton {
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, "HH:mm")
    readonly property string day: Qt.locale("en_US").toString(now, "ddd dd")
    readonly property string date: Qt.locale("en_US").toString(now, "dddd d MMMM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
