#!/usr/bin/env bash
# Input devices and the kind of the last input, for services/Touch.qml.
# Runs for the shell's life; prints lines:
#   devices <json>         {"touch":[names],"pen":[names],"pointer":[{id,name}],"keyboard":[names],"access":bool}
#                          at start and after every plug or unplug
#   input <kind> <eventN>  touch | pen | pointer | key: a device of that kind was used
# Inputs are only watched while a touch screen exists (nothing else needs the
# last input kind). A watcher blocks on one event of its device, reports it,
# rests half a second and waits again: events, not polling, and quiet while
# the device is. Nothing of what was typed is read beyond one event's bytes,
# which are thrown away. uinput devices (ydotool, the shell's own keys) do
# not count, except a touch screen (scripts/vtouch.py for tests).

set -u
watchers=()

# One device: its kind (touch, pen, pointer, key) or nothing
kind_of() {
    local e=$1 props path
    props=$(udevadm info -q property -p "/sys/class/input/$e" 2>/dev/null) || return
    path=$(readlink -f "/sys/class/input/$e")
    local uinput=0
    [[ $path == */devices/virtual/input/* ]] && uinput=1
    if grep -qx 'ID_INPUT_TOUCHSCREEN=1' <<<"$props"; then echo touch; return; fi
    ((uinput)) && return
    if grep -qx 'ID_INPUT_TABLET=1' <<<"$props"; then echo pen; return; fi
    if grep -qxE 'ID_INPUT_(MOUSE|TOUCHPAD)=1' <<<"$props"; then echo pointer; return; fi
    if grep -qx 'ID_INPUT_KEYBOARD=1' <<<"$props"; then echo key; return; fi
}

# Every process here is tied to its parent (setpriv --pdeathsig): when the
# shell stops this script in any way, even SIGKILL, nothing is left behind.

# One device, as its own process: `touch.sh watch <eventN> <kind>`
if [[ ${1:-} == watch ]]; then
    e=$2 kind=$3
    while :; do
        setpriv --pdeathsig KILL head -c 24 "/dev/input/$e" >/dev/null 2>&1 || exit
        echo "input $kind $e" || exit
        sleep 0.5
    done
fi

stop_watchers() {
    ((${#watchers[@]})) && kill "${watchers[@]}" 2>/dev/null
    watchers=()
}
trap stop_watchers EXIT
trap 'exit 0' TERM INT HUP

scan() {
    stop_watchers
    local touch=() pen=() pointer=() keyboard=() list=() access=true e k name
    for d in /sys/class/input/event*; do
        [[ -e $d ]] || continue
        e=${d##*/}
        k=$(kind_of "$e")
        [[ -n $k ]] || continue
        name=$(<"$d/device/name")
        list+=("$e $k")
        case $k in
            touch) touch+=("$name") ;;
            pen) pen+=("$name") ;;
            pointer) pointer+=("$(jq -cn --arg id "$e" --arg n "$name" '{id: $id, name: $n}')") ;;
            key) keyboard+=("$name") ;;
        esac
        [[ -r /dev/input/$e ]] || access=false
    done
    printf 'devices %s\n' "$(jq -cn --argjson access "$access" \
        --argjson touch "$(printf '%s\n' "${touch[@]}" | jq -R . | jq -cs 'map(select(. != ""))')" \
        --argjson pen "$(printf '%s\n' "${pen[@]}" | jq -R . | jq -cs 'map(select(. != ""))')" \
        --argjson pointer "$(printf '%s\n' "${pointer[@]}" | jq -cs '.')" \
        --argjson keyboard "$(printf '%s\n' "${keyboard[@]}" | jq -R . | jq -cs 'map(select(. != ""))')" \
        '{touch: $touch, pen: $pen, pointer: $pointer, keyboard: $keyboard, access: $access}')"
    ((${#touch[@]})) || return
    for item in "${list[@]}"; do
        e=${item% *}
        k=${item#* }
        [[ -r /dev/input/$e ]] || continue
        setpriv --pdeathsig TERM "$0" watch "$e" "$k" &
        watchers+=($!)
    done
}

scan
# Plugging in or out: scan again once the burst of udev lines is over
coproc MON { exec setpriv --pdeathsig TERM udevadm monitor --udev --subsystem-match=input 2>/dev/null; }
while read -r line <&"${MON[0]}"; do
    [[ $line == *" add "* || $line == *" remove "* ]] || continue
    while read -r -t 0.4 line <&"${MON[0]}"; do :; done
    scan
done
