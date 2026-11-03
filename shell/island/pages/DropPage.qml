import QtQuick
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// What was dropped on the island (services/Drop.qml): a preview, then the
// actions for its kind as chips (click, or arrows and Enter). Esc closes.
Item {
    id: root

    readonly property var item: Drop.item
    readonly property string kind: item?.kind ?? ""
    readonly property var files: item?.files ?? []
    readonly property var first: files[0] ?? null

    implicitWidth: 600
    implicitHeight: col.implicitHeight

    function size(b) {
        if (b === undefined || b === null)
            return "";
        const u = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) {
            b /= 1000;
            i++;
        }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i];
    }

    readonly property string icon: kind === "image" ? "image"
        : kind === "video" ? "smart_display"
        : kind === "link" ? "link"
        : kind === "text" ? "notes"
        : kind === "files" ? (files.length > 1 ? "file_copy" : first?.dir ? "folder" : "draft")
        : "hourglass_empty"
    readonly property string title: kind === "loading" ? "Reading " + (item?.label ?? "") + "…"
        : kind === "files" && files.length > 1 ? files.length + " files"
        : kind === "files" || kind === "image" ? (first?.name ?? "")
        : kind === "video" ? (item.title || "Getting the title…")
        : kind === "link" ? item.url
        : kind === "text" ? item.text.split("\n")[0]
        : ""
    readonly property string sub: kind === "files" && files.length > 1 ? size(files.reduce((a, f) => a + f.size, 0))
        : kind === "files" ? (first?.dir ? "Folder · " : "") + size(first?.size)
        : kind === "image" ? (first?.w ? first.w + " × " + first.h + "  ·  " : "") + size(first?.size) + (item.web ? "  ·  from the web" : "")
        : kind === "video" ? (item.site || "Video") + " link"
        : kind === "link" ? (item.note ?? "")
        : kind === "text" ? item.text.length + " characters"
        : ""

    Column {
        id: col
        width: root.width
        spacing: 18

        // Preview: a picture or an icon, the name and a line about it
        Row {
            width: parent.width
            spacing: 16
            ClippingRectangle {
                id: thumb
                width: 72
                height: 72
                radius: Theme.shape.small
                color: Theme.ink.raised
                Image {
                    id: pic
                    anchors.fill: parent
                    visible: root.kind === "image" && status === Image.Ready
                    source: root.kind === "image" && root.first ? "file://" + root.first.path : ""
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !pic.visible
                    name: root.icon
                    size: 30
                    color: Theme.ink.fg
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - thumb.width - 16
                spacing: 4
                Txt {
                    width: parent.width
                    text: root.title
                    size: Theme.font.body
                    face: Theme.font.medium
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                Txt {
                    width: parent.width
                    visible: text !== ""
                    text: root.sub
                    caps: true
                    color: Theme.ink.mute
                }
            }
        }

        // Several files: their names
        Column {
            visible: root.kind === "files" && root.files.length > 1
            width: parent.width
            spacing: 2
            Repeater {
                model: root.files.slice(0, 4)
                Txt {
                    required property var modelData
                    width: parent.width
                    text: (modelData.dir ? "▸ " : "") + modelData.name
                    color: Theme.ink.mute
                }
            }
            Txt {
                visible: root.files.length > 4
                text: "+ " + (root.files.length - 4) + " more"
                caps: true
                color: Theme.ink.mute
            }
        }

        // Text: a few more lines of it
        Txt {
            visible: root.kind === "text" && root.item.text.includes("\n")
            width: parent.width
            text: root.kind === "text" ? root.item.text.split("\n").slice(1, 5).join("\n") : ""
            color: Theme.ink.mute
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.ink.line
        }

        // The actions
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: Drop.actions
                Chip {
                    required property var modelData
                    required property int index
                    icon: modelData.icon
                    label: modelData.label
                    active: index === 0
                    onClicked: Drop.run(modelData.id)
                }
            }
        }
        Txt {
            visible: root.kind === "loading"
            text: "One moment"
            caps: true
            color: Theme.ink.mute
        }
    }
}
