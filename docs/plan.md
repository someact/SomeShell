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

### 12b Fixes from the code review (2026-10-14) ✅
Most of these only break on a machine that is not the one the code was written on.
- [x] 1. The shell forces the NVIDIA EGL vendor file (`shell.qml`, `settings.qml` pragma), so it cannot start on AMD/Intel or a hybrid laptop. Move it to a launcher that sets it only when NVIDIA is the only GPU — done in `hypr/scripts/shell.sh`; AMD/Intel path untested here
- [x] 2. Recording defaults to `h264_nvenc`. Default `auto`: NVENC with an NVIDIA GPU, else x264 — `services/Gpu.qml`; the x264 path was recorded once here
- [x] 3. Video wallpaper uses `hwdec=nvdec`. Use `auto-safe` — no video wallpaper on this machine to play it with
- [x] 4. System stats: CPU temperature only from `k10temp`, `nvidia-smi` always started. Add Intel sensors, AMD GPU from sysfs, hide the GPU rows otherwise — coretemp checked here; the AMD GPU counters are untested
- [x] 5. matugen writes Zen colors into one hardcoded profile. Write them into every Zen profile that has a `chrome/` folder — `matugen/hooks/zen-colors.sh`
- [x] 6. Personal defaults in tracked files (projects folder, dock pins, code editor, translate language, `us,th` layout, tablet output `DP-1`, tracked `hypr/monitors.lua`). Each becomes a setting or is detected; the installer keeps the keyboard layout a machine already uses — projects folder is `search.projectsDir` (Settings → Island → Search), the editor is the first one installed, layout default `us` with `keep_layout` in the installer
- [x] 7. `install.sh` does not install `ffmpeg`, `libnotify`, `hyprsunset`, `kdialog`, `libqalculate`, `xdg-utils`, which the shell runs
- [x] 8. `Capture.qml` builds shell strings with paths inside quotes; the OCR command is written twice; the fallback scripts use fixed `/tmp` file names — snippets run against a folder with a quote and a space; a drag in the picker is a hands-on check
- [x] 9. The location lookup for weather and sun times uses plain http
- [x] 10. `HYPR_DIR`, `record.sh` and the Appearance page ignore `XDG_CONFIG_HOME` — hypridle.conf and hyprlock.conf still name ~/.config (their format has no variable for it)
- [x] 11. Game mode forced on followed by `hyprctl reload` left the shell showing game mode for good: the shell now reads the state again after every reload (a forced mode ends with the reload). The suspected first-run write race (`config.json`, `wallpaper.json` right after a detached `mkdir -p`) did not reproduce in three fresh starts each, so nothing changed there
- [x] 12. Small: a failed `grim` shows a message; night light checks `hyprsunset` again after a toggle (not toggled by hand yet)

## Phase 13: Features

### 13a Cloudflare WARP ✅
- [x] `services/Warp.qml`: available only when `warp-cli` is installed; state from `warp-cli -l -j status` (an event stream, no polling); the mode is read from `settings` after each status change
- [x] Quick tile: click connects or disconnects, the subtitle shows state and mode
- [x] Right-click: a detail page (`island/views/WarpDetail.qml`) with the modes (`warp`, `doh`, `warp+doh`, `dot`, `warp+dot`, `proxy`, `tunnel_only`), and a hint when the client is not registered or the service is down
- [x] Status pill icon while connected (dim while connecting); right-click opens the page
- [x] IPC: `warp toggle`, `warp mode <name>`, `warp state`, and `island control <page>` for any Control detail page

