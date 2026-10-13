#!/usr/bin/env bash
# Open what Quick Share received (shell/services/QuickShare.qml):
#   quickshare-open.sh open   <dir> <name>...   open the file (several: show them in the folder)
#   quickshare-open.sh show   <dir> <name>...   show the files selected in the file manager
#   quickshare-open.sh notify <title> <body> <dir> <name>...
#                                               a notification with Open and Show in folder
# A name that was taken already is saved as 1_<name>, 2_<name>, …; the newest
# of those is the one that just arrived.
mode="${1:-}"
shift || exit 2
if [[ "$mode" == notify ]]; then
    title="$1" body="$2"
    shift 2
fi
dir="${1:-}"
shift || exit 2

paths=()
for name in "$@"; do
    newest="$(ls -t -- "$dir/$name" "$dir"/[0-9]*_"$name" 2>/dev/null | head -n1)"
    [[ -n "$newest" ]] && paths+=("$newest")
done

show() {
    if ((${#paths[@]})); then
        local uris=() p
        for p in "${paths[@]}"; do uris+=("file://$(jq -rn --arg p "$p" '$p | @uri | gsub("%2F"; "/")')"); done
        # The file manager opens the folder with the files selected
        gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems "[$(printf "'%s'," "${uris[@]}" | sed 's/,$//')]" "" >/dev/null 2>&1 && return
    fi
    xdg-open "$dir"
}
open() {
    if ((${#paths[@]} == 1)); then xdg-open "${paths[0]}"; else show; fi
}

case "$mode" in
open) open ;;
show) show ;;
notify)
    # Waits for a click; the notification's own timeout ends it otherwise
    case "$(notify-send -a "Quick Share" -i folder-download -A open=Open -A show="Show in folder" "$title" "$body")" in
    open) open ;;
    show) show ;;
    esac
    ;;
*) exit 2 ;;
esac
