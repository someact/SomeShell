#!/usr/bin/env bash
# Build the Quick Share helper (tools/quickshare) for the shell.
#
#   quickshare.sh            build if it is not installed yet
#   quickshare.sh --rebuild  build again (after a pull that changed tools/quickshare)
#   quickshare.sh --path     print where the helper goes
#
# Needs cargo (pacman -S rust, or rustup) and protoc (pacman -S protobuf). The
# first build downloads and compiles the dependencies and takes a few minutes.
# Result: two binaries in ~/.local/share/someshell/bin, which
# shell/services/QuickShare.qml starts when they are there:
#   someshell-quickshare      with Bluetooth (finds phones that are not on the Wi-Fi yet)
#   someshell-quickshare-net  network only
# The library switches Bluetooth on whenever its Bluetooth side runs, so the
# shell uses the first one only while Bluetooth is on already.
# Also adds "Send with Quick Share" to Dolphin's context menu.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SRC="$HERE/../tools/quickshare"
OUT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/someshell/bin"
OUT="$OUT_DIR/someshell-quickshare"
# Built outside the repo, so the checkout stays clean
TARGET="${XDG_CACHE_HOME:-$HOME/.cache}/someshell/quickshare-build"

case "${1:-}" in
--path) echo "$OUT"; exit 0 ;;
--rebuild) ;;
"") [[ -x "$OUT" ]] && { echo "already built: $OUT"; exit 0; } ;;
*) echo "usage: $0 [--rebuild|--path]" >&2; exit 2 ;;
esac

# A rustup install lives in ~/.cargo/bin, which a desktop session may not have in PATH
PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo is missing: sudo pacman -S rust" >&2; exit 1; }
command -v protoc >/dev/null || { echo "protoc is missing: sudo pacman -S protobuf" >&2; exit 1; }

mkdir -p "$OUT_DIR"
cargo build --release --locked --manifest-path "$SRC/Cargo.toml" --target-dir "$TARGET"
install -m 755 "$TARGET/release/someshell-quickshare" "$OUT-net"
cargo build --release --locked --features ble --manifest-path "$SRC/Cargo.toml" --target-dir "$TARGET"
install -m 755 "$TARGET/release/someshell-quickshare" "$OUT"
echo "built: $OUT and $OUT-net"
# A running shell looks for the helper again
qs -c someshell ipc call quickshare refresh >/dev/null 2>&1 || true

# Dolphin: right-click files → Send with Quick Share (KDE reads only executable service menus)
MENU_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kio/servicemenus"
if command -v dolphin >/dev/null; then
    mkdir -p "$MENU_DIR"
    cat >"$MENU_DIR/someshell-quickshare.desktop" <<MENU
[Desktop Entry]
Type=Service
MimeType=all/allfiles;
Actions=someshellQuickShare
X-KDE-ServiceTypes=KonqPopupMenu/Plugin

[Desktop Action someshellQuickShare]
Name=Send with Quick Share
Icon=document-send
Exec=$(readlink -f "$HERE/../hypr/scripts/quickshare-send.sh") %F
MENU
    chmod +x "$MENU_DIR/someshell-quickshare.desktop"
    echo "added: Dolphin → Send with Quick Share"
fi
