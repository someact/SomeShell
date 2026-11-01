# SomeShell

Personal Hyprland desktop for two machines: a desktop (CachyOS, Hyprland 0.56 Lua config, RTX 3060, 1920x1080@100 on DP-1, US/TH keyboard, UGTablet pen) and a laptop (Legion 5, RTX 3060 Mobile, eDP-1 2560x1440@165, touchpad, battery). Detect laptop features at runtime, never assume them.
Called SomeHypr until Phase 12; only `install.sh` (`migrate_legacy`) may use the old name.
Tasks and goals: `docs/plan.md`. Current work: Phase 17, the shell rebuilt from scratch (2026-11-01). The design spec is the Phase 16 mockup (artifact `claude.ai/artifact/ELqVxExVPZRZ3Fs6JKHL5F`): build it screen by screen to match it, never by porting the old UI.
SomeShell Reimagined (`../SomeShell-Reimagined`) is a fork; its `scripts/switch.sh someshell|reimagined` relinks this machine between the two.

## The old shell (v1)
- Archived as tag `archive/shell-v1` (Phases 0–16). A detached worktree of it, `../SomeShell-v1`, is what `~/.config/quickshell/someshell` points to, so this machine keeps a working shell until the new one takes over. Never edit or commit in that worktree.
- Read v1 for system knowledge (how a service talks to PipeWire, NetworkManager, UPower, Bluetooth, warp-cli, cliphist, wf-recorder, PAM, SomeLauncher's socket…) and rewrite what the new shell needs. Do not copy its views, components or theme: that is what the rebuild replaces.
- `git show archive/shell-v1:shell/<path>` reads a file; the v1 README lists its features (the parity list for the rebuild).
- `hypr/scripts/fuzzel-emoji.sh` reads `emoji.tsv` from the linked shell until the new shell has `lib/emoji.tsv` (`scripts/emoji-data.sh` writes it).

## Layout
- `hypr/` → `~/.config/hypr`. `hyprland.lua` loads files in a fixed order; each setting lives in exactly one file.
  - `user.lua`: user choices (apps, `glass`, `fastGlass`, `liquidGlass*`, `gameModeAuto`). The settings app overrides them via `~/.config/someshell/hypr.json` (`SETTINGS`, `lib/util.lua` + `lib/json.lua`); `core/settings.lua` loads last and applies its `hyprland` table (partial `hl.config`, changed values only).
  - `core/`: env (GPU vendors from `/sys/class/drm/card*/device/vendor`, NVIDIA env only when NVIDIA is the only GPU), input (touchpad, tablet, gestures; `touchpad.gestures` turns them off), look, motion, misc, execs. `rules/`: window and layer rules.
  - `binds/keybinds.lua` holds every bind. Shell binds use `shell_bind()` / `SHELL_ACTIONS` (`binds/shell.lua`): a `someshell:` global shortcut, with a CLI fallback only while the shell does not answer. `binds/user.lua` applies `~/.config/someshell/keybinds.json` (remap/disable by normalized combo, then custom binds and the `someshell-record` submap). User changes never go into keybinds.lua.
  - `core/liquidglass.lua`: optional hyprglass plugin, built by `scripts/hyprglass.sh` (one `.so` per Hyprland version in `~/.local/share/someshell/plugins/`). Call `hl.plugin.load()` on every config load while wanted, never "only if not loaded" (unload/reload loop → segfault). Test plugin changes in a nested `Hyprland -c <test.lua>`.
  - `modes/gamemode.lua`: blur, shadows, animations off while a game is the focused fullscreen window (`hyprctl eval 'GameMode.toggle()'` / `'GameMode.auto()'`).
  - `generated/` is machine-written and gitignored (matugen, `monitors.lua` from the Displays page). A catch-all `hl.monitor` (`highrr`) covers unnamed outputs.
  - `scripts/shell.sh` starts the shell (`qs -c someshell`; pins EGL to NVIDIA only when NVIDIA is the only GPU, never in a `//@ pragma Env`).
- `matugen/` → `~/.config/matugen`, the only color engine. `config.toml` lists every output; `hooks/` reload apps (`zen-colors.sh` writes every Zen profile with `chrome/`). Without a terminal run it only with `--source-color-index 0`. Default scheme `scheme-smart` (monochrome for a gray wallpaper).
- `shell/` → `~/.config/quickshell/someshell` once the new shell takes over (until then the link goes to v1). The new shell's own layout is written here as it is built.
- `fontconfig/60-someshell-mitr.conf`: fixes Mitr's face names for Qt. `sddm/`: login theme (`scripts/sddm-theme.sh`). `tools/quickshare`: Rust Quick Share helper (GPL-3.0+, `scripts/quickshare.sh`).
- `install.sh`: installer for any Arch PC (packages, fonts, ydotool, i2c, links with `*.pre-someshell` backups, migration, `generated/monitors.lua`, reload with rollback, starts the shell). `--update`, `--detect`, `--check`, `--rollback`. Questions default to no without a terminal: test with `./install.sh </dev/null` or a throwaway `XDG_CONFIG_HOME` with `env -u HYPRLAND_INSTANCE_SIGNATURE`.

## Quickshell and Qt gotchas (learned on v1)
- Focus: a layer with `Exclusive` focus keeps it, so a `HyprlandFocusGrab` never clears on an outside click; switch to `OnDemand` once the grab is active.
- Blur: compositor blur (`BackgroundEffect`) only. An empty `blurRegion` blurs the whole surface; set it to `null` when the shape is off-surface. Wayland regions have stepped corners, so keep a region 1 px inside a rounded shape.
- Config files: ignore file changes for a moment after the shell's own write, else several writes in one handler get lost.
- QML: a property named `onX` parses as a signal handler (use `fgX`-style names). Bindings are stale inside a change handler; read the source property. `Timer.restart()`/`start()` replaces a `running:` binding for good.
- Animation: `SpringAnimation`/`Spring` only in a `Behavior` or `on <prop>`; inside `Sequential`/`ParallelAnimation` Qt segfaults (use `NumberAnimation`).
- AnimatedImage: never `cache: false` on a network URL (Qt 6.12 stack overflow); download with curl and play local files.
- Fonts: the UI font is Mitr (static files in `~/.local/share/fonts/someshell`). Qt maps every numeric weight 300–600 of it to SemiBold, so pick faces with `font.styleName` (Light, Regular, Medium, SemiBold), never `font.weight`; rebuild names with `fc-cache -f`. Mitr digits are proportional (no `tnum`). Each distinct `font.variableAxes` value opens another face: snap icon axes to a few values, never animate an axis.
- Shapes: QtQuick.Shapes, never Canvas. Images: show a screen-sized copy of a big wallpaper (Qt keeps a large decode in memory).
- IPC function names must not be `show`, `call` or `prop` (clash with `qs ipc` subcommands).
- Hot reload can silently stop applying edits after many quick changes, and new fonts need a restart: `qs kill -c someshell`, then `hyprctl eval 'hl.exec_cmd("<repo>/hypr/scripts/shell.sh")'` (`hyprctl dispatch exec` does nothing under the Lua config). After a crash the shell restarts as `quickshell`, not `qs` (`qs list --all`, `qs kill`). Never `pkill -f` a pattern that is in your own command.
- Memory: compare with a fresh start, read `Anonymous`/`Pss` in `/proc/<pid>/smaps_rollup`; an empty one-window Quickshell is already ~250 MB RSS / ~55 MB anon here.
- Pointer tests: move the cursor with `ydotool mousemove -x <dx> -y <dy>` (`YDOTOOL_SOCKET=$XDG_RUNTIME_DIR/.ydotool_socket`), not a Hyprland cursor warp: a warp sends no leave event. Screenshots: `grim -o DP-1`.

## Hyprland Lua API
- Authoritative stub: `/usr/share/hypr/stubs/hl.meta.lua`; example `/usr/share/hypr/hyprland.lua`.
- Rules take flat effect fields (`hl.window_rule({ match = {...}, no_blur = true })`); unknown fields are errors.
- Springs: `hl.curve(name, { type = "spring", mass, stiffness, dampening })`, used as `spring = name`.
- `--verify-config` runs `config.reloaded` handlers; an `hl.dispatch` there segfaults it (exit 139). A reload resets Lua state without an event, so the shell rereads state on `configreloaded`.
- `hyprctl eval '<lua>'` runs code; `hyprctl repl 'return <expr>'` reads globals.

## Verify every change
```sh
./install.sh --check                     # verify-config on the repo
hyprctl reload && hyprctl configerrors    # must print nothing
hyprctl binds -j | jq length              # 201 with no keybinds.json
timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"    # once the new shell exists
```
Every new screen is checked on the real desktop (screenshot) against the mockup, in dark and light mode, before it is ticked.
Never edit `~/.config/hypr.pre-somehypr`, `~/.config/*.pre-someshell` or `~/.config/quickshell/ii` (the rollback).

## Workflow
- One phase at a time from `docs/plan.md`; tick tasks (`[x]`, `[~]` with a note).
- Commit and push after each verified task, ticked in the same commit: `Phase <n><sub>: <task>`, `git push origin main` (public `someact/SomeShell`). Unrelated changes get their own commit. Mark a phase ✅ in its last commit.
- New tasks asked mid-phase go into the plan first (dated section). Never change an agreed approach without asking.
- `README.md` holds only features and install; update it when a feature, dependency or install step changes.

## Rules for the shell
Lazy-load every panel. Events, not polling. matugen only (no Python, no cava). Compositor blur (`BackgroundEffect`), never QML blur, and only where the design asks for it. Global shortcuts under appid `someshell`. Never hardcode this machine (monitor, GPU, tablet, layouts, absolute paths, names): detect or read from settings.
