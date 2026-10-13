#!/usr/bin/env bash
# Build the hyprglass plugin (liquid glass) for the running Hyprland version.
#
#   hyprglass.sh            build if there is no plugin for this Hyprland version yet
#   hyprglass.sh --rebuild  build again (after a Hyprland update, or to pick up upstream fixes)
#   hyprglass.sh --path     print where the plugin for this version goes
#
# Source: ~/.local/src/hyprglass, branch hyprland-<major.minor> (upstream's
# release branch), plus plugins/hyprglass-fit-shape.patch. That patch makes
# layer glass follow the rounded shape the shell asks to blur instead of the
# whole layer surface (the shell's surfaces are larger than what they draw).
# The plugin is ABI-bound to one Hyprland build, so the file name carries the
# version; hypr/core/liquidglass.lua only loads the one that matches.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PATCH="$HERE/../plugins/hyprglass-fit-shape.patch"
SRC="$HOME/.local/src/hyprglass"
OUT_DIR="$HOME/.local/share/someshell/plugins"
VERSION="$(hyprctl version -j | jq -r .tag | sed 's/^v//; s/-.*//')"
BRANCH="hyprland-$(cut -d. -f1,2 <<<"$VERSION")"
OUT="$OUT_DIR/hyprglass-$VERSION.so"

case "${1:-}" in
--path) echo "$OUT"; exit 0 ;;
--rebuild) rm -f "$OUT" ;;
"") [[ -f "$OUT" ]] && { echo "already built: $OUT"; exit 0; } ;;
*) echo "usage: $0 [--rebuild|--path]" >&2; exit 2 ;;
esac

[[ -d "$SRC/.git" ]] || git clone https://github.com/hyprnux/hyprglass "$SRC"
cd "$SRC"
git fetch --quiet origin
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
    REF="origin/$BRANCH"
else
    echo "no $BRANCH branch upstream, using main (meant for hyprland-git)" >&2
    REF="origin/main"
fi
git checkout --quiet --force -B someshell "$REF"
git apply "$PATCH"
make clean >/dev/null 2>&1 || true
make
mkdir -p "$OUT_DIR"
install -m 755 hyprglass.so "$OUT"
echo "built: $OUT"
echo "turn it on: Settings > Appearance > Liquid glass (or liquidGlass = true in hypr/user.lua)"
