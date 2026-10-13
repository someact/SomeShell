# SomeShell

A Hyprland desktop with a dynamic island instead of a bar, glass surfaces, spring motion and colors taken from the wallpaper. It is built on Quickshell and stays light: no polling, no Python, and panels load only while they are open. One config fits desktops and laptops; hardware is detected at start.

## Features

- **Dynamic island.** Collapsed, it shows the clock, the playing track, notifications, volume and brightness changes, recording, and microphone or screen-share use. Tap Super or click it to open search, quick options, media, notifications, system stats and power. Hover it for a peek.
- **Search and commands.** Type right after Super to launch apps, calculate, or run a `/command` (`/wallpaper`, `/settings`, `/translate` and more). Clipboard history and an emoji picker are built in.
- **Quick options.** Wi-Fi, Bluetooth, Cloudflare WARP (when `warp-cli` is installed: on/off and mode), do not disturb, game mode, night light, keep awake, microphone, dark mode, streamer mode, record, screenshot and battery bypass, plus volume, microphone and brightness sliders. Show, hide, reorder and resize them with the pencil; right-click one for its details.
- **Media.** Player controls, the player's own volume, a per-app mixer and synced lyrics.
- **Pills.** Workspaces, window title, tray, status icons and clock, in the top corners or beside the island, as glass or floating.
- **Dock and overview.** A bottom dock with pinned and running apps, and a workspace overview on Super+Tab.
- **Wallpaper and colors.** Images and video wallpapers. Every wallpaper recolors the shell, Hyprland, terminals, GTK, KDE, Zen and Vesktop. A time-of-day schedule can change wallpaper, light or dark mode and night light, and can follow the sun.
- **Capture.** Region screenshot, copy text (OCR), Google Lens, translate, live translate for game subtitles, and screen recording with or without sound.
- **Game mode and overlay.** Blur, shadows and animations turn off while a game is in front. Super+G opens an overlay with resources, mixer, crosshair, FPS limit, notes and lyrics; cards can stay pinned over the game.
- **Streamer mode.** Hides notification text from screen shares and turns on by itself while the screen is shared.
- **Lock screen and login.** A lock screen with clock, media and animated password shapes, and a matching SDDM theme.
- **Desktop widgets.** Clock, now playing, system, notes, calendar, weather, wallpaper, gallery, lyrics and quick launch.
- **On-screen keyboard** on Super+K.
- **Laptops.** Battery in the status pill, battery bypass (charge limit), backlight brightness, touchpad options and gestures. None of it shows on a desktop.
- **Settings app.** Appearance, island, wallpaper, displays, keybinds, apps, modes, capture, power and Hyprland options, without editing files.
- **Glass.** The compositor blurs exactly the shapes the shell draws. An optional plugin adds refraction (liquid glass).

## Install

You need Arch or CachyOS with Hyprland 0.56 or newer (Lua config).

```sh
git clone https://github.com/someact/SomeShell && cd SomeShell
./install.sh
```

The installer asks before each change. It installs the missing packages (pacman, and paru or yay for the AUR), downloads the UI font, links `hypr/`, `shell/` and `matugen/` into `~/.config`, sets up your screens, reloads Hyprland and starts the shell. A directory it replaces is kept as `<name>.pre-someshell`, and a config error rolls the links back.

```sh
./install.sh -y                  # answer yes to every question
./install.sh --wallpaper <file>  # also set a wallpaper
./install.sh --no-deps           # skip packages and fonts
./install.sh --update            # git pull, then set up what is missing
./install.sh --detect            # set up the screens again
./install.sh --check             # only verify the Hyprland config
./install.sh --rollback          # remove the links and restore what was there
```

Optional parts:

```sh
./scripts/sddm-theme.sh --install        # the SDDM login theme (--preview to try it, --rollback to undo)
~/.config/hypr/scripts/hyprglass.sh      # build liquid glass, then turn it on in Settings → Appearance
```
