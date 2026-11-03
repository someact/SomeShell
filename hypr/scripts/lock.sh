#!/usr/bin/env bash
# Lock the session (hypridle's lock_cmd, `loginctl lock-session`, Super+L,
# the power key). The shell's own lock screen when the shell has one,
# hyprlock otherwise.

pidof hyprlock >/dev/null && exit 0

# `qs ipc call` exits 0 even when the target is missing, so ask for the list first
if timeout 3 qs -c someshell ipc show 2>/dev/null | grep -qx 'target lock'; then
    timeout 3 qs -c someshell ipc call lock lock && exit 0
fi

# hyprlock unlocked the session: the shell must not lock again on its next start
hyprlock && rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/someshell/locked"
