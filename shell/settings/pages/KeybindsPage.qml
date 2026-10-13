import QtQuick
import qs.core
import qs.components
import qs.settings
import qs.settings.ui

Page {
    id: page
    title: "Keybinds"
    subtitle: "Click a shortcut and press new keys. Changes go to ~/.config/someshell/keybinds.json and Hyprland reloads; keybinds.lua itself is never edited."

    property string query: ""
    property int editing: -2      // custom entry being edited: -1 new, >= 0 index, -2 none

    // Described binds in the main submap, one row per combo + description, grouped
    readonly property var groups: {
        const q = query.toLowerCase();
        const seen = new Set();
        const map = {};
        for (const b of KeybindStore.binds) {
            if (b.submap !== "" || b.description === "" || b.group === "Custom")
                continue;
            const id = b.norm + "|" + b.description;
            if (seen.has(id))
                continue;
            seen.add(id);
            if (q !== "" && !(b.group + " " + b.action + " " + KeybindStore.pretty(b.combo)).toLowerCase().includes(q))
                continue;
            const g = b.group || "Other";
            (map[g] = map[g] ?? []).push(b);
        }
        return Object.keys(map).map(name => ({ name, binds: map[name] }));
    }
    readonly property var custom: KeybindStore.data.custom ?? []

    Row {
        width: parent.width
        spacing: 12
        Field {
            width: parent.width - addButton.width - 12
            placeholder: "Search shortcuts"
            onTextChanged: page.query = text
        }
        SButton {
            id: addButton
            kind: "filled"
            icon: "add"
            text: "Add shortcut"
            onClicked: page.editing = -1
        }
    }

    // New / edited custom shortcut
    Section {
        visible: page.editing !== -2
        title: page.editing === -1 ? "New shortcut" : "Edit shortcut"
        CustomEditor {
            index: page.editing
            entry: page.editing >= 0 ? page.custom[page.editing] : ({ keys: "", command: "", description: "", enabled: true })
        }
    }

    Section {
        visible: page.custom.length > 0 && page.query === ""
        title: "Your shortcuts"
        Repeater {
            model: page.custom
            SettingRow {
                id: crow
                required property var modelData
                required property int index
                icon: "terminal"
                title: modelData.description || modelData.command
                subtitle: modelData.command
                opacity: modelData.enabled === false ? 0.5 : 1
                Row {
                    spacing: 4
                    KeyRecorder {
                        keys: crow.modelData.keys
                        onRecorded: k => KeybindStore.setCustom(crow.index, Object.assign({}, crow.modelData, { keys: k }))
                    }
                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: crow.modelData.enabled !== false
                        onToggled: on => KeybindStore.setCustom(crow.index, Object.assign({}, crow.modelData, { enabled: on }))
                    }
                    SmallButton {
                        icon: "edit"
                        onClicked: page.editing = crow.index
                    }
                    SmallButton {
                        icon: "delete"
                        danger: true
                        onClicked: KeybindStore.removeCustom(crow.index)
                    }
                }
            }
        }
    }

    Repeater {
        model: page.groups
        Section {
            id: group
            required property var modelData
            title: modelData.name
            Repeater {
                model: group.modelData.binds
                BindRow {}
            }
        }
    }

    Section {
        visible: KeybindStore.disabled.length > 0 && page.query === ""
        title: "Turned off"
        Repeater {
            model: KeybindStore.disabled
            SettingRow {
                required property string modelData
                icon: "block"
                title: KeybindStore.pretty(modelData)
                subtitle: "Bound in keybinds.lua, turned off here"
                SButton {
                    kind: "text"
                    text: "Turn back on"
                    onClicked: KeybindStore.reset(modelData)
                }
            }
        }
    }

    SText {
        visible: page.groups.length === 0 && page.query !== ""
        text: "No shortcut matches “" + page.query + "”"
        dim: true
    }

    // One bound shortcut: record to remap; conflicts must be confirmed
    component BindRow: SettingRow {
        id: row
        required property var modelData
        readonly property string origin: KeybindStore.originOf(modelData.norm)
        readonly property bool remapped: origin !== modelData.norm
        property string pending: ""
        readonly property var clashes: pending === "" ? [] : KeybindStore.conflicts(KeybindStore.normalize(pending), modelData.norm)

        title: modelData.action
        subtitle: pending !== "" ? (clashes.length > 0 ? "⚠ " + KeybindStore.pretty(pending) + " is already used by: " + clashes.join(", ") : "") : remapped ? "Changed from " + KeybindStore.pretty(origin) : ""
        changed: remapped
        onReset: KeybindStore.reset(origin)

        function apply(k) {
            pending = "";
            KeybindStore.remap(origin, k);
        }

        Row {
            spacing: 4
            SButton {
                visible: row.clashes.length > 0
                kind: "text"
                danger: true
                text: "Use anyway"
                onClicked: row.apply(row.pending)
            }
            SButton {
                visible: row.pending !== ""
                kind: "text"
                text: "Cancel"
                onClicked: row.pending = ""
            }
            KeyRecorder {
                keys: row.pending !== "" ? row.pending : row.modelData.combo
                onRecorded: k => {
                    if (KeybindStore.normalize(k) === row.modelData.norm)
                        return;
                    row.pending = k;
                    if (row.clashes.length === 0)
                        row.apply(k);
                }
            }
            SmallButton {
                icon: "block"
                onClicked: KeybindStore.disable(row.origin)
            }
        }
    }

    component SmallButton: IconButton {
        property bool danger: false
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        iconSize: 18
        iconColor: danger ? Theme.error : Theme.fgSurfaceVariant
        hoverColor: Theme.surfaceHigh
    }

    // Editor for a custom shortcut: name, command, keys, with a conflict check
    component CustomEditor: Column {
        id: ed
        required property int index
        required property var entry
        property string keys: entry.keys
        readonly property var clashes: keys === "" ? [] : KeybindStore.conflicts(KeybindStore.normalize(keys), index >= 0 ? KeybindStore.normalize(entry.keys) : "")
        readonly property bool valid: keys !== "" && command.text.trim() !== ""

        width: parent.width
        onEntryChanged: keys = entry.keys

        SettingRow {
            title: "Name"
            Field {
                id: description
                implicitWidth: 360
                placeholder: "e.g. Open btop"
                text: ed.entry.description ?? ""
            }
        }
        SettingRow {
            title: "Command"
            subtitle: "Runs through the shell, like hl.dsp.exec_cmd"
            Field {
                id: command
                implicitWidth: 360
                mono: true
                placeholder: "kitty -e btop"
                text: ed.entry.command ?? ""
            }
        }
        SettingRow {
            title: "Keys"
            subtitle: ed.clashes.length > 0 ? "⚠ Already used by: " + ed.clashes.join(", ") : ""
            KeyRecorder {
                keys: ed.keys
                onRecorded: k => ed.keys = k
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 8
            bottomPadding: 12
            SButton {
                kind: "text"
                text: "Cancel"
                onClicked: page.editing = -2
            }
            SButton {
                kind: "filled"
                text: ed.clashes.length > 0 ? "Save anyway" : "Save"
                enabled: ed.valid
                onClicked: {
                    KeybindStore.setCustom(ed.index, { keys: ed.keys, command: command.text.trim(), description: description.text.trim(), enabled: ed.entry.enabled !== false });
                    page.editing = -2;
                }
            }
        }
    }
}