Checked on a registered client: off and on, `doh` ↔ `dot`, several mode clicks in a row, a shell reload. Not checked: a machine without `warp-cli`, an unregistered client, the tunnel modes (they would have rerouted this session's network).

### 13b Quick option sizes ✅
Each tile is full (icon, title, state), medium (icon, title) or icon only: pencil, then the badge at the tile's corner or a right-click.
- [x] Third size `medium`: icon and title, two of the eight units, so four fit in a row; a long title wraps to two lines ("Streamer / mode")
- [x] The edit badge steps icon → medium → full; right-click in edit mode lists the three sizes under the tile
- [x] The grid button steps all tiles through the three sizes

Checked with the pointer: the chooser, the badge through all three sizes, the grid button, drag to reorder and click to hide (both still work with the right button added).

### 13c Island: two contents at once ✅
- [x] The collapsed island shows a main content and a side slot (`island/ambient/AmbientSide.qml`: a small pill at the right end with the red dot, the recording timer, and the screen-share and microphone icons)
- [x] Microphone / screen share and the recording timer move to the side slot while media, a notification or the OSD is the main content; alone they stay the main content
- [x] Clicking the slot stops the recording (or opens Control when nothing records); the hover peek does not open while the pointer is on it
- [x] One switch in Settings → Island → "Two things at once" (`island.dual`, on by default)
- [x] Game mode keeps the old behavior (the state takes the island over); the pulse stops under a fullscreen window like the other ambient states
- [x] The pulsing dot is one component now (`island/ambient/PulseDot.qml`)

Checked live with a test track, a microphone stream, a notification and a recording, switch on and off, and a click on the slot. Not checked: the OSD as the main content (same code path as the notification), and a screen share.

### 13d Quick Share with Android (added 2026-10-14)
Send files to and receive files from an Android phone over Quick Share (Nearby Share). Built and checked against a scripted stand-in for the helper; **a real transfer with a phone has not been tried yet**, so the phase stays open until it has.
- [x] Backend: an own helper, `tools/quickshare` (Rust, ~300 lines) on `rqs_lib`, the library of rquickshare, pinned to a commit. JSON lines over a pipe (its README has the protocol). It is GPL-3.0-or-later because the library is. Ruled out: rquickshare itself (window only), QNearbyShare (no longer works with Quick Share phones), the `qs` CLI (new, one author, and it can only auto-accept without a terminal)
- [x] `scripts/quickshare.sh` builds it (needs `cargo` and `protoc`) into `~/.local/share/someshell/bin` and adds "Send with Quick Share" to Dolphin. Two binaries: the library switches Bluetooth on whenever its Bluetooth side runs, so the one with Bluetooth is used only while Bluetooth is on already, and `-net` otherwise; the shell swaps them when Bluetooth changes
- [x] `services/QuickShare.qml`: available only with the helper built; the helper runs only while receiving is on, files wait to be sent, or a transfer is going
- [x] Quick tile: receiving on/off; the right-click page has the switch, a Bluetooth hint with a "Turn on" button, the files to send with the devices found, and this session's transfers with progress and cancel
- [x] Receiving: the island asks with Decline and Accept (sender, what, PIN, size), then shows progress, then a notification. Text is copied; a link is never opened on its own. Nothing is accepted without a click
- [x] Sending: `/share [file]`, a file dropped on the island, Dolphin's menu (`hypr/scripts/quickshare-send.sh`), IPC `quickshare offer`; pick the device on the page
- [x] Streamer mode hides the sender and file names in the island prompt
- [x] Settings → Island → Search → "Quick Share folder" (`quickshare.downloadDir`, empty: Downloads)
- [x] With a phone: sending to the phone works (2026-10-14)
- [x] The phone did not see the laptop: `ufw` drops incoming connections and the helper listened on a random port. It now listens on a fixed one (`quickshare.port`, 47893), the page warns when ufw or firewalld is in the way and gives the command to open it, and so does `scripts/quickshare.sh`
- [x] With a phone, after opening the port: receiving works (2026-10-14)
- [x] Easier to open what arrived: the notification has Open and Show in folder, and on the page a received transfer opens on click, with a folder button that shows the files selected in the file manager (`hypr/scripts/quickshare-open.sh`)
- [ ] Still to try with a phone: a link, several files, Bluetooth off, decline, cancel half way
- [ ] If the phone still does not see it: the helper announces every address of the machine (docker bridges, Tailscale too) and the phone may try a wrong one first
- [x] Drop a file on the island by hand: a file dragged from Dolphin lands in the Quick Share page (confirmed 2026-10-14)
- [ ] The page in streamer mode still shows names (it is opened on purpose); decide whether to mask it too
- [ ] Offer the build in `install.sh` when `cargo` is installed

### 13e Emoji picker (added 2026-10-14) ✅
- [x] The full Unicode emoji set with names and keywords as a data file of its own (`shell/lib/emoji.tsv`, 1,914 emoji), loaded only while the view is open; the fuzzel fallback reads the same file. `scripts/emoji-data.sh` rebuilds it from the Unicode emoji-test.txt and the CLDR keywords, up to Emoji 17.0 (18.0 has no glyphs in Noto or Twemoji yet)
- [x] A grid instead of a list, with category tabs (smileys, people, animals, food, travel, activities, objects, symbols, flags) and a "recent" row on top (the last 12)
- [x] Search across names and keywords; arrows move in the grid, Tab switches the category, Enter copies, Shift+Enter (or a right-click) copies and keeps it open
- [x] Skin tone choice for the emoji that have one (the hand button; remembered with the recent ones in `~/.local/state/someshell/emoji.json`)

Checked live with typed keys: search, arrows, Tab, Enter and Shift+Enter, the recent row, a saved tone on the hands and the two-person emoji. The tone button was not clicked by hand (a scripted click missed the island).

### 13f Clipboard history with image previews (added 2026-10-14) ✅
- [x] Image entries show a thumbnail (decoded with `cliphist decode` into `~/.cache/someshell/clipboard/<id>.<ext>`, once per entry; Delete removes the file with the entry, wipe the folder, and each refresh drops files of entries cliphist no longer has)
- [x] A larger preview of the selected entry beside the list: the image, or the full text (decoded when the selection rests, up to 20,000 bytes)
- [x] Type and size on the row ("image · 1280×720 · 409 KiB", "12 lines · 340 characters"; text is counted once per entry per session), streamer mode hides thumbnails and the preview

Checked live: thumbnails, the image and text preview, the counts, streamer mode on and off, Delete on an image entry (its file went with it).

### 13g GIF search (added 2026-10-14)
- [x] `/gif <words>` searches online and shows a grid of animated previews in the island (`services/Gifs.qml`, `island/views/GifView.qml`); scrolling to the end loads the next page
- [x] Service: Tenor closed its API on 2026-06-30, so it is Klipy (default; the Tenor team's successor, free key at partner.klipy.com) or Giphy, both over curl. The key is `gif.key` in config.json (Settings → Island → GIF search, masked), never in the repo; without one the view says where to get it
- [x] Enter copies the GIF as a file (`text/uri-list`, downloaded into `~/.cache/someshell/gif`, kept a day); Ctrl+S (or a right-click) saves it to `gif.saveDir` (empty: `~/Pictures/gif`, created)
- [x] Previews load only while the view is open and are dropped when it closes; nothing is fetched until a search is typed
- [ ] With a real key: a search on each service, and a paste into Discord / Vesktop. Checked so far against a local stand-in in Klipy's format (`SOMESHELL_GIF_FIXTURE`): grid, arrows, Enter, Ctrl+S, ads left out; and against both real APIs with a wrong key (their error is shown). The Klipy fields come from its API as other open-source clients use it, not from a live answer

### 13h Drop anything on the island (added 2026-10-14)
Drag a file, an image, a link or selected text onto the island and choose what happens to it. The island already takes dropped files for Quick Share (13d), and a file dragged from Dolphin works (confirmed 2026-10-14), so the foundation is there.
- [ ] Check the other sources: an image and a link from the browser, selected text, in notch and floating style, and note what each one offers (`text/uri-list`, `text/plain`, image data)
- [ ] While something is dragged near the top edge, the island grows into a drop target that says what it will take
- [ ] After the drop, a small shelf with actions that fit the content: files: send with Quick Share, copy, move or copy to a folder (recent folders, Downloads, Pictures); images: also save, copy text (OCR), Lens; links: open, copy, send to phone; text: copy, save as a note, translate, search
- [ ] The shelf keeps what was dropped until it is used or dismissed, so several things can be collected and sent together; it can be dragged back out to another app
- [ ] Nothing leaves the PC without a click (Lens uploads, Quick Share sends)

## Phase 14: Public release

Carried over from Phase 11. The repo is already public.
- [ ] LICENSE at the repo root (the vendored shapes are Apache-2.0, the SDDM theme has its own; `tools/quickshare` is GPL-3.0-or-later and needs the license text beside it)
- [ ] Screenshots in the README
- [ ] Install test on a clean user or a VM, and a rollback test
- [ ] Hands-on checks still open: lock and unlock after suspend, idle lock, dock peek over a window, region tools by mouse, the game overlay over a real game, streamer mode during a share, a day with the time-of-day schedule
- [ ] Bench (`hypr/scripts/bench.sh`, fresh and `--cycle 3`) against the Phase 11 numbers
- [ ] Thai OCR needs `tesseract-data-tha`: offer the language packs of the system locale in the installer

## Later: code quality

- [ ] `island/Island.qml`: the view and ambient `switch` blocks plus 13 `Component` declarations become one table
- [ ] `services/QuickTiles.qml`: `ids` and `byId` are two lists kept in sync by hand
- [ ] The translate language list is in three files (`TranslateView`, `TranslateCard`, `CapturePage`)
- [ ] `scripts/check.sh`: the CLAUDE.md checks plus shellcheck in one command
- [ ] `services/Brightness.qml` takes the first backlight device by name; `services/Lock.qml` sizes the blurred backdrop from the first screen only
- [x] `hypr/scripts/fuzzel-emoji.sh` is 1,950 lines of data inside a script — the data is `shell/lib/emoji.tsv` now (13e)
- [ ] Saved screenshots are named with `date`, which follows the locale calendar (year 2569 under `th_TH`), while recordings use Qt and say 2026

## Verification

Every change: `./install.sh --check`, `hyprctl reload && hyprctl configerrors` (empty), `hyprctl binds -j | jq length` (201), `timeout 10 qs -p shell/shell.qml 2>&1 | grep -E "WARN|ERROR"`. CLAUDE.md has the IPC calls for each part of the shell. A fix that cannot be tested on this hardware is noted as untested instead of ticked.
