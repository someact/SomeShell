#!/usr/bin/env bash
# Every wallpaper in the given folders, subfolders included (services/Wallpapers.qml).
#   wallpapers.sh <folder>...
# One line each, tab-separated: kind, path, name, picture for the thumbnail.
#   kind  image | video | scene | unsupported
#   path  the file, or the Wallpaper Engine folder (somewall loads the folder)
# A Wallpaper Engine item is a folder with project.json (dropped into the
# wallpaper folder as it came); nothing inside it is listed on its own.
# Its kind comes from project.json "type": scene, video; web and
# application wallpapers are "unsupported". Sound is never played.
set -u

tab=$'\t'
we_dirs=()

# Wallpaper Engine folders first
while IFS= read -r -d '' pj; do
    d=${pj%/project.json}
    we_dirs+=("$d")
    # One jq per folder: type, title, preview, file (tabs and newlines in a title become spaces)
    IFS=$tab read -r type title preview file < <(jq -r '[
        ((.type // "scene") | ascii_downcase),
        ((.title // "") | gsub("[\t\n\r]"; " ")),
        (.preview // ""),
        (.file // "")
    ] | @tsv' "$pj" 2>/dev/null) || continue
    [ -n "$title" ] || title=$(basename "$d")
    pic=""
    [ -n "$preview" ] && [ -f "$d/$preview" ] && pic="$d/$preview"
    case $type in
        scene)
            # A scene is packed (scene.pkg) or unpacked (its scene.json)
            if [ -f "$d/scene.pkg" ] || [ -f "$d/${file:-scene.json}" ]; then kind=scene; else kind=unsupported; fi ;;
        video)
            if [ -n "$file" ] && [ -f "$d/$file" ]; then kind=video; else kind=unsupported; fi
            # No preview picture: the video's own frame
            [ -n "$pic" ] || pic="$d/$file" ;;
        *) kind=unsupported ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$kind" "$d" "$title" "$pic"
done < <(find -L "$@" -maxdepth 4 -type f -name project.json -print0 2>/dev/null | sort -z)

# Pictures and videos, except those inside a Wallpaper Engine folder
inside() {
    local f=$1 d
    for d in "${we_dirs[@]}"; do
        case $f in "$d"/*) return 0 ;; esac
    done
    return 1
}
while IFS= read -r -d '' f; do
    inside "$f" && continue
    base=${f##*/}
    case ${base,,} in
        *.mp4|*.webm|*.mkv|*.mov) kind=video ;;
        *) kind=image ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$kind" "$f" "${base%.*}" "$f"
done < <(find -L "$@" -maxdepth 4 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
    -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print0 2>/dev/null | sort -z)
