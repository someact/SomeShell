import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Clipboard (Super+V). A page of its own with no tab: only the shortcut
// opens it. Type to filter, arrows choose, Enter copies the entry back and
// closes, Delete drops it from the history. The chosen entry shows in full
// beside the list (text, or the picture).
Item {
    id: root

    readonly property int listWidth: 340
    readonly property int previewWidth: 380
    readonly property int rowHeight: 50
    readonly property int maxRows: 8

    property int sel: 0
    property var results: []
    readonly property var chosen: results[sel] ?? null

    implicitWidth: listWidth + 20 + previewWidth
    implicitHeight: col.implicitHeight

    // Reads the input directly: inside its change handler a binding on
    // the text would still hold the previous value
    function update() {
        const keep = chosen?.id;
        results = Clipboard.search(input.text, 200);
        const at = results.findIndex(e => e.id === keep);
        sel = at < 0 ? 0 : at;
    }
    function move(step) {
        if (results.length)
            sel = Math.max(0, Math.min(results.length - 1, sel + step));
    }
    function activate(i) {
        const e = results[i];
        if (!e)
            return;
        Clipboard.copy(e);
        Ui.close();
    }
    function removeAt(i) {
        const e = results[i];
        if (!e)
            return;
        Clipboard.remove(e);
        sel = Math.max(0, Math.min(i, results.length - 1));
    }

    onChosenChanged: Clipboard.readFull(chosen)
    onSelChanged: list.positionViewAtIndex(sel, ListView.Contain)

    Connections {
        target: Clipboard
        function onEntriesChanged() { root.update(); }
    }

    Component.onCompleted: {
        Clipboard.refresh();
        update();
        input.forceActiveFocus();
    }

    Column {
        id: col
        width: root.implicitWidth
        spacing: 12

        // Filter
        Row {
            width: parent.width
            spacing: 14
            Icon {
                id: glass
                anchors.verticalCenter: parent.verticalCenter
                name: "content_paste_search"
                size: 24
                color: Theme.ink.mute
            }
            TextInput {
                id: input
                width: parent.width - glass.width - count.width - 28
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink.fg
                selectionColor: Theme.ink.accent
                selectedTextColor: Theme.ink.onAccent
                font.family: Theme.font.family
                font.styleName: Theme.font.regular
                font.pixelSize: 22
                clip: true
                focus: true
                onTextChanged: {
                    if (text !== "")
                        Ui.openedByHover = false;
                    root.update();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) root.move(1);
                    else if (event.key === Qt.Key_Up) root.move(-1);
                    else if (event.key === Qt.Key_PageDown) root.move(root.maxRows);
                    else if (event.key === Qt.Key_PageUp) root.move(-root.maxRows);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate(root.sel);
                    // Delete removes the entry once the filter is empty or the cursor is at its end
                    else if (event.key === Qt.Key_Delete && input.cursorPosition === input.text.length) root.removeAt(root.sel);
                    else return;
                    event.accepted = true;
                }

                Txt {
                    visible: input.text === ""
                    text: "Filter copied text"
                    size: 22
                    face: Theme.font.light
                    color: Theme.ink.mute
                    opacity: 0.6
                }
            }
            Txt {
                id: count
                anchors.verticalCenter: parent.verticalCenter
                text: Clipboard.loading && !Clipboard.entries.length ? "" : root.results.length + (root.results.length === 1 ? " item" : " items")
                caps: true
                color: Theme.ink.mute
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.ink.line
        }

        Row {
            spacing: 20
            height: Math.max(list.height, 160)

            // History, newest first
            ListView {
                id: list
                width: root.listWidth
                height: root.results.length ? Math.min(root.results.length, root.maxRows) * (root.rowHeight + spacing) - spacing : 160
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.results
                // The list follows `sel` itself (positionViewAtIndex)
                highlightFollowsCurrentItem: false

                delegate: Tap {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isLink: /^(https?:\/\/|www\.)\S+$/.test(modelData.text.trim())
                    width: ListView.view.width
                    height: root.rowHeight
                    radius: 14
                    highlighted: index === root.sel
                    onClicked: root.activate(index)
                    onRightClicked: root.removeAt(index)
                    onHoveredChanged: if (hovered) root.sel = index

                    Rectangle {
                        id: badge
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 11
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.ink.line
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: !!row.modelData.image
                            source: row.modelData.image ? "file://" + row.modelData.image : ""
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !row.modelData.image
                            name: row.isLink ? "link" : "notes"
                            color: row.fg
                        }
                    }
                    Txt {
                        anchors.left: badge.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text.replace(/\s+/g, " ").trim()
                        color: row.pressed ? row.fg : Theme.ink.fg
                    }
                }

                Txt {
                    visible: root.results.length === 0
                    anchors.centerIn: parent
                    text: Clipboard.loading ? "Reading the clipboard…" : input.text ? "Nothing matches" : "Nothing copied yet"
                    caps: true
                    color: Theme.ink.mute
                }
            }

            // The chosen entry in full
            Rectangle {
                width: root.previewWidth
                height: parent.height
                radius: Theme.shape.tile
                color: "transparent"
                border.width: 1
                border.color: Theme.ink.line
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: !!root.chosen?.image
                    source: root.chosen?.image ? "file://" + root.chosen.image : ""
                    sourceSize: Qt.size(root.previewWidth * 2, 800)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Txt {
                    anchors.fill: parent
                    anchors.margins: 16
                    visible: !!root.chosen && !root.chosen.image
                    text: root.chosen && Clipboard.fullId === root.chosen.id ? Clipboard.fullText : root.chosen?.text ?? ""
                    size: Theme.font.small
                    face: Theme.font.regular
                    wrapMode: Text.Wrap
                    maximumLineCount: Math.max(1, Math.floor(height / (Theme.font.small * 1.5)))
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !root.chosen
                    name: "content_paste_off"
                    size: 32
                    color: Theme.ink.mute
                }
            }
        }

        // Hints
        Row {
            spacing: 20
            Repeater {
                model: ["↑ ↓ choose", "Enter copies", "Del removes", "Esc close"]
                Txt {
                    required property string modelData
                    text: modelData
                    caps: true
                    color: Theme.ink.mute
                }
            }
        }
    }
}
