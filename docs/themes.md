# Themes

> Paused 2026-11-01 for Phase 16 (new flat front-end). The rules and roles below still guide the new front-end; the migration plan for the old views no longer applies.

SomeShell is one shell with switchable looks. The features, layout and services are shared. A theme changes only how things look: colors, shapes, type, effects and a few signature parts. A new look means a new theme folder, not a fork. SomeShell Reimagined (pop-art) and SomeRenaiShell (Renaissance) were forks; they come back as themes.

The tasks are in `plan.md`, Phase 15. Decided with the user on 2026-11-01.

## Rules

1. **The engine stays the same.** Services, IPC, commands, settings, island states and positions belong to the engine. A theme cannot move the island, add a bar or change what a view does.
2. **Views never style themselves.** A view (`island/views/*`, `corners/`, `dock/`, …) builds its UI only from theme primitives and theme roles. It uses no hex colors, `Qt.rgba`, numeric radii or font names. `scripts/check.sh` enforces this (15d).
3. **Colors always come from the wallpaper.** matugen remains the only color engine. Each theme maps matugen's colors to its own roles, so every theme fits every wallpaper. A theme may add fixed colors as materials, like fresco's gold, but never fixed base colors.
4. **Every theme has the full set of primitives.** A missing signature part falls back to `themes/base/`.
5. **Glass is the default theme** and looks the way SomeShell does today.

## Where SomeShell is now (2026-11-01, at 79ccc90)

The styling is mostly central, but not completely:
- 195 QML files, 104 of which read `Theme.*`
- 29 files use `Qt.rgba` outside `core/Theme.qml`, and 11 use hex colors (5 of those are in `overlay/`)
- 33 files set a numeric `radius:` (15 in `island/`, 5 in `overlay/`, 5 in `settings/`)
- 55 files draw raw `Rectangle`s; `Glass`/`GlassRegion` appears in 7

So 15d (moving the views onto primitives) is the large job. Reimagined changed 127 files (+7,400 lines) because it had no theme layer to change instead.

## Layout

```
shell/
  core/Theme.qml          roles + tokens of the active theme (the only thing views read)
  components/             engine-only pieces with no look of their own (KeyNavList, Reveal, Spring, …)
  themes/
    base/                 fallback signature parts, shared helpers
    glass/                default: SomeShell's current look
      Theme.js            roles from matugen colors, tokens (radius, line, fonts, motion)
      Surface.qml  Tile.qml  Button.qml  IconButton.qml  Toggle.qml  Slider.qml
      Progress.qml  Badge.qml  Label.qml  Icon.qml  SectionHeader.qml  Selection.qml  Separator.qml
      parts/              optional signature parts (see below)
      hypr.lua            window rounding, borders, blur, animations for this look
      meta.json           name, fonts it needs, options it offers, preview image
    pop/                  from SomeShell Reimagined
    fresco/               from SomeRenaiShell
```

## Roles (what views can ask for)

| Group | Roles |
|---|---|
| Surfaces | `surface` (panels), `surfaceIsland`, `surfaceRaised` (a control on a surface), `recess` (sunken track or tile) |
| Text | `fg`, `fgDim`, `fgOnAccent` |
| Color | `accent`, `second`, `third`, `deep`, `danger` (all from matugen through the theme's mapping) |
| Lines and light | `line`, `lineStrong`, `glow` (the active or selected mark), `shadow` |
| Shape | `radius.{small,normal,large,island,full}`, `lineWidth`, `space.*` |
| Type | `font.{display,title,ui,caption,inscription,mono,icon}`, `iconWeight` |
| Motion | `motion.{open,close,hover,press}` springs, `motion.event` (the one effect on an island state change: none, glass ripple, pop fringe pulse, fresco gold sheen) |

## Primitives

A view describes its intent with `kind` and `state`; the theme decides the look.
- `Surface { kind: island | panel | card | pill | dock | popup }`
- `Tile { on; size: icon | title | full }` is a quick option tile (a glass chip, a pop manga panel, a fresco coffer)
- `Button`, `IconButton { kind: plain | primary | danger }`
- `Toggle`, `Slider`, `Progress { kind: bar | ring }`, `Badge`
- `Label { role: display | title | body | caption | inscription }`, `Icon`
- `SectionHeader { text; sub }`. `sub` is the theme's caption: pop shows Japanese, fresco Italian or Latin, glass hides it
- `Selection` is the moving highlight in lists and grids
- `Separator`

## Signature parts

Each theme may replace a few whole parts, each with a fixed interface:

| Part | Glass (base) | Pop | Fresco |
|---|---|---|---|
| `MediaArt` | rounded cover | spinning CD with obi slip | round framed painting with a gold ring |
| `NotificationCard` | glass card | speech balloon (a shout when critical) | letter with a wax seal |
| `AmbientClock` (collapsed island) | time | ticket | time with a Roman date |
| `WorkspaceItem` | dot or number | tilted sticker | Roman numeral with a lozenge |
| `DockItem` | icon | sticker that jumps | pigment tile with a plaque label |
| `LockSurface` | current lock | pop lock | arched niche |

## Switching themes

Run a spike before building on it (15a). There are two ways to swap the primitives:
- **Relink and reload:** `shell/themes/current` is a link to the chosen theme, and views import from it. Switching relinks it and Quickshell reloads. There's no runtime cost, and a reload of about a second on switch is fine for something done rarely.
- **Loaders:** each primitive is a `Loader` that picks the theme's file. Switching is live, but there are hundreds of extra Loaders on screen.

The spike measures both with `hypr/scripts/bench.sh` (start time and memory). Unless the numbers say otherwise, relink and reload wins. The settings app is a separate process and follows the same link.

## Beyond the shell

- **Hyprland:** the theme's `hypr.lua` goes to `hypr/generated/theme.lua`, with rounding, border gradient and blur. Game mode still overrides it.
- **Fonts:** `meta.json` lists them. The installer installs the fonts of every bundled theme, and the theme picker warns if a font is missing.
- **matugen templates** (GTK, KDE, terminals, Zen, Vesktop) stay shared. A theme may add a template later; it isn't needed to start.
- **SDDM:** one theme for now. A per-theme login screen comes later.

## Where the looks come from

- **glass:** SomeShell today (`components/Glass.qml`, `GlassRegion.qml`, the current `Theme.qml` values)
- **pop:** `/mnt/ssd_backup/Projects/SomeShell-Reimagined/`, with its design in `CLAUDE.md` ("Decisions" and "Own style, v2"), `preview/v2.html` and `docs/plan.md` 2a–2w. Its primitives are `components/Block`, `Sticker`, `StickerShape`, `PaperTone`, `ToneStamps`, `Halftone` + `shaders/`, `PopText`, `PopChip`, `PopProgress`, `Tilted`, `lib/sticker.js` and `lib/palette.js`. The auto comfy/compact top bar density is an engine feature, so it moves to the engine for every theme.
- **fresco:** `/mnt/ssd_backup/Projects/SomeRenaiShell/`, with its design in `SomeRenaiShell.md` and an interactive mockup in `preview/index.html`
