import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// Command line control: qs -c someshell ipc call <target> <function> [args]
// Every feature can be driven from here, so it can be tested without a mouse.
Scope {
    id: root

    IpcHandler {
        target: "island"

        // open search|control|media|notify|calendar|system|power|clipboard
        function open(page: string): void { Ui.openPage(page || "search"); }
        function close(): void { Ui.close(); }
        function toggle(): void { Ui.toggle(); }
        function page(step: int): void { Ui.nextPage(step); }
        function alert(title: string, body: string): void { Ui.showAlert(title, body, "IPC", "terminal"); }
        function hide(): void { Ui.hidden = !Ui.hidden; }
        // A control tile's page: net, bt, sound, night
        function detail(name: string): void { Ui.openPage("control"); Ui.detail = name; }
        function state(): string {
            return JSON.stringify({
                open: Ui.open,
                page: Ui.pageId,
                controlEdit: Ui.controlEdit,
                detail: Ui.detail,
                // The keyboard mark: its label, title, icon or type
                kb: Ui.kbItem ? (Ui.kbItem.label || Ui.kbItem.title || Ui.kbItem.icon || Ui.kbItem.kind || Ui.kbItem.modelData?.name || String(Ui.kbItem).split("(")[0].replace(/_QML.*/, ""))
                    + " @" + Math.round(Ui.kbItem.mapToItem(null, 0, 0).x) + "," + Math.round(Ui.kbItem.mapToItem(null, 0, 0).y) : null,
                openedByHover: Ui.openedByHover,
                monitor: Ui.monitor,
                quiet: Ui.quiet,
                hidden: Ui.hidden,
                alert: Ui.alert ? Ui.alert.title : null,
                gameMode: GameMode.active,
                theme: { dark: Theme.dark, inkDark: Theme.inkDark, islandColor: String(Theme.ink.bg), style: Desktop.style, color: Desktop.island.color, preset: Desktop.preset }
            });
        }
    }

    // lock: lock the session (scripts/lock.sh calls this). preview: the
    // same page in a normal window, nothing locked (Esc closes). There is no
    // unlock here: only the password opens the lock.
    IpcHandler {
        target: "lock"

        function lock(): void { Locker.lock(); }
        function preview(): void { Locker.showPreview(); }
        function state(): string {
            return JSON.stringify({ locked: Locker.locked, preview: Locker.preview, fails: Locker.fails, checking: Locker.checking, typed: Locker.password.length });
        }
    }

    // settings open: the window on its last page; page <id>: on that page
    // (general, displays); close
    IpcHandler {
        target: "settings"

        function open(): void { Ui.openSettings(""); }
        function page(id: string): void { Ui.openSettings(id); }
        function close(): void { Ui.settings = false; }
        function state(): string { return JSON.stringify({ open: Ui.settings, page: Ui.settingsPage }); }
    }

    // displays: the Displays page's work without the window. set <name>
    // <key> <value> changes the draft (key: on, res, mode, scale, transform,
    // x, y, mirror, vrr, bits, main); apply starts the 15 s countdown; keep
    // saves; back goes back now
    IpcHandler {
        target: "displays"

        function state(): string {
            return JSON.stringify({ set: Displays.setKey, saved: Displays.saved, changes: Displays.changes, waiting: Displays.waiting, left: Displays.left,
                draft: Displays.draft.map(m => ({ name: m.name, mode: m.mode, scale: m.scale, transform: m.transform, x: m.x, y: m.y, on: m.on, mirror: m.mirror, vrr: m.vrr, bits: m.bits, main: m.main })) });
        }
        function set(name: string, key: string, value: string): void {
            const m = Displays.draft.find(d => d.name === name);
            if (!m)
                return;
            let v = value;
            if (["on", "main"].includes(key))
                v = value === "true";
            else if (["scale", "transform", "x", "y", "vrr", "bits"].includes(key))
                v = Number(value);
            if (key === "x" || key === "y")
                Displays.place(m.desc, key === "x" ? v : m.x, key === "y" ? v : m.y);
            else
                Displays.set(m.desc, key, v);
        }
        function apply(): void { Displays.apply(); }
        function keep(): void { Displays.keep(); }
        function back(): void { Displays.revert(); }
        function undo(): void { Displays.undo(); }
        function identify(): void { Displays.identify(); }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void { Wallpaper.set(path); }
        function get(): string { return Wallpaper.path; }
        function recolor(): void { Wallpaper.recolor(); }
    }

    IpcHandler {
        target: "record"

        function toggle(): void { Recorder.toggle(false); }
        function sound(): void { Recorder.toggle(true); }
        function state(): string { return JSON.stringify({ recording: Recorder.recording, seconds: Recorder.seconds, file: Recorder.file }); }
    }

    IpcHandler {
        target: "control"

        // Quick edit on/off; the tiles as they are now (id and size, in order)
        function edit(on: bool): void { Ui.openPage("control"); Ui.controlEdit = on; }
        function layout(): string { return JSON.stringify(Desktop.control.length ? ControlTiles.clean(Desktop.control) : ControlTiles.defaultLayout); }
        function reset(): void { Desktop.control = []; }

        function state(): string {
            return JSON.stringify({
                network: Network.label, online: Network.online, wifiScan: Network.wifi?.scannerEnabled ?? false,
                volume: Math.round(Audio.volume * 100), muted: Audio.muted, output: Audio.name(Audio.sink), apps: Audio.streams.length,
                brightness: Brightness.screens, nightLight: NightLight.on, keepAwake: KeepAwake.on, dnd: Notifications.dnd,
                media: Media.active ? { title: Media.title, kind: Media.kind, playing: Media.playing } : null,
                notifications: Notifications.history.length
            });
        }
    }

    IpcHandler {
        target: "widget"

        // Desktop widgets: every entry; add one of a kind on a monitor ("" for
        // the island's) at the first free place, or at a cell; change one
        // (JSON fields, e.g. {"x":2,"card":false}); set one option; remove
        function list(): string { return JSON.stringify(Desktop.widgets); }
        function add(kind: string, monitor: string): string { return root.addWidget(kind, monitor, undefined, undefined); }
        function addAt(kind: string, monitor: string, x: int, y: int): string { return root.addWidget(kind, monitor, x, y); }
        function change(id: string, json: string): void { Editor.record(); Widgets.change(id, JSON.parse(json)); }
        function option(id: string, key: string, json: string): void { Editor.record(); Widgets.setOpt(id, key, JSON.parse(json)); }
        function remove(id: string): void { Editor.record(); Widgets.remove(id); }
        function clear(): void { Editor.record(); Desktop.widgets = []; }
        function choose(id: string): void { Ui.edit("widgets", id); }
    }
    function addWidget(kind, monitor, x, y) {
        Editor.record();
        return Widgets.addOn(kind, Widgets.screenNamed(monitor || Ui.monitor), x, y);
    }

    IpcHandler {
        target: "battery"

        function state(): string {
            return JSON.stringify({
                available: Battery.available, percent: Battery.percent, charging: Battery.charging,
                full: Battery.full, low: Battery.low, minutes: Battery.minutes, icon: Battery.icon, testing: Battery.testing
            });
        }
        // Stand in for the hardware (alerts, colors); `real` goes back
        function simulate(percent: int, charging: bool): void { Battery.simulate(percent, charging); }
        function real(): void { Battery.testPercent = -1; }
    }

    IpcHandler {
        target: "media"

        // The active player and the browser tabs the extension reported
        function state(): string {
            return JSON.stringify({
                player: Media.player?.identity ?? null, title: Media.title, artist: Media.artist, kind: Media.kind,
                source: Media.source, art: Media.art, liked: Media.liked, fromExtension: Media.tab !== null,
                position: Number(Media.position.toFixed(2)), length: Math.round(Media.length), progress: Media.progress, watchers: Media.watchers,
                lyrics: { status: Lyrics.status, lines: Lyrics.lines.length, wanted: Lyrics.wanted, shown: Lyrics.shown, off: Lyrics.off, key: Lyrics.key },
                tabs: Browser.tabs.map(t => ({ browser: t.browser, tab: t.tab, site: t.site, title: t.title, kind: t.kind, playing: t.playing, duration: t.duration, cover: t.cover, liked: t.liked }))
            });
        }
        function like(): void { Media.like(); }
        // Lyrics off or on again for the playing song
        function lyrics(): void { Lyrics.toggleOff(); }
        function toggle(): void { Media.toggle(); }
        function seek(seconds: real): void { Media.seek(seconds); }
        function next(): void { Media.next(); }
    }

    // Something dropped on the island, without dragging: paths, file:// or
    // web addresses (separated by spaces or new lines), else it is text.
    // `image` is a picture's address as a browser gives it
    IpcHandler {
        target: "drop"
        function take(data: string): void {
            const parts = data.trim().split(/\s+/);
            const urls = parts.every(p => /^(file:\/\/|https?:\/\/|\/)/.test(p))
                ? parts.map(p => p.startsWith("/") ? "file://" + p : p) : [];
            Drop.take(urls, urls.length ? "" : data, [], "");
        }
        function image(url: string): void { Drop.take([], "", ["application/x-moz-file-promise-url"], url); }
        function run(action: string): void { Drop.run(action); }
        function state(): string { return JSON.stringify({ over: Drop.over, label: Drop.label, item: Drop.item, actions: Drop.actions.map(a => a.id) }); }
    }

    IpcHandler {
        target: "share"
        function devices(): string { Share.refresh(); return JSON.stringify(Share.devices); }
        function send(device: string, paths: string): void {
            Share.pending = { files: paths.trim().split(/\s+/), url: "" };
            // By name, Quick Share id or Bluetooth address
            Share.sendTo(Share.targets.find(t => t.name === device || t.id === device) ?? null);
        }
        function pick(paths: string): void { Share.offer(paths.trim().split(/\s+/), ""); }
        function cancel(): void { Share.cancel(); }
        function page(view: string): void { Share.openPage(view || undefined); }
        function receive(on: bool): void { Config.share.receive = on; }
        function accept(): void { if (Share.offers.length) Share.answer(Share.offers[0].id, true); }
        function decline(): void { if (Share.offers.length) Share.answer(Share.offers[0].id, false); }
        function state(): string { return JSON.stringify({ available: Share.available, receiving: Share.receiving, view: Share.view, chosen: Share.chosen, history: Share.history.length, discoverable: Share.discoverable, pairs: Share.pairs, adapter: Share.adapter, installed: Share.installed, ready: Share.ready, quick: Share.quick, nearby: Share.nearby, targets: Share.targets.map(d => d.name + " (" + d.via + ")"), offers: Share.offers, pending: Share.pending }); }
    }

    IpcHandler {
        target: "download"
        function start(url: string, mode: string): void { Downloads.start(url, mode || "video", ""); }
        function cancel(): void { if (Jobs.current) Jobs.cancel(Jobs.current.id); }
        function state(): string { return JSON.stringify(Jobs.list); }
    }

    IpcHandler {
        target: "capture"

        // shot or text: freeze the screens and open the picker
        function start(mode: string): void { Capture.start(mode || "shot"); }
        function cancel(): void { Capture.cancel(); }
        // Take a box (layout pixels on that monitor) without the mouse
        function box(monitor: string, x: int, y: int, w: int, h: int): void { Capture.finish(monitor, { x: x, y: y, w: w, h: h }); }
        function state(): string { return JSON.stringify({ picking: Capture.picking, mode: Capture.session?.mode ?? null, monitors: (Capture.session?.monitors ?? []).map(m => m.name), windows: (Capture.session?.windows ?? []).length }); }
    }

    IpcHandler {
        target: "edit"

        // open [wallpaper|island|dock|widgets|workspaces|presets]
        function open(tab: string): void { Ui.edit(tab || ""); }
        function close(): void { Ui.endEdit(); }
        function tab(tab: string): void { Ui.editTab = tab; }
        function undo(): void { Editor.undo(); }
        function state(): string { return JSON.stringify({ editing: Ui.editing, tab: Ui.editTab, edited: Editor.edited, undo: Editor.history.length, preset: Desktop.preset }); }
    }

    IpcHandler {
        target: "preset"

        function list(): string { return JSON.stringify(Presets.list.map(p => p.name)); }
        function current(): string { return Desktop.preset; }
        function apply(name: string): void { Presets.apply(name); }
        // Save over the current preset (or "Preset"); saveAs makes a new one
        function save(): void { Presets.save("", Ui.monitor); }
        function saveAs(name: string): void { Presets.save(name, Ui.monitor); }
        function remove(name: string): void { Presets.remove(name); }
        function refresh(): void { Presets.refresh(); }
    }

    IpcHandler {
        target: "overview"

        // The overview (Super+Tab): open, close, toggle, state
        function open(): void { Ui.openOverview(); }
        function close(): void { Ui.closeOverview(); }
        function toggle(): void { Ui.toggleOverview(); }
        function state(): string { return JSON.stringify({ open: Ui.overview, monitor: Ui.overviewMonitor }); }
    }

    IpcHandler {
        target: "workspace"

        // Designs per workspace number 1-10: list, set <slot> <name> <clock|media>, clear <slot>
        function list(): string { return JSON.stringify(Desktop.workspaces); }
        function set(slot: int, name: string, rest: string): void { Editor.record(); Spaces.set(slot, name, rest); }
        function clear(slot: int): void { Editor.record(); Spaces.clear(slot); }
        // Flash a number's name now (the current one with 0)
        function flash(slot: int): void { Spaces.flashNow(slot || Spaces.slot); }
        function state(): string { return JSON.stringify({ slot: Spaces.slot, rest: Spaces.rest, flash: Spaces.flash, editSlot: Spaces.editSlot }); }
    }

    IpcHandler {
        target: "theme"

        // dark or light
        function mode(mode: string): void { Config.theme.mode = mode; }
        // notch, plain or dock
        function style(style: string): void { Desktop.island.style = style; }
        // The separate dock with Notch and Plain: on/off, auto-hide, pin a desktop id
        function dock(on: bool): void { Desktop.dock.enabled = on; }
        function dockAutoHide(on: bool): void { Desktop.dock.autoHide = on; }
        function pin(id: string): void {
            const p = Desktop.dock.pinned.slice();
            const at = p.indexOf(id);
            if (at < 0) p.push(id); else p.splice(at, 1);
            Desktop.dock.pinned = p;
        }
        // ink or inverse
        function color(color: string): void { Desktop.island.color = color; }
    }
}
