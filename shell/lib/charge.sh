#!/usr/bin/env bash
# Charge limit, for services/ChargeLimit.qml. Finds how this machine can stop
# charging and writes the files (directly when writable, else `sudo -n`;
# `sudo scripts/charge-access.sh` makes them writable for wheel).
#
#   charge.sh detect
#       One JSON line: { method, ... }
#         "kernel"        battery's charge_control_end_threshold: end, start
#                         (start -1 when there is no start file), dir
#         "conservation"  Lenovo conservation mode: file, on
#         "software"      a charger with a writable current_max: file, max
#                         (the current to give back)
#         "none"
#   charge.sh kernel <dir> <start> <end>   set the thresholds (start -1: none)
#   charge.sh write <file> <value>
#   charge.sh hold <file> <restore>
#       Software limit: current_max to 0 until stdin closes (the shell went
#       away) or a TERM, then <restore> again.

set -u
state="${XDG_STATE_HOME:-$HOME/.local/state}/someshell"

put() { # file value
    if [ -w "$1" ]; then
        printf '%s\n' "$2" > "$1" 2>/dev/null && return 0
    fi
    printf '%s\n' "$2" | sudo -n tee "$1" > /dev/null 2>&1
}

detect() {
    local d
    for d in /sys/class/power_supply/*; do
        [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
        if [ -e "$d/charge_control_end_threshold" ]; then
            local s=-1
            [ -e "$d/charge_control_start_threshold" ] && s=$(cat "$d/charge_control_start_threshold")
            printf '{"method":"kernel","dir":"%s","end":%s,"start":%s}\n' "$d" "$(cat "$d/charge_control_end_threshold")" "$s"
            return
        fi
    done
    for f in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
        [ -e "$f" ] || continue
        printf '{"method":"conservation","file":"%s","on":%s}\n' "$f" "$([ "$(cat "$f")" = 1 ] && echo true || echo false)"
        return
    done
    # A charger whose input current can be set (needs a battery too)
    local bat=0
    for d in /sys/class/power_supply/*; do
        [ "$(cat "$d/type" 2>/dev/null)" = Battery ] && [ "$(cat "$d/present" 2>/dev/null || echo 1)" = 1 ] && bat=1
    done
    if [ "$bat" = 1 ]; then
        for d in /sys/class/power_supply/*; do
            case "$(cat "$d/type" 2>/dev/null)" in USB|Mains) ;; *) continue ;; esac
            local f="$d/current_max"
            [ -f "$f" ] || continue
            # Owner-writable in sysfs means the driver takes a value
            [ "$(stat -c %A "$f" | cut -c3)" = w ] || continue
            local now saved max
            now=$(cat "$f" 2>/dev/null || echo 0)
            saved="$state/charger-max-$(basename "$d")"
            if [ "$now" -gt 0 ] 2>/dev/null; then
                max=$now
                mkdir -p "$state" && printf '%s\n' "$now" > "$saved"
            else
                # Left at 0 (a hold that never ended): the last value seen
                max=$(cat "$saved" 2>/dev/null || echo 1500000)
            fi
            printf '{"method":"software","file":"%s","max":%s,"now":%s}\n' "$f" "$max" "$now"
            return
        done
    fi
    echo '{"method":"none"}'
}

case "${1:-}" in
    detect) detect ;;
    kernel)
        dir=$2 start=$3 end=$4
        e="$dir/charge_control_end_threshold" s="$dir/charge_control_start_threshold"
        # The order matters (start must stay below end): try one, then the other
        if [ "$start" -lt 0 ] || [ ! -e "$s" ]; then
            put "$e" "$end"
        else
            { put "$e" "$end" && put "$s" "$start"; } || { put "$s" "$start" && put "$e" "$end"; }
        fi
        ;;
    write) put "$2" "$3" ;;
    hold)
        file=$2 restore=$3
        put "$file" 0 || { echo "no permission" >&2; exit 1; }
        echo held
        # A guard of its own gives the current back: Qt kills this script with
        # SIGKILL when the shell exits, but the guard still sees the shell's
        # end of the pipe close (or gets the TERM from shell.sh)
        exec 3<&0
        (
            trap 'kill $reader 2>/dev/null; put "$file" "$restore"; exit 0' TERM INT HUP
            cat <&3 > /dev/null &
            reader=$!
            wait $reader
            put "$file" "$restore"
        ) &
        guard=$!
        exec 3<&-
        trap 'kill $guard 2>/dev/null; wait $guard; exit 0' TERM INT HUP
        wait $guard
        ;;
    *) echo "usage: charge.sh detect | kernel <dir> <start> <end> | write <file> <value> | hold <file> <restore>" >&2; exit 2 ;;
esac
