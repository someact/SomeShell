#!/usr/bin/env bash
# Lock the session (hypridle's lock_cmd, `loginctl lock-session`, Super+L).
# The shell's own lock screen when the shell answers, hyprlock otherwise.

pidof hyprlock >/dev/null && exit 0

# `ipc call` fails when no shell is running
timeout 3 qs -c someshell ipc call lock lock 2>/dev/null && exit 0

exec hyprlock
