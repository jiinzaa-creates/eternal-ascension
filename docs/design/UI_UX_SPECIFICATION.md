# ETERNAL ASCENSION — UI/UX SPECIFICATION

**Basis.** This specification describes the UI **as implemented** (the implemented
UI is the spec), drawn from the Visual Bible §§78–81 (which record the 2026-11-25
UI work) and the compliance matrix M71. Requirement gaps against the Directive and
roadmap are listed at the end, not smoothed over.

## Frame language — `game/ui/ui_frame.gd` (UiFrame)

The game's UI is code-drawn by design, so the art direction's UI lock (ink-brown
panels, jade/bronze cloud trim, bronze plaque buttons) is implemented as a drawing
grammar, not textures:

- Anchors: bronze `#b08b3d`, bronze-dim `#6a5638`, jade `#3d8a68`.
- `panel()` — fill + bronze-dim rule + jade hairline + bronze corner ticks.
- `page()` — the page's own accent rule preserved + bronze inner hairline + corner
  ticks; every page keeps its own accent-colour identity.
- `card()` — warmed bronze-dim rule. `plaque()` — prompts, banners, menu rows,
  toasts. `divider()` with a bronze heart. `frame()` for the world-map grid.
- Applied across: HUD panels and pages, the title screen (framed panel + plaque
  menu rows; selected row = bronze plaque + accent bar), the skill-bar panel,
  shop/travel panels, and the world map.
- The authored palette and the high-contrast accessibility palette are unchanged by
  the frame language; frames and dividers only — no layout, text, control name or
  behaviour changed when it was applied.

## HUD (ambient layer)

The ambient HUD shows only:

- **HP and Qi as liquid orbs, top-left** (Diablo-style, bronze rings, low-HP pulse;
  HP orb centre (62,62) r42, Qi orb (142,70) r34 in the recorded layout).
- **Skill slots, bottom-left** — three skill bars × 6 slots (18 total, per M34);
  the bar is a readout in combat: clicking a HUD slot opens the arrange panel
  rather than rearranging mid-fight. In the panel: click-to-pick-up / click-to-place,
  wheel walks unplaced arts into a slot, right-click clears or cancels a held art,
  drag-and-drop still works.
- **Circular minimap, bottom-right** — terrain sampled live from the streamed
  ground tiles (per-source average colour, cached), herbs and POIs from chunk
  payloads, NPCs as jade dots, enemies as red dots, the waypoint as a gold diamond
  (rim-clamped), the player as a facing arrow; bronze rim with accent sweep and an
  N marker. Palette fallback when tiles are off.
- **MENU plaque beside the minimap** (clickable) and transient feedback: prompts,
  toasts, event banners, and a **CULTIVATING plaque** under the orbs while
  meditating ("F to stop · step to rise").

Everything else that used to sit on the ambient HUD (world panel, satchel panel,
quest tracker, party/captives panels, NPC dossier, statuses, boss bar, waypoint
strip, help strip) lives on its system page.

## Menu hub

Esc (when no page is open) opens a grouped hub — **CHARACTER / WORLD / SECT /
SYSTEM** — listing every system page with its direct key on a bronze chip.
Up/Down + Enter activates through the same open functions the direct keys call;
Esc closes a page first, then opens the menu; world simulation pauses while the
menu is open. The hub's SYSTEM group includes a **Keybinds** entry (opens Settings
on the keybinds tab) and ends with **Quit Game** (saves to slot 1 via the
quick-save path, then quits). Key help lives in the menu footer.

## Input

- **No F-key bindings in defaults.** The 2026-11-25 remap (in `core/settings.gd`
  defaults): help `?`, mute `` ` ``, council `7`, quick save `8`, quick load `9`,
  player sect `0`, storylines `.`, narrative archive `,`, endgame page `Z`,
  settings `X` — all collision-free and all rebindable. A player's saved bindings
  file overrides defaults until reset in Settings.
- **Full mouse support in menus:** hover highlights, the wheel walks cursors and
  scrolls list pages, click selects, clicking the selected row activates it, click
  outside closes the hub. List pages (ledger, council, player sect, storylines)
  share one hit-test table mirroring their draw geometry.
- **Keybind customisation** lives in Settings on a plaque-tabbed DISPLAY / KEYBINDS
  page: click a binding row to start key capture (Enter-then-press, Esc cancels,
  Backspace unbinds, reset-all row at the bottom).
- **Cultivation stop affordance:** meditation toggles with F; the stop inputs (F
  again, any step, dodge, interact) are read before the meditating branch can
  swallow them — a bug found by play and fixed 2026-11-25 — and the CULTIVATING
  plaque states the way out while it applies.

## Layout rule

Every full-screen page takes its rect from `_page_rect()`: the authored size,
centred, clamped to the viewport minus a 32px margin; hit tests read the same
rect. (Verified at 1024×576 in the Bible §80 record.) Shop, travel, world map and
the skill panel are size-relative by construction.

## Accessibility (per M71)

Settings/accessibility screen: rebindable actions, high contrast, reduced motion,
volumes. The frame-language work preserved the accessibility palette untouched.

## Requirement gaps (Directive/roadmap vs the implemented UI)

Per the compliance matrix M71 and the 2026-11-26 addendum, the following required
surfaces **do not exist** and are not specified here because there is nothing
implemented to specify:

- Dedicated cultivation screen and realm-progression screen.
- Root/physique screens (the data lives on the character sheet / HUD lines).
- Passive collection screen.
- Technique library screen.
- Quest journal screen (a HUD tracker existed pre-diet; quests now live behind
  their page access, with no journal screen).
- Party management screen.
- Dialogue UI.
- A tooltips system.
- Skill-bar slots do not display Qi costs (per M34).

Typography is code-drawn throughout.
