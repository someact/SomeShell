import QtQuick
import Quickshell.Io
import qs.core
import qs.components

// Quick notes, saved to ~/.local/state/someshell/notes.md a moment after typing stops.
OverlayCard {
    id: root
    icon: "sticky_note_2"
    title: "Notes"
    implicitWidth: 320

    FileView {
        id: file
        path: Paths.notes
        onLoaded: edit.text = text()
        printErrors: false
    }
    // Closing the overlay mid-typing still saves
    Component.onDestruction: if (save.running) file.setText(edit.text)
    Timer {
        id: save
        interval: 600
        onTriggered: file.setText(edit.text)
    }

    Rectangle {
        width: parent.width
        height: 180
        radius: Theme.radius.normal
        color: Theme.islandRaised
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: edit.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            TextEdit {
                id: edit
                width: flick.width
                wrapMode: TextEdit.Wrap
                color: Theme.fgIsland
                selectionColor: Theme.primary
                selectedTextColor: Theme.fgPrimary
                font.family: Theme.font.ui
                font.pixelSize: Theme.font.normal
                onTextChanged: if (activeFocus) save.restart()
                onActiveFocusChanged: if (!activeFocus && save.running) {
                    save.stop();
                    file.setText(text);
                }
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                        flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                    else if (cursorRectangle.y < flick.contentY)
                        flick.contentY = cursorRectangle.y;
                }
            }
        }
        Label {
            visible: edit.text === ""
            x: 10
            y: 10
            text: "Notes…"
            color: Theme.fgIslandDim
        }
    }
}
