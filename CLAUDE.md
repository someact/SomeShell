# SomeShell

Personal Hyprland desktop for two machines: a desktop (CachyOS, Hyprland 0.56 Lua config, RTX 3060, one 1920x1080@100 monitor DP-1, US/TH keyboard, UGTablet pen) and a laptop (Lenovo Legion 5, RTX 3060 Mobile, eDP-1 2560x1440@165, touchpad, battery). Laptop features are detected at runtime, never assumed.
The project was called SomeHypr until Phase 12; `install.sh` (`migrate_legacy`) moves the old `somehypr` directories over, and that is the only place the old name may appear.
Goals and the task tracker are in `docs/plan.md`. Phases 0–11 are finished and live in git history only.
Current work: Phase 13 (13a WARP and 13b tile sizes are done; then two contents in the island, Quick Share with Android), then Phase 14 (public release). Phase 12 (rename, fixes from the code review) is done.

## Layout
- `hypr/` is linked to `~/.config/hypr`. `hyprland.lua` loads files in a fixed order, and each setting lives in exactly one file:
  - `user.lua` holds user choices: apps, `glass`, `fastGlass`, `liquidGlass*`, `gameModeAuto`. The settings app overrides them through `~/.config/someshell/hypr.json` (`SETTINGS`, loaded by `lib/util.lua` with `lib/json.lua`); `core/settings.lua` loads last and applies its `hyprland` table (a partial `hl.config`). The file only holds changed values.
  - `core/` covers env (GPU detected), input (touchpad, tablet), look, motion, misc, and execs.
  - `rules/` holds window rules (windows, media, art, gaming) and layer rules.
  - `binds/keybinds.lua` holds every bind. Shell binds go through `shell_bind()` / `SHELL_ACTIONS` in `binds/shell.lua`: a `someshell:` global shortcut plus an optional CLI fallback that runs only while the shell is not answering.
  - `binds/user.lua` applies `~/.config/someshell/keybinds.json` (settings app): it wraps `hl.bind` while keybinds.lua runs (remap/disable by normalized combo), then `UserBinds.finish()` adds custom binds and the `someshell-record` submap. User changes never go into keybinds.lua.
  - `core/liquidglass.lua` is the optional hyprglass plugin (`liquidGlass`). Build with `scripts/hyprglass.sh` (upstream branch + `plugins/hyprglass-fit-shape.patch`, one `.so` per Hyprland version in `~/.local/share/someshell/plugins/`). `hl.plugin.load()` is declarative: call it on every config load while the plugin is wanted, never only "if not loaded" (that loops unload/load/reload until Hyprland segfaults). Test plugin changes in a nested `Hyprland -c <test.lua>` first.
  - `modes/gamemode.lua` turns blur, shadows and animations off while a game is the focused fullscreen window. Control it with `hyprctl eval 'GameMode.toggle()'` and `'GameMode.auto()'`.
  - `generated/` is machine-written (matugen, and `generated/monitors.lua` from the Displays page, per machine) and gitignored. A catch-all `hl.monitor` (`highrr`) covers outputs it does not name.
  - Touchpad options and gestures live in `core/input.lua` (`touchpad.gestures` in hypr.json turns gestures off).
