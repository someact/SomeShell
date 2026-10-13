import QtQuick
import Quickshell.Io
import qs.core
import qs.components

// Quick notes on the desktop: the same file as the game overlay's notes
// (~/.local/state/someshell/notes.md), saved a moment after typing stops.
DesktopWidget {
    id: root

    FileView {
        id: file
        path: Paths.notes
        watchChanges: true
        printErrors: false
        // The overlay may have written it; take its text unless typing here
        onFileChanged: if (!edit.activeFocus) reload()
        onLoaded: if (!edit.activeFocus) edit.text = text()
    }
    Component.onDestruction: if (save.running) file.setText(edit.text)
    Timer {
        id: save
        interval: 600
        onTriggered: file.setText(edit.text)
    }

    Column {
        spacing: 10
        Row {
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "sticky_note_2"
                size: 18
                fill: 1
                color: Theme.primary
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notes"
                color: root.fg
                font.weight: Theme.font.weightTitle
            }
        }
        Flickable {
            id: flick
            width: 280
            height: 200
            contentHeight: edit.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            TextEdit {
                id: edit
                width: flick.width
                wrapMode: TextEdit.Wrap
                color: root.fg
                selectionColor: Theme.primary
                selectedTextColor: Theme.fgPrimary
                font.family: Theme.font.ui
                font.pixelSize: Theme.font.normal
                onTextChanged: if (activeFocus) save.restart()
                onActiveFocusChanged: if (!activeFocus && save.running) {
                    save.stop();
                    file.setText(text);
                }
                Keys.onEscapePressed: focus = false
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                        flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                    else if (cursorRectangle.y < flick.contentY)
                        flick.contentY = cursorRectangle.y;
                }
            }
            Label {
                visible: edit.text === ""
                text: "Click to write…"
                color: root.fgDim
            }
        }
    }
}
