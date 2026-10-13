#!/usr/bin/env bash
# Lock the session. Called by hypridle (lock_cmd) and by `loginctl lock-session`.
# Uses the shell's own lock screen when it answers, hyprlock otherwise
# (shell not running or crashed).
#   lock.sh               lock now
#   lock.sh --after-sleep refocus the shell's lock surface after resume

if [[ "$1" == "--after-sleep" ]]; then
    qs -c someshell ipc call lock focus 2>/dev/null
    exit 0
fi

pidof hyprlock >/dev/null && exit 0

# `ipc call` fails when no someshell instance is running
timeout 3 qs -c someshell ipc call lock lock 2>/dev/null && exit 0

exec hyprlock
