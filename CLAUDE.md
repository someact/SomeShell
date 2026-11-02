# SomeShell

Personal Hyprland desktop for three machines. Detect every hardware feature at runtime, never assume one.
- Desktop: CachyOS x86_64, Hyprland 0.56 Lua config, RTX 3060, DP-1 and HDMI-A-1 1920x1080@100, Ethernet only (no Wi-Fi), US/TH keyboard, UGTablet pen, monitors dimmed over DDC.
- Laptop: Legion 5, RTX 3060 Mobile, eDP-1 2560x1440@165, touchpad, battery.
- Tablet (added 2026-11-02): Xiaomi Pad 6 (`pipa`), aarch64 Snapdragon 870 (SM8250), Adreno 650 on Mesa freedreno, panel DSI-1 1800x2880@120 portrait (turned to landscape with transform 3, scale 2), 8 GB RAM / 256 GB storage, Arch Linux ARM (`linux-pipa` kernel) dual-booted with Android through the A/B slots (one slot each, storage split 128/128). Backlight `ktz8866-backlight`, battery `qcom-battery`. Used with keyboard and mouse, so touch is not a priority. It is where battery, Wi-Fi, backlight brightness and SDDM get tested.
Called SomeHypr until Phase 12; only the installer may use the old name.
Current work: a full rebuild from scratch (2026-11-02). Base (steps 1–4) is done and live on the desktop. The design and decisions are in `SomeShell.md`; tasks are tracked in `docs/plan.md` (one step at a time, tick tasks in the commit that finishes them).
SomeShell Reimagined (`../SomeShell-Reimagined`) is a fork; its `scripts/switch.sh someshell|reimagined` relinks a machine between the two.

## Working on several machines
- One repo for all three. Run `git pull` before starting and push after each verified task, so the machines never diverge. Work on one machine at a time.
- Machine-specific things never go into the repo: they live in `~/.config/someshell/` (`hypr.json`: layouts, `devices` such as the UGTablet pen area, overrides; `shell.json`: shell options) and `hypr/generated/` (gitignored: matugen colors, monitors).
- Code must work on x86_64 and aarch64, NVIDIA, AMD, Intel and Adreno. The NVIDIA-only parts (`hypr/core/env.lua`, `hypr/scripts/shell.sh`) switch off when NVIDIA is not the only GPU; on an ARM SoC there is no PCI vendor file, so they stay off. Check `uname -m` and the hardware before assuming a tool exists (`ddcutil`, `nvidia-smi`, a backlight, a battery, Wi-Fi).
- Write down what each machine lacks in `docs/plan.md` when a test cannot run there (e.g. Wi-Fi on the desktop).

### Setting up a machine (until the new installer, step 7)
1. Packages (on Arch Linux ARM some may have to be built from the AUR or source; Hyprland must be 0.56+ for the Lua config): `hyprland quickshell matugen hypridle hyprlock hyprsunset grim slurp wl-clipboard cliphist imagemagick jq curl playerctl wireplumber brightnessctl gnome-keyring fuzzel ydotool libnotify xdg-utils wf-recorder networkmanager bluez bluez-utils`, plus `ddcutil` for desktop monitors and `upower` on battery machines. Fonts: Material Symbols Rounded (`ttf-material-symbols-variable`), Mitr (below).
2. `git clone https://github.com/someact/SomeShell` and link: `ln -sfn <repo>/hypr ~/.config/hypr`, `ln -sfn <repo>/matugen ~/.config/matugen`, `ln -sfn <repo>/shell ~/.config/quickshell/someshell`, `ln -sfn <repo>/fontconfig/60-someshell-mitr.conf ~/.config/fontconfig/conf.d/` (move any existing config away first, never delete it).
3. Mitr: download `Mitr-{Light,Regular,Medium,SemiBold,Bold}.ttf` from `https://raw.githubusercontent.com/google/fonts/main/ofl/mitr/` into `~/.local/share/fonts/someshell/`, then `fc-cache -f`.
4. Keyboard layouts: `~/.config/someshell/hypr.json` with `{ "hyprland": { "input": { "kb_layout": "us,th" } } }` (without it only `us` loads and Super+Space has nothing to switch to).
5. Log in to Hyprland; autostart runs `hypr/scripts/shell.sh`. With no wallpaper set, the shell uses the bundled poster (`shell/assets/wallpapers/poster-moon.png`) and runs matugen. Redraw the posters at the screen's size with `scripts/poster-wallpaper.sh <w> <h>` if it is not 16:9.
6. Check: `hyprctl configerrors` (empty), `qs -c someshell ipc call island state`, `qs -c someshell ipc call control state`.

