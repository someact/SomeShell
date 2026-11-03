#!/usr/bin/env bash
# Things dropped on the island (services/Drop.qml).
#   drop.sh info <path>…
#       One JSON line per file: {path, name, size, mime, dir, w, h} (w and h
#       only for images; dir true for a folder).
#   drop.sh fetch <url>
#       Downloads a picture dragged from a browser into the cache and prints
#       its path (the extension follows the type the server sends).
#   drop.sh title <url>
#       The title of a video link (yt-dlp), or nothing.
#   drop.sh image text|lens <picture>
#       Reads the whole picture's text (copied), or uploads it to Google Lens
#       (prints the results address); capture.sh does the work.
#   drop.sh copy-image <picture>
#       Puts the picture on the clipboard as an image.
#   drop.sh copy-files <path>…
#       Puts the files on the clipboard (text/uri-list: a file manager pastes them).
#   drop.sh save <picture> [wallpaper]
#       Copies it into Pictures (or Pictures/Wallpapers) and prints the new path.
#   drop.sh note <text>
#       Saves the text as ~/Documents/notes/<date>.txt and prints the path.
#   drop.sh url-file <url>
#       Writes the link as a small .url file (to share it) and prints its path.
#   drop.sh show <path>
#       Shows the file selected in the file manager.
set -u
here=$(cd "$(dirname "$0")" && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/someshell/drop
pictures=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
documents=$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")

# A free name in a folder: photo.png, photo-2.png, …
free_name() {
    local dir=$1 name=$2 base ext n=2 out
    base=${name%.*}; ext=${name##*.}
    [ "$base" = "$name" ] && ext="" || ext=".$ext"
    out="$dir/$name"
    while [ -e "$out" ]; do out="$dir/$base-$n$ext"; n=$((n + 1)); done
    printf '%s' "$out"
}

case ${1:-} in
info)
    shift
    for f in "$@"; do
        [ -e "$f" ] || continue
        mime=$(file --mime-type -b -- "$f")
        if [ -d "$f" ]; then
            size=$(du -sb -- "$f" 2>/dev/null | cut -f1)
            jq -nc --arg path "$f" --argjson size "${size:-0}" '{path: $path, name: ($path | split("/") | last), size: $size, mime: "inode/directory", dir: true}'
        elif [[ $mime == image/* ]]; then
            read -r w h < <(magick identify -format '%w %h\n' -- "$f[0]" 2>/dev/null | head -1)
            jq -nc --arg path "$f" --argjson size "$(stat -c %s -- "$f")" --arg mime "$mime" \
                --argjson w "${w:-0}" --argjson h "${h:-0}" \
                '{path: $path, name: ($path | split("/") | last), size: $size, mime: $mime, dir: false, w: $w, h: $h}'
        else
            jq -nc --arg path "$f" --argjson size "$(stat -c %s -- "$f")" --arg mime "$mime" \
                '{path: $path, name: ($path | split("/") | last), size: $size, mime: $mime, dir: false}'
        fi
    done
    ;;
fetch)
    url=$2
    mkdir -p "$cache"
    tmp="$cache/fetch.part"
    # As a browser first (some sites only serve browsers), then as curl
    # (others, like Wikimedia, refuse a borrowed browser name)
    type=$(curl -sSL --max-time 30 -A 'Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0' \
        -o "$tmp" -w '%{content_type}' -- "$url")
    if [[ $type != image/* ]]; then
        type=$(curl -sSL --max-time 30 -o "$tmp" -w '%{content_type}' -- "$url") || exit 1
    fi
    case $type in
        image/png*) ext=png ;; image/jpeg*) ext=jpg ;; image/webp*) ext=webp ;; image/gif*) ext=gif ;;
        image/avif*) ext=avif ;; image/svg*) ext=svg ;; image/*) ext=img ;;
        *) mime=$(file --mime-type -b "$tmp"); [[ $mime == image/* ]] || { rm -f "$tmp"; exit 1; }; ext=${mime#image/} ;;
    esac
    # The name from the address when it has one, else the time
    name=$(basename -- "${url%%[?#]*}")
    name=${name%.*}
    [[ $name =~ ^[A-Za-z0-9._-]{1,60}$ ]] || name="image-$(date +%H%M%S)"
    out="$cache/$name.$ext"
    mv -f "$tmp" "$out"
    printf '%s\n' "$out"
    ;;
title)
    yt-dlp --no-warnings --no-playlist --skip-download --socket-timeout 8 --print title -- "$2" 2>/dev/null | head -1
    ;;
image)
    what=$2 f=$3
    # Text and Lens read a box of a picture: the whole picture (first frame)
    flat="$cache/whole.png"
    mkdir -p "$cache"
    magick -- "$f[0]" "$flat" || exit 1
    read -r w h < <(magick identify -format '%w %h\n' "$flat")
    "$here/capture.sh" "$what" "$flat" 0 0 "$w" "$h"
    ;;
copy-image)
    f=$2
    mime=$(file --mime-type -b -- "$f")
    # Apps paste PNG most reliably
    if [ "$mime" = image/png ]; then
        wl-copy --type image/png < "$f"
    else
        magick -- "$f[0]" png:- | wl-copy --type image/png
    fi
    ;;
copy-files)
    shift
    for f in "$@"; do printf 'file://%s\r\n' "$(jq -rn --arg p "$f" '$p | @uri' | sed 's/%2F/\//g')"; done | wl-copy --type text/uri-list
    ;;
save)
    f=$2
    dir=$pictures
    [ "${3:-}" = wallpaper ] && dir="$pictures/Wallpapers"
    mkdir -p "$dir"
    out=$(free_name "$dir" "$(basename -- "$f")")
    cp -- "$f" "$out" && printf '%s\n' "$out"
    ;;
note)
    dir="$documents/notes"
    mkdir -p "$dir"
    out=$(free_name "$dir" "$(date '+%Y-%m-%d_%H.%M').txt")
    printf '%s\n' "$2" > "$out" && printf '%s\n' "$out"
    ;;
url-file)
    mkdir -p "$cache"
    host=$(printf '%s' "$2" | sed -E 's#^[a-z]+://(www\.)?##; s#[/?#:].*##')
    out="$cache/${host:-link}.url"
    printf '[InternetShortcut]\r\nURL=%s\r\n' "$2" > "$out" && printf '%s\n' "$out"
    ;;
show)
    uri="file://$(jq -rn --arg p "$2" '$p | @uri' | sed 's/%2F/\//g')"
    gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
        --method org.freedesktop.FileManager1.ShowItems "['$uri']" "" >/dev/null 2>&1 \
        || xdg-open "$(dirname -- "$2")"
    ;;
*)
    echo "usage: drop.sh info|fetch|title|image|copy-image|copy-files|save|note|show …" >&2
    exit 2
    ;;
esac
