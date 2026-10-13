#!/usr/bin/env bash
# matugen post-hook: apply the generated KDE/Qt color scheme.
# plasma-apply-colorscheme ignores a scheme that is already active even when its
# file changed, so alternate between two copies with different names.
dir="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"
src="$dir/SomeShell.colors"
[[ -f "$src" ]] || exit 0
command -v plasma-apply-colorscheme >/dev/null || exit 0
current="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
next=SomeShellA
[[ "$current" == SomeShellA ]] && next=SomeShellB
sed "s/^ColorScheme=.*/ColorScheme=$next/; s/^Name=.*/Name=$next/" "$src" > "$dir/$next.colors"
plasma-apply-colorscheme "$next" >/dev/null 2>&1