## The old version (v1)
- Archived as tag `archive/shell-v1`. Since 2026-11-02 this machine runs the new version (links point at this repo); the detached worktree `../SomeShell-v1` stays as the rollback for now. Never edit or commit in that worktree.
- Nothing is brought back from v1 (user, 2026-11-02). Read it only to learn how something worked or why a bug happened: `git show archive/shell-v1:<path>`.

## The new shell (`shell/`)
- `shell.qml`: a wallpaper window and a `TopBar` per screen, `Shortcuts.qml` (global shortcuts `someshell:<name>`, the names `hypr/binds/keybinds.lua` uses), `Ipc.qml` (targets `island`, `wallpaper`, `theme`).
- `core/` singletons: `Paths`, `Config` (`~/.config/someshell/shell.json`), `Theme` (palette from matugen: `Theme.ink.*` for the island, `Theme.bg/fg/paper.*` for desktop surfaces; fonts by style name), `Motion`, `Ui` (island state), `Clock`, `GameMode`. `core` never imports `qs.services` (no import loops).
- `services/`: one singleton per system source (`Wallpaper` runs matugen). `components/`: `Txt`, `Icon`, `Digits` (rolling digits), `Tap` (press inverts).
- `top/`: `TopBar` (one layer window per screen, namespace `someshell:island`, input mask = badge + tray + island, keyboard only while open, `HyprlandFocusGrab` closes on an outside click), `Island` (shape, state choice, hover/click, size spring), `Badge`, `Tray`. `island/`: one file per island state (`Rest`, `Peek`, `Alert`, `Quiet`, `Open`). Every state and page sets its own implicit size; the island never has a fixed size.
- `assets/wallpapers/`: the poster wallpapers (moon is the default), drawn by `scripts/poster-wallpaper.sh`. `lib/`: `calc.js` (math), `emoji.tsv` (built by `scripts/emoji-data.sh`).
- State files: `~/.local/state/someshell/palette.json` (matugen), `wall.json`. v1 used `colors.json`, `wallpaper.json` and `config.json`; the new names avoid clashes while both exist.
- Testing: the live shell is `qs -c someshell` (this repo). Restart it with `qs kill -c someshell`, then `hyprctl eval 'hl.exec_cmd("~/.config/hypr/scripts/shell.sh")'`; drive it with `qs -c someshell ipc call …` and real keys through ydotool. `SOMESHELL_DRY_POWER=1` makes the power page only say what it would run.
- A Hyprland release bind (the Super tap) sends a global shortcut as "released" only; `Shortcuts.qml` handles that for `island`.
- Live reload is not reliable for judging a change: after several edits it keeps running old code (seen 2026-11-02: a fixed bug stayed until a restart). Restart the shell before a screenshot that has to prove a fix.
- Qt's JavaScript has no `Array.prototype.flatMap`; build arrays with a loop. A property named `top`, `bottom`, `left`, `right` etc. on an Item clashes with its anchor lines ("Cannot override FINAL property").
- After many live reloads, `qs kill` can segfault in a Wayland destructor, and Quickshell's crash handler relaunches the shell as `quickshell` (a second copy draws over the first). After killing, check `ps -C qs,quickshell` and `kill -9` leftovers by PID. A fresh start stops cleanly.

