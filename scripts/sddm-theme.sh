#!/usr/bin/env bash
# Stage assets as the desktop user; only copying/activation needs sudo.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=${1:---preview}
case "$mode" in
    --prepare|--preview|--install|--rollback) ;;
    *) printf 'Usage: %s [--preview|--prepare|--install|--rollback]\n' "$0" >&2; exit 2 ;;
esac

if [[ "$mode" == --rollback ]]; then
    sudo sh -eu -c '
        conf=/etc/sddm.conf.d/zz-someshell.conf
        [ -f "$conf.pre-someshell" ] || exit 0
        if [ -s "$conf.pre-someshell" ]; then
            mv -- "$conf.pre-someshell" "$conf"
        else
            rm -f -- "$conf"
            rm -f -- "$conf.pre-someshell"
        fi
    '
    printf 'Restored the previous SDDM selection. It applies at the next login.\n'
    exit
fi
if (( EUID == 0 )); then
    printf 'Run this as your desktop user; it asks sudo only when installing.\n' >&2
    exit 1
fi
for tool in jq magick fc-match; do
    command -v "$tool" >/dev/null || { printf 'Missing dependency: %s\n' "$tool" >&2; exit 1; }
done
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/someshell/sddm
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/someshell
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/someshell
mkdir -p -- "$cache_dir"
stage_dir=$(mktemp -d "$cache_dir/theme.XXXXXXXX")
trap 'rm -rf -- "$stage_dir"' EXIT
cp -R -- "$repo_dir/sddm/." "$stage_dir/"

# SDDM cannot assume it can read an encrypted/private home at the login screen.
# A blurred copy and fonts are installed in the theme, never linked to home.
wallpaper=$(jq -r '.path // empty' "$state_dir/wallpaper.json" 2>/dev/null || true)
case "${wallpaper,,}" in
    *.mp4|*.webm|*.mkv|*.mov|*.m4v|*.avi) wallpaper=$state_dir/video-frame.jpg ;;
esac
background=assets/background.svg
if [[ -f "$wallpaper" ]]; then
    if magick "$wallpaper[0]" -auto-orient -resize '2560x1440>' -resize 12.5% -blur 0x6 -resize 800% -quality 92 "$stage_dir/assets/background.jpg"; then
        background=assets/background.jpg
    else
        printf 'Wallpaper conversion failed; using the bundled background.\n' >&2
    fi
fi
font_file=
icon_file=
for family in 'Google Sans Flex' 'Material Symbols Rounded'; do
    source_font=$(fc-match -f '%{file}' "$family")
    actual_family=$(fc-match -f '%{family}' "$family")
    if [[ -f "$source_font" && "$actual_family" == *"$family"* ]]; then
        if [[ "$family" == 'Google Sans Flex' ]]; then
            dest=assets/ui.ttf; font_file=$dest
        else
            dest=assets/icons.ttf; icon_file=$dest
        fi
        cp -- "$source_font" "$stage_dir/$dest"
        # Preserve any locally supplied font license beside the copied face.
        for license in "$(dirname -- "$source_font")"/{OFL.txt,LICENSE,LICENSE.txt}; do
            [[ ! -f "$license" ]] || cp -- "$license" "$stage_dir/$dest.LICENSE"
        done
    fi
done
clock_format=$(jq -r '.clock.format // "HH:mm"' "$config_dir/config.json" 2>/dev/null || printf 'HH:mm')
clock_format=${clock_format//$'\n'/}
reduced=$(jq -r '.motion.reduce // false' "$config_dir/config.json" 2>/dev/null || printf 'false')
preview_mode=true
[[ "$mode" != --install ]] || preview_mode=false
cat > "$stage_dir/theme.conf.user" <<CONFIG
[General]
Background=$background
FontFile=$font_file
IconFontFile=$icon_file
ClockFormat=$clock_format
ReducedMotion=$reduced
PreviewMode=$preview_mode
CONFIG

if [[ "$mode" == --install ]]; then
    sudo sh -eu -c '
        source_dir=$1
        destination=/usr/share/sddm/themes/someshell
        conf=/etc/sddm.conf.d/zz-someshell.conf
        mkdir -p -- "$destination" /etc/sddm.conf.d
        # Installed under the old name (SomeHypr): its backup of the earlier
        # selection carries over, the old theme and selection go
        old=/etc/sddm.conf.d/zz-somehypr.conf
        if [ -f "$old.pre-somehypr" ] && [ ! -f "$conf.pre-someshell" ]; then
            mv -- "$old.pre-somehypr" "$conf.pre-someshell"
        fi
        rm -f -- "$old" "$old.pre-somehypr"
        rm -rf -- /usr/share/sddm/themes/somehypr
        if [ ! -f "$conf.pre-someshell" ]; then
            if [ -f "$conf" ]; then
                cp -p -- "$conf" "$conf.pre-someshell"
            else
                touch "$conf.pre-someshell"
            fi
        fi
        cp -R -- "$source_dir/." "$destination/"
        chown -R root:root "$destination"
        find "$destination" -type d -exec chmod 755 {} +
        find "$destination" -type f -exec chmod 644 {} +
        tmp_conf=$(mktemp /etc/sddm.conf.d/.someshell.XXXXXXXX)
        printf "[General]\nInputMethod=\nGreeterEnvironment=QT_IM_MODULE=compose\n\n[Theme]\nCurrent=someshell\n" > "$tmp_conf"
        chmod 644 "$tmp_conf"
        mv -- "$tmp_conf" "$conf"
    ' sh "$stage_dir"
    printf 'SomeShell SDDM theme installed. It applies at the next login.\n'
    printf 'Rollback: %s --rollback\n' "$0"
else
    # --prepare keeps a stable preview directory for inspection/tests.
    prepared=$cache_dir/preview
    mkdir -p -- "$prepared"
    cp -R -- "$stage_dir/." "$prepared/"
    if [[ "$mode" == --prepare ]]; then
        printf '%s\n' "$prepared"
    else
        greeter=$(command -v sddm-greeter-qt6 || command -v sddm-greeter || true)
        [[ -n "$greeter" ]] || { printf 'Install the Qt 6 SDDM greeter first.\n' >&2; exit 1; }
        # Existing ii's virtual-keyboard configuration otherwise opens an
        # unrelated full-screen keyboard during an X11 preview.
        platform=${QT_QPA_PLATFORM:-}
        platform=${platform%%;*}
        platform=${platform:-wayland}
        QT_QPA_PLATFORM=$platform QT_IM_MODULE=compose QT_VIRTUALKEYBOARD_DESKTOP_DISABLE=1 \
            "$greeter" --test-mode --theme "$prepared"
    fi
fi
