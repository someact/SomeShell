#!/usr/bin/env bash
# matugen hook: recolor open terminals. Kitty rereads its config (which
# includes the theme) on SIGUSR1; other terminals get color sequences
# written to their ttys.
seq="${XDG_STATE_HOME:-$HOME/.local/state}/someshell/terminal-sequences.txt"
pkill -USR1 -x kitty 2>/dev/null
[[ -f "$seq" ]] || exit 0
for pty in /dev/pts/[0-9]*; do
    [[ -O "$pty" ]] && cat "$seq" >"$pty" 2>/dev/null &
done
wait
