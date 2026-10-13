#!/usr/bin/env bash
# SomeShell installer. Sets up this repo as the desktop on any Arch/CachyOS PC.
#
#   ./install.sh              full setup: packages, fonts, services, screens, links, start the shell
#   ./install.sh --update     git pull, then the same setup (skips what is already done)
#   ./install.sh --detect     write the screen setup again from the connected monitors
#   ./install.sh --check      only verify the Hyprland config, change nothing
#   ./install.sh --rollback   remove the links and restore the previous directories
#
# Options: -y/--yes (no questions), --no-deps (skip packages and fonts),
#          --wallpaper <file> (set it once the shell runs; colors come from it)
#
# Every step is safe to run again. The first time a real directory is replaced
# it is moved to <name>.pre-someshell, which is what --rollback restores. If
# Hyprland reports config errors after linking, the links are rolled back.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
SUFFIX=".pre-someshell"
# The project was called SomeHypr before; migrate_legacy moves its directories
# over, and --rollback still restores backups made under the old name
LEGACY="somehypr"
LEGACY_SUFFIX=".pre-$LEGACY"
MONITORS="$REPO/hypr/generated/monitors.lua"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/someshell"
SANS_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BGRAD,ROND,opsz,slnt,wdth,wght%5D.ttf"

YES=0
DEPS=1
WALLPAPER=""
MODE="setup"

# repo path -> target path
LINKS=(
    "hypr:$CONFIG/hypr"
    "matugen:$CONFIG/matugen"
    "shell:$CONFIG/quickshell/someshell"
)

# Packages, as "package:command-or-path that proves it is there"
CORE=(
    "hyprland:Hyprland" "quickshell:qs" "matugen:matugen" "hypridle:hypridle" "hyprlock:hyprlock"
    "grim:grim" "slurp:slurp" "wl-clipboard:wl-copy" "cliphist:cliphist" "imagemagick:magick"
    "jq:jq" "curl:curl" "playerctl:playerctl" "wireplumber:wpctl" "brightnessctl:brightnessctl"
    "gnome-keyring:gnome-keyring-daemon" "fuzzel:fuzzel" "ydotool:ydotool"
)
EXTRAS=(
    "wf-recorder:wf-recorder" "tesseract:tesseract" "tesseract-data-eng:/usr/share/tessdata/eng.traineddata"
    "translate-shell:trans" "mpvpaper:mpvpaper" "swappy:swappy" "ddcutil:ddcutil"
)
LAPTOP=("upower:upower" "power-profiles-daemon:powerprofilesctl")
FONTS=(
    "ttf-material-symbols-variable-git:font:Material Symbols Rounded"
    "ttf-jetbrains-mono-nerd:font:JetBrainsMono Nerd Font"
    "bibata-cursor-theme-bin:/usr/share/icons/Bibata-Modern-Classic"
)

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

# ask "question" → 0 for yes. Enter means yes; --yes answers yes to all;
# without a terminal (and no --yes) the answer is no, so nothing runs unattended.
ask() {
    ((YES)) && return 0
    [[ -t 0 ]] || return 1
    local reply
    read -r -p "$(printf '\033[1;35m??\033[0m %s [Y/n] ' "$1")" reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

hypr_running() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl version >/dev/null 2>&1; }
has_battery() { compgen -G "/sys/class/power_supply/BAT*" >/dev/null; }
has_backlight() { [[ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]]; }

# --- Packages ----------------------------------------------------------------

