#!/usr/bin/env bash
# Builds and installs the wallpaper engine (videos and Wallpaper Engine
# scenes) → ~/.local/lib/someshell/somewall. The shell starts it for an
# animated wallpaper when it is there.
#
# Scenes need Wallpaper Engine's own assets/ folder (not part of this repo).
# Found in the usual Steam paths; anywhere else, set it once:
#   wall/install.sh --assets /path/to/wallpaper_engine/assets
# which writes wallpaper.assets in ~/.config/someshell/shell.json.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
libdir=$HOME/.local/lib/someshell
build=$here/build

assets=""
while [ $# -gt 0 ]; do
    case $1 in
        --assets) assets=$(realpath "$2"); shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

missing=()
for m in wayland-client wayland-egl egl gl liblz4 libavformat libavcodec libavutil libswscale freetype2 fontconfig duktape; do
    pkg-config --exists "$m" 2>/dev/null || missing+=("$m")
done
[ -f /usr/include/glm/glm.hpp ] || missing+=(glm)
command -v cmake >/dev/null || missing+=(cmake)
command -v ninja >/dev/null || missing+=(ninja)
if [ ${#missing[@]} -gt 0 ]; then
    echo "missing libraries: ${missing[*]}" >&2
    echo "Arch: pacman -S --needed cmake ninja wayland wayland-protocols mesa lz4 ffmpeg freetype2 fontconfig duktape glm" >&2
    exit 1
fi

cmake -S "$here" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$build"
mkdir -p "$libdir"
install -m 755 "$build/somewall" "$libdir/somewall"
echo ":: installed $libdir/somewall"

if [ -n "$assets" ]; then
    [ -d "$assets/shaders" ] || { echo "not a Wallpaper Engine assets folder: $assets" >&2; exit 1; }
    conf=$HOME/.config/someshell/shell.json
    mkdir -p "$(dirname "$conf")"
    [ -s "$conf" ] || echo '{}' > "$conf"
    tmp=$(mktemp "$conf.XXXX")
    jq --arg a "$assets" '.wallpaper.assets = $a' "$conf" > "$tmp" && mv "$tmp" "$conf"
    echo ":: wallpaper.assets = $assets"
fi
