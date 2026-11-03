#!/usr/bin/env bash
# Text lines for the hyprlock backup lock screen (hyprlock.conf), in the
# shell's style A: small spaced capitals.
#   date    WED · 04 · XI · MMXXVI
#   locked  LOCKED AT 02:10, and that this is the backup
#   who     the user's name in capitals
#   host    CACHYOS-BYACT · HYPRLAND
#   layout  EN (with an optional text before and after)
#   status  ONLINE · ETHERNET. / BATTERY 82%, CHARGING.

# Spaced capitals (pango markup, hyprlock labels read it)
sp() { printf '<span letter_spacing="2600">%s</span>\n' "$1"; }

roman() {
    local n=$1 out="" v s
    for pair in 1000:M 900:CM 500:D 400:CD 100:C 90:XC 50:L 40:XL 10:X 9:IX 5:V 4:IV 1:I; do
        v=${pair%%:*} s=${pair#*:}
        while (( n >= v )); do out+=$s; (( n -= v )); done
    done
    printf '%s' "$out"
}

case "$1" in
    date)
        sp "$(printf '%s · %s · %s · %s' "$(LC_ALL=C date +%a | tr a-z A-Z)" "$(date +%d)" \
            "$(roman "$(date +%-m)")" "$(roman "$(date +%Y)")")" ;;
    locked) sp "LOCKED AT $(date +%H:%M),"; sp "BY HYPRLOCK,"; sp "THE SHELL IS NOT RUNNING." ;;
    who) printf '<span letter_spacing="3000">%s</span>\n' "${USER^^}" ;;
    host) sp "$(uname -n | tr a-z A-Z) · HYPRLAND" ;;
    # The active keyboard layout as a short code (EN, TH), like the shell's tray
    layout)
        name=$(hyprctl devices -j 2>/dev/null | jq -r '((.keyboards | map(select(.main))) + .keyboards)[0].active_keymap // ""')
        case "$name" in
            English*|english*) code=EN ;;
            *) code=$(printf '%s' "$name" | tr -cd 'A-Za-z' | cut -c1-2 | tr a-z A-Z) ;;
        esac
        sp "${2:-}$code${3:-}" ;;
    status)
        lines=()
        if command -v nmcli >/dev/null; then
            conn=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep -vE '^(loopback|bridge|tun|wireguard)' | head -1)
            case "$conn" in
                *ethernet*) lines+=("ONLINE · ETHERNET.") ;;
                *wireless*) lines+=("ONLINE · ${conn#*:}.") ;;
                "") lines+=("OFFLINE.") ;;
                *) lines+=("ONLINE.") ;;
            esac
        fi
        for b in /sys/class/power_supply/*; do
            [ "$(cat "$b/type" 2>/dev/null)" = Battery ] || continue
            [ "$(cat "$b/scope" 2>/dev/null)" = Device ] && continue
            pct=$(cat "$b/capacity" 2>/dev/null) || continue
            st=$(cat "$b/status" 2>/dev/null)
            case "$st" in
                Charging) lines+=("BATTERY $pct%, CHARGING.") ;;
                Full) lines+=("BATTERY $pct%, FULL.") ;;
                *) lines+=("BATTERY $pct%.") ;;
            esac
            break
        done
        for l in "${lines[@]}"; do sp "$l"; done ;;
esac
