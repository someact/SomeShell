# SomeShell (rebuild)

A shell where everything happens through one **Island**, and the island changes with the workspace you are on.

> [!info] Status
> Brainstorm only, no code yet (2026-11-02). The old shell is archived as git tag `archive/shell-v1`; this machine still runs it until the new one is ready.

---

## 1. Why rebuild

The old shell grew feature by feature and the base got messy. Problems to never repeat:
- **Super+Tab sometimes can't switch workspace.**
- **Focus gets lost**: after changing workspace, the window there is sometimes not focused.
- **Blender misbehaves** with the shell running.
- Too many layers (glass, themes, pills, two layouts) built on top of each other, so every fix breaks something else.

The new shell starts from the rules in section 6 (System), so these bugs can't come back.

---

## 2. Look: "editorial monochrome"

Not just flat color. It should feel like a printed poster or a magazine page: ink on paper, made by hand.

References:
![[Desktop - 1.png]]
![[34c9c50bafd3346d2da96fa647d64e4d.jpg]]
![[d86c52d8d7c6c3f4043ed6eab1779724.jpg]]
![[ef227bd714c9fd1866ddb2c18e217872.jpg]]

What these images have in common, and how it could become the shell:

| In the posters | In the shell |
|---|---|
| Black and paper white, strong contrast | Colors come from the wallpaper (matugen): a dark ink and a light paper tone from its palette, and its accent for active things. The poster feel comes from type, lines and layout, not from removing color. |
| Huge headline type (MOON, DECAY) | The clock, the workspace name and the page titles are set big in Mitr SemiBold. |
| Small spaced-out caps (LIFE IS BUT A FLEETING MOMENT) | Labels, metadata and hints: small, uppercase, wide letter spacing, in Mitr. |
| Thin rules, crosshairs `+`, corner marks | Panels get hairline borders and corner marks instead of shadows or glass. Separators are drawn lines. |
| Index numbers, dates, barcodes, MMXXVI | Details that make it feel designed: `01 / 05` on pages, the date in small caps, a barcode-style progress bar. |
| Outlined pills and icon boxes | Buttons are outlined when off and filled ink when on. |

**Shape (from Desktop - 1):** the island is a black tab hanging from the top edge. It's flat against the screen edge with rounded bottom corners. The workspace is a small round badge top-left, and the system tray is another tab top-right. Little else is on screen.

**Motion: like print, not like jelly.**
- Opening: the island grows down from the edge, and its contents are revealed by a wipe, line by line.
- Lines draw themselves (a rule grows from left to right).
- Numbers roll like an odometer (clock, volume, battery).
- Text can type in for short labels (a notification title).
- Hover: an outline appears and the crosshair marks slide in. Press: invert (ink ↔ paper).
- Fast and exact (150–300 ms), with a small spring only where a shape changes size.

**Light and dark:** dark is a dark paper with light ink, light is a light paper with dark ink (like Desktop - 1). Both are first-class, both in the wallpaper's colors.

> [!check] Decided (2026-11-02)
> - Colors follow the wallpaper (matugen), every color, in light and dark.
> - One font for now: Mitr (Light, Regular, Medium, SemiBold).
> - No grain or texture.

---

## 3. The island

Everything is done through the island: control, search, media, all with just the **Super** key.

### 3.1 How to call it
- **Super key:** press to open the island on the search page. Arrow keys to move, Enter to choose, Super or Esc again to close.
- **Mouse:** move onto the island and it **peeks** (grows a little and shows more). Click it to open fully, click outside to close. When it was opened by hover, moving away closes it.
- **Shortcuts to a page:** e.g. Super+V clipboard, Super+. emoji, Super+A control panel.

### 3.2 States
| State | When | Looks like |
|---|---|---|
| Rest | nothing happening | small tab: time, day, date |
| Live | music playing, recording, timer, call | tab grows to the side with a cover or dot, keeps the clock |
| Alert | a notification arrives | drops down for a few seconds, then back to rest |
| Peek | pointer on it | a bit bigger, shows a preview of the page |
| Open | Super or click | full panel with pages |
| Quiet | fullscreen game, do not disturb | shrinks to a thin line or hides |

### 3.3 Changes with the workspace (the main idea)
In the desktop editor (section 4) each workspace can get its own design: a name and what the island shows when resting. This is saved as part of the preset. Examples:
- `01 WORK`: rest shows the clock and next calendar event.
- `02 CODE`: shows the focused project or git branch, and DND on.
- `03 ART`: shows the pen and tablet state and a color picker shortcut, and the dock hidden.
- `04 PLAY`: the island goes quiet, game mode on.
- `05 MEDIA`: shows the playing media large.

Switching workspace animates the island to the new layout, and the workspace name flashes big for a moment like a poster headline.

### 3.4 Pages
Pages in the open island, switched with Tab or arrows, numbered `01 / 07`:

**Search (first page)**
- Apps, quick math, files maybe later.
- `/` for commands: `/clip` clipboard history, `/gif`, `/emoji`, `/wall` quick wallpaper change, `/preset` switch preset, `/edit` edit desktop, `/settings`.
- Results as a clean list with big type for the top match.

