#!/bin/sh
# Switch to Android on a device that dual boots through the A/B slots (one
# slot Linux, the other Android, like the Xiaomi Pad 6). qbootctl sets the
# other slot active; the next boot starts it.
#   android.sh check   prints "android" when the device boots from A/B slots,
#                      has Android's userdata and qbootctl (no root needed)
#   android.sh plan    prints the slot it would switch to (needs root)
#   android.sh go      switches to the other slot and restarts (needs root)
# Root: run as root, or sudo without a password; else it exits 3 (the shell
# then runs it with sudo in a terminal). Errors go to stderr, exit 1.
set -u
parts=/dev/disk/by-partlabel

if [ "${1:-}" = check ]; then
    [ -e "$parts/boot_a" ] && [ -e "$parts/boot_b" ] && [ -e "$parts/userdata" ] \
        && command -v qbootctl >/dev/null && echo android
    exit 0
fi

if [ "$(id -u)" = 0 ]; then
    run() { "$@"; }
elif sudo -n true 2>/dev/null; then
    run() { sudo -n "$@"; }
else
    echo "needs root" >&2
    exit 3
fi

# "Current slot: _b" (qbootctl also prints notes on stderr)
cur=$(run qbootctl -c 2>/dev/null | sed -n 's/^Current slot: _\{0,1\}\([ab]\)$/\1/p')
case "$cur" in
    a) other=b ;;
    b) other=a ;;
    *) echo "Could not read the current boot slot" >&2; exit 1 ;;
esac
run qbootctl -b "$other" >/dev/null 2>&1 || { echo "Slot $other is not marked bootable" >&2; exit 1; }

case "${1:-}" in
    plan) echo "$other" ;;
    go)
        run qbootctl -s "$other" >/dev/null 2>&1 || { echo "qbootctl could not set slot $other" >&2; exit 1; }
        systemctl reboot ;;
    *) echo "usage: android.sh check|plan|go" >&2; exit 2 ;;
esac
