import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Result of the translate region tool (Super+Shift+T): the recognized text and
// its translation. Enter copies the translation, Tab swaps the target between
// Thai and English, Esc closes.
FocusScope {
    id: root

    implicitWidth: 620
    implicitHeight: col.implicitHeight

    readonly property var languages: [
        { code: "th", name: "ไทย" },
        { code: "en", name: "English" },
        { code: "ja", name: "日本語" }
    ]

    function copy() {
        if (Capture.translated !== "") {
            Quickshell.execDetached(["wl-copy", "--", Capture.translated]);
            Osd.show("capture", "content_copy", -1, "Translation copied");
            UiState.close();
        }
    }
    function cycle() {
        const codes = languages.map(l => l.code);
        Capture.translate(Capture.sourceText, codes[(codes.indexOf(Config.capture.translateTo) + 1) % codes.length]);
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            copy();
            return true;
        }
        if (event.key === Qt.Key_Tab) {
            cycle();
            return true;
        }
        if (event.key === Qt.Key_Escape) {
            UiState.close();
            return true;
        }
        return false;
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "translate"
                size: 22
                fill: 1
                color: Theme.accentIsland
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Translate"
                font.pixelSize: Theme.font.large
                font.styleName: Theme.font.styleTitle
            }
            Item {
                width: parent.width - 22 - x - langs.width - 10
                height: 1
            }
            Row {
                id: langs
                spacing: 4
                Repeater {
                    model: root.languages
                    PressButton {
                        id: chip
                        required property var modelData
                        width: langLabel.implicitWidth + 22
                        height: 28
                        radius: 14
                        color: Theme.islandRaised
                        active: Config.capture.translateTo === modelData.code
                        onClicked: Capture.translate(Capture.sourceText, modelData.code)
                        Label {
                            id: langLabel
                            anchors.centerIn: parent
                            text: modelData.name
                            font.pixelSize: Theme.font.small
                            color: chip.active ? Theme.fgPrimary : Theme.fgIsland
                        }
                    }
                }
            }
        }

        // Recognized text
        Rectangle {
            width: parent.width
            height: Math.min(140, source.implicitHeight + 20)
            radius: Theme.radius.normal
            color: Theme.islandRaised
            visible: Capture.sourceText !== ""
            clip: true
            Label {
                id: source
                x: 12
                y: 10
                width: parent.width - 24
                text: Capture.sourceText
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.fgIslandDim
                font.pixelSize: Theme.font.small
            }
        }

        // Translation (scrolls when long)
        Flickable {
            width: parent.width
            height: Math.max(40, Math.min(260, result.implicitHeight))
            contentHeight: result.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Label {
                id: result
                width: parent.width
                text: Capture.busy ? (Capture.sourceText === "" ? "Reading text…" : "Translating…") : Capture.error !== "" ? Capture.error : Capture.translated
                color: Capture.error !== "" ? Theme.error : Capture.busy ? Theme.fgIslandDim : Theme.fgIsland
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                font.pixelSize: Theme.font.large
            }
        }

        Label {
            text: "Enter copy · Tab language · Esc close"
            color: Theme.fgIslandDim
            font.pixelSize: Theme.font.small
        }
    }
}
