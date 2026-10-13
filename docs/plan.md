# SomeShell: plan

The task tracker. `[x]` done, `[~]` done differently (with a note), `[ ]` open. Each task is one commit, `Phase <n><sub>: <task>`.

## Goals

- A smooth, seamless desktop: shape and content move together, Apple-style motion, round edges, real glass.
- Rich but light: no polling, no Python, panels load only while open.
- One island instead of a bar: search, commands, media, quick options, notifications, system and power.
- Everything is set in the settings app, never by editing files.
- Fits daily work: coding, games, art, video, streaming. One config for any Arch PC, desktop or laptop.

## History

Phases 0–11 (Hyprland Lua rewrite, the shell, wallpaper and theming, dock, overview, settings app, capture, game tools, lock screen, widgets, on-screen keyboard, laptop support, installer, SDDM theme) are finished. Their task lists are in git history (`git log -- docs/plan.md`). The project was called SomeHypr until Phase 12.

## Phase 12: SomeShell rename and review fixes

### 12a Housekeeping ✅
- [x] Remote is `https://github.com/someact/SomeShell`
- [x] Full rename to `someshell` (directories, `qs -c someshell`, shortcut appid, layer names, templates)
- [x] `install.sh` migrates from the old name: moves config, state, cache, data and font directories, stops the old shell, relinks dead links, still restores `.pre-somehypr` backups; the SDDM script removes an old theme
- [x] This plan replaces the old one; `idea.md` removed; README holds only features and install; CLAUDE.md updated
- [ ] On the other machine: `git remote set-url origin https://github.com/someact/SomeShell && ./install.sh --update`
- [ ] Vesktop: turn on `someshell.theme.css` (the theme file has a new name)

### 12b Fixes from the code review (2026-10-14)
Most of these only break on a machine that is not the one the code was written on.
- [x] 1. The shell forces the NVIDIA EGL vendor file (`shell.qml`, `settings.qml` pragma), so it cannot start on AMD/Intel or a hybrid laptop. Move it to a launcher that sets it only when NVIDIA is the only GPU — done in `hypr/scripts/shell.sh`; AMD/Intel path untested here
- [ ] 2. Recording defaults to `h264_nvenc`. Default `auto`: NVENC with an NVIDIA GPU, else x264
- [ ] 3. Video wallpaper uses `hwdec=nvdec`. Use `auto-safe`
- [ ] 4. System stats: CPU temperature only from `k10temp`, `nvidia-smi` always started. Add Intel sensors, AMD GPU from sysfs, hide the GPU rows otherwise
- [ ] 5. matugen writes Zen colors into one hardcoded profile. Write them into every Zen profile that has a `chrome/` folder
- [ ] 6. Personal defaults in tracked files (projects folder, dock pins, code editor, translate language, `us,th` layout, tablet output `DP-1`, tracked `hypr/monitors.lua`). Each becomes a setting or is detected; the installer keeps the keyboard layout a machine already uses
- [ ] 7. `install.sh` does not install `ffmpeg`, `libnotify`, `hyprsunset`, `kdialog`, `libqalculate`, `xdg-utils`, which the shell runs
- [ ] 8. `Capture.qml` builds shell strings with paths inside quotes; the OCR command is written twice; the fallback scripts use fixed `/tmp` file names
- [ ] 9. The location lookup for weather and sun times uses plain http
- [ ] 10. `HYPR_DIR`, `record.sh` and the Appearance page ignore `XDG_CONFIG_HOME`
- [ ] 11. To verify first: the first run writes `config.json` and `wallpaper.json` right after a detached `mkdir -p`; game mode forced on followed by `hyprctl reload` may leave the shell showing a stale state
- [ ] 12. Small: a failed `grim` says nothing; night light shows "on" when `hyprsunset` is missing

## Phase 13: Features

### 13a Cloudflare WARP
- [ ] `services/Warp.qml`: available only when `warp-cli` is installed; state from `warp-cli -l -j status` (an event stream, no polling)
- [ ] Quick tile: click connects or disconnects, the subtitle shows state and mode
- [ ] Right-click: a detail page with the modes (`warp`, `doh`, `warp+doh`, `dot`, `warp+dot`, `proxy`, `tunnel_only`), and a hint when the client is not registered
- [ ] Status pill icon while connected

### 13b Quick option sizes
Each tile is already full (icon, title, state) or icon only (pencil, then the badge at the tile's corner).
- [ ] Third size `medium`: icon and title, two of the eight units, so four fit in a row
- [ ] The edit badge cycles icon → medium → full; right-click in edit mode lists the three sizes
- [ ] The grid button cycles all tiles through the three sizes

### 13c Island: two contents at once
- [ ] The collapsed island shows a main content and a side slot
- [ ] Microphone / screen share and the recording timer move to the side slot while media, a notification or the OSD is the main content; alone they stay the main content
- [ ] One switch in Settings → Island
- [ ] Check under game mode and under a fullscreen window (animations pause)

## Phase 14: Public release

Carried over from Phase 11. The repo is already public.
- [ ] LICENSE at the repo root (the vendored shapes are Apache-2.0, the SDDM theme has its own)
- [ ] Screenshots in the README
- [ ] Install test on a clean user or a VM, and a rollback test
- [ ] Hands-on checks still open: lock and unlock after suspend, idle lock, dock peek over a window, region tools by mouse, the game overlay over a real game, streamer mode during a share, a day with the time-of-day schedule
- [ ] Bench (`hypr/scripts/bench.sh`, fresh and `--cycle 3`) against the Phase 11 numbers
- [ ] Thai OCR needs `tesseract-data-tha`: offer the language packs of the system locale in the installer

## Later: code quality

- [ ] `island/Island.qml`: the view and ambient `switch` blocks plus 13 `Component` declarations become one table
- [ ] `services/QuickTiles.qml`: `ids` and `byId` are two lists kept in sync by hand
- [ ] The pulsing red dot is written twice (`AmbientPrivacy`, `AmbientRecord`); 13c makes it one component
- [ ] The translate language list is in three files (`TranslateView`, `TranslateCard`, `CapturePage`)
- [ ] `scripts/check.sh`: the CLAUDE.md checks plus shellcheck in one command
- [ ] `services/Brightness.qml` takes the first backlight device by name; `services/Lock.qml` sizes the blurred backdrop from the first screen only
- [ ] `hypr/scripts/fuzzel-emoji.sh` is 1,950 lines of data inside a script

## Verification

Every change: `./install.sh --check`, `hyprctl reload && hyprctl configerrors` (empty), `hyprctl binds -j | jq length` (201), `timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"`. CLAUDE.md has the IPC calls for each part of the shell. A fix that cannot be tested on this hardware is noted as untested instead of ticked.
