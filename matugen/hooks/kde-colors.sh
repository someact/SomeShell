#!/usr/bin/env bash
# matugen hook: apply the KDE/Qt color scheme. plasma-apply-colorscheme skips
# a scheme that is already active even when its file changed, so it switches
# between two copies with different names.
dir="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"
src="$dir/SomeShell.colors"
[[ -f "$src" ]] && command -v plasma-apply-colorscheme >/dev/null || exit 0
current="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
next=SomeShellA
[[ "$current" == SomeShellA ]] && next=SomeShellB
sed "s/^ColorScheme=.*/ColorScheme=$next/; s/^Name=.*/Name=$next/" "$src" >"$dir/$next.colors"
plasma-apply-colorscheme "$next" >/dev/null 2>&1
