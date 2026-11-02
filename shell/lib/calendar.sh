#!/usr/bin/env bash
# Calendars for the calendar page. Arguments: the calendar links from
# shell.json. A link is downloaded when its saved copy is missing or older
# than 15 minutes; a failed download keeps the old copy and prints
# "#FAILED <n>" (the link's number, never the link: it is private).
# Then prints every saved copy and the .ics files of
# ~/.config/someshell/calendar, one after another.
set -u
cache=${XDG_CACHE_HOME:-$HOME/.cache}/someshell/calendar
local_dir=${XDG_CONFIG_HOME:-$HOME/.config}/someshell/calendar
mkdir -p "$cache"
now=$(date +%s)

n=0
for url in "$@"; do
    n=$((n + 1))
    url=${url/#webcal:\/\//https://}
    f=$cache/$(printf '%s' "$url" | sha1sum | cut -c1-16).ics
    if [ ! -s "$f" ] || (( now - $(stat -c %Y "$f") > 900 )); then
        if curl -fsSL --max-time 20 -o "$f.part" "$url" && grep -q "BEGIN:VCALENDAR" "$f.part"; then
            mv "$f.part" "$f"
        else
            rm -f "$f.part"
            echo "#FAILED $n"
        fi
    fi
    [ -s "$f" ] && cat "$f" && echo
done

for f in "$local_dir"/*.ics; do
    [ -f "$f" ] && cat "$f" && echo
done
exit 0
