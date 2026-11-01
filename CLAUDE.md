# SomeShell

Personal Hyprland desktop for two machines: a desktop (CachyOS, Hyprland 0.56 Lua config, RTX 3060, 1920x1080@100 on DP-1, US/TH keyboard, UGTablet pen) and a laptop (Legion 5, RTX 3060 Mobile, eDP-1 2560x1440@165, touchpad, battery). Detect laptop features at runtime, never assume them.
Called SomeHypr until Phase 12; only `install.sh` (`migrate_legacy`) may use the old name.
Tasks and goals: `docs/plan.md`. Current work: Phase 16, the flat redesign with motion, done in place area by area (design: the 16a mockup). Open leftovers of Phase 13 and Phase 14 (release) are listed there; Phase 15 (themes, `docs/themes.md`) is paused.
SomeShell Reimagined (`../SomeShell-Reimagined`) is a fork; its `scripts/switch.sh someshell|reimagined` relinks this machine between the two.

## Layout
- `hypr/` → `~/.config/hypr`. `hyprland.lua` loads files in a fixed order; each setting lives in exactly one file.
  - `user.lua`: user choices (apps, `glass`, `fastGlass`, `liquidGlass*`, `gameModeAuto`). The settings app overrides them via `~/.config/someshell/hypr.json` (`SETTINGS`, `lib/util.lua` + `lib/json.lua`); `core/settings.lua` loads last and applies its `hyprland` table (partial `hl.config`, changed values only).
  - `core/`: env (GPU vendors from `/sys/class/drm/card*/device/vendor`, NVIDIA env only when NVIDIA is the only GPU), input (touchpad, tablet, gestures; `touchpad.gestures` turns them off), look, motion, misc, execs. `rules/`: window and layer rules.
  - `binds/keybinds.lua` holds every bind. Shell binds use `shell_bind()` / `SHELL_ACTIONS` (`binds/shell.lua`): a `someshell:` global shortcut, with a CLI fallback only while the shell does not answer. `binds/user.lua` applies `~/.config/someshell/keybinds.json` (remap/disable by normalized combo, then custom binds and the `someshell-record` submap). User changes never go into keybinds.lua.
  - `core/liquidglass.lua`: optional hyprglass plugin, built by `scripts/hyprglass.sh` (one `.so` per Hyprland version in `~/.local/share/someshell/plugins/`). Call `hl.plugin.load()` on every config load while wanted, never "only if not loaded" (unload/reload loop → segfault). Test plugin changes in a nested `Hyprland -c <test.lua>`.
  - `modes/gamemode.lua`: blur, shadows, animations off while a game is the focused fullscreen window (`hyprctl eval 'GameMode.toggle()'` / `'GameMode.auto()'`).
  - `generated/` is machine-written and gitignored (matugen, `monitors.lua` from the Displays page). A catch-all `hl.monitor` (`highrr`) covers unnamed outputs.
