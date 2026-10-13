pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Streamer mode: notification text is masked in the island, peeks move to a
// layer that Hyprland leaves out of screen shares (`someshell:private`,
// no_screen_share), and do not disturb is on (Config.streamer.silence).
// Turns on by itself while the screen is shared over Pipewire (OBS, Discord,
// browsers) when Config.streamer.auto is set.
Singleton {
    id: root

    readonly property bool sharing: Privacy.screenSharing
    // Turned off by hand during the current screen share
    property bool dismissed: false
    onSharingChanged: if (!sharing) dismissed = false

    readonly property bool auto: Config.streamer.auto && sharing && !dismissed
    readonly property bool active: Config.streamer.enabled || auto

    function toggle() {
        if (active) {
            Config.streamer.enabled = false;
            if (sharing)
                dismissed = true;
        } else {
            Config.streamer.enabled = true;
            dismissed = false;
        }
    }
}
