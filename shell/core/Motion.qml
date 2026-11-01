pragma Singleton
import QtQuick
import Quickshell

// The motion language. One motion per action, only where it tells you
// something changed. Nothing moves while you edit.
//   Shapes that change size use a spring (in a Behavior; a Spring inside a
//   Sequential/ParallelAnimation crashes Qt).
//   Everything else is a short ease-out.
Singleton {
    readonly property int fast: 150
    readonly property int normal: 260
    readonly property int slow: 420

    // Spring for size changes: settles without a visible bounce
    readonly property real springStrength: 4.2
    readonly property real springDamping: 0.34
    readonly property real springMass: 1.0

    readonly property int easing: Easing.OutCubic
}
