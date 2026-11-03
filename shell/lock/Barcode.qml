import QtQuick

// A barcode-style row of bars, the same every time (a fixed seed), like the
// one on the poster wallpapers.
Row {
    id: root
    property real unit: 10
    property color color: "white"
    property int bars: 46

    readonly property var widths: {
        let seed = 7;
        const out = [];
        for (let i = 0; i < bars; i++) {
            seed = (seed * 9301 + 49297) % 233280;
            const w = seed / 233280 < 0.3 ? 0.26 : 0.1;
            seed = (seed * 9301 + 49297) % 233280;
            const g = seed / 233280 < 0.5 ? 0.12 : 0.22;
            out.push([w, g]);
        }
        return out;
    }

    Repeater {
        model: root.widths
        Item {
            required property var modelData
            width: Math.max(1, Math.round(modelData[0] * root.unit)) + Math.max(1, Math.round(modelData[1] * root.unit))
            height: root.height
            Rectangle {
                width: Math.max(1, Math.round(modelData[0] * root.unit))
                height: parent.height
                color: root.color
                opacity: 0.85
            }
        }
    }
}
