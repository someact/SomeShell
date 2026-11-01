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

The design is in `docs/themes.md` (look = a theme folder; views use only primitives and roles; pop from SomeShell Reimagined and fresco from SomeRenaiShell come back as themes). Paused for Phase 16: the new front-end is built on primitives and roles from its first file, so 15b–15d (moving the old views onto primitives) are no longer needed. What stays for later, on the new front-end:
- [ ] Theme switching (relink + reload or a Loader per primitive; bench both), picker in Settings, `themes/<name>/hypr.lua`, fonts from `meta.json`, IPC `theme set · list · state`
- [ ] Pop theme from Reimagined; fresco theme from SomeRenaiShell

## Phase 16: New front-end (added 2026-11-01)

Today's front-end is heavy (compositor blur on every surface) and its look is spread over ~100 files. A new front-end is built beside it, flat with motion, on the same engine (services, IPC, Hyprland config). It runs as its own Quickshell config next to `shell/` until it covers everything, then replaces it. Ideas from the user: `Improvement idea.md` (2026-11-01).

### 16a Design first
- [ ] Interactive mockup page (artifact): the look (flat surfaces from promptjang.com: slate neutrals, one accent, pill and medium radii, Prompt/Mitr type), the motion language, and the main screens
- [ ] Decide with the user: where glass or blends stay, accent from the wallpaper or a fixed one, the island's idle "personality"
- [ ] Write the design down (tokens, roles, motion rules) as the source for 16b

### 16b Foundation
- [ ] New config beside `shell/` (`qs -c someshell-next`, switch with `scripts/switch.sh`-style relink), sharing `services/` and the core singletons
- [ ] Tokens and roles (colors from matugen, radii, type, durations, one ease-out curve) and the primitives (Surface, Button, IconButton, Tile, Toggle, Slider, Progress, Label, Icon, Selection), with motion built in: hover lift, press squeeze, open morph from the source, one pulse on state change
- [ ] Style check: only the theme folder may set colors, radii and fonts
- [ ] Bench against today's shell (memory, GPU while idle and while animating)

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

### 16h Switch over
- [ ] Every view of `shell/` exists in the new front-end; it becomes `shell/`, the old one goes to git history
- [ ] README and CLAUDE.md updated

## Later: code quality

- [ ] The translate language list is in three files (`TranslateView`, `TranslateCard`, `CapturePage`)
- [ ] `scripts/check.sh`: the CLAUDE.md checks plus shellcheck in one command
- [ ] `services/Brightness.qml` takes the first backlight by name; `services/Lock.qml` sizes the backdrop from the first screen only
- [ ] Saved screenshots are named with `date`, which follows the locale calendar (year 2569 under `th_TH`); recordings use Qt and say 2026

## Verification

Every change: `./install.sh --check`, `hyprctl reload && hyprctl configerrors` (empty), `hyprctl binds -j | jq length` (201), `timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"`. CLAUDE.md lists the IPC calls per part. A fix that cannot be tested on this hardware is noted as untested instead of ticked.