**Control panel** (like Android and iOS)
- A snap grid with block sizes **1×1, 2×1, 1×2, 2×2**. Long-press or the pencil enters edit mode: blocks wiggle, drag to move, pull a corner to resize, remove or add from a drawer. The same editor arranges the island and the desktop (section 4).
- Each block is a toggle. Click it to go into its own page, like a phone.
  - **Internet:** Wi-Fi list, connect, forget, Ethernet, edit DNS, IP and proxy.
  - **Bluetooth:** pair, connect, rename, switch the audio device.
  - **Keep awake:** forever or for a time.
  - **Night light:** on/off, how warm, schedule (sunset to sunrise or set times).
  - **Do not disturb:** no notifications and no island alerts. Until a time, or while a game or screen share runs.
  - Also: sound output and mixer, mic, brightness, dark mode, game mode, screenshot, screen record, color picker, VPN/WARP, Quick Share, battery (laptop).

**Media**
- A browser extension (Zen/Firefox, later Chrome) sends the page info to the shell: site, title, full-size cover, and whether it's music.
  - music.youtube.com, Spotify web, SoundCloud → **music**
  - youtube.com, Netflix, other video → **video**
  - Without the extension: normal MPRIS, guessed by the player name.
- **Music design:** peek like a phone lock-screen player (cover, title, artist, progress). Full panel: big cover, synced lyrics, like button, queue, volume for that player.
- **Video design:** peek with a 16:9 thumbnail and progress. Full panel: thumbnail, chapters if any, skip ±10 s, picture-in-picture maybe.
- Poster touch: the track title set big, artist in spaced caps, the year and duration as small metadata.

**Notifications**
- Grouped by app, swipe or click to dismiss, reply when the app allows.
- History with "today", "yesterday".

**Calendar**
- Month grid like a printed calendar, today circled.
- Events from a local `.ics` or online calendar (decide later).

**Resources**
- CPU, GPU, RAM, temperature, disk, network.
- Drawn as editorial charts: thin lines, big numbers, no gauges.

**Operation (power)**
- Lock, sleep, log out, restart, shut down.
- Hold to confirm, the button fills like ink.

---

## 4. Edit desktop

One edit mode for the whole desktop, like a phone home screen. Open it with `/edit`, a right-click on the desktop, or a long press.
- The desktop zooms out a little and a grid appears.
- **Widgets:** a drawer at the bottom, drag a widget onto the desktop, it snaps to the grid, pull to resize.
- **Island:** choose a style, position (top center, top left…) and what it shows when resting.
- **Dock:** on/off, position, auto-hide, pinned apps.
- **Wallpaper:** swipe through wallpapers right there, the colors update live.
- **Workspaces:** name each workspace and design what its island shows (section 3.3).

**Presets.** After setting up the desktop (wallpaper, workspace designs, widgets, island, dock), save it as a preset, for example "Clean", "Work" or "Stream". Apply any preset any time with `/preset` or from the editor, and the whole desktop changes to it. Editing a preset and saving updates it; "save as new" makes another.

Widget ideas: clock (poster style, huge), now playing, calendar, notes, system, weather, photo frame, quote or text (for poster-like typography on the desktop).

---

## 5. Other parts (smaller)
- **Workspace badge** (top-left): the workspace number in a circle. Click for overview, scroll to switch.
- **Tray tab** (top-right): system tray and status icons.
- **Overview** (Super+Tab): workspaces as a row of "pages" with their names big. It must always switch (see section 6).
- **Lock screen:** big clock in poster style, password dots that pop in and shake when wrong.
- **Dock:** optional, hidden by default?
- **On-screen keyboard, capture tools, game overlay:** later, after the core works.

---

## 6. System (how it's built)

Rules that fix the old bugs by design:

1. **Hyprland owns windows and focus, the shell never does.** Switching workspace, focusing and moving windows are always Hyprland dispatches. The shell only asks; it never keeps its own idea of which window is focused.
2. **The shell takes keyboard focus only while you type in it.** When the island closes, focus goes straight back to the window under it. No layer keeps `Exclusive` focus. This is the likely cause of "window not focused after switching workspace" and of Blender problems.
3. **Keys stay with apps.** The shell grabs as few global keys as possible. Super alone opens the island only when it's pressed and released with nothing else, so Blender, games and other apps keep every Super+key combo.
4. **Overview is simple and reliable.** Super+Tab always switches. Clicking or pressing Enter on a workspace switches and closes, every time.
5. **Small core, clear parts.** One service per system thing (audio, network, bluetooth, media, notifications, power). Pages only load while open. No polling: everything reacts to events.
6. **Light.** No glass by default, no blur on big areas. A memory and idle-CPU budget checked on every big change.
7. **Settings live in the shell.** Edit mode and the control panel replace most of the separate settings app; a settings page remains only for rare options.
8. **Testable.** Every feature can be triggered from the command line (IPC), so each bug can be reproduced and tested after a fix.

Before building, reproduce each old bug on v1 and write down the cause, so the design really avoids it:
- [ ] Super+Tab not switching workspace: when, and what was focused
- [ ] Window not focused after a workspace change: with keys, mouse or overview?
- [ ] Blender: what goes wrong (shortcuts, menus, focus, tablet)?

> [!check] Scope (decided 2026-11-02)
> Everything is rebuilt fresh: the shell, the Hyprland config (keybinds, rules, look), colors, installer. Nothing is brought back from the old version; it's only read to learn what went wrong.

---

## 7. Build order (draft)
1. Design page: the look from section 2 on a few screens (rest island, open search, control panel, music), to approve before code.
2. Hyprland config, fresh: keybinds, window rules, look, focus behavior (rules 1–4 in section 6).
3. Base: colors from the wallpaper, Mitr, motion parts, the island window with its states.
4. Search and commands.
5. Control panel with the snap grid.
6. Media and the browser extension.
7. Notifications, calendar, resources, power.
8. Edit desktop, widgets, presets.
9. Lock, overview, dock, installer, the rest.
