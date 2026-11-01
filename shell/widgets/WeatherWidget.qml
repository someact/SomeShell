import QtQuick
import qs.core
import qs.components
import qs.services

// Current weather and the next three days (Weather: Open-Meteo every 30 min).
DesktopWidget {
    id: root

    Component.onCompleted: Weather.watchers++
    Component.onDestruction: Weather.watchers--

    readonly property string unit: Config.widgets.fahrenheit ? "°F" : "°C"

    Column {
        width: 260
        spacing: 12

        Row {
            spacing: 14
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.current ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud_off"
                size: 48
                fill: 1
                color: Theme.primary
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    text: Weather.current ? Weather.current.temp + root.unit : "--"
                    color: root.fg
                    font.pixelSize: 34
                    font.styleName: Theme.font.styleTitle
                }
                Label {
                    text: Weather.current ? Weather.text(Weather.current.code) + " · feels " + Weather.current.feels + "°" : Weather.loading ? "Loading…" : Weather.error
                    color: root.fgDim
                    font.pixelSize: Theme.font.small
                }
            }
        }
        Label {
            visible: Weather.place !== ""
            text: Weather.place + (Weather.current ? "  ·  wind " + Weather.current.wind + " km/h" : "")
            color: root.fgDim
            font.pixelSize: Theme.font.small
        }
        Row {
            visible: Weather.days.length > 1
            spacing: 0
            Repeater {
                model: Weather.days.slice(1, 4)
                Column {
                    required property var modelData
                    width: 260 / 3
                    spacing: 2
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd")
                        color: root.fgDim
                        font.pixelSize: Theme.font.small
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Weather.icon(modelData.code, true)
                        size: 24
                        color: root.fg
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.max + "° / " + modelData.min + "°"
                        color: root.fg
                        font.pixelSize: Theme.font.small
                    }
                }
            }
        }
    }
}
