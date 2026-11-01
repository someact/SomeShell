import QtQuick
import qs.core
import qs.components
import qs.services

// Control → right-click Night light: on/off and the color temperature
// (2500–6500 K, applied live while on). The day/night schedule lives in
// Settings → Wallpaper.
Column {
    id: root

    spacing: 10

    readonly property int minK: 2500
    readonly property int maxK: 6500

    Item {
        width: parent.width
        height: 34
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            text: "Night light"
            font.styleName: Theme.font.styleTitle
        }
        PillSwitch {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: NightLight.active
            onToggled: NightLight.toggle()
        }
    }

    // Warmer to the left, like the color it gives
    Slider {
        id: temp
        width: parent.width
        icon: "thermostat"
        label: NightLight.temperature + " K"
        value: (root.maxK - NightLight.temperature) / (root.maxK - root.minK)
        fillColor: Qt.rgba(1, 0.62 + 0.3 * (1 - value), 0.35 + 0.5 * (1 - value), 1)
        step: 50 / (root.maxK - root.minK)
        onMoved: v => NightLight.setTemperature(root.maxK - v * (root.maxK - root.minK))
    }

    Row {
        spacing: 6
        Repeater {
            model: [{ k: 3000, name: "Warm" }, { k: 4500, name: "Neutral" }, { k: 5500, name: "Mild" }]
            PressButton {
                id: preset
                required property var modelData
                width: chip.implicitWidth + 28
                height: 30
                color: Theme.islandRaised
                active: NightLight.temperature === modelData.k
                onClicked: NightLight.setTemperature(modelData.k)
                Label {
                    id: chip
                    anchors.centerIn: parent
                    text: preset.modelData.name + " · " + preset.modelData.k
                    font.pixelSize: Theme.font.small
                    color: preset.active ? Theme.fgPrimary : Theme.fgIsland
                }
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            temp.set(temp.value + (event.key === Qt.Key_Right ? 0.05 : -0.05));
            return true;
        }
        return false;
    }
}
