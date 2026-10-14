import QtQuick
import qs.core
import qs.components
import qs.services

// cliphist history with image thumbnails and a preview of the selected entry
// (the image, or the full text). Enter copies, Delete removes, type to filter.
// Streamer mode hides the thumbnails and the preview.
FilterListView {
    id: root
    icon: "content_paste"
    placeholder: "Clipboard history"
    implicitWidth: 880
    sideWidth: 320
    side: previewPane
    results: Clipboard.entries.filter(e => query === "" || e.text.toLowerCase().includes(query.toLowerCase())).slice(0, 200)

    readonly property var current: results[list.currentIndex] ?? null
    readonly property bool hide: Streamer.active
    onCurrentChanged: Clipboard.preview(current)

    Component.onCompleted: Clipboard.refresh()

    onActivated: i => {
        Clipboard.copy(results[i]);
        UiState.close();
    }
    extraKey: event => {
        if (event.key === Qt.Key_Delete) {
            const e = results[list.currentIndex];
            if (e)
                Clipboard.remove(e);
            return true;
        }
        return false;
    }

    delegate: ResultRow {
        required property var modelData
        required property int index
        icon: modelData.isImage ? "image" : "notes"
        thumb: modelData.isImage && !root.hide ? Clipboard.imageUrl(modelData) : ""
        title: modelData.isImage ? "Image" : modelData.text.replace(/\s+/g, " ")
        subtitle: Clipboard.describe(modelData)
        hint: "Copy"
        onClicked: root.activated(index)
        onRightClicked: Clipboard.remove(modelData)
    }

    Component {
        id: previewPane

        Rectangle {
            radius: Theme.radius.normal
            color: Theme.islandRaised
            clip: true

            readonly property var entry: root.current

            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 8
                visible: root.hide || !parent.entry
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.hide ? "visibility_off" : "content_paste"
                    size: 28
                    color: Theme.fgIslandDim
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.hide ? "Previews are hidden in streamer mode" : "Nothing selected"
                    color: Theme.fgIslandDim
                    font.pixelSize: Theme.font.small
                }
            }

            Image {
                id: image
                anchors.fill: parent
                anchors.margins: 10
                visible: !root.hide && parent.entry?.isImage === true
                source: visible ? Clipboard.imageUrl(parent.entry) : ""
                sourceSize: Qt.size(600, 760)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Label {
                anchors.centerIn: parent
                visible: image.visible && image.status !== Image.Ready
                text: image.status === Image.Error ? "Cannot show this image" : "Loading"
                color: Theme.fgIslandDim
            }

            Flickable {
                id: textPane
                anchors.fill: parent
                anchors.margins: 12
                visible: !root.hide && parent.entry !== null && !parent.entry.isImage
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Label {
                    id: body
                    width: textPane.width
                    text: Clipboard.previewText
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                    mono: true
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }
}
