# SomeShell: plan

The task tracker. `[x]` done, `[~]` done differently (with a note), `[ ]` open. Each task is one commit, `Phase <n><sub>: <task>`. Finished task lists live in git history (`git log -- docs/plan.md`).

## Goals

- One island instead of a bar: search, commands, media, quick options, notifications, system and power.
- Light: no polling, no Python, panels load only while open, blur only where it earns its cost.
- Flat and alive (2026-11-01): flat color surfaces with motion on every interaction (like promptjang.com); glass and color blends are used on purpose in a few places, not everywhere.
- Colors follow the wallpaper (matugen), so every look fits every wallpaper.
- Everything is set in the settings app, never by editing files.
- Fits daily work: coding, games, art, video, streaming. One config for any Arch PC, desktop or laptop.

## History

- Phases 0–11: Hyprland Lua rewrite, the shell, wallpaper and theming, dock, overview, settings app, capture, game tools, lock screen, widgets, on-screen keyboard, laptop support, installer, SDDM theme.
- Phase 12 (2026-10-14): rename SomeHypr → SomeShell (installer migrates the old name); 12 fixes from the code review, mostly for machines other than this one (EGL launcher, encoder `auto`, `hwdec=auto-safe`, sensors, Zen profiles, personal defaults → settings, installer dependencies, quoting, https, `XDG_CONFIG_HOME`, game mode after reload).
- Phase 13 done parts: 13a Cloudflare WARP, 13b quick option sizes (icon / medium / full), 13c two contents on the island (side slot), 13e emoji picker, 13f clipboard image previews, 13g+ saved GIF library in /gif.

## Open from Phase 12–13

- [ ] 12a On the other machine: `git remote set-url origin https://github.com/someact/SomeShell && ./install.sh --update`
- [ ] 12a Vesktop: turn on `someshell.theme.css`
- 13d Quick Share (sending and receiving with a phone work since 2026-10-14):
  - [ ] Try with a phone: a link, several files, Bluetooth off, decline, cancel half way
  - [ ] If the phone does not see the PC: the helper announces every address (docker, Tailscale), the phone may try a wrong one first
  - [ ] Decide whether the page masks names in streamer mode too
  - [ ] Offer the build in `install.sh` when `cargo` is installed
- 13g GIF search (Klipy works):
  - [ ] Giphy with a real key (only tried against a stand-in and with a wrong key)
- 13h Drop shelf (everything checked through IPC; Zen image drop offers image data, see `lastFormats`):
  - [ ] Real drags: a link and selected text from Zen, a file from Dolphin, the floating style, the drop target, a drag out, the buttons by mouse
- 13i SomeLauncher:
  - [ ] A click on the island or the Games card opens the launcher (needs `qs -c somelauncher`, SomeLauncher Phase 9a)

## Phase 14: Public release

- [ ] LICENSE at the repo root (vendored shapes Apache-2.0, SDDM theme its own, `tools/quickshare` GPL-3.0-or-later with the text beside it)
- [ ] Screenshots in the README
- [ ] Install test on a clean user or a VM, and a rollback test
- [ ] Hands-on: lock after suspend, idle lock, dock peek over a window, region tools by mouse, overlay over a real game, streamer mode during a share, a day of the wallpaper schedule
- [ ] Bench (`hypr/scripts/bench.sh`, fresh and `--cycle 3`) against the Phase 11 numbers
- [ ] Thai OCR: the installer offers `tesseract-data-<lang>` for the system locale

## Phase 15: Themes — paused (2026-11-01)

The design is in `docs/themes.md` (look = a theme folder; views use only primitives and roles; pop from SomeShell Reimagined and fresco from SomeRenaiShell come back as themes). Paused for Phase 16 (the flat redesign). What stays for later:
- [ ] Theme switching (relink + reload or a Loader per primitive; bench both), picker in Settings, `themes/<name>/hypr.lua`, fonts from `meta.json`, IPC `theme set · list · state`
- [ ] Pop theme from Reimagined; fresco theme from SomeRenaiShell

## Phase 16: Flat redesign (added 2026-11-01)

The look moves from frosted glass (compositor blur on every surface, heavy) to flat color with motion on every interaction. Ideas from the user: `Improvement idea.md` (2026-11-01).

