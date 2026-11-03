#!/usr/bin/env bash
# Downloads a video link with yt-dlp (services/Downloads.qml).
#   download.sh video|audio <url>
# Video goes to Videos (up to 1080p, mp4), audio to Music (as the site gives
# it, no re-encode). Prints "T <title>" first, "P <percent>" while downloading, "F <path>" at the
# end; yt-dlp's errors go to stderr. For tests: SOMESHELL_DOWNLOAD_DIR overrides
# the folder, SOMESHELL_DOWNLOAD_RATE limits the speed (e.g. 300K).
set -u
mode=$1 url=$2
case $mode in
video)
    dir=${SOMESHELL_DOWNLOAD_DIR:-$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")}
    args=(-S "res:1080,ext:mp4:m4a" --merge-output-format mp4) ;;
audio)
    dir=${SOMESHELL_DOWNLOAD_DIR:-$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/Music")}
    args=(-x) ;;
*) echo "usage: download.sh video|audio <url>" >&2; exit 2 ;;
esac
mkdir -p "$dir"
[ -n "${SOMESHELL_DOWNLOAD_RATE:-}" ] && args+=(-r "$SOMESHELL_DOWNLOAD_RATE")
# Parts are kept in a folder of their own, so a cancel (SIGTERM) leaves
# nothing half-done in Videos or Music
tmp=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/someshell-download.XXXXXX")
trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -rf "$tmp"; exit 143' TERM INT
yt-dlp --newline --progress --no-playlist --no-warnings --no-mtime \
    --progress-template 'download:P %(progress._percent_str)s' \
    --print 'before_dl:T %(title)s' --print 'after_move:F %(filepath)s' \
    -P "$dir" -P "temp:$tmp" -o '%(title).150B.%(ext)s' "${args[@]}" -- "$url" &
pid=$!
wait "$pid"
code=$?
rm -rf "$tmp"
exit $code
