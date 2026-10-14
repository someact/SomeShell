#!/bin/bash
# Emoji picker for when the shell is not running. Reads the list the island
# picker uses (shell/lib/emoji.tsv, made by scripts/emoji-data.sh).
set -euo pipefail

MODE="${1:-type}"

HERE="$(dirname "$(readlink -f "$0")")"
DATA="$HERE/../../shell/lib/emoji.tsv"
[ -f "$DATA" ] || DATA="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/someshell/lib/emoji.tsv"

emoji="$(cut -f 1,3,4 "$DATA" | tr '\t' ' ' | fuzzel --match-mode fzf --dmenu | cut -d ' ' -f 1 | tr -d '\n')"
[ -n "$emoji" ] || exit 0

case "$MODE" in
    type)
        wtype "${emoji}" || wl-copy "${emoji}"
        ;;
    copy)
        wl-copy "${emoji}"
        ;;
    both)
        wtype "${emoji}" || true
        wl-copy "${emoji}"
        ;;
    *)
        echo "Usage: $0 [type|copy|both]"
        exit 1
        ;;
esac
