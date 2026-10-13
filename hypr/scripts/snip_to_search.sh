#!/usr/bin/env bash
# Fallback for region search while the shell is down: upload the region to
# uguu.se (expires in 3 h) and open Google Lens on it.
img="$(mktemp --tmpdir="${XDG_RUNTIME_DIR:-/tmp}" someshell-lens.XXXXXX.png)"
trap 'rm -f "$img"' EXIT
grim -g "$(slurp)" "$img" || exit 1
imageLink=$(curl -sF "files[]=@$img" 'https://uguu.se/upload' | jq -r '.files[0].url')
xdg-open "https://lens.google.com/uploadbyurl?url=${imageLink}"
