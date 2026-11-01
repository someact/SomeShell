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
        target: "theme"

        // dark or light
        function mode(mode: string): void { Config.theme.mode = mode; }
        // ears, tab or float
        function shape(shape: string): void { Config.island.shape = shape; }
        // ink or inverse
        function color(color: string): void { Config.island.color = color; }
    }
}
