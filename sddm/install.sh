#!/usr/bin/env bash
# Installs SomeShell's SDDM theme (lock style A) and selects it.
#   sudo sddm/install.sh            install or update (run again after a
#                                   wallpaper change to take its colors)
#   sudo sddm/install.sh --remove   unselect it (the theme files stay)
# SDDM runs as its own user and cannot read the user's files, so the theme,
# the Mitr files and the current palette are copied in. Other themes stay
# installed; the choice lives in its own file in /etc/sddm.conf.d/ (read
# after files whose names sort earlier, so it wins over them).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
dest=/usr/share/sddm/themes/someshell
conf=/etc/sddm.conf.d/someshell.conf

[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0 $*" >&2; exit 1; }

if [ "${1:-}" = "--remove" ]; then
    rm -f "$conf"
    echo "SDDM no longer uses the SomeShell theme (files left in $dest)."
    exit 0
fi

# The user whose fonts and colors to take
user=${SUDO_USER:-}
[ -n "$user" ] && [ "$user" != root ] || { echo "Run through sudo from your own account." >&2; exit 1; }
home=$(getent passwd "$user" | cut -d: -f6)
state=$(sudo -u "$user" sh -c 'echo "${XDG_STATE_HOME:-$HOME/.local/state}"')

install -d "$dest/fonts"
install -m 644 "$here/someshell/Main.qml" "$here/someshell/metadata.desktop" "$dest/"

# Mitr: from the user's fonts, else downloaded (the same files the setup uses)
for face in Light Regular Medium SemiBold; do
    src="$home/.local/share/fonts/someshell/Mitr-$face.ttf"
    if [ -f "$src" ]; then
        install -m 644 "$src" "$dest/fonts/"
    elif [ ! -f "$dest/fonts/Mitr-$face.ttf" ]; then
        curl -fsSL -o "$dest/fonts/Mitr-$face.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/mitr/Mitr-$face.ttf"
    fi
done

# Colors: the palette in its current mode (dark or light), else the defaults
palette="$state/someshell/palette.json"
cp "$here/someshell/theme.conf" "$dest/theme.conf"
if [ -f "$palette" ] && command -v jq >/dev/null; then
    jq -r '
        (if .mode == "light" then .light else .dark end) as $p
        | (if .mode == "light" then
              { raised: $p.surface_container }
           else
              { raised: $p.surface_container_high }
           end) as $r
        | "[General]",
          "paper=\($p.surface_container_lowest)",
          "ink=\($p.on_surface)",
          "mute=\($p.on_surface_variant)",
          "line=\($p.outline_variant)",
          "raised=\($r.raised)",
          "error=\($p.error)"
    ' "$palette" > "$dest/theme.conf"
fi
chmod 644 "$dest/theme.conf"

install -d /etc/sddm.conf.d
cat > "$conf" <<'CONF'
# Written by SomeShell's sddm/install.sh (sudo sddm/install.sh --remove to undo)
[Theme]
Current=someshell

[General]
# No on-screen keyboard (an earlier theme may have turned it on)
InputMethod=
CONF

echo "SDDM now uses the SomeShell theme. Test it without logging out:"
echo "  sddm-greeter-qt6 --test-mode --theme $dest"