- `matugen/` is linked to `~/.config/matugen` and is the only color engine. `config.toml` lists every output (shell, Hyprland, terminals, GTK, KDE, fuzzel, Zen, Vesktop); `hooks/` reload apps (`zen-colors.sh` copies the colors into every Zen profile that has a `chrome/` folder). Run it without a terminal only with `--source-color-index 0`.
- Wallpaper state is `~/.local/state/someshell/wallpaper.json`; set it through the shell (`qs -c someshell ipc call wallpaper set <path>`) so videos start mpvpaper and get a matugen frame. Images are shown from a screen-sized copy (`~/.cache/someshell/wall-<WxH>-<md5>.jpg`, ImageMagick), because Qt keeps a large original's full decode in memory. The time-of-day schedule is `shell/services/Schedule.qml` (slot model in `shell/lib/schedule.js`, shared with the settings page so it never runs a second scheduler); `Wallpaper.save()` does nothing until the saved state is `loaded`, so a check at start cannot write an empty path over it.
- `shell/` is linked to `~/.config/quickshell/someshell` and runs with `qs -c someshell`:
  - `core/` singletons (Config, Theme, Motion, Paths, UiState, GameMode), `components/`, `services/` (one singleton per system source).
  - `island/Island.qml` is the notch window; `island/views/*View.qml` are loaded only while open; `island/ambient/` holds the collapsed states.
  - `commands/` holds one file per `/command`, registered in `commands/Commands.qml`.
  - `Shortcuts.qml` (global shortcuts) and `Ipc.qml` (IPC targets) sit at the root; `corners/` holds the pills: `PillParts.qml` defines each part (a `PillPart`, glass or floating per `config.json` `pills`), `Pills.qml` creates a `CornerWindow` per zone (corners or beside the island, `pills.layout`), which joins neighboring glass parts into one pill and `wallpaper/` the background layer.
  - `settings.qml` + `settings/` is the settings app, a separate process (`qs -c someshell ipc call settings open` or `settings page <id>`; a second call focuses the running one). `settings/` holds its stores (HyprSettings, KeybindStore, ShellIpc), `ui/` and one file per page in `pages/`. It changes shell state over IPC, never by running a second copy of a service.
  - `capture/RegionSelector.qml` is the region picker over a grim-frozen frame; `services/Capture.qml` runs the tools and `services/Recorder.qml` owns wf-recorder (the island shows the timer).
  - `overlay/` is the Super+G game overlay (one card file per widget). Its cards are frosted over the game itself (shell layers have no `xray`); game mode turns compositor blur back on only while it is open, or while frosted cards are pinned (`overlay.blur` / `overlay.pinnedBlur`, `GameMode.overlay()` in `modes/gamemode.lua`). Card blur regions are built from the card's window x/y, because an `item:` region does not follow a dragged parent.
  - Laptop: `services/Battery.qml` (UPower; `available` false on a desktop) feeds the status pill, the `battery` quick tile and Settings → Power (listed only with a battery). Battery bypass is UPower `EnableChargeThreshold` on the real battery (`UPower.devices`; the display device has no path), with no password for the active session. UPower devices populate only once something binds to them. `services/Brightness.qml` uses the backlight (brightnessctl) for eDP/LVDS/DSI, DDC otherwise.
  - `services/Warp.qml` is Cloudflare WARP (`available` only with `warp-cli`): one long-lived `warp-cli -l -j status` for status, `settings` for the mode, commands queued one at a time. Tile `warp`, page `island/views/WarpDetail.qml`, IPC `warp toggle · mode <name> · state`.
  - `services/Streamer.qml` is streamer mode; peeks then go to `island/PrivatePeek.qml` on the `someshell:private` layer (`no_screen_share`). `services/GameClients.qml` feeds gamemoded PIDs to `GameMode.set_clients()`.
  - `lock/` is the lock screen (`WlSessionLock`, surfaces only while locked); state and PAM live in `services/Lock.qml`. `hypr/scripts/lock.sh` calls `ipc call lock lock` and runs hyprlock when the shell does not answer. There is no unlock IPC; test with `ipc call lock preview` (no PAM, Esc closes).
  - `widgets/` holds the desktop widgets (bottom layer, one window per screen, hidden in game mode); `services/Widgets.qml` lists them, `config.json` `widgets` stores which are on and where. Edit mode: `ipc call widgets edit`.
  - `osk/` is the Super+K keyboard; `services/VirtualKeys.qml` types through ydotoold (`YDOTOOL_SOCKET` is passed per call, the shell's env lacks it).
  - `dock/` is the bottom dock (contents from `services/Taskbar.qml`, settings under `dock` in config.json). `overview/` is Super+Tab, created only while open.
  - Glass: `components/Glass.qml` (tint + rim + highlight, tokens `Theme.glass*`, `Config.glass`) with its blur from `GlassRegion` (direct window children) or `Region { item: g.frost; radius: g.frostRadius }`. The region stays 1 px inside because Wayland regions have whole-pixel stepped corners. Gate blur on `Theme.blur` (glass on and not game mode).
  - Expressive style: `components/MaterialShape.qml` (35 Material 3 shapes from `lib/shapes/`, drawn with QtQuick.Shapes, never Canvas), `ShapeIcon.qml` (floating icon, shape when active); `PressButton` `radius`/`activeRadius` morph on a spring. Text weights come from `Theme.font.weight`/`weightTitle` through `font.weight`, not `variableAxes`.
  - Color gotcha: the island, game overlay, overview and region picker stay dark in light mode. Accents there use `Theme.accentIsland`/`fgAccentIsland` (fixed tones), content on a light fill `Theme.fgOnIslandFill`; `Theme.primary` turns dark in light mode. Surfaces that follow the theme (settings, widgets, keyboard, dock glass) use the theme tokens and must set `iconColor` on an `IconButton` (its default is island white). Check new UI in both modes.
  - Blur gotcha: an empty `BackgroundEffect.blurRegion` blurs the whole surface, so set it to `null` whenever the shape is off-surface. Gate with a few px of margin: the region is inset and rounded, so it leaves the surface before the item does.
  - Focus gotcha: a layer with `Exclusive` keyboard focus keeps it, so a `HyprlandFocusGrab` never clears on an outside click; switch to `OnDemand` once the grab is active (`island/Island.qml`).
  - Config gotcha: `core/Config.qml` ignores file changes for 600 ms after its own write; without that, several `Config.x = …` in one handler lost some of them to the reload.
  - QML gotcha: a property named `onX` is parsed as a signal handler, so theme colors use `fgX` (e.g. `Theme.fgIsland`).
  - Bindings are stale inside a change handler: in `onBusChanged`, a property bound to `bus` (or a `command` bound to it) still has its old value; read the source property itself. `Timer.restart()`/`start()` replaces a `running:` binding for good; leave a bound timer alone.
  - Animation gotcha: `SpringAnimation` (and `Spring`) only in a `Behavior` or as `SpringAnimation on <prop>`. Inside a `Sequential`/`ParallelAnimation` Qt segfaults when it starts; use `NumberAnimation` there (`components/Reveal.qml`).
  - Font gotcha: every distinct `font.variableAxes` value opens another face (mmap + glyph cache). `components/Icon.qml` snaps FILL to 0/1 and opsz to 20/24/40/48; never animate an axis.
- `install.sh` is the installer for any Arch PC: missing packages (pacman, paru/yay), Google Sans Flex download, ydotool service, i2c group, links (backup `*.pre-someshell`; a dead link is replaced), migration from the old name, screens (`generated/monitors.lua` from `hyprctl monitors all -j`, kept if present), reload with automatic rollback on config errors, then it starts the shell (stopping other Quickshell configs). `--update` pulls first, `--detect` rewrites screens, `--check` only verifies, `--rollback` restores. Questions default to no without a terminal, so test it with `./install.sh </dev/null` (changes nothing that needs an answer) or into a throwaway `XDG_CONFIG_HOME` with `env -u HYPRLAND_INSTANCE_SIGNATURE`.
- The shell starts through `hypr/scripts/shell.sh` (autostart, the restart bind, `install.sh`): it pins EGL to the NVIDIA vendor file only when NVIDIA is the only GPU. Never put that in a `//@ pragma Env`; it leaves the shell without EGL on other GPUs. `services/Gpu.qml` says what the shell may use (`nvidia`: NVENC and nvidia-smi; `amd`: sysfs counters); it is touched in `shell.qml` so it is ready before the first use.
- `core/env.lua` reads GPU vendors from `/sys/class/drm/card*/device/vendor` (`GPU_VENDORS`); the NVIDIA env applies only when NVIDIA is the only GPU.

## Hyprland Lua API
- The authoritative stub is `/usr/share/hypr/stubs/hl.meta.lua`: events, rule fields, config keys and dispatchers. Example config: `/usr/share/hypr/hyprland.lua`.
- Window and layer rules take effects as flat fields, e.g. `hl.window_rule({ match = {...}, no_blur = true })`. Unknown fields are config errors.
- Springs: `hl.curve(name, { type = "spring", mass, stiffness, dampening })`, used as `spring = name` in `hl.animation`.
- `Hyprland --verify-config` runs the `config.reloaded` handlers too, and an `hl.dispatch` there segfaults it (exit 139, no "config ok"). A reload also resets the Lua state (`GameMode.forced` is lost) without an event, so the shell reads state again on `configreloaded` (`core/GameMode.qml`, `services/GameClients.qml`).
- Runtime: `hyprctl eval '<lua>'` runs code, and `hyprctl repl 'return <expr>'` reads Lua globals (e.g. `GameMode.active`).

## Verify every change
```sh
./install.sh --check                 # Hyprland --verify-config on the repo config
hyprctl reload && hyprctl configerrors   # live; must print nothing
hyprctl binds -j | jq length         # 201 (with no keybinds.json)
```
Shell changes:
```sh
timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"   # dev copy; only notification/polkit clashes with the live shell may appear
qs -c someshell ipc call island open <view>                     # search control media notifications system power clipboard emoji keys
qs -c someshell ipc call island state
qs -c someshell ipc call island control <page>                 # wifi bluetooth warp nightlight audio
qs -c someshell ipc call overview toggle
qs -c someshell ipc call capture region <mode>                   # shot ocr lens translate record recordSound
qs -c someshell ipc call overlay toggle · streamer toggle
qs -c someshell ipc call lock preview · widgets edit · osk toggle
qs -c someshell ipc call schedule state · schedule at <HH:MM|now> · wallpaper slot <name>   # time-of-day schedule (at/slot change the wallpaper)
timeout 8 qs -p shell/settings.qml 2>&1 | grep -E "WARN|ERROR"   # settings app
```
- IPC function names must not clash with `qs ipc` subcommands (`show`, `call`, `prop`): `qs ipc call x show` is parsed as `qs ipc show`.
Never edit `~/.config/hypr.pre-somehypr` (the backup keeps its old name), `~/.config/*.pre-someshell` or `~/.config/quickshell/ii`. They are the rollback (`install.sh --rollback`).
- Memory: compare against a fresh start and read `Anonymous`/`Pss` in `/proc/<pid>/smaps_rollup`, not only RSS. An empty one-window Quickshell already shows ~250 MB RSS / ~55 MB anon on this NVIDIA stack. Measure with `pgrep -x qs`; `pkill -f "qs -c someshell"` also matches the shell running the command.

## Phase workflow
- Work through `docs/plan.md` one phase at a time and tick its checkboxes (`[x]` done, `[~]` done differently, with a note) as tasks land.
- Commit and push after **each task** (one checklist item, or one small sub-phase), once it is verified: tick it in `docs/plan.md` in the same commit, then `git push origin main` (remote `someact/SomeShell`, public). Message: `Phase <n><sub>: <task>` (e.g. `Phase 12b: recorder encoder auto`). Unrelated changes go in their own commit.
- When the last task of a phase is done and the phase-level checks pass, mark the phase ✅ in the plan in that final commit.
- New tasks the user asks for mid-phase go into the plan first (as a `12a+`-style section, dated), so every change is tracked.
- `README.md` holds only the feature list and how to install. Update it in the same commit when a change adds a feature, a dependency or an install step; how things work goes here instead.

## Rules for the shell (Phase 2 onward)
- Lazy-load every panel.
- Use events instead of polling.
- Use matugen only: no Python and no cava.
- Use compositor blur (`BackgroundEffect`) instead of QML blur.
- Use global shortcuts under appid `someshell`.
- Don't hardcode this machine in new code (monitor name or size, GPU, tablet, keyboard layouts, absolute paths, user or place names). The repo goes public in Phase 11, so detect these values or read them from settings.
