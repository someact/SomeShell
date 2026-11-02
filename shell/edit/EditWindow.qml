import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// Edit mode on one monitor: the desktop zooms down into a live card, the
// strip on top (preset, Undo, Save, Save as new, Done) and the editing panel
// below with its tabs. The strip and panel are on the island's monitor only;
// other monitors show their card. One motion: the zoom in and out.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property bool main: Ui.monitor === "" || Ui.monitor === modelData.name
    readonly property real sw: modelData.width
    readonly property real sh: modelData.height

    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "someshell:edit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // 0: the card fills the screen (the desktop as it is), 1: zoomed out
    property real zoom: 0
    Component.onCompleted: {
        if (main)
            Editor.start();
        zoom = 1;
    }
    Behavior on zoom {
        NumberAnimation { duration: Motion.slow; easing.type: Easing.InOutCubic }
    }
    // Done: zoom back to the full desktop, then close
    function done() {
        Ui.endEdit();
    }
    Connections {
        target: Ui
        function onEditClosingChanged() { if (Ui.editClosing) win.zoom = 0; }
    }

    // Behind the card
    Rectangle {
        anchors.fill: parent
        color: Theme.ink.bg
        opacity: win.zoom
    }

    // Where the card ends up: centred at the top, as large as the panel allows
    readonly property real panelHeight: main ? 280 : 0
    readonly property real cardScale: Math.min(0.66, (sh - panelHeight - 140) / sh)
    readonly property rect target: Qt.rect((sw - sw * cardScale) / 2, 72, sw * cardScale, sh * cardScale)

    DeskCard {
        id: card
        screen: win.modelData
        interactive: win.main && win.zoom === 1
        x: win.target.x * win.zoom
        y: win.target.y * win.zoom
        width: win.sw + (win.target.width - win.sw) * win.zoom
        height: win.sh + (win.target.height - win.sh) * win.zoom
    }

    // Top strip
    Item {
        visible: win.main
        opacity: win.zoom
        x: card.x
        width: card.width
        height: 72
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Edit desktop"
                caps: true
                size: Theme.font.title
                face: Theme.font.bold
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: (Desktop.preset || "No preset") + (Editor.edited ? "  ·  edited" : "")
                caps: true
                color: Theme.ink.mute
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            StripButton {
                icon: "undo"
                label: "Undo"
                enabled: Editor.canUndo
                onClicked: Editor.undo()
            }
            StripButton {
                icon: "save"
                label: "Save"
                visible: !saveAs.visible
                onClicked: Desktop.preset ? win.save(Desktop.preset) : win.askName()
            }
            Field {
                id: saveAs
                visible: false
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                placeholder: "Preset name, Enter"
                onAccepted: text => {
                    if (text.trim())
                        win.save(text.trim());
                    visible = false;
                }
                Keys.onEscapePressed: visible = false
            }
            StripButton {
                icon: "bookmark_add"
                label: "Save as new"
                visible: !saveAs.visible
                onClicked: win.askName()
            }
            StripButton {
                icon: "check"
                label: "Done"
                active: true
                onClicked: win.done()
            }
        }
    }

    function askName() {
        saveAs.text = "";
        saveAs.visible = true;
        saveAs.focusField();
    }
    // The thumbnail is the card itself, without the outline of a chosen part
    function save(name) {
        Presets.save(name, "none");
    }
    Connections {
        target: Presets
        enabled: win.main
        function onSaved(name, dir) {
            card.showChoice = false;
            Qt.callLater(() => card.grabToImage(r => {
                r.saveToFile(dir + "/thumb.png");
                card.showChoice = true;
                Presets.refresh();
            }, Qt.size(360, Math.round(360 * win.sh / win.sw))));
        }
    }

    EditPanel {
        id: panel
        visible: win.main
        opacity: win.zoom
        x: card.x
        y: win.target.y + win.target.height + 20
        width: win.target.width
        height: win.panelHeight
    }

    // A widget dragged from the drawer: its icon under the mouse (the card
    // shows where it lands)
    Rectangle {
        visible: win.main && Ui.drawerDrag !== null
        x: (Ui.drawerDrag?.x ?? 0) - width / 2
        y: (Ui.drawerDrag?.y ?? 0) - height / 2
        width: 52
        height: 52
        radius: 26
        color: Theme.ink.accent
        Icon {
            anchors.centerIn: parent
            name: Widgets.kind(Ui.drawerDrag?.kind ?? "")?.icon ?? "widgets"
            filled: true
            size: 26
            color: Theme.ink.onAccent
        }
    }

    // Keys: Esc closes (first lets go of a chosen widget), Ctrl+Z undoes,
    // Delete removes the chosen widget
    Item {
        focus: win.main
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && Ui.editWidget !== "")
                Ui.editWidget = "";
            else if (event.key === Qt.Key_Escape)
                win.done();
            else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && Ui.editTab === "widgets" && Ui.editWidget !== "") {
                Editor.record();
                Widgets.remove(Ui.editWidget);
                Ui.editWidget = "";
            }
            else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))
                Editor.undo();
            else
                return;
            event.accepted = true;
        }
    }

    component StripButton: Tap {
        id: btn
        property string icon
        property string label
        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: btnRow.implicitWidth + 24
        implicitHeight: 38
        radius: 19
        outlined: true
        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: btn.icon
                size: 18
                color: btn.fg
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                caps: true
                color: btn.fg
            }
        }
    }
}
