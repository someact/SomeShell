import QtQuick
import qs.core
import qs.components

// The open island: page tabs along the top (icons; the active one shows its
// number and name, the clock sits at the end), the page title, then the page.
// The island takes the size of this content, so each page sets its own size.
FocusScope {
    id: root

    readonly property var current: Ui.pageInfo

    // Wide enough for the page, and for the tabs plus the clock at the end
    implicitWidth: Math.max(tabs.x + tabs.implicitWidth + 24 + clock.width + 24, page.implicitWidth + 52)
    implicitHeight: page.y + page.implicitHeight + 24

    focus: true
    Component.onCompleted: {
        show();
        forceActiveFocus();
        Qt.callLater(() => underline.ready = true);
    }

    // Keyboard: the arrows move a mark (Ui.kbItem) between the things on
    // the page you can click, by position. Anything can join by having
    //   kbNav: bool        can be marked now
    //   kbClick()          Enter            kbAlt()   Shift+Enter (right click)
    //   kbHold(bool)       Enter held down (instead of kbClick)
    //   kbStep(d): bool    Left/Right while marked (a slider); true if used
    //   kbLeaf: true       the things inside it are not marked on their own
    //   kbField: true      a text field (Enter types in it)
    // and a KeyRing to show the mark. With nothing marked, Left/Right switch
    // pages and Down marks the first thing; Up from the top unmarks.
    Keys.onPressed: event => {
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        const shift = event.modifiers & Qt.ShiftModifier;
        const kb = Ui.kbItem;
        if (event.key === Qt.Key_Escape) {
            if (Ui.controlEdit)
                Ui.controlEdit = false;
            else if (Ui.detail !== "")
                Ui.detail = "";
            else
                Ui.close();
        } else if (event.key === Qt.Key_Tab) {
            Ui.nextPage(1);
        } else if (event.key === Qt.Key_Backtab) {
            Ui.nextPage(-1);
        } else if (enter && kb && shift) {
            if (!event.isAutoRepeat && typeof kb.kbAlt === "function")
                kb.kbAlt();
        } else if (enter && kb) {
            if (event.isAutoRepeat) {
                // held: nothing more
            } else if (typeof kb.kbHold === "function") {
                kb.kbHold(true);
            } else if (typeof kb.kbClick === "function") {
                kb.kbClick();
            }
        } else if (shift && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            return;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const d = event.key === Qt.Key_Left ? -1 : 1;
            if (kb && typeof kb.kbStep === "function" && kb.kbStep(d)) {
                // a slider took it
            } else if (kb) {
                mark(d, 0);
            } else {
                Ui.nextPage(d);
            }
        } else if (event.key === Qt.Key_Down) {
            mark(0, 1);
        } else if (event.key === Qt.Key_Up) {
            if (kb && !mark(0, -1))
                Ui.kbItem = null;
        } else {
            return;
        }
        event.accepted = true;
    }
    Keys.onReleased: event => {
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        if (enter && !event.isAutoRepeat && Ui.kbItem && typeof Ui.kbItem.kbHold === "function") {
            Ui.kbItem.kbHold(false);
            event.accepted = true;
        }
    }

    // Everything that can be marked now: the Edit chip and the page
    function navItems() {
        const out = [];
        const walk = item => {
            if (!item || !item.visible || item.opacity === 0)
                return;
            if (item.kbNav === true && item.width > 0 && item.height > 0) {
                out.push(item);
                if (item.kbLeaf === true)
                    return;
            }
            for (const c of item.children)
                walk(c);
        };
        walk(editChip);
        walk(page);
        return out;
    }
    // Moves the mark one step (dx, dy); false when there is nothing that way
    function mark(dx, dy) {
        const items = navItems();
        const cur = items.includes(Ui.kbItem) ? Ui.kbItem : null;
        let best = null;
        if (!cur) {
            // Nothing marked: Down starts at the page's top left (the Edit
            // chip above it is reached with Up)
            if (dy <= 0)
                return false;
            const onPage = items.filter(it => it !== editChip);
            let bestKey = Infinity;
            for (const it of onPage.length ? onPage : items) {
                const r = it.mapToItem(root, 0, 0, it.width, it.height);
                const k = Math.round(r.y / 8) * 100000 + r.x;
                if (k < bestKey) {
                    bestKey = k;
                    best = it;
                }
            }
        } else {
            const a = cur.mapToItem(root, 0, 0, cur.width, cur.height);
            const acx = a.x + a.width / 2, acy = a.y + a.height / 2;
            let bestScore = Infinity;
            for (const it of items) {
                if (it === cur)
                    continue;
                const b = it.mapToItem(root, 0, 0, it.width, it.height);
                const bcx = b.x + b.width / 2, bcy = b.y + b.height / 2;
                // Its centre must lie that way
                if ((bcx - acx) * dx + (bcy - acy) * dy <= 2)
                    continue;
                // The gap along the way, and how far off to the side
                const gap = dx > 0 ? b.x - (a.x + a.width) : dx < 0 ? a.x - (b.x + b.width)
                    : dy > 0 ? b.y - (a.y + a.height) : a.y - (b.y + b.height);
                const side = dx !== 0
                    ? Math.max(0, Math.max(a.y, b.y) - Math.min(a.y + a.height, b.y + b.height))
                    : Math.max(0, Math.max(a.x, b.x) - Math.min(a.x + a.width, b.x + b.width));
                const offCentre = dx !== 0 ? Math.abs(bcy - acy) : Math.abs(bcx - acx);
                const score = Math.max(0, gap) + side * 3 + offCentre * 0.05;
                if (score < bestScore) {
                    bestScore = score;
                    best = it;
                }
            }
        }
        if (!best)
            return false;
        // Leaving a text field: the keys come back here
        if (cur && cur.kbField === true)
            root.forceActiveFocus();
        Ui.kbItem = best;
        reveal(best);
        return true;
    }
    // Scrolls the list that holds `it` so it shows
    function reveal(it) {
        for (let p = it.parent; p && p !== root; p = p.parent) {
            if (p.contentItem === undefined || p.contentY === undefined || p.contentHeight === undefined)
                continue;
            const r = it.mapToItem(p.contentItem, 0, 0, it.width, it.height);
            if (p.contentHeight > p.height) {
                if (r.y < p.contentY)
                    p.contentY = r.y;
                else if (r.y + r.height > p.contentY + p.height)
                    p.contentY = r.y + r.height - p.height;
            }
            if (p.contentWidth > p.width) {
                if (r.x < p.contentX)
                    p.contentX = r.x;
                else if (r.x + r.width > p.contentX + p.width)
                    p.contentX = r.x + r.width - p.width;
            }
            return;
        }
    }

    // The mouse wheel switches pages. Pages that scroll (lists, lyrics, the
    // calendar's month, sliders) take the wheel first, so this only gets it
    // over the tab row and over pages with nothing to scroll. One page per
    // notch; a touchpad adds up to a notch.
    WheelHandler {
        property real acc: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x) ? event.angleDelta.y : event.angleDelta.x;
            acc += d;
            while (Math.abs(acc) >= 120) {
                const step = acc > 0 ? -1 : 1;
                acc -= acc > 0 ? 120 : -120;
                if (Ui.controlEdit)
                    return;
                Ui.nextPage(step);
            }
        }
    }

    // Tabs
    Row {
        id: tabs
        x: 14
        y: 6
        spacing: 2

        Repeater {
            id: tabRepeater
            model: Ui.pages

            Tap {
                id: tab
                required property var modelData
                required property int index
                readonly property bool on: index === Ui.page && Ui.extra === ""
                implicitHeight: 36
                implicitWidth: tabRow.implicitWidth + 20
                radius: Theme.shape.small
                onClicked: Ui.goTo(index)

                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: tab.modelData.icon
                        filled: tab.on
                        size: 19
                        color: tab.pressed ? tab.fg : tab.on ? Theme.ink.fg : Theme.ink.mute
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.on
                        text: String(tab.index + 1).padStart(2, "0") + "  " + tab.modelData.label
                        caps: true
                        color: tab.fg
                    }
                }
            }
        }
    }

    // One underline that slides to the active tab
    Rectangle {
        id: underline
        property bool ready: false   // no slide on the first layout
        readonly property Item tab: tabRepeater.count > Ui.page ? tabRepeater.itemAt(Ui.page) : null
        x: tabs.x + (tab ? tab.x + 10 : 0)
        // No tab is lit on a tabless page
        opacity: Ui.extra === "" ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }
        y: tabs.y + tabs.height - height
        width: tab ? tab.width - 20 : 0
        height: 2
        color: Theme.ink.accent
        Behavior on x {
            enabled: underline.ready
            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
        }
        Behavior on width {
            enabled: underline.ready
            NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
        }
    }

    Digits {
        id: clock
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: tabs.verticalCenter
        text: Clock.time
        size: Theme.font.body
    }

    Rectangle {
        id: tabLine
        anchors.top: tabs.bottom
        width: parent.width
        height: 1
        color: Theme.ink.line
    }

    // Page number and title
    Row {
        id: head
        anchors.top: tabLine.bottom
        anchors.topMargin: 14
        x: 26
        spacing: 14
        Txt {
            anchors.baseline: title.baseline
            text: root.current.keys ?? String(Ui.page + 1).padStart(2, "0") + " / " + String(Ui.pages.length).padStart(2, "0")
            caps: true
            color: Theme.ink.accent
        }
        Txt {
            id: title
            text: root.current.label
            caps: true
            size: Theme.font.headline
            face: Theme.font.bold
            font.letterSpacing: 1
        }
    }

    // Control: quick edit of its tiles (also a long press on a tile)
    Chip {
        id: editChip
        visible: root.current.id === "control" && !Ui.detail
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: head.verticalCenter
        icon: Ui.controlEdit ? "check" : "edit"
        label: Ui.controlEdit ? "Done" : "Edit"
        active: Ui.controlEdit
        onClicked: Ui.controlEdit = !Ui.controlEdit
    }

    // Pages live in two slots: on a switch the new page loads into the free
    // slot and slides in (from the side you moved toward) while it is wiped
    // in top to bottom; the old one fades out fast and is unloaded.
    readonly property var files: ({ search: "pages/SearchPage.qml", control: "pages/ControlPage.qml", media: "pages/MediaPage.qml", notify: "pages/NotifyPage.qml", calendar: "pages/CalendarPage.qml", system: "pages/SystemPage.qml", power: "pages/PowerPage.qml", clipboard: "pages/ClipboardPage.qml", drop: "pages/DropPage.qml" })
    readonly property int slide: 24
    property int slot: 0
    readonly property Item page: slot === 0 ? slotA : slotB
    property Item incoming: null
    property Item outgoing: null

    component PageSlot: FocusScope {
        property var info: null      // the page this slot holds
        property real reveal: 1      // the wipe: 0 hidden, 1 fully shown
        property real shift: 0       // the slide, in pixels
        property alias loader: loader
        x: 26 + shift
        implicitWidth: loader.implicitWidth
        implicitHeight: loader.implicitHeight
        width: implicitWidth
        height: implicitHeight * reveal
        clip: reveal < 1
        Loader {
            id: loader
            focus: true
        }
    }
    PageSlot {
        id: slotA
        anchors.top: head.bottom
        anchors.topMargin: 16
        focus: true
    }
    PageSlot {
        id: slotB
        anchors.top: head.bottom
        anchors.topMargin: 16
    }

    // Loading is done here, imperatively: writing sourceComponent (even
    // undefined) clears source, so two bindings can unload the page when
    // they update in the wrong order (seen on the tablet)
    function fill(s, info) {
        s.info = info;
        const file = files[info.id];
        if (file)
            s.loader.source = Qt.resolvedUrl(file);
        else
            s.loader.sourceComponent = placeholder;
    }
    function empty(s) {
        s.loader.sourceComponent = null;
        s.info = null;
        s.opacity = 1;
        s.reveal = 1;
        s.shift = 0;
    }
    function show() {
        // A switch during the last one: finish it at once
        if (fadeOut.running) {
            fadeOut.stop();
            empty(outgoing);
        }
        if (wipeIn.running) {
            wipeIn.stop();
            incoming.reveal = 1;
            incoming.shift = 0;
            incoming.opacity = 1;
        }
        if (!page.info) {
            fill(page, current);
            return;
        }
        const prev = page;
        const next = slot === 0 ? slotB : slotA;
        next.reveal = 0;
        next.shift = slide * Ui.direction;
        next.opacity = 0;
        fill(next, current);
        slot = slot === 0 ? 1 : 0;
        next.focus = true;
        prev.focus = false;
        outgoing = prev;
        incoming = next;
        fadeOut.restart();
        wipeIn.restart();
    }
    onCurrentChanged: show()

    NumberAnimation {
        id: fadeOut
        target: root.outgoing
        property: "opacity"
        to: 0
        duration: Motion.quick
        onFinished: root.empty(root.outgoing)
    }
    ParallelAnimation {
        id: wipeIn
        NumberAnimation { target: root.incoming; property: "reveal"; to: 1; duration: Motion.normal; easing.type: Motion.easing }
        NumberAnimation { target: root.incoming; property: "shift"; to: 0; duration: Motion.normal; easing.type: Motion.easing }
        NumberAnimation { target: root.incoming; property: "opacity"; to: 1; duration: Motion.fast; easing.type: Motion.easing }
    }

    Component {
        id: placeholder
        Item {
            // The page of this slot (the old one keeps its text while it fades)
            readonly property var info: parent?.parent?.info ?? root.current
            // Sizes from the approved mockup, so the island already reshapes per page
            readonly property var sizes: ({
                search: [588, 400], control: [768, 420], media: [868, 270], notify: [488, 430],
                calendar: [728, 330], system: [928, 250], power: [748, 250]
            })
            readonly property var size: sizes[info.id] ?? [500, 300]
            implicitWidth: size[0]
            implicitHeight: size[1]

            Rectangle {
                anchors.fill: parent
                radius: Theme.shape.tile
                color: "transparent"
                border.width: 1
                border.color: Theme.ink.line
            }
            Txt {
                anchors.centerIn: parent
                text: info.label + " page comes in step " + (["search", "power"].includes(info.id) ? 3 : info.id === "calendar" || info.id === "system" ? 5 : 4)
                caps: true
                color: Theme.ink.mute
            }
        }
    }

    // The open island wipes in, once, when it opens
    opacity: 0
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: Motion.normal
        easing.type: Motion.easing
    }
}