Changed 2026-11-01, after the mockup was approved: the redesign is done **in place**, area by area, instead of in a second front-end beside `shell/`. It keeps every working service and view, each step goes live at once, and it reaches "everything redesigned" much sooner. The user asked for: colors that follow the wallpaper, Mitr as the default font (like promptjang.com's headings), icons that suit a flat design.

### 16a Design first ✅
- [x] Interactive mockup page (artifact `claude.ai/artifact/ELqVxExVPZRZ3Fs6JKHL5F`): flat slate surfaces, one accent, pill and medium radii, Mitr type, the motion language (hover lift, press squeeze, open morph, state pulse; 200/400/700 ms, ease-out, spring only for opening shapes), the main screens
- [~] Decisions: approved as shown ("look good"); accent from the wallpaper (matugen); glass off by default, `island.glass` keeps it as an option; the island stays dark in light mode

### 16b Foundation
- [x] Font: Mitr (installer downloads it, `fontconfig/60-someshell-mitr.conf` fixes its names for Qt; faces by `font.styleName`), also on the SDDM theme and hyprlock
- [x] Flat by default: `island.glass` off, surfaces solid (`surfaceContainer`, no rim or highlight), the island a dark slate tinted from the wallpaper
- [x] Icons: Material Symbols Rounded filled everywhere (active state shown by the container, not the fill)
- [x] Motion in the shared parts: PressButton (every button, tile and icon button) lifts 2 px on hover, squeezes on press, pulses one ring when it turns on; tiles are rounded cards that round out into pills when on; island tiles, sliders and switches fill with the wallpaper accent (`accentIsland`)
- [ ] Fixed-width digits for clocks and percentages (Mitr has no tabular figures)
- [ ] Bench against the glass look (memory, GPU while idle and while animating)

### 16c Island and pills
- [ ] Island opens when the pointer reaches the top edge and closes when it leaves; Super and outside clicks keep working
- [ ] Clean edges: no stepped blur rim (flat fill, or blur shaped by alpha where glass stays)
- [ ] Corner pills as floating icons without a background, with an outline or soft shadow, phone-style
- [ ] Workspaces: only the used ones (and the special workspace when it has windows), animated in and out
- [ ] Icons and fonts in the Android/ChromeOS style of end-4's dots-hyprland, adapted to the new look

### 16d Quick options and audio
- [ ] Tiles: icon only or with text, show/hide and reorder in place
- [ ] Right-click opens the tile's own settings (Wi-Fi, Bluetooth, WARP, …)
- [ ] Mixer: right-click on volume opens per-app volume

### 16e Media
- [ ] Browser extension (Zen/Firefox, native messaging to the shell): page URL, full-size cover, lyrics when the site has them; without it, MPRIS as today
- [ ] Music layout for music sites (music.youtube.com first: large cover, lyrics, like, queue); the normal card for other media
- [ ] Auto lyrics in the island and the media widget (can be turned off); per-player volume

### 16f Wallpaper and widgets
- [ ] Phone-style edit mode: zoom the wallpaper out, a widget drawer, a snap grid, wallpaper and schedule in the same screen
- [ ] More widgets: wallpaper, gallery, others to decide

### 16g Overlay and lock
- [ ] Game overlay in the new look, with options for how it looks
- [ ] Translate in the overlay: an area once, or auto (re-read a fixed area every few seconds, show the translation over it)
- [ ] Lock screen: smooth password dots

### 16h Finish
- [ ] Every area checked in dark and light mode; leftover hardcoded colors (`Qt.rgba`, hex) and radii moved to Theme
- [ ] README and CLAUDE.md updated

## Later: code quality

- [ ] The translate language list is in three files (`TranslateView`, `TranslateCard`, `CapturePage`)
- [ ] `scripts/check.sh`: the CLAUDE.md checks plus shellcheck in one command
- [ ] `services/Brightness.qml` takes the first backlight by name; `services/Lock.qml` sizes the backdrop from the first screen only
- [ ] Saved screenshots are named with `date`, which follows the locale calendar (year 2569 under `th_TH`); recordings use Qt and say 2026

## Verification

Every change: `./install.sh --check`, `hyprctl reload && hyprctl configerrors` (empty), `hyprctl binds -j | jq length` (201), `timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"`. CLAUDE.md lists the IPC calls per part. A fix that cannot be tested on this hardware is noted as untested instead of ticked.
