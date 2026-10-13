#!/usr/bin/env bash
# Measure the shell and Hyprland (read-only unless --cycle).
#
#   bench.sh                 memory now, then CPU/GPU over 30 s of whatever is on screen
#   bench.sh -t 60           sample for 60 s
#   bench.sh --cycle 3       open every island view, the overview, overlay and widget
#                            edit mode N times (over IPC), printing memory after each
#   bench.sh --mem           memory only
#
# Memory: Anonymous/PSS from smaps_rollup are the numbers to compare (RSS also
# counts shared libraries and every font mapping). Compare against a fresh start.
set -euo pipefail

secs=30 cycles=0 memonly=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) secs="$2"; shift 2 ;;
        --cycle) cycles="${2:-1}"; shift 2 ;;
        --mem) memonly=1; shift ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

qs_pid() {
    local p
    for p in $(pgrep -x qs); do
        if tr '\0' ' ' < "/proc/$p/cmdline" | grep -q -- "-c someshell"; then echo "$p"; return; fi
    done
}
QS=$(qs_pid || true)
HY=$(pgrep -x Hyprland | head -1 || true)
[[ -n "$QS" ]] || { echo "the shell (qs -c someshell) is not running" >&2; exit 1; }

mem() {
    local label="$1"
    awk -v l="$label" '
        /^Rss:/ {r=$2} /^Pss:/ {p=$2} /^Anonymous:/ {a=$2}
        END {printf "%-14s RSS %4d MB   PSS %4d MB   anon %4d MB\n", l, r/1024, p/1024, a/1024}' "/proc/$QS/smaps_rollup"
}
fonts() {
    awk '/\.(ttf|otf|ttc)$/ {print $6}' "/proc/$QS/maps" | sort | uniq -c | sort -rn |
        awk '{n=split($2, f, "/"); printf "  %d× %s\n", $1, f[n]}'
}
ticks() { awk '{print $14+$15}' "/proc/$1/stat"; }
pct() { awk -v a="$1" -v b="$2" -v hz="$(getconf CLK_TCK)" -v s="$secs" 'BEGIN {printf "%.2f", (b-a)/hz/s*100}'; }
ipc() { qs -c someshell ipc call "$@" >/dev/null 2>&1 || true; }

echo "shell pid $QS, up $(ps -o etime= -p "$QS" | tr -d ' ')"
mem "now"
echo "font mappings:"; fonts

if (( cycles > 0 )); then
    views=(search control media notifications system power clipboard emoji keys mixer wallpaper)
    for ((c = 1; c <= cycles; c++)); do
        for v in "${views[@]}"; do ipc island open "$v"; sleep 0.8; done
        ipc island close; sleep 0.5
        ipc overview toggle; sleep 1; ipc overview toggle; sleep 0.5
        ipc overlay toggle; sleep 1; ipc overlay toggle; sleep 0.5
        ipc widgets edit; sleep 1; ipc widgets edit; sleep 0.5
        sleep 2
        mem "after cycle $c"
    done
fi
(( memonly || cycles > 0 )) && exit 0

echo "sampling CPU${HY:+ and GPU} for ${secs}s…"
q0=$(ticks "$QS"); h0=$([[ -n "$HY" ]] && ticks "$HY" || echo 0)
gpu=""
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu=$(nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits -l 1 2>/dev/null &
          pid=$!; sleep "$secs"; kill "$pid" 2>/dev/null)
else
    sleep "$secs"
fi
q1=$(ticks "$QS"); h1=$([[ -n "$HY" ]] && ticks "$HY" || echo 0)
echo "CPU            shell $(pct "$q0" "$q1") %   Hyprland $(pct "$h0" "$h1") %"
if [[ -n "$gpu" ]]; then
    awk -F', *' '{u+=$1; w+=$2; n++} END {if (n) printf "GPU            %.1f %% util   %.1f W   (%d samples)\n", u/n, w/n, n}' <<<"$gpu"
fi
