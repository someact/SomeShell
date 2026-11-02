#!/usr/bin/env bash
# Capture tools for the shell's picker (services/Capture.qml).
#   capture.sh freeze
#       Takes a picture of every monitor at once and prints one JSON line:
#       {"dir":…, "monitors":[{name,x,y,w,h,scale,file}], "windows":[{x,y,w,h,title,monitor}]}
#       Geometry is in layout (logical) pixels; the pictures are full size.
#   capture.sh shot <picture> <x> <y> <w> <h>
#       Cuts the box (picture pixels), saves it to ~/Pictures/Screenshots,
#       copies it and prints the saved path.
#   capture.sh screen <monitor>
#       Takes the whole monitor (PrtSc), saves, copies and prints the path.
#   capture.sh text <picture> <x> <y> <w> <h>
#       Reads the text in the box (English and Thai), copies it and prints it.
#   capture.sh clean
#       Deletes the frozen pictures.
set -u
dir=${XDG_RUNTIME_DIR:-/tmp}/someshell-capture

case ${1:-} in
freeze)
    rm -rf "$dir"
    mkdir -p "$dir"
    monitors=$(hyprctl monitors -j)
    # All at once, so every monitor shows the same moment; PPM skips compression
    for name in $(jq -r '.[].name' <<<"$monitors"); do
        grim -t ppm -o "$name" "$dir/$name.ppm" &
    done
    wait
    # Windows on the shown workspaces (normal and special), as boxes to pick
    hyprctl clients -j | jq -c --arg dir "$dir" --argjson mons "$monitors" '
        ([$mons[] | .activeWorkspace.id, .specialWorkspace.id] | map(select(. != 0))) as $shown
        | {
            dir: $dir,
            monitors: [$mons[] | {
                name, scale,
                x, y,
                w: ((if .transform % 2 == 1 then .height else .width end) / .scale),
                h: ((if .transform % 2 == 1 then .width else .height end) / .scale),
                file: ($dir + "/" + .name + ".ppm")
            }],
            windows: [.[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $shown | index($w)))
                | {x: .at[0], y: .at[1], w: .size[0], h: .size[1], title, monitor: (.monitor as $m | [$mons[] | select(.id == $m) | .name][0]), focus: .focusHistoryID}]
                | sort_by(.focus)
        }'
    ;;
shot)
    src=$2 x=$3 y=$4 w=$5 h=$6
    out_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
    mkdir -p "$out_dir"
    out="$out_dir/Screenshot_$(LC_ALL=C date '+%Y-%m-%d_%H.%M.%S').png"
    magick "$src" -crop "${w}x${h}+${x}+${y}" +repage "$out" || exit 1
    wl-copy --type image/png < "$out"
    printf '%s\n' "$out"
    ;;
screen)
    out_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
    mkdir -p "$out_dir"
    out="$out_dir/Screenshot_$(LC_ALL=C date '+%Y-%m-%d_%H.%M.%S').png"
    grim -o "$2" "$out" || exit 1
    wl-copy --type image/png < "$out"
    printf '%s\n' "$out"
    ;;
text)
    src=$2 x=$3 y=$4 w=$5 h=$6
    # Tesseract reads small text better a little larger, in grey
    grow=100
    (( w * h < 600000 )) && grow=200
    (( w * h < 60000 )) && grow=300
    # and dark text on light: a dark box is flipped
    flip=()
    mean=$(magick "$src" -crop "${w}x${h}+${x}+${y}" +repage -colorspace Gray -format '%[fx:mean]' info:)
    awk -v m="$mean" 'BEGIN { exit !(m < 0.5) }' && flip=(-negate)
    # Thai: preserve_interword_spaces keeps words joined (else every letter
    # stands alone). English read as Thai shows up as loose one- or two-letter
    # Thai bits on a line with Latin letters; those are dropped.
    text=$(magick "$src" -crop "${w}x${h}+${x}+${y}" +repage -colorspace Gray "${flip[@]}" -resize "${grow}%" png:- \
        | tesseract stdin stdout -l eng+tha --psm 6 -c preserve_interword_spaces=1 2>/dev/null \
        | perl -CSD -pe 'if (/[A-Za-z]/) { s/(?:^|(?<=\s))\p{Thai}{1,2}(?=\s|$)[ \t]*//g; s/^[ \t]+//; }' \
        | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    [ -n "$text" ] && printf '%s' "$text" | wl-copy
    printf '%s' "$text"
    ;;
clean)
    rm -rf "$dir"
    ;;
*)
    echo "usage: capture.sh freeze | shot|text <picture> <x> <y> <w> <h> | clean" >&2
    exit 2
    ;;
esac
