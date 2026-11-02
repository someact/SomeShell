pragma Singleton
import QtQuick
import Quickshell

// The motion language. One motion per action, only where it tells you
// something changed. Nothing moves while you edit.
//   Shapes that change size use a spring (in a Behavior; a Spring inside a
//   Sequential/ParallelAnimation crashes Qt).
//   Everything else is a short ease-out.
Singleton {
    readonly property int quick: 90     // something leaving
    readonly property int fast: 150
    readonly property int normal: 260
    readonly property int slow: 420

    // Spring for size changes: settles without a visible bounce (no overshoot,
    // ~200 ms to 95%; measured on the tablet 2026-11-02)
    readonly property real springStrength: 6.5
    readonly property real springDamping: 0.6
    readonly property real springMass: 1.0

    readonly property int easing: Easing.OutCubic
}
