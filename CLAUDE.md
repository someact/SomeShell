# SomeShell

Personal Hyprland desktop for two machines: a desktop (CachyOS, Hyprland 0.56 Lua config, RTX 3060, 1920x1080@100 on DP-1, US/TH keyboard, UGTablet pen) and a laptop (Legion 5, RTX 3060 Mobile, eDP-1 2560x1440@165, touchpad, battery). Detect laptop features at runtime, never assume them.
Called SomeHypr until Phase 12; only `install.sh` (`migrate_legacy`) may use the old name.
Current work: a full rebuild from scratch (2026-11-02): shell, Hyprland config, colors and installer. The design and decisions are in `SomeShell.md` (the user's note, brainstorm stage: no code until they say so).
SomeShell Reimagined (`../SomeShell-Reimagined`) is a fork; its `scripts/switch.sh someshell|reimagined` relinks this machine between the two.

## The old version (v1)
- Archived as tag `archive/shell-v1`. This machine still runs it from the detached worktree `../SomeShell-v1`: `~/.config/hypr`, `~/.config/matugen`, `~/.config/quickshell/someshell` and the Mitr fontconfig rule link there until the new version replaces them. Never edit or commit in that worktree.
- Nothing is brought back from v1 (user, 2026-11-02). Read it only to learn how something worked or why a bug happened: `git show archive/shell-v1:<path>`.

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

## Verify
Every new screen is checked on the real desktop (screenshot), in dark and light mode. Never edit `~/.config/hypr.pre-somehypr`, `~/.config/*.pre-someshell` or `~/.config/quickshell/ii` (the rollback).

## Workflow
- Commit and push after each verified task: `git push origin main` (public `someact/SomeShell`). Unrelated changes get their own commit.
- Decisions go into `SomeShell.md` first. Never change an agreed approach without asking.

## Rules for the shell
Lazy-load every panel. Events, not polling. matugen only (no Python, no cava). Compositor blur (`BackgroundEffect`), never QML blur, and only where the design asks for it. Global shortcuts under appid `someshell`. Never hardcode this machine (monitor, GPU, tablet, layouts, absolute paths, names): detect or read from settings.
