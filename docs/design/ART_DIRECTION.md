# ETERNAL ASCENSION — ART DIRECTION

**Source.** This document distils the locked art standard from the Visual Bible
(`game/assets/art-studio/VISUAL_BIBLE.md`, v0.2, Direction B locked 2026-11-25 with
Amendment 1). The Bible remains the working standard and asset registry; this
document is the M01 art direction filing. The Directive's own art requirement is
§17: a visually compelling 2D world, layered landscapes, atmospheric lighting,
weather and day/night, distinct regional architecture and character silhouettes —
and no placeholder graphics in the final production build.

## Locked direction

- **Direction B — "Spirit-Ink Cel Painterly"** is the permanent gameplay standard:
  hand-painted texture inside clean dark ink outlines, cel-assisted 2-step shading,
  strong silhouettes, saturated spiritual accents reserved for Qi/VFX/rarity.
  Direction A (ink-wash painterly) is permitted only for storytelling illustrations,
  re-outlined to B's ink colour. Direction C (semi-realistic painted) is rejected.
- **Amendment 1 — tileset backgrounds only.** Gameplay backgrounds are built from
  modular, seamless tilesets (ground, transitions, cliffs, water, vegetation, props,
  building kits). No large painted scene may be delivered or used as a gameplay
  background; a painted environment is a reference/mood piece only, decomposed into
  tiles. Storytelling art (loading screens, murals, boss intros) is unaffected.

## Technical standards (locked 2026-11-25)

| Standard | Value |
|---|---|
| Tile size | 32 × 32 px |
| Character sprite frames | 64 × 64 px (bosses 128 × 128 px) |
| Pivot | Feet baseline (feet pivot) for all frames |
| Directions | 8 directions; frames are never mirrored to fake a direction |
| Proportions | ~3 head-units tall (concept); sprite simplification keeps head, shoulders and robe triangle readable |
| Camera | Orthographic top-down oblique; characters/buildings in 3/4 front view; Y-sort by feet baseline |
| Light | Single key light from the upper-left (northwest) for every asset, every biome; biome tints change ambient colour, never light direction |
| Shading | Base + one shadow step + one highlight step; texture never breaks the silhouette |
| Readability rule | If an asset is not identifiable as a black silhouette at gameplay size, it fails QA |

## Palette anchors

- Ink outline: **#1E1B18** (continuous outer silhouette; thinner interior lines; no
  pure-black fills except the Void element).
- Visual Bible core palette: Paper #F2EDE4 · Jade #2E7D6B · Deep Jade #1F5C4D ·
  Stone #8A8D84 · Wood #7A5230 · Gold #C9A227 · Vermilion #C0392B · Spirit Cyan
  #4FD8D0 · Void Purple #3B2A5D, with per-element colours (Water #256D85, Earth ochre
  #B07A2A, Ice pale cyan #BFEFFF, etc.) and one core palette + accent + danger colour
  per biome.
- UI implementation anchors (as built in `game/ui/ui_frame.gd`, Bible §78): bronze
  **#b08b3d**, bronze-dim #6a5638, jade **#3d8a68** (see the UI/UX specification).

## UI lock

Ink-brown panels, jade/bronze cloud trim, bronze plaque buttons. Rarity is
communicated by **frame ornament + colour, never colour alone** — the same rule as
character rank (trim complexity, belt material, added ornaments, aura only at high
tiers) and item rarity (notch/band → engraving → inlay + tassel → unique guard +
glow → floating element + aura → patina + cracks → named silhouette).

## Design languages (summary; full text in the Bible §§3–5)

- **Characters:** silhouette first (robe triangle, topknot/hair mass, one signature
  shape); layers inner tunic / outer robe in sect or root colour / belt + pendant /
  footwear; armour sits over the robe silhouette. Each of the 12 sects has one motif,
  one primary colour, one metal. Concepts are not sprites — every concept is redrawn
  simplified for production.
- **Environments:** ground low-contrast and desaturated against characters; paths
  lighter/warmer than wild ground; vegetation as ink-outlined clustered masses;
  water teal-blue with white ink foam edge; architecture curved tile roofs and
  upturned eaves, wood warm-brown + stone grey; corruption is a palette shift +
  damage overlays on the same kits, not new geometry; hidden realms get one dominant
  surreal element each.
- **Creatures:** nine families (Beast, Avian, Aquatic, Insectoid, Undead, Elemental,
  Humanoid, Guardian, Mythical); variants by structure, not just colour (Elite,
  Rare, Champion, Boss steps add mass, markings and features); corruption read is
  cracked skin, black veins, red/void eyes as an overlay language.
- **Registry:** every asset carries an ID `EA-{DEPT}-{####}` (CHR, ENE, ENV, BLD,
  WPN, ITM, VFX, UI, STY) and snake_case filenames
  `{dept}_{subject}_{variant}_{state}_{direction}.png`, with QC status recorded in
  the Bible.

## Implementation status (2026-11-26)

The library is complete and integrated. Per the Bible (§§75–81) and the compliance
addendum: the full sprite + tileset library (1,200 art PNGs recorded in the parent
production record) was produced under the 2026-11-25 standing directive and wired
into the game — `ActorSprite` renders sprite sets under the existing pose animator
for Player/Npc/Dummy, `TerrainTiles` builds per-biome TileSets and chunk ground
paints real tiles, props/buildings/herbs are textured, hair/skin colourway overlays
render the full 6 robe × 6 hair × 5 skin appearance matrix, and the UI frame
language is implemented in code. Toggles in `project.godot` (`[art_studio]
use_sprites / use_tiles`) restore the code-drawn renderer when off. Contradiction
C10 (final art vs the code-drawn 1.0.0 release) is recorded as largely closed by
this integration. Remaining presentation gaps on record: water animation frames and
a small cosmetic list (Storm Crane beak colour, Abyss Jade Carp paleness); the web
export has not been rendered/played in a browser (addendum).
