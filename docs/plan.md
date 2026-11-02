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
- [x] Global shortcuts (all names in keybinds.lua; unbuilt ones say which step brings them) and IPC (`island`, `wallpaper`, `theme`)

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
  - [x] Wi-Fi join: enterprise (802.1X, PEAP + MSCHAPv2) joined @NU-WiFi with the user's login through the Internet page (2026-11-02). Join, Edit and failure path built in `394e01b`; a failed new network leaves no profile (tested with a missing SSID)
  - [x] Right-click no longer forgets a saved network at once (the user lost @NU-WiFi that way): Edit and Forget buttons
  - [ ] Wi-Fi join with a home (WPA personal) password (later, away from college). The wrong-password message itself was seen: a mistyped join showed "Could not connect: wrong password or username" and left no profile
  - [x] DNS edit: 1.1.1.1 1.0.0.1 applied from the page, back to automatic from the page (`nmcli` save and reconnect now run in order). The college network blocks outside DNS: with 1.1.1.1 no name resolved, so a wrong DNS can cut the internet (idea: undo a DNS change that resolves nothing)
  - [x] Backlight brightness (`ktz8866-backlight`, through logind): click, drag, brightness key and a change from another tool all show on the tile (keys now go through the service, the backlight is reread when Control opens, `410563d`)
  - [x] Battery: tray, alerts (simulated 15% and 8%)
  - [x] Power key (user: an accidental press shut the tablet down): logind's power-key block for the session; the key locks and turns the screen off, again turns it on. `lock.sh` never locked (`qs ipc call` exits 0 for a missing target); it now checks the target, else hyprlock. Tested with the real key (user), `6a06364`
  - [x] Level on the island (user: volume keys showed nothing; decision in `SomeShell.md`): volume, mute, mic and brightness keys go through the shell and show one row (icon, label, bars, rolling percent) for 1.6 s; muted dims it. Volume steps 5%, up unmutes. Tested by IPC and virtual keys, dark and light
  - [ ] SDDM (step 7)
- [ ] Blender on the tablet (later, when working on the PC): no aarch64 package (Arch Linux ARM has none, Flathub is x86_64 only); the GPU is enough for light work (OpenGL 4.6 freedreno, Vulkan 1.3 Turnip; Cycles CPU only). Build from source, or check whether blender.org has Linux ARM64 builds

