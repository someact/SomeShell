# SomeShell rebuild: plan

Task tracker for the rebuild. The design and every decision are in `SomeShell.md`; this file only tracks work.
`[x]` done, `[~]` done differently (with a note), `[ ]` open. One commit per finished task: `Step <n>: <task>`.
Commits stay local until **base** (steps 1–4) is done; then everything is pushed and the new version replaces v1 on this machine.

## Step 1: Hyprland config, fresh
Written new in `hypr/`; v1 stays live (`~/.config/hypr` → `../SomeShell-v1`) until base is done, so the new config is checked with `Hyprland --verify-config` and in a nested Hyprland, not by switching.
- [x] Entry file with a fixed load order; helpers (paths, optional files, settings from `~/.config/someshell/hypr.json`, a small JSON reader)
- [x] Environment (GPU detection), input (layouts from settings, touchpad, gestures), look (rounded like the island, thin border in the wallpaper color, small gaps, no dim), motion (springs), misc
- [x] Window, app, game and layer rules
- [x] Keybinds: the same keys as v1; shell actions as `someshell:` global shortcuts with a fallback while the shell is down; workspaces 1–10 per monitor. Number keys bind by key code only (any layout, one action per press)
- [x] Super tap in Hyprland: opens the island only when Super is pressed and released alone within 450 ms; Super press and release still reach apps (Blender)
- [x] Game mode (effects off while a game is the focused fullscreen window)
- [x] Autostart (skipped with `SOMESHELL_NO_AUTOSTART=1`), hypridle (lock 10 min, screen off 15 min, sleep 30 min), hyprlock backup lock, `scripts/shell.sh`, `scripts/lock.sh`
- [x] Verified 2026-11-02: `--verify-config` clean (it does report unknown keys and rule fields); a nested Hyprland loads it with no config errors, 165 binds (v1 had 201: it bound every number key twice), Super binds non-consuming, layouts `us,th` read from `hypr.json`

Old bugs (section 6 of `SomeShell.md`):
- [~] Super+2 opening the island and stealing focus: tested on v1 (2026-11-02), Hyprland does not send the Super release after a combo, so not the cause
- [x] Blender (user, 2026-11-02): after Super+number into Blender, clicks work but middle-mouse pan/rotate do not until Blender is clicked again. Cause: v1 swallowed the Super release, so Blender still thought Super was held. The new Super binds are non-consuming. Confirm in Blender after the switch
- [x] Focus lost after Super+number (user: the mouse rests on a window that does not get focus). Cause: Hyprland gives back the workspace's last focused window. `modes/focus.lua` focuses the window under the mouse after every workspace change, without moving the mouse. Reproduced and fixed live on v1 (2026-11-02): mouse over Kitty / Obsidian / Dolphin each got focus, a gap kept Hyprland's choice
- [ ] Super+Tab (user): in v1's overview a window can't be clicked to switch to its workspace. Overview is shell work, see step 7

## Step 2: Shell skeleton
- [x] matugen config (relative template paths, run with `-c`) and the core templates: the shell palette (every role in dark and light, `~/.local/state/someshell/palette.json`), Hyprland borders and background, hyprlock
- [ ] App templates: GTK 3/4, KDE, Kitty and other terminals, Zen, Vesktop, Fuzzel (last in step 2: they recolor live apps, so they are written only when the switch is near)
- [x] Shell entry, theme from the palette (desktop colors follow the mode; the island uses the ink set: always dark, or the opposite of the desktop), Mitr faces, motion parts (resize spring, rolling digits, press invert, fade-in on open)
- [x] Wallpaper layer (decoded at screen size, crossfade), state `wall.json` (first start takes v1's wallpaper), matugen on wallpaper, mode and scheme changes, IPC
- [~] Island window: rest, alert over everything, peek on hover, open (tabs on top, each page sets the size), quiet line in game mode or fullscreen; size from content with a spring; follows the mouse while closed; shapes ears, tab, float. Live items (music, recording, several at once) come with their services in step 4
- [~] Keyboard focus: none at rest, OnDemand while open (keys stay with the island even when the mouse moves over windows), Esc and Tab work, a hover-opened island closes 450 ms after the mouse leaves, a click outside closes it. Exception: a click on a window border or in the gap between windows does not count (Hyprland takes it for resizing); tested by mouse with ydotool 2026-11-02
- [x] Workspace badge per monitor (slot number, scroll to switch), tray tab with the keyboard layout (tray icons untested: no tray apps were running)
- [x] Global shortcuts (all 23 names in keybinds.lua; unbuilt ones say which step brings them) and IPC (`island`, `wallpaper`, `theme`)

## Step 3: Search and power
- [x] Apps (name, generic name and keywords; letters-in-order matches; apps you open often and recently rank first, `launches.json`; an empty search lists only apps you have opened), math parser `lib/calc.js` (no eval, 18 cases tested with node), web search fallback (Google). The page is as tall as its results
- [x] Commands: `/clip` (Super+V; text and images, image thumbnails decoded once), `/emoji` (Super+.; list from `scripts/emoji-data.sh`, recent first), `/wall` (Ctrl+Super+T; thumbnails made once with ImageMagick, each shown as soon as it exists; Ctrl+Super+Alt+T picks a random one), `/settings` (says step 7). At start the shell recolors when the palette was made from another wallpaper
- [~] Power page: lock, sleep, log out, restart, shut down; hold 0.8 s to confirm (fills like ink inside the rounded shape), letting go early cancels; tested with `SOMESHELL_DRY_POWER=1`. Lock goes through `loginctl lock-session` → `scripts/lock.sh`, which falls back to hyprlock until the shell has its own lock screen (step 7)

## Step 4: Control, media, notifications
- [ ] Control tiles in a fixed layout: Internet, Bluetooth, Sound, Brightness, Night light, Do not disturb, Keep awake, Game mode, Screenshot, Record
- [ ] Detail pages: Wi-Fi (password, DNS), Bluetooth (pair, rename), Sound (outputs, mixer), Night light
- [ ] Media through MPRIS: music and video layouts
- [ ] Notification server, alerts, history

**Base done → push, switch this machine to the new version, remove the v1 worktree.**

## Later steps
- Step 5: browser extension, music layout data, lyrics; calendar and system pages
- Step 6: edit desktop (grid editor without motion while editing, widgets, presets, workspace designs, control layout editing)
- Step 7: lock screen, overview, dock, settings window, installer. Overview must: click a window → switch to its workspace, focus that window, close; Enter on a workspace → switch and close; tested by mouse with ydotool
- Step 8: GIFs, Quick Share, WARP, capture tools, game overlay, on-screen keyboard

## Notes
- Hypridle times and the tablet area: the UGTablet trim lived in v1's config; in the new one devices come from `hypr.json` (`devices`), added to this machine's file at the switch.
