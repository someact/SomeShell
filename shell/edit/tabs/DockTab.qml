import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// Dock: on/off and auto-hide for the separate dock (Notch and Plain; the
// Dock style always has its bar), the extra buttons (overview, trash) for
// either bar, and the pinned apps: click one to pick it, then move it left or
// right or unpin it; add one from the search, or one of the apps running now.
Item {
    id: root
    property string tab
    readonly property bool docked: Desktop.style === "dock"
    // The pinned app picked for moving or unpinning (its desktop id)
    property string chosen: ""
    readonly property int chosenAt: Desktop.dock.pinned.indexOf(chosen)

    function setPinned(list) {
        Editor.record();
        Desktop.dock.pinned = list;
    }
    function move(d) {
        const p = Desktop.dock.pinned.slice();
        const at = p.indexOf(chosen);
        const to = at + d;
        if (at < 0 || to < 0 || to >= p.length)
            return;
        p.splice(at, 1);
        p.splice(to, 0, chosen);
        setPinned(p);
    }
    function unpin() {
        const p = Desktop.dock.pinned.slice();
        const at = p.indexOf(chosen);
        if (at < 0)
            return;
        p.splice(at, 1);
        chosen = "";
        setPinned(p);
    }
    function pin(id) {
        if (!id || Desktop.dock.pinned.includes(id))
            return;
        setPinned(Desktop.dock.pinned.concat([id]));
    }

    // Apps with a window open that are not pinned (desktop entries only)
    readonly property var running: {
        DesktopEntries.applications.values.length;
        const out = [];
        const seen = {};
        for (const t of ToplevelManager.toplevels.values) {
            const e = t.appId ? DesktopEntries.heuristicLookup(t.appId) : null;
            if (!e || seen[e.id] || Desktop.dock.pinned.includes(e.id))
                continue;
            seen[e.id] = true;
            out.push(e);
        }
        return out.slice(0, 5);
    }

    Column {
        id: left
        width: 250
        spacing: 10
        Txt {
            width: parent.width
            text: root.docked ? "Dock style has its own bar" : "Separate dock"
            caps: true
            color: Theme.ink.mute
            elide: Text.ElideRight
        }
        Row {
            spacing: 6
            Chip {
                icon: "dock_to_bottom"
                label: Desktop.dock.enabled ? "On" : "Off"
                active: Desktop.dock.enabled
                enabled: !root.docked
                onClicked: { Editor.record(); Desktop.dock.enabled = !Desktop.dock.enabled; }
            }
            Chip {
                icon: "unfold_less"
                label: "Auto-hide"
                active: Desktop.dock.autoHide
                enabled: !root.docked && Desktop.dock.enabled
                onClicked: { Editor.record(); Desktop.dock.autoHide = !Desktop.dock.autoHide; }
            }
        }
        Txt {
            width: parent.width
            text: "Buttons"
            caps: true
            color: Theme.ink.mute
        }
        Row {
            spacing: 6
            Chip {
                icon: "view_carousel"
                label: "Overview"
                active: Desktop.dock.overview
                onClicked: { Editor.record(); Desktop.dock.overview = !Desktop.dock.overview; }
            }
            Chip {
                icon: "delete"
                label: "Trash"
                active: Desktop.dock.trash
                onClicked: { Editor.record(); Desktop.dock.trash = !Desktop.dock.trash; }
            }
        }
    }

    Column {
        anchors.left: left.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        spacing: 10

        // Title, or what to do with the picked app
        Row {
            height: 20
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.chosenAt < 0 ? "Pinned  ·  click one to move or unpin it"
                    : "Pinned  ·  " + (DesktopEntries.byId(root.chosen)?.name ?? root.chosen)
                caps: true
                color: Theme.ink.mute
            }
        }
        Row {
            spacing: 6
            height: 44
            Repeater {
                model: Desktop.dock.pinned
                Tap {
                    id: pin
                    required property string modelData
                    readonly property var entry: DesktopEntries.byId(modelData)
                    width: 44
                    height: 44
                    radius: 12
                    outlined: true
                    active: root.chosen === modelData
                    onClicked: root.chosen = root.chosen === modelData ? "" : modelData
                    Image {
                        id: pinIcon
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: Quickshell.iconPath(pin.entry?.icon ?? "", true)
                        sourceSize: Qt.size(56, 56)
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: pinIcon.status !== Image.Ready
                        name: "apps"
                        color: pin.fg
                    }
                }
            }
            Txt {
                visible: Desktop.dock.pinned.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Nothing pinned yet"
                color: Theme.ink.mute
            }
            // What to do with the picked one
            Item { width: 12; height: 1; visible: root.chosenAt >= 0 }
            Tap {
                visible: root.chosenAt >= 0
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.chosenAt > 0
                onClicked: root.move(-1)
                Icon { anchors.centerIn: parent; name: "chevron_left"; color: parent.fg }
            }
            Tap {
                visible: root.chosenAt >= 0
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.chosenAt >= 0 && root.chosenAt < Desktop.dock.pinned.length - 1
                onClicked: root.move(1)
                Icon { anchors.centerIn: parent; name: "chevron_right"; color: parent.fg }
            }
            Chip {
                visible: root.chosenAt >= 0
                anchors.verticalCenter: parent.verticalCenter
                icon: "keep_off"
                label: "Unpin"
                onClicked: root.unpin()
            }
        }
        // Add: search the apps; with nothing typed, the apps running now
        Row {
            spacing: 6
            Field {
                id: find
                width: 200
                placeholder: "Add an app…"
                onAccepted: {
                    const hit = adds.model[0];
                    if (hit) {
                        root.pin(hit.id);
                        find.text = "";
                    }
                }
            }
            Txt {
                visible: !find.text.trim() && root.running.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Running"
                size: Theme.font.small
                color: Theme.ink.mute
            }
            Repeater {
                id: adds
                model: find.text.trim()
                    ? Apps.search(find.text, 4).filter(e => !Desktop.dock.pinned.includes(e.id))
                    : root.running
                Tap {
                    id: hit
                    required property var modelData
                    width: Math.min(hitRow.implicitWidth + 22, 170)
                    height: 34
                    radius: 17
                    outlined: true
                    onClicked: {
                        root.pin(modelData.id);
                        find.text = "";
                    }
                    Row {
                        id: hitRow
                        anchors.centerIn: parent
                        spacing: 6
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            source: Quickshell.iconPath(hit.modelData.icon ?? "", true)
                            sourceSize: Qt.size(40, 40)
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 170 - 22 - 26)
                            text: hit.modelData.name ?? hit.modelData.id
                            color: hit.fg
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
