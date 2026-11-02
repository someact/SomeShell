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

        // open search|control|media|notify|calendar|system|power
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
                page: Ui.pages[Ui.page].id,
                openedByHover: Ui.openedByHover,
                monitor: Ui.monitor,
                quiet: Ui.quiet,
                hidden: Ui.hidden,
                alert: Ui.alert ? Ui.alert.title : null,
                gameMode: GameMode.active,
                theme: { dark: Theme.dark, inkDark: Theme.inkDark, islandColor: String(Theme.ink.bg), shape: Config.island.shape, color: Config.island.color }
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
                network: Network.label, online: Network.online,
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
        target: "theme"

        // dark or light
        function mode(mode: string): void { Config.theme.mode = mode; }
        // ears, tab or float
        function shape(shape: string): void { Config.island.shape = shape; }
        // ink or inverse
        function color(color: string): void { Config.island.color = color; }
    }
}
