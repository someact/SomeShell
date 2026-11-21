#!/usr/bin/env bash
# Lets the shell's charge limit write its files without sudo: a udev rule
# gives the wheel group write access to the battery's charge thresholds and
# charge behaviour, a charger's input current (the software limit) and
# Lenovo's conservation mode. Nothing else changes.
#   sudo scripts/charge-access.sh            install, apply now
#   sudo scripts/charge-access.sh --remove   take the rule away
# Not needed where `sudo -n` works without a password (the shell falls back
# to it).
set -euo pipefail

rule=/etc/udev/rules.d/70-someshell-charge.rules

[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0 $*" >&2; exit 1; }

if [ "${1:-}" = "--remove" ]; then
    rm -f "$rule"
    udevadm control --reload
    echo "Removed $rule (takes effect at the next boot)."
    exit 0
fi

# $$ is a literal $ inside a udev RUN
cat > "$rule" <<'EOF'
# SomeShell charge limit (scripts/charge-access.sh)
SUBSYSTEM=="power_supply", ATTR{type}=="Battery", RUN+="/bin/sh -c 'cd /sys$devpath && for f in charge_control_start_threshold charge_control_end_threshold charge_behaviour; do [ -e $$f ] && chgrp wheel $$f && chmod g+w $$f; done; true'"
SUBSYSTEM=="power_supply", ATTR{type}=="USB|Mains", RUN+="/bin/sh -c 'f=/sys$devpath/current_max; [ -e $$f ] && chgrp wheel $$f && chmod g+w $$f; true'"
SUBSYSTEM=="platform", DRIVER=="ideapad_acpi", RUN+="/bin/sh -c 'f=/sys$devpath/conservation_mode; [ -e $$f ] && chgrp wheel $$f && chmod g+w $$f; true'"
EOF
udevadm control --reload
udevadm trigger --action=change --subsystem-match=power_supply
udevadm trigger --action=change --subsystem-match=platform
echo "Installed $rule. Members of wheel can now set the charge limit."
