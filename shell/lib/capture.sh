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
#   capture.sh translate <picture> <x> <y> <w> <h>
#       Reads the text and translates it (Thai <-> English); prints JSON.
#   capture.sh translate-text <text>
#       Translates text as given (Thai <-> English); prints the same JSON.
#   capture.sh lens <picture> <x> <y> <w> <h>
#       Uploads the box to Google Lens; prints the results address.
#   capture.sh color <picture> <x> <y>
#       Copies the pixel's color (#rrggbb) and prints it.
#   capture.sh clean
#       Deletes the frozen pictures.
set -u
dir=${XDG_RUNTIME_DIR:-/tmp}/someshell-capture

# The text in a box of a picture (English and Thai), on stdout
read_text() {
    local src=$1 x=$2 y=$3 w=$4 h=$5 grow mean text
    # Tesseract reads small text better a little larger, in grey
    grow=100
    (( w * h < 600000 )) && grow=200
    (( w * h < 60000 )) && grow=300
    # and dark text on light: a dark box is flipped
    local flip=()
    mean=$(magick "$src" -crop "${w}x${h}+${x}+${y}" +repage -colorspace Gray -format '%[fx:mean]' info:)
    awk -v m="$mean" 'BEGIN { exit !(m < 0.5) }' && flip=(-negate)
    # Thai: preserve_interword_spaces keeps words joined (else every letter
    # stands alone). English read as Thai shows up as loose one- or two-letter
    # Thai bits on a line with Latin letters; those are dropped.
    text=$(magick "$src" -crop "${w}x${h}+${x}+${y}" +repage -colorspace Gray "${flip[@]}" -resize "${grow}%" png:- \
        | tesseract stdin stdout -l eng+tha --psm 6 -c preserve_interword_spaces=1 2>/dev/null \
        | perl -CSD -pe 'if (/[A-Za-z]/) { s/(?:^|(?<=\s))\p{Thai}{1,2}(?=\s|$)[ \t]*//g; s/^[ \t]+//; }' \
        | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    printf '%s' "$text"
}

# Google Translate's free endpoint: Thai to English, anything else to Thai.
# Prints {from, to, text, translation}; copies the translation. No answer:
# prints nothing.
translate() {
    local text=$1 thai latin to answer result
    # Thai when Thai letters are at least 30% of all letters (a few English
    # letters misread as Thai must not flip it)
    thai=$(printf '%s' "$text" | grep -oP '\p{Thai}' | wc -l)
    latin=$(printf '%s' "$text" | grep -oP '[A-Za-z]' | wc -l)
    to=th
    (( thai * 10 >= (thai + latin) * 3 && thai > 0 )) && to=en
    answer=$(curl -sS --max-time 8 -G "https://clients5.google.com/translate_a/t" \
        --data-urlencode "client=dict-chrome-ex" --data-urlencode "sl=auto" \
        --data-urlencode "tl=$to" --data-urlencode "q=$text") || return 0
    result=$(jq -c --arg text "$text" --arg to "$to" '{from: (.[0][1] // "auto"), to: $to, text: $text, translation: .[0][0]}' <<<"$answer" 2>/dev/null) || return 0
    jq -j .translation <<<"$result" | wl-copy
    printf '%s\n' "$result"
}

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
    text=$(read_text "$2" "$3" "$4" "$5" "$6")
    [ -n "$text" ] && printf '%s' "$text" | wl-copy
    printf '%s' "$text"
    ;;
translate)
    # Read the text, then translate it (below)
    text=$(read_text "$2" "$3" "$4" "$5" "$6")
    [ -n "$text" ] || exit 0
    translate "$text"
    ;;
translate-text)
    # Text given as is (a drop on the island)
    [ -n "${2:-}" ] || exit 0
    translate "$2"
    ;;
lens)
    # Upload the box to Google Lens; prints the results page's address
    src=$2 x=$3 y=$4 w=$5 h=$6
    f="$dir/lens.png"
    mkdir -p "$dir"
    magick "$src" -crop "${w}x${h}+${x}+${y}" +repage "$f" || exit 1
    curl -sS --max-time 20 -o /dev/null -w '%{redirect_url}' \
        -A 'Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0' \
        -F "encoded_image=@$f" "https://lens.google.com/v3/upload?ep=ccm&s=&st=$(date +%s%3N)"
    ;;
color)
    # One pixel of the frozen picture: copies #rrggbb and draws a swatch for
    # the alert (kept outside the frozen pictures' folder, which is cleaned)
    src=$2 x=$3 y=$4
    hex=$(magick "$src" -crop "1x1+${x}+${y}" +repage -format '#%[hex:p{0,0}]' info: | cut -c1-7 | tr 'A-F' 'a-f')
    [ -n "$hex" ] || exit 1
    magick -size 96x96 "xc:$hex" "${XDG_RUNTIME_DIR:-/tmp}/someshell-swatch.png"
    printf '%s' "$hex" | wl-copy
    printf '%s\n' "$hex"
    ;;
clean)
    rm -rf "$dir"
    ;;
*)
    echo "usage: capture.sh freeze | shot|text|translate|lens <picture> <x> <y> <w> <h> | color <picture> <x> <y> | screen <monitor> | clean" >&2
    exit 2
    ;;
esac
