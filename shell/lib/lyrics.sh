#!/usr/bin/env bash
# Lyrics for the media page, from LRCLIB (https://lrclib.net).
#   lyrics.sh <title> <artist> <seconds>
# Prints one JSON line: {"found":true,"synced":"[00:12.30] ...","plain":"...","instrumental":false}
# or {"found":false} (cached for a day) or {"found":false,"offline":true} (not cached).
# Found lyrics are cached for good in ~/.cache/someshell/lyrics.
set -u
title=$1 artist=$2 len=${3:-0}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/someshell/lyrics
mkdir -p "$cache"
f=$cache/$(printf '%s\n%s\n%s' "$title" "$artist" "$len" | sha1sum | cut -c1-16).json

if [ -s "$f" ]; then
    if jq -e '.found' "$f" >/dev/null 2>&1 || (( $(date +%s) - $(stat -c %Y "$f") < 86400 )); then
        cat "$f"
        exit 0
    fi
fi

ua="SomeShell (https://github.com/someact/SomeShell)"
# LRCLIB answers 503 when busy: one more try after a moment
search() {
    curl -fs --max-time 12 -A "$ua" -G "https://lrclib.net/api/search" "$@" && return
    sleep 2
    curl -fs --max-time 12 -A "$ua" -G "https://lrclib.net/api/search" "$@"
}
# The closest length within 3 s (any length when unknown), synced lyrics first
pick='[ .[] | select($len == 0 or ((.duration - $len) | if . < 0 then -. else . end) <= 3) ]
    | (map(select((.syncedLyrics // "") != "")) + .) | first
    | if . == null then {found: false}
      else {found: true, synced: (.syncedLyrics // ""), plain: (.plainLyrics // ""), instrumental: (.instrumental // false)} end'

if ! res=$(search --data-urlencode "track_name=$title" --data-urlencode "artist_name=$artist"); then
    echo '{"found":false,"offline":true}'
    exit 0
fi
out=$(jq -c --argjson len "$len" "$pick" <<<"$res" 2>/dev/null) || out='{"found":false}'
# Nothing under that artist: one wider search with the words of both
if [ "$out" = '{"found":false}' ] && res=$(search --data-urlencode "q=$title $artist"); then
    out=$(jq -c --argjson len "$len" "$pick" <<<"$res" 2>/dev/null) || out='{"found":false}'
fi
printf '%s\n' "$out" > "$f"
printf '%s\n' "$out"
