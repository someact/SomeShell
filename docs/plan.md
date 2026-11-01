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
- [ ] Blender: v1 consumed the Super press and release (its Super binds had no `non_consuming`), so apps could see Super stuck down. The new binds pass Super through; check in Blender after the switch
- [ ] Focus lost after a workspace change: reproduce with the user after the switch (keys, mouse, overview?)
- [ ] Super+Tab not switching: overview is shell work (step 7); check then

## Step 2: Shell skeleton
- [ ] matugen config and templates (shell, Hyprland, hyprlock, GTK, KDE, terminals, Zen), `scheme-smart`
- [ ] Shell entry, theme from the color file, Mitr faces, motion parts (resize spring, rolling digits, press invert, wipe on open)
- [ ] Wallpaper layer (screen-sized copy), wallpaper state and IPC
- [ ] Island window: rest, live (several at once, smaller), alert over them, peek, open, quiet; size from content; follows the mouse while closed
- [ ] Keyboard focus rules: none at rest, only while open; outside click closes
- [ ] Workspace badge per monitor, tray tab
- [ ] Global shortcuts and IPC for every action the keybinds use

## Step 3: Search and power
- [ ] Apps (fuzzy, recent first), math parser, web fallback
- [ ] Commands: `/clip` (Super+V), `/emoji`, `/wall`, `/settings`
- [ ] Power page with hold to confirm; lock screen hand-off (`scripts/lock.sh`)

## Step 4: Control, media, notifications
- [ ] Control tiles in a fixed layout: Internet, Bluetooth, Sound, Brightness, Night light, Do not disturb, Keep awake, Game mode, Screenshot, Record
- [ ] Detail pages: Wi-Fi (password, DNS), Bluetooth (pair, rename), Sound (outputs, mixer), Night light
- [ ] Media through MPRIS: music and video layouts
- [ ] Notification server, alerts, history

**Base done → push, switch this machine to the new version, remove the v1 worktree.**

## Later steps
- Step 5: browser extension, music layout data, lyrics; calendar and system pages
- Step 6: edit desktop (grid editor without motion while editing, widgets, presets, workspace designs, control layout editing)
- Step 7: lock screen, overview, dock, settings window, installer
- Step 8: GIFs, Quick Share, WARP, capture tools, game overlay, on-screen keyboard

## Notes
- Hypridle times and the tablet area: the UGTablet trim lived in v1's config; in the new one devices come from `hypr.json` (`devices`), added to this machine's file at the switch.
