pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/ics.js" as Ics

// Calendar events from the links in shell.json (calendar.feeds) and the .ics
// files in ~/.config/someshell/calendar. Read when the calendar page opens
// (lib/calendar.sh downloads a link only when its copy is 15 minutes old);
// nothing runs while the page is closed.
Singleton {
    id: root

    property var events: []          // parsed, repeats not yet expanded
    property bool loading: false
    property bool loaded: false
    property int failed: 0           // links that could not be downloaded this time
    readonly property bool hasSources: (Config.calendar.feeds?.length ?? 0) > 0 || events.length > 0
    readonly property bool sundayFirst: Config.calendar.weekStart !== "monday"

    function refresh() {
        if (reader.running)
            return;
        loading = true;
        reader.command = [Quickshell.shellPath("lib/calendar.sh")].concat(Config.calendar.feeds ?? []);
        reader.running = true;
    }

    // Events from `from` to `to` (Dates), repeats expanded
    function between(from, to) {
        return Ics.occurrences(events, from, to);
    }
    function onDay(list, day) {
        return Ics.onDay(list, day);
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                root.failed = (text.match(/^#FAILED /gm) ?? []).length;
                root.events = Ics.parse(text);
                root.loading = false;
                root.loaded = true;
            }
        }
    }
}
