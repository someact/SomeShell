#!/usr/bin/env bash
# Builds and installs the SomeShell browser parts for Zen/Firefox:
#   - the native helper (Rust) → ~/.local/lib/someshell/someshell-browser
#   - its native-messaging manifest (both places Firefox-family browsers look)
#   - the extension, packed as browser/someshell.xpi
# With --profile <dir>: also lets that profile install unsigned add-ons
# (xpinstall.signatures.required = false in its user.js) and drops the .xpi
# into its extensions folder; the browser asks to enable it on the next start.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
libdir=$HOME/.local/lib/someshell
id="browser@someshell"
profile=""

while [ $# -gt 0 ]; do
    case $1 in
        --profile) profile=${2:?--profile needs a folder}; shift 2 ;;
        *) echo "usage: $0 [--profile <browser profile folder>]" >&2; exit 2 ;;
    esac
done

command -v cargo >/dev/null || { echo "cargo is missing (pacman -S rust)" >&2; exit 1; }
command -v bsdtar >/dev/null || { echo "bsdtar is missing (pacman -S libarchive)" >&2; exit 1; }

echo ":: helper"
cargo build --release --quiet --manifest-path "$here/host/Cargo.toml"
mkdir -p "$libdir"
install -m 755 "$here/host/target/release/someshell-browser" "$libdir/someshell-browser"

echo ":: native-messaging manifest"
for dir in "$HOME/.mozilla/native-messaging-hosts" "$config/mozilla/native-messaging-hosts"; do
    mkdir -p "$dir"
    cat > "$dir/someshell_browser.json" <<EOF
{
  "name": "someshell_browser",
  "description": "SomeShell: passes what tabs play to the desktop shell",
  "path": "$libdir/someshell-browser",
  "type": "stdio",
  "allowed_extensions": ["$id"]
}
EOF
    echo "   $dir/someshell_browser.json"
done

echo ":: extension"
rm -f "$here/someshell.xpi"
(cd "$here/extension" && bsdtar --format zip -cf "$here/someshell.xpi" -- *)
echo "   $here/someshell.xpi"

if [ -n "$profile" ]; then
    [ -d "$profile" ] || { echo "no such profile folder: $profile" >&2; exit 1; }
    echo ":: profile $profile"
    if ! grep -qs 'xpinstall.signatures.required' "$profile/user.js"; then
        printf '\n// SomeShell extension is installed unsigned\nuser_pref("xpinstall.signatures.required", false);\n' >> "$profile/user.js"
    fi
    mkdir -p "$profile/extensions"
    cp "$here/someshell.xpi" "$profile/extensions/$id.xpi"
    echo "   restart the browser and allow the SomeShell add-on when it asks"
else
    echo "Install: about:config → xpinstall.signatures.required = false, then about:addons → Install Add-on From File → someshell.xpi"
fi