- `matugen/` → `~/.config/matugen`, the only color engine. `config.toml` lists every output; `hooks/` reload apps (`zen-colors.sh` writes every Zen profile with `chrome/`). Without a terminal run it only with `--source-color-index 0`.
- Wallpaper: state in `~/.local/state/someshell/wallpaper.json`; set it with `qs -c someshell ipc call wallpaper set <path>` (videos start mpvpaper and get a matugen frame). Images are shown from a screen-sized copy (`~/.cache/someshell/wall-<WxH>-<md5>.jpg`) because Qt keeps a big original's decode in memory. Schedule: `services/Schedule.qml` + `lib/schedule.js` (shared with the settings page, never a second scheduler); `Wallpaper.save()` is a no-op until state is `loaded`.
- `shell/` → `~/.config/quickshell/someshell`, run with `qs -c someshell`, started through `hypr/scripts/shell.sh` (pins EGL to NVIDIA only when NVIDIA is the only GPU; never in a `//@ pragma Env`). `services/Gpu.qml` says what the shell may use (`nvidia`: NVENC, nvidia-smi; `amd`: sysfs).
  - `core/` singletons (Config, Theme, Motion, Paths, UiState, GameMode), `components/`, `services/` (one singleton per system source), `Shortcuts.qml` (global shortcuts), `Ipc.qml` (IPC targets).
  - Island: `island/Island.qml` is the notch window; `views/*View.qml` load only while open; `ambient/` holds collapsed states (`side` = `AmbientSide.qml`, `island.dual`: recording/privacy beside media, a notification or the OSD; not part of the peek hover).
  - `commands/`: one file per `/command`, registered in `commands/Commands.qml`.
  - `corners/`: pills. `PillParts.qml` defines parts (`PillPart`, glass or floating per `config.json` `pills`); `Pills.qml` makes a `CornerWindow` per zone (`pills.layout`) that joins neighboring glass parts. `wallpaper/`: background layer.
  - `settings.qml` + `settings/`: the settings app, a separate process (`ipc call settings open` / `settings page <id>`). Stores in `settings/` (HyprSettings, KeybindStore, ShellIpc), `ui/`, one file per page in `pages/`. It changes shell state over IPC, never by running a second copy of a service.
  - Other parts: `capture/RegionSelector.qml` (picker over a grim-frozen frame; `services/Capture.qml`, `services/Recorder.qml` owns wf-recorder), `overlay/` (Super+G game overlay, one file per card), `lock/` (`WlSessionLock`; state and PAM in `services/Lock.qml`; `hypr/scripts/lock.sh` falls back to hyprlock; no unlock IPC, test with `ipc call lock preview`), `widgets/` (desktop widgets, bottom layer, hidden in game mode; `services/Widgets.qml`, `config.json` `widgets`), `osk/` (Super+K; `services/VirtualKeys.qml` passes `YDOTOOL_SOCKET` per call), `dock/` (`services/Taskbar.qml`, `dock` in config.json), `overview/` (Super+Tab, created only while open).
  - Overlay blur: shell layers have no `xray`, so game mode turns compositor blur back on only while the overlay is open or frosted cards are pinned (`overlay.blur` / `overlay.pinnedBlur`, `GameMode.overlay()`). Card blur regions use the card window's x/y (an `item:` region does not follow a dragged parent).
  - Services worth knowing:
    - `Clipboard.qml`: `cliphist list` on open; images decoded once to `~/.cache/someshell/clipboard/<id>.<ext>`, pruned each refresh; preview pane `FilterListView.side`.
    - `Shelf.qml`: drops on the island (`IslandDrop`, notch + 2 px top strip) sorted by `Shelf.take()` into file/image/link/text; `ambient/AmbientDrop.qml` during a drag, `views/ShelfView.qml` after; cache `~/.cache/someshell/shelf`; drag out with `Drag.Automatic`, `Shelf.draggingOut` keeps the focus grab from closing the island; each drop logs its formats.
    - `Gifs.qml` (`/gif`, Klipy or Giphy, `gif.key`; Tenor is gone): empty query lists saved GIFs (`gif.saveDir` = Uncategorized, subfolders = categories, Ctrl+S saves); copy = `text/uri-list` file; `SOMESHELL_GIF_FIXTURE` replaces the network in tests.
    - `Emojis.qml` + `lib/emoji.tsv` (also used by `hypr/scripts/fuzzel-emoji.sh`), rebuilt with `scripts/emoji-data.sh`; the tone form has U+1F3FB replaced by the chosen tone.
    - `Battery.qml` (UPower, `available` false on a desktop; bypass = `EnableChargeThreshold` on the real battery from `UPower.devices`; devices populate only once bound). `Brightness.qml`: backlight for eDP/LVDS/DSI, DDC otherwise.
    - `Warp.qml` (only with `warp-cli`): one long-lived `warp-cli -l -j status`, commands queued; page `island/views/WarpDetail.qml`.
    - `QuickShare.qml`: helper `tools/quickshare` (Rust on `rqs_lib`, GPL-3.0+, JSON lines; `scripts/quickshare.sh`; stand-in via `SOMESHELL_QUICKSHARE`). `someshell-quickshare` runs only while Bluetooth is on (the library powers Bluetooth), `-net` otherwise. Fixed TCP port `quickshare.port` 47893; `blocked` warns about ufw/firewalld. Runs only while wanted; wait for exit before the next start (`swapping` clears in `onExited`). Received files open via `hypr/scripts/quickshare-open.sh` (taken names saved as `N_<name>`).
    - `Launcher.qml`: client of SomeLauncher's `somelauncherd` socket (JSON lines, protocol in that repo's `docs/protocol.md`); never starts it; connects at start and on `openwindow` (+2 s). Ambient `launcher` (`island.showLauncher`), overlay `GamesCard.qml`.
    - `Streamer.qml`: streamer mode; peeks go to `island/PrivatePeek.qml` on `someshell:private` (`no_screen_share`). `GameClients.qml` feeds gamemoded PIDs to `GameMode.set_clients()`.
- `install.sh`: installer for any Arch PC (packages, fonts, ydotool, i2c, links with `*.pre-someshell` backups, migration, `generated/monitors.lua`, reload with rollback, starts the shell). `--update`, `--detect`, `--check`, `--rollback`. Questions default to no without a terminal: test with `./install.sh </dev/null` or a throwaway `XDG_CONFIG_HOME` with `env -u HYPRLAND_INSTANCE_SIGNATURE`.

