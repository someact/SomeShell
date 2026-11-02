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
- [x] App templates: GTK 3/4, KDE (plasma-apply-colorscheme), Kitty (its include now points at `~/.local/state/someshell/kitty-theme.conf`; it pointed at the pre-rename `somehypr` folder) and other terminals, Zen, Vesktop, Fuzzel (2026-11-02, at the switch)
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
- [x] Control tiles in a fixed layout (4 columns, Sound 2x2 with the volume): Internet, Bluetooth, Sound, Brightness (DDC on desktops, backlight on laptops; detection takes ~15 s at start), Night light (hyprsunset, schedule 20:00-07:00 by default), Do not disturb, Keep awake (systemd idle block), Game mode, Screenshot, Record (wf-recorder, focused monitor). Tested by mouse and IPC 2026-11-02
- [~] Detail pages: Internet (Ethernet, Wi-Fi list with password field, DNS edit through nmcli), Bluetooth (on/off, scan, connect/pair/forget, rename this computer), Sound (outputs, mic, per-app mixer), Night light (warmth, schedule). Untested on this machine: Wi-Fi (no Wi-Fi card) and pairing (no devices); DNS edit not run (it changes the live connection)
- [x] Media through MPRIS: music layout (square cover, big title) and video layout (wide picture), guessed from the player, the page address or an audio file; player chips when several play; seekable progress; live on the resting island (cover and meter) and as a row with controls in the peek. Tested with a silent VLC test track
- [x] Notification server (alerts unless do not disturb; critical ones always), history grouped by app (`notifications.json`, last 100), dismiss, clear all, default action on click. Recording shows on the resting island next to music (several live things at once)

**Base done (2026-11-02): this machine switched to the new version and everything was pushed.** The v1 worktree stays as the rollback until the new one has run for a while (`ln -sfn ../SomeShell-v1/{hypr,matugen,shell}` back, reload, start its shell).

Switch notes:
- [x] Links: `~/.config/hypr`, `matugen`, `quickshell/someshell`, the Mitr fontconfig rule (back in `fontconfig/`, written fresh) point at the repo; hypridle restarted on the new config
- [x] The UGTablet area moved to `~/.config/someshell/hypr.json` (`devices`)
- [x] Super tap fixed for real keys: a release bind sends the global shortcut as "released" only, so `Shortcuts.qml` acts on the release for `island`. Tested with ydotool: tap opens, tap closes, Super+2 and a 0.7 s hold do not, Super+N held 0.6 s opens once
- [ ] Blender: check that pan/rotate keep working after Super+number (the user)
- [ ] Live for a day, then remove the v1 worktree

## Tablet (added 2026-11-02)
An ARM tablet (Snapdragon, Arch Linux ARM) joins as the third machine; keyboard and mouse, touch is not a priority. Setup steps are in CLAUDE.md ("Setting up a machine").
- [x] Note the exact chip and how Arch was installed in CLAUDE.md (Xiaomi Pad 6 8/256, A/B slot dual boot with Android, 128/128)
- [x] Packages on aarch64: Hyprland 0.56+ (Lua config), Quickshell, matugen (build from the AUR or source where Arch Linux ARM has none). All installed; Hyprland is 0.57.0
- [x] Set up, log in, check the base works (island, search, control, media, notifications). Checked 2026-11-02 by IPC, real keys and mouse (ydotool), dark and light; fixes below
  - [x] Pages stayed empty after a switch while open: the page Loader bound both `source` and `sourceComponent` (binding order differs per machine). Fixed, `017dc33`
  - [x] A hover-opened island closed on a page switch: Hyprland sends a leave when the shape changes under a still pointer. The leave timer now asks `hyprctl cursorpos`. Fixed, `648ea04`
  - [x] Peek: the date ran into "Click to open". Fixed, `558a261`
  - [x] Super+Space did nothing: the tablet had no `hypr.json`, so only `us` loaded. Written with `us,th`; setup step added to CLAUDE.md, `8da33e0`
  - [x] Page switch motion (user): slide + wipe, sliding tab underline, size spring without bounce (decision in `SomeShell.md`), `9428b5f`
  - [x] ydotool: user added to `input`, `ydotool.service` enabled (works from the next login)
  - [x] Tray status (user, decision in `SomeShell.md`): layout (click switches), network (signal bars; click opens Internet), Bluetooth (connected icon; click opens Bluetooth), battery (UPower: icon, rolling percentage, error color at 20%); alerts at 20% and 10% once per discharge (10% even with Do not disturb). `ipc call battery simulate <percent> <charging>` for tests. Tested on the tablet by mouse, dark and light. App tray icons (Discord) still untested: none installed
  - [ ] Desktop: battery hidden (no laptop battery), Ethernet icon
  - [x] Search by real keys: apps, math, web fallback, letters-in-order, `/clip` (Thai text), `/emoji` (arrows + Enter copies), `/wall`, `/`. Fixed: ☺-style emoji drew as black text glyphs (emoji cells now use fontconfig's `emoji` font)
  - [x] Control detail pages: Internet, Bluetooth, Sound, Night light. Fixed: the Wi-Fi list showed only the connected network (the Quickshell scanner was never on; now on only while the Internet page shows, `37af1cd`); two Bluetooth devices with one name now show the end of their address
  - [x] Media with VLC (silent test track and video): music and video layouts, peek row, resting island, play/pause and seek by mouse. Fixed: VLC registers twice on D-Bus and showed two player chips
  - [x] Power page with `SOMESHELL_DRY_POWER=1`: a short press cancels, a hold fills and confirms ("Would run: systemctl reboot")
  - [x] Super tap (ydotool): tap opens on Search, tap closes, Super+1/2 only switch, a 0.7 s hold does nothing. Once, right after a restart, a tap seemed to land before the shortcuts were registered (not reproduced; the user was also using the tablet)
  - [x] Memory and idle CPU: fresh 268 MB RSS / 177 MB anon, after every page 286 / 182 (pages unload); idle ~0.4% of one core. Anon is high next to an empty Quickshell (~55 MB on the desktop): likely the layer buffers (Adreno shares system memory; the top window is 80% of a 2880x1800 screen). Desktop numbers still to take for comparison
- [ ] Test what the desktop cannot: Wi-Fi (join, password, DNS), backlight brightness, battery (once the battery part exists), SDDM (step 7)

## Later steps
- Step 5: browser extension, music layout data, lyrics; calendar and system pages
- Step 6: edit desktop (grid editor without motion while editing, widgets, presets, workspace designs, control layout editing)
- Step 7: lock screen, overview, dock, settings window, installer. Overview must: click a window → switch to its workspace, focus that window, close; Enter on a workspace → switch and close; tested by mouse with ydotool
- Step 8: GIFs, Quick Share, WARP, capture tools, game overlay, on-screen keyboard

## Notes
- Hypridle times and the tablet area: the UGTablet trim lived in v1's config; in the new one devices come from `hypr.json` (`devices`), added to this machine's file at the switch.
