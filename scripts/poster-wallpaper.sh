#!/usr/bin/env bash
# Render the poster wallpapers (moon, ember, tide, moss, rose) into
# shell/assets/wallpapers at a given size. Needs node and rsvg-convert.
#   scripts/poster-wallpaper.sh [width height]
set -euo pipefail
w="${1:-1920}"; h="${2:-1080}"
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
out="$here/../shell/assets/wallpapers"
mkdir -p "$out"
for name in moon ember tide moss rose; do
    node "$here/poster-wallpaper.mjs" "$name" "$w" "$h" | rsvg-convert -w "$w" -h "$h" -o "$out/poster-$name.png"
    echo "$out/poster-$name.png"
done
