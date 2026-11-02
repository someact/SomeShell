pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sound from PipeWire: the default output and input, every output device,
// and every app that is playing (the mixer). All event driven.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micMuted: source?.audio?.muted ?? true

    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink === false && n.audio && n.properties["media.class"] === "Stream/Output/Audio")

    function name(node) {
        return node?.description || node?.nickname || node?.name || "";
    }
    function appName(node) {
        return node?.properties["application.name"] || node?.name || "App";
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Node properties (volume, mute) are only live while tracked
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputs).concat(root.streams)
    }
}
