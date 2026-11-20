#!/usr/bin/env bash
# Start the shell (qs -c someshell). Autostart, the restart bind and the
# installer all go through here, so the environment is decided in one place.
#
# NVIDIA as the only GPU: glvnd would also load Mesa and LLVM (~100 MB for
# nothing), so EGL is pinned to the NVIDIA vendor file. With any other GPU
# (AMD, Intel, a hybrid laptop) that pin would leave the shell without EGL.
vendors="$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u)"
egl=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
if [[ "$vendors" == "0x10de" && -f "$egl" ]]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="$egl"
fi

# One shell only. `qs kill` can crash in a Wayland destructor, and the crash
# handler then relaunches the old shell as `quickshell`, which keeps drawing
# under the new one; so every running copy is stopped first, by PID.
# Its child processes (an idle block, a DDC search, samplers) are not stopped
# with it: they would live on under systemd, so they are collected first.
descendants() {
    local c
    for c in $(pgrep -P "$1"); do
        echo "$c"
        descendants "$c"
    done
}
pids=$(qs list -c someshell -j 2>/dev/null | jq -r '.[].pid' 2>/dev/null)
children=$(for p in $pids; do descendants "$p"; done)
if [[ -n "$pids" ]]; then
    kill $pids 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        alive=$(for p in $pids; do kill -0 "$p" 2>/dev/null && echo "$p"; done)
        [[ -z "$alive" ]] && break
        sleep 0.1
    done
    [[ -n "$alive" ]] && kill -9 $alive 2>/dev/null
fi
[[ -n "$children" ]] && kill $children 2>/dev/null
# A keep-awake block left by a shell that crashed earlier (its parent is gone)
for p in $(pgrep -f -- '--why=Keep awake is on'); do
    [[ "$(ps -o ppid= -p "$p" | tr -d ' ')" == 1 ]] && kill "$p" 2>/dev/null
done
# and the crash reporters those crashes left behind
for p in $(pgrep -x quickshell); do
    grep -qa __QUICKSHELL_CRASH_DUMP_PID "/proc/$p/environ" 2>/dev/null && kill -9 "$p" 2>/dev/null
done

exec qs -c someshell "$@"
