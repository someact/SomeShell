import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// The Quick Share page (services/Share.qml): receiving on/off, then Send
// (the files, chosen from a drop or the browser, and the devices: Quick
// Share on the network first, Bluetooth after) or Recent (the last
// transfers). A device asking to pair or a phone sending a file takes the
// page over until answered.
Item {
    id: root

    readonly property var incoming: Share.offers[0] ?? null
    readonly property bool asking: incoming !== null || Share.pairs.length > 0
    readonly property var pending: Share.pending
    readonly property var files: pending?.files ?? []
    readonly property string view: Share.view

    implicitWidth: 620
    implicitHeight: col.implicitHeight

    function size(b) {
        const u = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) {
            b /= 1000;
            i++;
        }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i];
    }
    function when(t) {
        const d = new Date(t), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "d MMM, HH:mm");
    }
    function fileIcon(name) {
        return /\.(png|jpe?g|gif|webp|heic|avif|bmp|svg)$/i.test(name) ? "image"
            : /\.(mp4|mkv|webm|mov|avi)$/i.test(name) ? "movie"
            : /\.(mp3|m4a|opus|ogg|flac|wav)$/i.test(name) ? "music_note"
            : /\.(pdf)$/i.test(name) ? "picture_as_pdf"
            : /\.(zip|tar|gz|xz|7z|rar)$/i.test(name) ? "folder_zip"
            : "draft";
    }

    // The devices again whenever the page opens (pairing may have changed),
    // and phones on the network while it is open
    Component.onCompleted: {
        Share.refresh();
        Share.setScan(true);
    }
    Component.onDestruction: Share.setScan(false)

    Column {
        id: col
        width: root.width
        spacing: 14

        // A device asking to pair
        PairPrompt {
            width: parent.width
        }

        // Incoming: who, what, Accept / Decline
        Column {
            visible: root.incoming !== null && Share.pairs.length === 0
            width: parent.width
            spacing: 14
            Row {
                width: parent.width
                spacing: 16
                Rectangle {
                    width: 60
                    height: 60
                    radius: Theme.shape.small
                    color: Theme.ink.raised
                    Icon {
                        anchors.centerIn: parent
                        name: "download"
                        size: 28
                        color: Theme.ink.fg
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 76
                    spacing: 4
                    Txt {
                        width: parent.width
                        text: root.incoming?.name ?? ""
                        size: Theme.font.body
                        face: Theme.font.medium
                    }
                    Txt {
                        width: parent.width
                        text: (root.incoming?.peer ?? "") + " wants to send this  ·  " + root.size(root.incoming?.size ?? 0)
                            + (root.incoming?.pin ? "  ·  PIN " + root.incoming.pin : "")
                            + (root.incoming?.via === "quick" ? "  ·  Wi-Fi" : "  ·  Bluetooth")
                            + (Share.offers.length > 1 ? "  ·  " + (Share.offers.length - 1) + " more" : "")
                        caps: true
                        color: Theme.ink.mute
                    }
                }
            }
            Row {
                spacing: 8
                Chip {
                    icon: "check"
                    label: "Accept"
                    active: true
                    onClicked: Share.answer(root.incoming.id, true)
                }
                Chip {
                    icon: "close"
                    label: "Decline"
                    onClicked: Share.answer(root.incoming.id, false)
                }
            }
        }

        // Top: receiving on/off, and the views
        Item {
            visible: !root.asking
            width: parent.width
            height: 34
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Share.receiving ? "download" : "file_download_off"
                    label: Share.receiving ? "Receiving on" : "Receiving off"
                    active: Share.receiving
                    enabled: Share.alive
                    onClicked: Share.toggleReceive()
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Share.alive
                    text: Share.receiving ? "Visible as " + (Bluetooth.defaultAdapter?.name ?? "this computer") : "Phones cannot send here"
                    caps: true
                    color: Theme.ink.mute
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Chip {
                    icon: "send"
                    label: "Send"
                    active: root.view !== "recent"
                    onClicked: Share.view = "send"
                }
                Chip {
                    icon: "history"
                    label: "Recent"
                    active: root.view === "recent"
                    onClicked: Share.view = "recent"
                }
            }
        }

        Rectangle {
            visible: !root.asking
            width: parent.width
            height: 1
            color: Theme.ink.line
        }

        // Not running: why
        Txt {
            visible: !root.asking && !Share.alive
            width: parent.width
            text: !Share.adapter ? "No Bluetooth on this machine." : !Share.installed ? "The Quick Share helper is not installed (share/install.sh)." : "Starting…"
            color: Theme.ink.mute
        }

        // SEND: the files, then where to
        Column {
            visible: !root.asking && Share.alive && root.view === "send"
            width: parent.width
            spacing: 12

            Item {
                width: parent.width
                height: 34
                Txt {
                    anchors.left: parent.left
                    anchors.right: sendChips.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pending?.url ? "The link  ·  " + root.pending.url
                        : root.files.length === 0 ? "No files chosen: choose some, or drop them on the island"
                        : root.files.length === 1 ? root.files[0].split("/").pop()
                        : root.files.length + " files  ·  " + root.files.slice(0, 3).map(f => f.split("/").pop()).join(", ") + (root.files.length > 3 ? "…" : "")
                    face: root.files.length || root.pending?.url ? Theme.font.medium : Theme.font.light
                    color: root.files.length || root.pending?.url ? Theme.ink.fg : Theme.ink.mute
                }
                Row {
                    id: sendChips
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Chip {
                        icon: "folder_open"
                        label: root.files.length ? "Change" : "Choose files"
                        active: root.files.length === 0 && !root.pending?.url
                        onClicked: {
                            Share.chosen = root.files.slice();
                            Share.view = "browse";
                        }
                    }
                    Chip {
                        visible: root.pending !== null
                        icon: "close"
                        label: "Clear"
                        onClicked: Share.pending = null
                    }
                }
            }

            Txt {
                visible: Share.targets.length > 0
                text: "Send to"
                caps: true
                color: Theme.ink.mute
            }
            Column {
                width: parent.width
                Repeater {
                    model: Share.targets
                    ListRow {
                        id: target
                        required property var modelData
                        icon: modelData.icon
                        title: modelData.name
                        sub: modelData.sub
                        clickable: root.files.length > 0 || !!root.pending?.url
                        onClicked: Share.sendTo(modelData)
                        Icon {
                            visible: target.clickable
                            anchors.verticalCenter: parent.verticalCenter
                            name: "send"
                            size: 20
                            color: Theme.ink.mute
                        }
                    }
                }
            }
            // Quick Share phones show up here once found on the network
            Txt {
                visible: Share.quick && Share.nearby.length === 0
                width: parent.width
                text: "Looking on the network: on the phone, Quick Share visible to Everyone, on the same Wi-Fi"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                color: Theme.ink.mute
            }
            Row {
                visible: Share.targets.length === 0
                spacing: 12
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Or pair a phone by Bluetooth"
                    color: Theme.ink.mute
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "bluetooth"
                    label: "Bluetooth"
                    onClicked: {
                        Ui.openPage("control");
                        Ui.detail = "bt";
                    }
                }
            }
        }

        // BROWSE: places, the folder, Done
        Column {
            visible: !root.asking && Share.alive && root.view === "browse"
            width: parent.width
            spacing: 10

            Row {
                spacing: 4
                Repeater {
                    model: [["Home", "home", ""], ["Downloads", "download", "/Downloads"], ["Pictures", "image", "/Pictures"],
                        ["Documents", "description", "/Documents"], ["Videos", "movie", "/Videos"]]
                    Chip {
                        required property var modelData
                        icon: modelData[1]
                        label: modelData[0]
                        active: Share.browseDir === Paths.home + modelData[2]
                        onClicked: Share.browseDir = Paths.home + modelData[2]
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 10
                Tap {
                    id: up
                    width: 34
                    height: 34
                    radius: 17
                    outlined: true
                    enabled: Share.browseDir !== "/"
                    onClicked: Share.browseDir = Share.browseDir.replace(/\/[^\/]+\/?$/, "") || "/"
                    Icon {
                        anchors.centerIn: parent
                        name: "arrow_upward"
                        size: 18
                        color: parent.fg
                    }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - up.width - 10
                    text: Share.browseDir.replace(Paths.home, "~")
                    elide: Text.ElideMiddle
                    color: Theme.ink.mute
                }
            }

            FolderListModel {
                id: folder
                folder: "file://" + Share.browseDir
                showDirsFirst: true
                showHidden: false
                showDotAndDotDot: false
                sortCaseSensitive: false
            }
            Flickable {
                id: list
                width: parent.width
                height: Math.min(entries.implicitHeight, 52 * 6)
                contentHeight: entries.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: entries
                    width: list.width
                    Repeater {
                        model: folder
                        ListRow {
                            id: entry
                            required property string fileName
                            required property string filePath
                            required property bool fileIsDir
                            required property int fileSize
                            required property date fileModified
                            required property int index
                            readonly property bool picked: Share.chosen.includes(filePath)
                            // Long folders: the first 200
                            visible: index < 200
                            height: visible ? implicitHeight : 0
                            icon: fileIsDir ? "folder" : root.fileIcon(fileName)
                            iconFilled: picked
                            title: fileName
                            sub: fileIsDir ? "Folder" : root.size(fileSize) + "  ·  " + root.when(fileModified.getTime())
                            onClicked: {
                                if (fileIsDir)
                                    Share.browseDir = filePath;
                                else
                                    Share.chosen = picked ? Share.chosen.filter(f => f !== filePath) : Share.chosen.concat([filePath]);
                            }
                            Icon {
                                visible: !entry.fileIsDir
                                anchors.verticalCenter: parent.verticalCenter
                                name: entry.picked ? "check_box" : "check_box_outline_blank"
                                filled: entry.picked
                                size: 22
                                color: entry.picked ? Theme.ink.accent : Theme.ink.mute
                            }
                        }
                    }
                    ListRow {
                        visible: folder.status === FolderListModel.Ready && folder.count === 0
                        icon: "folder_off"
                        title: "Nothing here"
                        clickable: false
                        line: false
                    }
                }
            }

            Item {
                width: parent.width
                height: 34
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Share.chosen.length === 0 ? "Click files to choose them" : Share.chosen.length + " chosen"
                    caps: true
                    color: Share.chosen.length ? Theme.ink.fg : Theme.ink.mute
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Chip {
                        icon: "close"
                        label: "Cancel"
                        onClicked: Share.view = "send"
                    }
                    Chip {
                        icon: "check"
                        label: "Done"
                        active: true
                        enabled: Share.chosen.length > 0
                        onClicked: {
                            Share.pending = { files: Share.chosen.slice(), url: "" };
                            Share.view = "send";
                        }
                    }
                }
            }
        }

        // RECENT: the last transfers
        Column {
            visible: !root.asking && root.view === "recent"
            width: parent.width
            spacing: 10
            Flickable {
                id: recent
                width: parent.width
                height: Math.min(recentRows.implicitHeight, 52 * 6)
                contentHeight: recentRows.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: recentRows
                    width: recent.width
                    Repeater {
                        model: Share.history
                        ListRow {
                            required property var modelData
                            icon: modelData.dir === "receive" ? "download" : "upload"
                            title: modelData.name
                            sub: (modelData.dir === "receive" ? "From " : "To ") + modelData.peer + "  ·  " + root.when(modelData.time)
                                + "  ·  " + (modelData.via === "quick" ? "Wi-Fi" : "Bluetooth")
                            onClicked: {
                                Ui.close();
                                Quickshell.execDetached(["xdg-open", modelData.path]);
                            }
                            // Right click, Shift+Enter: in its folder
                            onRightClicked: {
                                Ui.close();
                                Quickshell.execDetached([Quickshell.shellPath("lib/drop.sh"), "show", modelData.path]);
                            }
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 34
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Share.history.length === 0 ? "Nothing shared yet" : "Click: open  ·  right click: show in folder"
                    caps: true
                    color: Theme.ink.mute
                }
                Chip {
                    visible: Share.history.length > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "delete_sweep"
                    label: "Clear"
                    onClicked: Share.clearHistory()
                }
            }
        }
    }
}
