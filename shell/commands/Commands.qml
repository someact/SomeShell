pragma Singleton

import QtQuick
import Quickshell

// Registry of island commands, typed as `/name arg` in search.
Singleton {
    readonly property list<QtObject> all: [
        WallpaperCommand {}, SettingsCommand {}, PowerCommand {}, LockCommand {}, ClipCommand {}, EmojiCommand {}, GifCommand {}, ProjectCommand {},
        GameCommand {}, OverlayCommand {}, DndCommand {}, StreamCommand {}, ShotCommand {}, OcrCommand {}, LensCommand {}, TranslateCommand {},
        RecordCommand {}, KeysCommand {}, WidgetsCommand {}, OskCommand {}, ShareCommand {}
    ]

    // Changes when any command's suggestions change (search rebuilds on it)
    readonly property int revision: all.reduce((sum, c) => sum + c.revision, 0)

    // "/pro foo" -> { command: Project, arg: "foo" } when the name is complete
    function parse(text) {
        const body = text.replace(/^\//, "");
        const space = body.indexOf(" ");
        const name = space < 0 ? body : body.slice(0, space);
        const arg = space < 0 ? "" : body.slice(space + 1).trim();
        return { name, arg, complete: space >= 0, command: all.find(c => c.name === name) ?? null };
    }

    function run(name, arg) {
        all.find(c => c.name === name)?.run(arg ?? "");
    }

    function matching(name) {
        return all.filter(c => c.name.startsWith(name.toLowerCase()));
    }
}
