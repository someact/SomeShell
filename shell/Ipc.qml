import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// `qs -c someshell ipc call <target> <function> [args]`
Scope {
    IpcHandler {
        target: "island"
        function open(view: string): void {
            UiState.open(view);
        }
        function toggle(view: string): void {
            UiState.toggle(view);
        }
        // The Control view on a detail page: wifi bluetooth warp nightlight audio
        function control(detail: string): void {
            UiState.openControl(detail);
        }
        function search(text: string): void {
            UiState.open("search", text);
        }
        function close(): void {
            UiState.close();
        }
        function hide(): void {
            UiState.hidden = !UiState.hidden;
        }
        function state(): string {
            return JSON.stringify({ expanded: UiState.expanded, peeking: UiState.peeking, view: UiState.view, ambient: UiState.ambient });
        }
    }

    // WARP (services/Warp.qml): state is { available, service, registered, status, reason, mode }
    IpcHandler {
        target: "warp"
        function toggle(): void {
            Warp.toggle();
        }
        function mode(name: string): void {
            Warp.setMode(name);
        }
        function state(): string {
            return JSON.stringify({ available: Warp.available, service: Warp.service, registered: Warp.registered, status: Warp.status, reason: Warp.reason, mode: Warp.mode });
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void {
            UiState.toggleOverview();
        }
        function open(): void {
            if (!UiState.overview)
                UiState.toggleOverview();
        }
        function close(): void {
            UiState.overview = false;
        }
    }

    // mode: shot | ocr | lens | translate | record | recordSound
    IpcHandler {
        target: "capture"
        function region(mode: string): void {
            Capture.start(mode || "shot");
        }
        function screen(sound: bool): void {
            Recorder.toggleScreen(sound);
        }
        function stop(): void {
            Recorder.stop();
        }
        function recording(): bool {
            return Recorder.active;
        }
    }

    // scripts/lock.sh calls `lock lock`; there is deliberately no unlock
    IpcHandler {
        target: "lock"
        function lock(): void {
            Lock.lock();
        }
        function focus(): void {
            Lock.refocus();
        }
        function preview(): void {
            Lock.showPreview();
        }
        function locked(): bool {
            return Lock.locked;
        }
    }

    IpcHandler {
        target: "widgets"
        function edit(): void {
            UiState.widgetEdit = !UiState.widgetEdit;
        }
        function toggle(id: string): void {
            Widgets.toggle(id);
        }
    }

    IpcHandler {
        target: "osk"
        function toggle(): void {
            UiState.osk = !UiState.osk;
        }
        function open(): void {
            UiState.osk = true;
        }
        function close(): void {
            UiState.osk = false;
        }
    }

    IpcHandler {
        target: "overlay"
        function toggle(): void {
            UiState.overlay = !UiState.overlay;
        }
        function close(): void {
            UiState.overlay = false;
        }
    }

    IpcHandler {
        target: "streamer"
        function toggle(): void {
            Streamer.toggle();
        }
        function active(): bool {
            return Streamer.active;
        }
    }

    IpcHandler {
        target: "livetranslate"
        // "<status> <area> | <source> => <translated>"
        function state(): string {
            return `${LiveTranslate.running ? LiveTranslate.status : "stopped"} ${LiveTranslate.geometry} | ${LiveTranslate.source} => ${LiveTranslate.translated}`;
        }
        function pick(): void {
            LiveTranslate.pick();
        }
    }

    IpcHandler {
        target: "lyrics"
        // "<status> <index>/<lines> <current line>"
        function state(): string {
            return Lyrics.status + " " + Lyrics.index + "/" + Lyrics.lines.length + " " + Lyrics.line;
        }
        function retry(): void {
            Lyrics.retry();
        }
    }

    IpcHandler {
        target: "dock"
        function pin(appId: string): void {
            Taskbar.pin(appId.toLowerCase());
        }
        function unpin(appId: string): void {
            Taskbar.unpin(appId.toLowerCase());
        }
    }

    IpcHandler {
        target: "brightness"
        function increment(): void {
            Brightness.increment();
        }
        function decrement(): void {
            Brightness.decrement();
        }
        function set(percent: int): void {
            Brightness.set(percent / 100);
        }
    }

    IpcHandler {
        target: "notifications"
        function dnd(): void {
            Notifs.toggleDnd();
        }
        function clear(): void {
            Notifs.clear();
        }
    }

    // The settings app is its own process (`qs -p settings.qml`), alive only while
    // its window is open. A second open raises the running one instead.
    IpcHandler {
        target: "settings"
        function open(): void {
            Session.openSettings("");
        }
        function page(name: string): void {
            Session.openSettings(name);
        }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void {
            Wallpaper.set(path);
        }
        function random(): void {
            Wallpaper.random();
        }
        function pick(): void {
            Wallpaper.pick();
        }
        // dark | light
        function mode(m: string): void {
            Wallpaper.setMode(m);
        }
        // a matugen scheme, e.g. scheme-tonal-spot
        function scheme(name: string): void {
            Config.theme.scheme = name;
            Wallpaper.retheme();
        }
        // Preview a schedule slot (sunrise noon sunset night midnight) until the next one starts
        function slot(name: string): void {
            Schedule.preview(name);
        }
    }

    IpcHandler {
        target: "schedule"
        function state(): string {
            return Schedule.state();
        }
        // Test a time of day ("HH:MM"); "now" goes back to the clock
        function at(time: string): string {
            Schedule.testNow = time === "now" ? -1 : Schedule.minutesOf(time);
            Schedule.check();
            return Schedule.state();
        }
    }
}
