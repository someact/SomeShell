import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.services

// Image wallpaper on the background layer, crossfading between changes.
// Video wallpapers are played by mpvpaper (services/Wallpaper.qml); this layer
// hides while one is active.
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData

    visible: !Wallpaper.isVideo
    WlrLayershell.namespace: "someshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.surface

    // The image is shown from a copy cropped to the screen size, made once by
    // ImageMagick. Decoding a large original and scaling it in Qt leaves the
    // full-size decode behind (+24 MB for a 3000x2000 JPEG, measured).
    readonly property string wanted: Wallpaper.path !== "" && !Wallpaper.isVideo ? Wallpaper.path : ""
    property string source: ""
    property bool frontIsA: true

    onWantedChanged: fit.kick()
    onWidthChanged: fit.kick()
    onHeightChanged: fit.kick()
    Component.onCompleted: fit.kick()

    Process {
        id: fit
        property bool again: false
        property string src
        property string out
        function kick() {
            const w = Math.round(win.width), h = Math.round(win.height);
            if (w <= 0 || h <= 0)
                return;
            if (running) {
                again = true;
                return;
            }
            again = false;
            src = win.wanted;
            if (src === "") {
                win.source = "";
                return;
            }
            const size = w + "x" + h;
            out = Paths.cacheHome + "/someshell/wall-" + size + "-" + Qt.md5(src) + ".jpg";
            command = ["sh", "-c", 'src="$1" out="$2" size="$3"; dir="${out%/*}"; '
                + '[ -s "$out" ] && [ "$out" -nt "$src" ] && exit 0; mkdir -p "$dir"; '
                + 'find "$dir" -maxdepth 1 -name "wall-$size-*.jpg" ! -name "${out##*/}" -delete; '
                + 'magick "$src[0]" -resize "$size^" -gravity center -extent "$size" -quality 95 "$out.tmp.jpg" && mv -f "$out.tmp.jpg" "$out"',
                "_", src, out, size];
            running = true;
        }
        onExited: code => {
            if (again)
                kick();
            else
                win.source = Paths.url(code === 0 ? out : src);   // magick failed: decode the original
        }
    }

    // Load the new image into the hidden slot; fade it in once decoded
    onSourceChanged: {
        const front = frontIsA ? a : b, back = frontIsA ? b : a;
        if (source === "") {
            a.source = b.source = "";   // video wallpaper: free both images
            return;
        }
        if (front.source.toString() === source)
            return;     // switched back before the fade: keep showing it
        if (front.source.toString() === "")
            front.source = source;      // first image: no fade from nothing
        else if (back.source.toString() === source && back.status === Image.Ready)
            frontIsA = !frontIsA;   // already decoded (A→B→A): no status change will come
        else
            back.source = source;
    }

    // Once a fade ends, drop the image that faded out
    onFrontIsAChanged: release.restart()
    Timer {
        id: release
        interval: 600
        onTriggered: {
            const back = win.frontIsA ? b : a;
            if (back.source.toString() !== win.source)
                back.source = "";
        }
    }

    component Slot: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 450
                easing.type: Easing.InOutQuad
            }
        }
    }

    Slot {
        id: a
        opacity: win.frontIsA ? 1 : 0
        onStatusChanged: if (status === Image.Ready && !win.frontIsA && source.toString() === win.source) win.frontIsA = true
    }
    Slot {
        id: b
        opacity: win.frontIsA ? 0 : 1
        onStatusChanged: if (status === Image.Ready && win.frontIsA && source.toString() === win.source) win.frontIsA = false
    }
}
