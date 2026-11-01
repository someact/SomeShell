# SomeShell: plan

The task tracker. `[x]` done, `[~]` done differently (with a note), `[ ]` open. Each task is one commit, `Phase <n><sub>: <task>`. Finished task lists live in git history (`git log -- docs/plan.md`).

## Goals

- One island instead of a bar: search, commands, media, quick options, notifications, system and power.
- Flat and alive (2026-11-01): flat color surfaces with motion on every interaction (like promptjang.com); glass and color blends only in a few chosen places.
- Light: no polling, no Python, panels load only while open, blur only where it earns its cost.
- Colors follow the wallpaper (matugen), so every look fits every wallpaper. Font: Mitr.
- Everything is set in the settings app, never by editing files.
- Fits daily work: coding, games, art, video, streaming. One config for any Arch PC, desktop or laptop.

## History

- Phases 0–11: Hyprland Lua rewrite, the shell, wallpaper and theming, dock, overview, settings app, capture, game tools, lock screen, widgets, on-screen keyboard, laptop support, installer, SDDM theme.
- Phase 12 (2026-10-14): rename SomeHypr → SomeShell; fixes from the code review.
- Phase 13: WARP, quick option sizes, two contents on the island, emoji picker, clipboard previews, Quick Share, GIF search, drop shelf, SomeLauncher client.
- Phase 15 (themes) was paused, Phase 16 (flat redesign done in place) was dropped on 2026-11-01: the user found the restyled old shell "not as expected" and asked for a rebuild from scratch. Its mockup stays the design.
- The whole v1 shell is archived as tag `archive/shell-v1` (2026-11-01).

## Phase 17: Rebuild from scratch (added 2026-11-01)

A new shell in `shell/`, designed fresh from the mockup (`claude.ai/artifact/ELqVxExVPZRZ3Fs6JKHL5F`). v1 keeps running from the `../SomeShell-v1` worktree until the new shell takes over. Kept from v1 outside the shell: `hypr/`, `matugen/`, `install.sh`, `sddm/`, `fontconfig/`, `tools/quickshare`. Each screen is shown on the desktop and approved by the user before the next one.

### 17a Clean slate
- [x] v1 archived (tag `archive/shell-v1`, pushed), the machine runs it from a worktree, `shell/` and `docs/themes.md` removed, CLAUDE.md and this plan rewritten

### 17b Foundation
- [ ] How the new shell runs beside v1 while it is built (own config name and IPC, or switch over per screen)
- [ ] Design tokens from the mockup (colors from matugen, slate neutrals, one accent; Mitr faces; radii 8/16/pill; durations 200/400/700 ms; ease-out and spring)
- [ ] Motion primitives: hover lift, press squeeze, open morph, state pulse

### 17c Island
- [ ] Idle, peek, notify, open and game-doze states, matched to the mockup

### Next, in an order the user picks
- Corners and workspaces, dock, quick options and mixer, media (music layout and browser extension), notifications, search and commands, wallpaper and phone-style widget editing, lock screen, overview, overlay, on-screen keyboard, settings app, capture
- v1 features to bring back or drop are listed in the v1 README (`git show archive/shell-v1:README.md`)

## Phase 14: Public release (after the rebuild)

- [ ] LICENSE at the repo root (SDDM theme its own, `tools/quickshare` GPL-3.0-or-later with the text beside it)
- [ ] Screenshots in the README
- [ ] Install test on a clean user or a VM, and a rollback test
- [ ] Bench against v1 (memory, GPU while idle and while animating)
- [ ] On the other machine: `git remote set-url origin https://github.com/someact/SomeShell && ./install.sh --update`

## Verification

Every change: `./install.sh --check`, `hyprctl reload && hyprctl configerrors` (empty), `hyprctl binds -j | jq length` (201), and for shell work `timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"` plus a screenshot compared with the mockup. A fix that cannot be tested on this hardware is noted as untested instead of ticked.
