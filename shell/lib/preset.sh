#!/usr/bin/env bash
# Preset folders for the shell (services/Presets.qml). A preset is
# <presets>/<slug>/preset.json plus thumb.png.
#   preset.sh list <presets>
#       One JSON array: [{slug, name, saved, thumb}] newest first.
#   preset.sh save <presets> <slug> <json> [monitor]
#       Writes preset.json (temporary file + rename) and a small picture of
#       the monitor (default: the focused one; "none": no picture) as thumb.png.
#   preset.sh remove <presets> <slug>
set -u
root=${2:-}
[[ -n "$root" ]] || exit 2

case ${1:-} in
list)
    shopt -s nullglob
    files=("$root"/*/preset.json)
    if (( ${#files[@]} == 0 )); then echo '[]'; exit 0; fi
    for f in "${files[@]}"; do
        d=${f%/preset.json}
        jq -c --arg slug "${d##*/}" --arg thumb "$([[ -s $d/thumb.png ]] && echo "$d/thumb.png")" \
            '{slug: $slug, name: (.name // $slug), saved: (.saved // ""), thumb: $thumb}' "$f" 2>/dev/null
    done | jq -s 'sort_by(.saved) | reverse'
    ;;
save)
    slug=$3 json=$4 monitor=${5:-}
    # No monitor given: the focused one; "none" skips the picture
    [[ -z "$monitor" ]] && monitor=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty')
    [[ "$monitor" == none ]] && monitor=
    [[ "$slug" =~ ^[a-z0-9-]+$ ]] || exit 2
    d="$root/$slug"
    mkdir -p "$d"
    printf '%s\n' "$json" | jq . > "$d/.preset.json.tmp" && mv "$d/.preset.json.tmp" "$d/preset.json" || exit 1
    if [[ -n "$monitor" ]]; then
        grim -o "$monitor" -s 0.25 "$d/.thumb.png" 2>/dev/null && mv "$d/.thumb.png" "$d/thumb.png"
    fi
    echo "$d"
    ;;
remove)
    slug=$3
    [[ "$slug" =~ ^[a-z0-9-]+$ && -d "$root/$slug" ]] || exit 2
    rm -rf -- "${root:?}/$slug"
    ;;
*)
    exit 2
    ;;
esac
