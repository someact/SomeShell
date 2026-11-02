#!/usr/bin/env bash
# matugen hook: give the colors to Zen. Every profile with a chrome/ folder
# gets a copy, imported at the top of its userChrome.css (added once).
# Profiles without chrome/ are left alone.
src="${XDG_STATE_HOME:-$HOME/.local/state}/someshell/zen-colors.css"
[[ -f "$src" ]] || exit 0
import='@import "someshell-colors.css";'
for chrome in "${XDG_CONFIG_HOME:-$HOME/.config}"/zen/*/chrome "$HOME"/.zen/*/chrome; do
    [[ -d "$chrome" ]] || continue
    cp -f "$src" "$chrome/someshell-colors.css"
    css="$chrome/userChrome.css"
    if [[ ! -f "$css" ]]; then
        printf '%s\n' "$import" >"$css"
    elif ! grep -qF "$import" "$css"; then
        printf '%s\n%s\n' "$import" "$(cat "$css")" >"$css.tmp" && mv "$css.tmp" "$css"
    fi
done