present() {
    local what="$1"
    case "$what" in
        font:*) fc-list : family 2>/dev/null | grep -iF -- "${what#font:}" >/dev/null ;;  # no -q: SIGPIPE + pipefail
        /*) [[ -e "$what" ]] ;;
        *) command -v "$what" >/dev/null 2>&1 ;;
    esac
}

aur_helper() {
    local h
    for h in paru yay; do command -v "$h" >/dev/null && { echo "$h"; return; }; done
}

# install_missing "label" entries... : collects what is missing, installs repo
# packages with pacman and the rest with the AUR helper
install_missing() {
    local label="$1"
    shift
    local entry pkg check missing=()
    for entry in "$@"; do
        pkg="${entry%%:*}"
        check="${entry#*:}"
        present "$check" || pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]} == 0)); then
        ok "$label"
        return
    fi
    warn "$label missing: ${missing[*]}"
    ask "Install them?" || { warn "Skipped; some features will not work"; return; }
    local repo=() aur=()
    for pkg in "${missing[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then repo+=("$pkg"); else aur+=("$pkg"); fi
    done
    if ((${#repo[@]})); then
        sudo pacman -S --needed --noconfirm "${repo[@]}" || warn "pacman failed for: ${repo[*]}"
    fi
    if ((${#aur[@]})); then
        local helper
        helper="$(aur_helper)"
        if [[ -n "$helper" ]]; then
            "$helper" -S --needed --noconfirm "${aur[@]}" || warn "$helper failed for: ${aur[*]}"
        else
            warn "No AUR helper (paru or yay); install by hand: ${aur[*]}"
        fi
    fi
}

install_packages() {
    command -v pacman >/dev/null || { warn "Not an Arch-based system: install the packages in README.md by hand"; return; }
    say "Packages"
    install_missing "core" "${CORE[@]}"
    install_missing "capture, OCR, video wallpaper, DDC" "${EXTRAS[@]}"
    if has_battery; then
        install_missing "laptop (battery, power profiles)" "${LAPTOP[@]}"
    fi
    install_missing "fonts and cursor" "${FONTS[@]}"
    # Google Sans Flex is not packaged; it is OFL on google/fonts
    if present "font:Google Sans Flex"; then
        ok "Google Sans Flex"
    elif ask "Download Google Sans Flex (the shell's UI font) to $FONT_DIR?"; then
        mkdir -p "$FONT_DIR"
        if curl -fsSL -o "$FONT_DIR/GoogleSansFlex.ttf" "$SANS_URL"; then
            fc-cache -f "$FONT_DIR" >/dev/null
            ok "Google Sans Flex"
        else
            warn "Download failed; the shell falls back to another font"
        fi
    fi
}

# --- System services -----------------------------------------------------------

setup_services() {
    say "Services"
    # ydotoold: the on-screen keyboard types through it
    if systemctl --user cat ydotool.service >/dev/null 2>&1; then
        if systemctl --user is-active -q ydotool.service; then
            ok "ydotool (on-screen keyboard)"
        elif ask "Enable the ydotool user service (on-screen keyboard)?"; then
            systemctl --user enable --now ydotool.service && ok "ydotool"
        fi
    fi
    # DDC brightness for external monitors: i2c-dev and the i2c group
    if command -v ddcutil >/dev/null; then
        local need=()
        [[ -f /etc/modules-load.d/i2c-dev.conf || -d /sys/module/i2c_dev ]] || need+=("load i2c-dev at boot")
        getent group i2c >/dev/null && [[ " $(id -nG) " != *" i2c "* ]] && need+=("add $USER to the i2c group")
        if ((${#need[@]} == 0)); then
            ok "i2c (external monitor brightness)"
        elif ask "For external monitor brightness: ${need[*]}? (sudo)"; then
            [[ " ${need[*]} " == *i2c-dev* ]] && { echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null; sudo modprobe i2c-dev || true; }
            [[ " ${need[*]} " == *group* ]] && sudo usermod -aG i2c "$USER"
            ok "i2c (the group applies after you log in again)"
        fi
    fi
}

# --- Screens -------------------------------------------------------------------

# Snapshot the connected monitors into generated/monitors.lua (the Displays page
# file): each at its largest resolution and fastest refresh, a scale from its
# pixel density unless one is already set, laid out left to right in their
# current order. Monitors that are off now stay off.
detect_monitors() {
    if ! hypr_running; then
        # An empty file still counts, so the desktop's tracked monitors.lua (other
        # output names) is not applied here; every screen gets its fastest mode
        if [[ ! -f "$MONITORS" ]]; then
            mkdir -p "$(dirname "$MONITORS")"
            echo "-- Placeholder from install.sh: run ./install.sh --detect inside Hyprland" >"$MONITORS"
        fi
        warn "Hyprland is not running: screens use their fastest mode until you run ./install.sh --detect inside it"
        return
    fi
    local json
    json="$(hyprctl monitors all -j)"
    mkdir -p "$(dirname "$MONITORS")"
    jq -r '
        def best: (.availableModes // [])
            | map(capture("(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz") | {w: (.w|tonumber), h: (.h|tonumber), r: (.r|tonumber)})
            | sort_by(.w * .h, .r) | last;
        def ppi: if (.physicalWidth // 0) > 0 then .width / (.physicalWidth / 25.4) else 96 end;
        def autoscale: ppi as $p | if $p < 150 then 1 elif $p < 200 then 1.25 elif $p < 250 then 1.5 else 2 end;
        "-- Written by install.sh (detected; change it in Settings → Displays)",
        (sort_by(.x) | reduce .[] as $m ({x: 0, out: []};
            if $m.disabled then .out += ["hl.monitor({ output = \"\($m.name)\", disabled = true })"]
            else
                ($m | best) as $b
                | (if $b == null then {w: $m.width, h: $m.height, r: $m.refreshRate} else $b end) as $mode
                | (if $m.scale != 1 then $m.scale else ($m | autoscale) end) as $s
                | (if ($m.transform % 2) == 1 then $mode.h else $mode.w end) as $lw
                | .out += ["hl.monitor({ output = \"\($m.name)\", mode = \"\($mode.w)x\($mode.h)@\(($mode.r * 100 | round) / 100)Hz\", position = \"\(.x)x0\", scale = \($s), transform = \($m.transform) })"]
                | .x += (($lw / $s) | floor)
            end) | .out[])
    ' <<<"$json" >"$MONITORS.new"
    mv "$MONITORS.new" "$MONITORS"
    while read -r line; do ok "$line"; done < <(grep -o 'output = "[^"]*".*' "$MONITORS" | sed 's/ })$//')
}

screens() {
    say "Screens"
    if [[ -f "$MONITORS" && "$MODE" != "detect" ]]; then
        ok "kept $MONITORS (./install.sh --detect writes it again)"
    else
        detect_monitors
    fi
}

# --- Links -----------------------------------------------------------------------

verify() {
    say "Verifying Hyprland config"
    local out
    out="$(Hyprland --verify-config -c "$REPO/hypr/hyprland.lua" 2>&1 | sed -n '/Config parsing result/,$p' | tail -n +2)"
    echo "$out"
    grep -q '^config ok' <<<"$out"
}

link_one() {
    local src="$REPO/$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        ok "$dst"
        return
    fi
    # A dead link (the repo moved or was renamed) holds nothing worth a backup
    if [[ -L "$dst" && ! -e "$dst" ]]; then
        warn "$dst pointed at $(readlink "$dst"), which is gone; relinking"
        rm "$dst"
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ -e "$dst$SUFFIX" ]]; then
            local stamp="$dst$SUFFIX.$(date +%Y%m%d-%H%M%S)"
            warn "$dst$SUFFIX exists, moving current $dst to $stamp"
            mv "$dst" "$stamp"
        else
            mv "$dst" "$dst$SUFFIX"
            say "backup  $dst -> $dst$SUFFIX"
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "linked $dst -> $src"
}

unlink_one() {
    local dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$REPO/$1")" ]]; then
        rm "$dst"
        say "removed $dst"
    fi
    local backup
    for backup in "$dst$SUFFIX" "$dst$LEGACY_SUFFIX"; do
        if [[ -e "$backup" && ! -e "$dst" ]]; then
            mv "$backup" "$dst"
            say "restored $dst"
        fi
    done
}

# --- Migration from SomeHypr ---------------------------------------------------

# Moves what the old name left behind to the new one. Every step checks first,
# so it does nothing on a fresh machine or on a second run.
migrate_legacy() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}" moved=0 base old new f
    for base in "$CONFIG" "${XDG_STATE_HOME:-$HOME/.local/state}" "${XDG_CACHE_HOME:-$HOME/.cache}" "$data" "$data/fonts"; do
        old="$base/$LEGACY"
        new="$base/someshell"
        if [[ -d "$old" && ! -L "$old" && ! -e "$new" ]]; then
            mv "$old" "$new"
            ok "moved $old -> $new"
            moved=1
        fi
    done
    # The old shell link and the old shell itself (its shortcuts no longer match)
    if [[ -L "$CONFIG/quickshell/$LEGACY" ]]; then
        rm "$CONFIG/quickshell/$LEGACY"
        moved=1
    fi
    if hypr_running; then
        local pids
        pids="$(pgrep -a -x qs | awk -v n="$LEGACY" '{ for (i = 2; i < NF; i++) if ($i == "-c" && $(i + 1) == n) print $1 }' || true)"
        if [[ -n "$pids" ]]; then
            xargs -r kill <<<"$pids"
            ok "stopped the old shell (qs -c $LEGACY)"
            moved=1
        fi
    fi
    # Files matugen wrote under the old names; it writes the new ones on the next wallpaper change
    for f in "$data"/color-schemes/SomeHypr*.colors "$CONFIG/vesktop/themes/$LEGACY.theme.css" "$CONFIG"/zen/*/chrome/"$LEGACY-colors.css"; do
        [[ -f "$f" ]] && rm "$f" && moved=1
    done
    for f in "$CONFIG"/zen/*/chrome/userChrome.css; do
        [[ -f "$f" ]] && sed -i "s/$LEGACY-colors\.css/someshell-colors.css/g" "$f"
    done
    # State files that hold the old cache path
    if [[ -d "${XDG_STATE_HOME:-$HOME/.local/state}/someshell" ]]; then
        { grep -rlZ -- "/$LEGACY/" "${XDG_STATE_HOME:-$HOME/.local/state}/someshell" 2>/dev/null || true; } |
            xargs -0 -r sed -i "s#/$LEGACY/#/someshell/#g"
    fi
    ((moved)) && say "Migrated from SomeHypr"
    return 0
}

# State that end-4's ii keeps inside ~/.config/hypr and that should survive the swap
carry_state() {
    local old="$CONFIG/hypr"
    [[ -L "$old" ]] && return
    if [[ -d "$old/custom/scripts" ]]; then
        mkdir -p "$REPO/hypr/custom"
        cp -rn "$old/custom/scripts" "$REPO/hypr/custom/" 2>/dev/null || true
    fi
    [[ -f "$old/hyprland/colors.lua" && ! -f "$REPO/hypr/generated/colors.lua" ]] &&
        cp "$old/hyprland/colors.lua" "$REPO/hypr/generated/colors.lua"
    [[ -f "$old/hyprlock/colors.conf" && ! -f "$REPO/hypr/generated/hyprlock-colors.conf" ]] &&
        cp "$old/hyprlock/colors.conf" "$REPO/hypr/generated/hyprlock-colors.conf"
    return 0
}

restart_hypridle() {
    pkill -x hypridle || true
    setsid -f hypridle >/dev/null 2>&1
}

reload_session() {
    hypr_running || return 0
    say "Reloading Hyprland"
    hyprctl reload >/dev/null
    sleep 1
    local errors
    errors="$(hyprctl configerrors)"
    if [[ -n "${errors//[[:space:]]/}" ]]; then
        warn "Hyprland reported config errors:"
        echo "$errors" >&2
        return 1
    fi
    ok "no config errors"
    restart_hypridle    # it reads its config only at start
}

rollback() {
    for entry in "${LINKS[@]}"; do unlink_one "${entry%%:*}" "${entry#*:}"; done
    if hypr_running; then
        hyprctl reload >/dev/null
        restart_hypridle
    fi
    say "Rolled back"
}

# --- Shell ---------------------------------------------------------------------

# Autostart runs only at login, so start the shell now in a running session,
# after stopping any other Quickshell config (e.g. ii) that would draw on top
start_shell() {
    hypr_running || return 0
    say "Shell"
    local others
    others="$( { pgrep -a -x qs | grep -v -- '-c someshell'; pgrep -a -x quickshell; } || true)"
    if [[ -n "$others" ]]; then
        warn "Another Quickshell is running:"
        echo "$others" | sed 's/^/     /' >&2
        if ask "Stop it and start SomeShell?"; then
            awk '{print $1}' <<<"$others" | xargs -r kill
            sleep 1
        fi
    fi
    if qs -c someshell ipc call island state >/dev/null 2>&1; then
        ok "SomeShell shell running"
    else
        hyprctl dispatch exec "$REPO/hypr/scripts/shell.sh" >/dev/null 2>&1 ||
            hyprctl eval "hl.exec_cmd(\"$REPO/hypr/scripts/shell.sh\")" >/dev/null
        local i
        for i in {1..20}; do
            qs -c someshell ipc call island state >/dev/null 2>&1 && break
            sleep 0.5
        done
        if qs -c someshell ipc call island state >/dev/null 2>&1; then ok "SomeShell shell started"; else warn "The shell did not answer; check: qs log -c someshell"; fi
    fi
    if [[ -n "$WALLPAPER" ]]; then
        qs -c someshell ipc call wallpaper set "$(realpath "$WALLPAPER")" >/dev/null && ok "wallpaper set; matugen recolors everything"
    elif [[ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/someshell/wallpaper.json" ]]; then
        say "No wallpaper yet: pick one with Ctrl+Super+T, or ./install.sh --wallpaper <file>"
    fi
}

summary() {
    say "This machine"
    local gpus
    gpus="$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u | sed 's/0x10de/NVIDIA/;s/0x8086/Intel/;s/0x1002/AMD/' | paste -sd' ')"
    ok "GPU: ${gpus:-unknown}$([[ "$gpus" == "NVIDIA" ]] && echo ' (NVIDIA env on)')"
    has_battery && ok "battery: shown in the status pill, charge limit in Settings → Power"
    has_backlight && ok "backlight: brightness keys drive the panel"
    if hypr_running && hyprctl devices -j | jq -e '.mice[] | select(.name | test("touchpad"; "i"))' >/dev/null; then
        ok "touchpad: gestures on, options in Settings → Hyprland → Touchpad"
    fi
    hypr_running || say "Log in to Hyprland to start SomeShell (then run ./install.sh --detect for the screens)"
}

# --- Main --------------------------------------------------------------------------

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

while (($#)); do
    case "$1" in
        -y | --yes) YES=1 ;;
        --no-deps) DEPS=0 ;;
        --wallpaper)
            [[ $# -ge 2 && -f "$2" ]] || die "--wallpaper needs an image or video file"
            WALLPAPER="$2"
            shift
            ;;
        --check) MODE="check" ;;
        --rollback) MODE="rollback" ;;
        --detect) MODE="detect" ;;
        --update) MODE="update" ;;
        -h | --help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "Run as your user, not root (it asks for sudo when needed)"

case "$MODE" in
    check)
        verify
        exit
        ;;
    rollback)
        rollback
        exit
        ;;
    detect)
        screens
        reload_session || warn "Fix the errors above, or remove $MONITORS"
        exit
        ;;
    update)
        say "Updating"
        git -C "$REPO" pull --ff-only || die "git pull failed (local changes?); nothing else changed"
        ;;
esac

((DEPS)) && install_packages
command -v Hyprland >/dev/null || die "Hyprland is not installed"
setup_services
verify || die "Config does not verify, nothing linked"
carry_state
migrate_legacy
say "Links"
for entry in "${LINKS[@]}"; do link_one "${entry%%:*}" "${entry#*:}"; done
screens
if ! reload_session; then
    warn "Rolling back"
    rollback
    exit 1
fi
start_shell
summary
say "Done"
