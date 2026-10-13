import QtQuick
import qs.core
import qs.services

Command {
    name: "share"
    icon: "nearby"
    args: "[file]"
    description: QuickShare.available ? "Send a file to your phone with Quick Share (no file: pick some)" : "Quick Share is not built yet: run scripts/quickshare.sh"
    keepOpen: true
    function run(arg) {
        if (!QuickShare.available)
            return;
        const path = arg.trim().replace(/^~/, Paths.home);
        if (path === "") {
            UiState.openControl("quickshare");
            QuickShare.pick();
        } else {
            QuickShare.offer([path]);
        }
    }
}
