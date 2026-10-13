#!/usr/bin/env bash
# matugen post-hook: recolor every open terminal.
# kitty rereads its config (and the included theme) on SIGUSR1; other
# terminals get OSC color sequences written to their ptys.
seq="${XDG_STATE_HOME:-$HOME/.local/state}/someshell/sequences.txt"
pkill -USR1 -x kitty 2>/dev/null
[[ -f "$seq" ]] || exit 0
for pty in /dev/pts/[0-9]*; do
    [[ -O "$pty" ]] && cat "$seq" > "$pty" 2>/dev/null &
done
wait
