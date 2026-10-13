# SomeShell SDDM theme

A standalone Qt 6 port of `shell/lock/LockSurface.qml`: the large clock and date,
blurred wallpaper, glass password pill, shuffled Material password shapes,
animated entry and failure feedback. The avatar has an initial fallback. The
login screen adds editable user selection, desktop sessions, Caps Lock and
keyboard layouts, and suspend/restart/shutdown controls. Restart and shutdown
require a second click within four seconds.

Authentication and session startup go through SDDM's own `login()` API. The
theme does not read your shell state, run Quickshell, or access a user-session
D-Bus service before login. Media and notifications belong to the logged-in
session and are therefore absent here.

From the repository root:

```sh
./scripts/sddm-theme.sh --preview   # no login or power actions; close with Alt+F4
./scripts/sddm-theme.sh --install   # asks sudo; takes effect at the next login
./scripts/sddm-theme.sh --rollback  # restore the previous SDDM selection
```

Run the script as your desktop user, including `--install`; it escalates only
for the system copy. It does not restart SDDM or end your session. Requirements
are SDDM with its Qt 6 greeter, QtQuick Controls and Effects, Qt SVG, jq,
ImageMagick and fontconfig. On Arch/CachyOS, the relevant packages are `sddm`,
`qt6-declarative`, `qt6-svg`, `jq`, `imagemagick` and `fontconfig`.

The script snapshots your current wallpaper (or a video wallpaper's saved
frame) into a blurred image and copies Google Sans Flex and Material Symbols
when available. Those files live under `/usr/share/sddm/themes/someshell`, so the
greeter does not depend on a readable home directory. Running `--install`
again refreshes the wallpaper and fonts. Personal images and fonts are not
committed to the repository. Without a wallpaper, the bundled background is
used.

The script stages previews at `~/.cache/someshell/sddm/preview` and writes the
installed theme selection to `/etc/sddm.conf.d/zz-someshell.conf`. It saves any
previous contents of that drop-in, and rollback restores them (or removes the
drop-in when none existed). Existing themes are kept.

Customize `/usr/share/sddm/themes/someshell/theme.conf.user` after installation:

```ini
[General]
Background=assets/background.jpg
ClockFormat=HH:mm
ReducedMotion=false
PreviewMode=false
```

`PreviewMode=true` simulates an authentication failure and disables power
actions so the preview stays usable. The installer always writes it as `false`
for the real login screen. Password shapes cap their visible count at 16;
longer passwords still reach SDDM in full.

The implementation uses [SDDM's theme API](https://github.com/sddm/sddm/blob/v0.21.0/docs/THEMING.md).
The theme code is MIT licensed. Material password outlines and Material
Symbols are Apache-2.0; their licenses are included. Copied Google Sans Flex
fonts keep their local font license.