## Gotchas
- Colors: the island, game overlay, overview and region picker stay dark in light mode; use `Theme.accentIsland`/`fgAccentIsland`, `Theme.fgOnIslandFill` there (`Theme.primary` turns dark in light mode). Theme-following surfaces use theme tokens and must set `iconColor` on `IconButton` (default is island white). Check new UI in both modes.
- Glass: `components/Glass.qml` (tokens `Theme.glass*`, `Config.glass`), blur from `GlassRegion` or `Region { item: g.frost; radius: g.frostRadius }`, kept 1 px inside (Wayland regions have stepped corners). Gate blur on `Theme.blur`.
- Blur: an empty `BackgroundEffect.blurRegion` blurs the whole surface; set it to `null` when the shape is off-surface, with a few px of margin.
- Focus: a layer with `Exclusive` focus keeps it, so a `HyprlandFocusGrab` never clears on an outside click; switch to `OnDemand` once the grab is active.
- Config: `core/Config.qml` ignores file changes for 600 ms after its own write (else several `Config.x = …` in one handler get lost).
- QML: a property named `onX` parses as a signal handler (hence `fgX` names). Bindings are stale inside a change handler; read the source property. `Timer.restart()`/`start()` replaces a `running:` binding for good.
- Animation: `SpringAnimation`/`Spring` only in a `Behavior` or `on <prop>`; inside `Sequential`/`ParallelAnimation` Qt segfaults (use `NumberAnimation`, see `components/Reveal.qml`).
- AnimatedImage: never `cache: false` on a network URL (Qt 6.12 stack overflow); download with curl and play local files.
- Fonts: the UI font is Mitr (static files in `~/.local/share/fonts/someshell`). Qt maps every numeric weight 300–600 of it to SemiBold, so pick faces with `font.styleName` (`Theme.font.style` Light, `styleTitle` Regular, `styleDisplay` SemiBold), never `font.weight`; `fontconfig/60-someshell-mitr.conf` cleans the face names (rebuild with `fc-cache -f`). Mitr digits are proportional (no `tnum`). Each distinct `font.variableAxes` value opens another face; `components/Icon.qml` snaps FILL (default 1, flat filled icons) and opsz to 20/24/40/48; never animate an axis.
- Shapes: `components/MaterialShape.qml` (35 M3 shapes from `lib/shapes/`) with QtQuick.Shapes, never Canvas.
- IPC function names must not be `show`, `call` or `prop` (clash with `qs ipc` subcommands).
- Hot reload can silently stop applying edits after many quick changes, and new fonts need a restart: `qs kill -c someshell`, then `hyprctl eval 'hl.exec_cmd("<repo>/hypr/scripts/shell.sh")'` (`hyprctl dispatch exec` does nothing under the Lua config). After a crash the shell restarts as `quickshell`, not `qs` (`qs list --all`, `qs kill`). Never `pkill -f` a pattern that is in your own command.
- Memory: compare with a fresh start, read `Anonymous`/`Pss` in `/proc/<pid>/smaps_rollup`; an empty one-window Quickshell is already ~250 MB RSS / ~55 MB anon here.

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
timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"    # only notification/polkit clashes with the live shell
timeout 8 qs -p shell/settings.qml 2>&1 | grep -E "WARN|ERROR"
```
IPC (`qs -c someshell ipc call …`): `island open <search control media notifications system power clipboard emoji gif keys>` · `island state` · `island control <wifi bluetooth warp nightlight audio>` · `overview toggle` · `capture region <shot ocr lens translate record recordSound>` · `overlay toggle` · `streamer toggle` · `lock preview` · `widgets edit` · `osk toggle` · `shelf add|text|open|clear|state` · `schedule state|at <HH:MM|now>` · `wallpaper slot <name>` · `warp toggle|mode <name>|state` · `quickshare toggle|offer|accept|reject|state|refresh`.
Never edit `~/.config/hypr.pre-somehypr`, `~/.config/*.pre-someshell` or `~/.config/quickshell/ii` (the rollback).

## Workflow
- One phase at a time from `docs/plan.md`; tick tasks (`[x]`, `[~]` with a note).
- Commit and push after each verified task, ticked in the same commit: `Phase <n><sub>: <task>`, `git push origin main` (public `someact/SomeShell`). Unrelated changes get their own commit. Mark a phase ✅ in its last commit.
- New tasks asked mid-phase go into the plan first (dated section).
- `README.md` holds only features and install; update it when a feature, dependency or install step changes.

## Rules for the shell
Lazy-load every panel. Events, not polling. matugen only (no Python, no cava). Compositor blur (`BackgroundEffect`), never QML blur. Global shortcuts under appid `someshell`. Never hardcode this machine (monitor, GPU, tablet, layouts, absolute paths, names): detect or read from settings.