## Quickshell and Qt gotchas (learned on v1)
- Focus: a layer with `Exclusive` focus keeps it, so a `HyprlandFocusGrab` never clears on an outside click; switch to `OnDemand` once the grab is active.
- Blur: compositor blur (`BackgroundEffect`) only. An empty `blurRegion` blurs the whole surface; set it to `null` when the shape is off-surface. Wayland regions have stepped corners, so keep a region 1 px inside a rounded shape.
- Config files: ignore file changes for a moment after the shell's own write, else several writes in one handler get lost.
- Loader: never bind both `source` and `sourceComponent`; writing `sourceComponent` (even `undefined`) clears `source`, and the binding order differs between machines (the tablet showed empty pages after a switch). Set one of them imperatively.
- QML: a property named `onX` parses as a signal handler (use `fgX`-style names). Bindings are stale inside a change handler; read the source property. `Timer.restart()`/`start()` replaces a `running:` binding for good.
- Animation: `SpringAnimation`/`Spring` only in a `Behavior` or `on <prop>`; inside `Sequential`/`ParallelAnimation` Qt segfaults (use `NumberAnimation`).
- AnimatedImage: never `cache: false` on a network URL (Qt 6.12 stack overflow); download with curl and play local files.
- Fonts: the UI font is Mitr (static files in `~/.local/share/fonts/someshell`). Qt maps every numeric weight 300–600 of it to SemiBold, so pick faces with `font.styleName` (Light, Regular, Medium, SemiBold), never `font.weight`; rebuild names with `fc-cache -f`. Mitr digits are proportional (no `tnum`). Each distinct `font.variableAxes` value opens another face: snap icon axes to a few values, never animate an axis.
- Shapes: QtQuick.Shapes, never Canvas. Images: show a screen-sized copy of a big wallpaper (Qt keeps a large decode in memory).
- IPC function names must not be `show`, `call` or `prop` (clash with `qs ipc` subcommands).
- Hot reload can silently stop applying edits after many quick changes, and new fonts need a restart: `qs kill -c someshell`, then `hyprctl eval 'hl.exec_cmd("<repo>/hypr/scripts/shell.sh")'` (`hyprctl dispatch exec` does nothing under the Lua config). After a crash the shell restarts as `quickshell`, not `qs` (`qs list --all`, `qs kill`). Never `pkill -f` a pattern that is in your own command.
- Memory: compare with a fresh start, read `Anonymous`/`Pss` in `/proc/<pid>/smaps_rollup`; an empty one-window Quickshell is already ~250 MB RSS / ~55 MB anon on the desktop.
- Hover: when a layer's shape or input region changes under a still pointer, Hyprland can send a leave and no enter until the pointer moves, so a `HoverHandler` reads "outside". Before acting on a leave, ask `hyprctl cursorpos -j` (the island does).
- Pointer tests: move the cursor with `ydotool mousemove -x <dx> -y <dy>` (`YDOTOOL_SOCKET=$XDG_RUNTIME_DIR/.ydotool_socket`), not a Hyprland cursor warp: a warp sends no leave event. Screenshots: `grim -o <monitor>` (names from `hyprctl monitors`).

## Hyprland Lua API
- Authoritative stub: `/usr/share/hypr/stubs/hl.meta.lua`; example `/usr/share/hypr/hyprland.lua`.
- Rules take flat effect fields (`hl.window_rule({ match = {...}, no_blur = true })`); unknown fields are errors.
- Springs: `hl.curve(name, { type = "spring", mass, stiffness, dampening })`, used as `spring = name`.
- `--verify-config` runs `config.reloaded` handlers; an `hl.dispatch` there segfaults it (exit 139). A reload resets Lua state without an event, so the shell rereads state on `configreloaded`.
- `hyprctl eval '<lua>'` runs code; `hyprctl repl 'return <expr>'` reads globals.

## Verify
Every new screen is checked on the real desktop (screenshot), in dark and light mode. Never edit `~/.config/hypr.pre-somehypr`, `~/.config/*.pre-someshell` or `~/.config/quickshell/ii` (the rollback).

## Workflow
- Commit and push after each verified task (`git push origin main`, public `someact/SomeShell`; base is done, so pushing is on again). Unrelated changes get their own commit. Never commit images or other files that are not ours to publish.
- Decisions go into `SomeShell.md` first. Never change an agreed approach without asking.

## Rules for the shell
Lazy-load every panel. Events, not polling. matugen only (no Python, no cava). Compositor blur (`BackgroundEffect`), never QML blur, and only where the design asks for it. Global shortcuts under appid `someshell`. Never hardcode this machine (monitor, GPU, tablet, layouts, absolute paths, names): detect or read from settings.