## Step 5: Media data, calendar, system
- [x] System page (decision in `SomeShell.md`): CPU, Memory, GPU, Network, Disk, Battery as label, rolling number, a minute's thin line (Disk and Battery: a bar), one line of detail. `lib/sysmon.sh` samples once a second only while the page is open (sensors found once; no `sleep` or command substitution per sample: ~0.9% of one core on the tablet, was 1.9%). GPU: NVIDIA (one `nvidia-smi -l 1`), AMD busy file, else the devfreq clock (Adreno: shown as "GPU clock"). Battery power from UPower or the battery's own current x voltage (UPower says 0 W on the tablet). The tray's battery opens the page. Tested on the tablet, dark and light
- [ ] System page on the PC: NVIDIA load and temperature, coretemp/k10temp, Ethernet traffic, no battery column
- [x] Calendar page (decision in `SomeShell.md`): printed month grid (Sunday first, `calendar.weekStart`), today circled, chosen day filled, a dot under days with events; the chosen day's events beside it (all day first, time, place). Events from calendar links (`calendar.feeds` in `shell.json`, downloaded by `lib/calendar.sh` when the page opens and the copy is 15 min old; a failed link keeps the copy and the page says "Offline") and `.ics` files in `~/.config/someshell/calendar/`. `lib/ics.js` expands repeats (daily/weekly/monthly/yearly, interval, count, until, BYDAY incl. "-1FR", BYMONTHDAY, EXDATE, moved occurrences); tested with node and on the tablet with Google's public Thai holiday calendar (322 events, Thai titles). ‹ › and the wheel change the month
- [x] Browser extension (decision in `SomeShell.md`): `browser/extension` (Manifest V2, every site through mediaSession; YouTube Music: 1200 px cover, like state and like command; YouTube: the full-size thumbnail, checked), the Rust helper `browser/host` (native messaging ↔ the shell's socket; finds the shell again after a restart through inotify, no polling) and `browser/install.sh`. The shell matches a tab to the browser's MPRIS player by title; its cover, site and kind win. Tested in Zen on the tablet with YouTube Music and YouTube (user), unsigned install. Like button not tried yet
- [x] Music on the island (decision in `SomeShell.md`): resting cover is a circle with the track's progress as a ring (`CoverRing`); the peek shows elapsed, a progress line (click seeks) and the length. The position ticks once a second only while something plays and a view shows it (`PositionWatch`). Tested with a silent VLC track (ring at 25%, peek), dark and light
- [x] Lyrics (decision in `SomeShell.md`): `lib/lyrics.sh` searches LRCLIB by title and artist, takes the match within 3 s of the length (synced first), one retry when LRCLIB is busy (it answers 503 now and then), caches found lyrics for good and misses for a day. `Lyrics` service only while a media page is open, music only; titles cleaned. Synced lines beside the player (current bright a third down, edges fade), timed to each line's start. Tested with a silent VLC track tagged Coldplay "Yellow" (49 synced lines, lines change on time), dark and light. VLC sends a wrong first length for some files and never corrects it to listeners (a low-bitrate test file showed 135 s for 269 s), so no lyrics match there
- [x] Track time fixes (user: "time duration when skip or drag, it really bug and not real time"). Seeking shows at once (reports far from the target are skipped for 1.5 s: Zen sends the old position while a new track loads); a new track resets to 0:00; the position ticks on the track's own whole seconds (shown = floor, was rounded and up to a second late); the media bar seeks once on release and shows the drag meanwhile (`BarSlider.live: false`); ±10 s use the live position. Length: Zen drops `mpris:length` after a seek and Quickshell then reports about the position as the length (30, 53 for a 214 s song), and a seek was clamped to it (or to 0 right after a skip): the extension's duration (media element) comes first, the player's only when `lengthSupported`. Tested on Zen with YouTube Music: shell and outside seeks, pause and resume, skip then seek, a mouse drag
- [x] Lyrics off for one song (decision in `SomeShell.md`): a lyrics button in the music controls whenever lyrics were found; lit while shown, a click hides them for that song (title and artist, `lyrics-off.json`) and the page narrows, a click again brings them back. `ipc call media lyrics` toggles. Tested: off by IPC, kept over a shell restart, back on by a mouse click (ydotool)
- [x] Clipboard page (user, decision in `SomeShell.md`): Super+V opens its own tabless island page (`Ui.extraPages`), `/clip` left search. Filter, list, full preview (text or picture), Enter copies, Delete removes. Tested on the tablet by real keys: open/close with Super+V, filter, Delete, Enter, Tab back to the tabs, dark and light

## Capture (pulled forward from step 8, user 2026-11-02)
- [x] Picker and screenshot (decision in `SomeShell.md`): `lib/capture.sh freeze` takes every monitor at once (`grim` PPM, ~0.15 s on the tablet) and lists the windows on shown workspaces; `capture/Picker.qml` (one Overlay layer per monitor, only while picking) shows the frozen picture dimmed: hover lights a window, click takes it, drag draws a box with its size, Enter the whole monitor, Esc or right click cancels. Cut from the frozen picture at full size, saved to `~/Pictures/Screenshots` and copied; the island alerts with a preview, a click opens the file. Super+Shift+S, the Control tile (closes the island first) and `ipc call capture`. Tested on the tablet: drag, window (2848x1688 = its 1424x844 at scale 2), Enter (2880x1800), Esc, the open-island path, alert click (opens in Brave, the tablet's default image app)
- [x] Copy text (Super+Shift+X): Tesseract English + Thai on the box (enlarged when small, dark boxes flipped), `preserve_interword_spaces` so Thai words stay joined, loose one- or two-letter Thai bits on lines with Latin letters dropped (English misread as Thai). The text is copied, the island shows its start and line count; "No text found" copies nothing
- [ ] On the PC: two monitors (a box per monitor, the picker on both), NVIDIA
- [ ] Later: Lens, translate, region recording, editing a shot

## Later steps
- Step 6: edit desktop (grid editor without motion while editing, widgets, presets, workspace designs, control layout editing)
- Step 7: lock screen, overview, dock, settings window, installer. Overview must: click a window → switch to its workspace, focus that window, close; Enter on a workspace → switch and close; tested by mouse with ydotool
- Step 8: GIFs, Quick Share, WARP, capture tools, game overlay, on-screen keyboard

## Where each part can be built
The tablet (one screen, battery, Wi-Fi, backlight, ARM, 8 GB) and the PC (two monitors, DDC, NVIDIA, Ethernet, games, pen) test different things. Build on either; check the "PC" or "tablet" parts on that machine before ticking.
- Tablet is fine for: step 5 (calendar page, system page with battery detail, music data and lyrics, browser extension in Zen), step 6 on one screen (grid editor, widgets, presets, workspace designs, control layout editing), step 7 lock screen and SDDM (the tablet is the SDDM test machine), overview, dock, settings window, the ARM half of the installer, step 8 on-screen keyboard (the tablet has a touch screen), GIFs, capture tools, Quick Share. Small items: shrink the top window (memory), undo a DNS change that resolves nothing, `shell.sh` killing leftover shells before a start
- PC only: Blender pan/rotate after Super+number, removing the v1 worktree, battery hidden and Ethernet icon, memory numbers to compare, DDC brightness, two monitors (island follows the mouse, a badge per monitor, presets per monitor), NVIDIA environment, game mode and the game overlay with real games, UGTablet pen, the x86 half of the installer
- Laptop: touchpad gestures, hybrid graphics, 165 Hz panel
- Unsure on ARM until tried: WARP (`warp-cli` for aarch64)

## Notes
- Hypridle times and the tablet area: the UGTablet trim lived in v1's config; in the new one devices come from `hypr.json` (`devices`), added to this machine's file at the switch.
