#!/usr/bin/env bash
# Builds and installs the Quick Share helper (Bluetooth file push through
# bluez's obexd) → ~/.local/lib/someshell/someshell-share. The shell starts it
# when it is there and the machine has a Bluetooth adapter.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
libdir=$HOME/.local/lib/someshell

command -v cargo >/dev/null || { echo "cargo is missing (pacman -S rust)" >&2; exit 1; }
[ -x /usr/lib/bluetooth/obexd ] || [ -x /usr/libexec/bluetooth/obexd ] \
    || echo "note: obexd was not found (it comes with bluez; Arch: bluez)" >&2

cargo build --release --quiet --manifest-path "$here/Cargo.toml"
mkdir -p "$libdir"
install -m 755 "$here/target/release/someshell-share" "$libdir/someshell-share"
echo ":: installed $libdir/someshell-share (restart the shell to start it)"
