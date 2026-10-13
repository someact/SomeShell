#!/usr/bin/env bash
# Hand files to the shell's Quick Share page (file manager menu, scripts):
#   quickshare-send.sh <file>...
# The shell opens the page that lists the devices to send them to.
[[ $# -gt 0 ]] || { echo "usage: $0 <file>..." >&2; exit 2; }
paths="$(for f in "$@"; do realpath -- "$f"; done)"
qs -c someshell ipc call quickshare offer "$paths"
