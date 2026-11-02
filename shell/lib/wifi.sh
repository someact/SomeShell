#!/usr/bin/env bash
# Join or edit a Wi-Fi network for the Internet page (NetworkManager).
#   wifi.sh psk <ssid>    stdin: password
#   wifi.sh eap <ssid>    stdin: username, then password (PEAP + MSCHAPv2)
# A saved profile for the SSID is edited and kept; otherwise a new one is
# made, and removed again if the first connection fails. Secrets come on
# stdin, never as arguments to this script. The last line printed is "ok" or
# "error: <reason>".
set -u
kind=${1:-}
ssid=${2:-}
[ -n "$kind" ] && [ -n "$ssid" ] || { echo "error: usage"; exit 2; }

if [ "$kind" = eap ]; then
    IFS= read -r user || true
fi
IFS= read -r pass || true

dev=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" { print $1; exit }')
[ -n "$dev" ] || { echo "error: no Wi-Fi device"; exit 1; }

# The saved profile whose SSID matches (its name may differ from the SSID)
profile=""
while IFS= read -r line; do
    name=${line%:802-11-wireless}
    [ "$name" = "$line" ] && continue
    name=${name//\\:/:}
    if [ "$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null)" = "$ssid" ]; then
        profile=$name
        break
    fi
done < <(nmcli -t -f NAME,TYPE connection show)

reason() {
    # nmcli's last line, shortened to what a person needs
    local msg
    msg=$(printf '%s\n' "$1" | grep -v '^$' | tail -1)
    case "$msg" in
        *"Secrets were required"* | *"secrets"* | *"802-1x"*) echo "wrong password or username" ;;
        *"Timeout"* | *"timed out"*) echo "no answer from the network (timeout)" ;;
        *"No network with SSID"*) echo "network not in range" ;;
        *) echo "${msg#Error: }" ;;
    esac
}

up() {
    local out
    if out=$(nmcli --wait 40 connection up "$1" ifname "$dev" 2>&1); then
        echo ok
        return 0
    fi
    echo "error: $(reason "$out")"
    return 1
}

if [ -n "$profile" ]; then
    # Edit the saved network: new secrets, same profile
    if [ "$kind" = eap ]; then
        nmcli connection modify "$profile" 802-1x.identity "$user" 802-1x.password "$pass" || { echo "error: could not save the login"; exit 1; }
    else
        nmcli connection modify "$profile" wifi-sec.psk "$pass" || { echo "error: could not save the password"; exit 1; }
    fi
    up "$profile"
    exit $?
fi

# A new network
if [ "$kind" = eap ]; then
    nmcli connection add type wifi con-name "$ssid" ifname "$dev" ssid "$ssid" \
        wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 \
        802-1x.identity "$user" 802-1x.password "$pass" >/dev/null 2>&1 \
        || { echo "error: could not save the network"; exit 1; }
    up "$ssid" || { nmcli connection delete id "$ssid" >/dev/null 2>&1; exit 1; }
else
    if out=$(nmcli --wait 40 device wifi connect "$ssid" password "$pass" ifname "$dev" 2>&1); then
        echo ok
    else
        echo "error: $(reason "$out")"
        # nmcli keeps the profile it made even when joining failed
        nmcli connection delete id "$ssid" >/dev/null 2>&1
        exit 1
    fi
fi
