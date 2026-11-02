import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// Command line control: qs -c someshell ipc call <target> <function> [args]
// Every feature can be driven from here, so it can be tested without a mouse.
Scope {
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
