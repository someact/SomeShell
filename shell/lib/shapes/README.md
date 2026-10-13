# Material shapes (vendored)

Rounded-polygon math and the 35 Material 3 Expressive shapes, copied unchanged
from end-4's dots-hyprland (`modules/common/widgets/shapes/`), which is a QML
JavaScript port of [Knugel/rounded-polygon-ts](https://github.com/Knugel/rounded-polygon-ts),
itself a port of AndroidX `graphics-shapes`. Apache License 2.0 (see `LICENSE`).

SomeShell draws them with `QtQuick.Shapes` in `components/MaterialShape.qml`
instead of ii's `Canvas` (no offscreen texture per shape).
