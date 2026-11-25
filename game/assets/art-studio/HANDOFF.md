# ETERNAL ASCENSION — ART STUDIO HANDOFF PACKAGE
Prepared 2026-11-25 by the Art & Asset Production Studio (Muse, Art Director) for the developer / any future art hire. Read this first, then VISUAL_BIBLE.md (the single source of truth — art direction, palette, registry, QC verdicts, production flags).

## STATE OF THE STUDIO
Prototype program COMPLETE (Phases 1–12). 43 registered assets (EA-IDs), 45 art files in the repo, every one QC'd and filed. Everything is CONCEPT/PROTOTYPE level — by design. Production sprite/tileset work is gated on developer specs (see BLOCKERS).

## WHERE THINGS LIVE (game/assets/art-studio/)
- VISUAL_BIBLE.md — the bible. HANDOFF.md — this file.
- assets/ — game-facing art in Jawanza's structure: characters/{player,npcs,companions}, enemies/{beasts,demons,bosses}, environments/{terrain,vegetation,buildings,props}, items/{weapons,armor,consumables,materials}, vfx/{combat,elements,cultivation}, ui/{icons,portraits,panels}, audio/ (empty).
- marketing/ — key art (EA-MKT). reference/ — storytelling reference only (EA-ENV-0001, NEVER a game background). rejected/ — failed QC, kept for the record. tests/ — seam-test evidence.

## LOCKED DECISIONS (do not relitigate without Jawanza)
1. Direction B "Spirit-Ink Cel Painterly" — ink #1E1B18 outlines, 2-step cel, hand-painted texture, light always upper-left. A (ink-wash) = storytelling only. C (semi-realistic) = rejected.
2. Amendment 1: gameplay backgrounds are TILESETS ONLY. Painted scenes are reference/mood, never backgrounds.
3. Proportions: HOLD 3 HEADS for adults (chibi rejected, EA-CHR-0002 v1 in rejected/).
4. Rarity = shape + ornament escalation, never color alone (proven, EA-WPN-0002 + EA-UI-0004).
5. Corruption = structure change (cracks + crystals + eye shift + aura), never recolor (EA-ENE-0008). Shadow violet ≠ corruption violet (EA-SEC-0003 rule).
6. Breakthrough ≠ level-up (EA-VFX-0002 vs. small ring spec). Tribulation language never reused for player skills.
7. Sect identity = one motif × four surfaces (emblem/banner/uniform/architecture); rank = trim metal (EA-SEC-0001..0004). The 12 canon sects are NOT yet kitted — names/doctrines come from the developer; the four kits are path archetypes + the player-founded template.
8. No baked text in key art/UI art; glyphs stay abstract (no character-like marks) — see flags.
9. UI language: ink-brown panels, jade/bronze cloud trim, bronze plaque buttons, rarity = frame ornament (Phase 7).
10. AI generations feed the CONCEPT step only; production art is frame work (bible §17.3).

## BLOCKERS — SPECS NEEDED FROM THE DEVELOPER (bible §17.5)
1. TILE SIZE (px) — blocks all tileset production. 2. Sprite frame size. 3. Direction count (4 vs 8; studio recommends 8 for player/bosses). 4. Animation FPS targets. 5. Atlas max size + Godot import filter. 6. Pivot/Y-sort confirmation. 7. Target resolutions + UI scaling. 8. Particle/lighting perf budget.
Until 1–4 land: stay at concept level. FIRST production job when unblocked = the Founder pilot animation set (bible §17.3).

## OPEN PRODUCTION FLAGS (collected from all phases)
- EA-CHR-0002: sprite is a single-pose prototype, not a sheet; ribbons on EA-CHR-0003 shorten for sprites; EA-CHR-0005 talisman glyphs stay abstract, aura ships as separate VFX layer.
- EA-ITM-0001: pill glow ships as a separate layer.
- EA-ENV-0003: grass needs 3–4 variant tiles + flips to break the repeat lattice. EA-ENV-0004: stone rows FAILED QC — regenerate as flagstone before production. EA-ENV-0005: shoreline/waterfall rows need discrete-tile rework. EA-ENV-0006: props ship as individual transparent sprites, shadows separated — never slice the sheet.
- EA-ENE-0004: ember spirit needs a tighter core silhouette at sprite size. EA-ENE-0005: crane tail feathers shorten/cluster. EA-ENE-0007: mantis chitin glyph-marks stripped to cloud-scroll engraving in production.
- EA-VFX-0002: production ground array = pure geometric rings, no glyph marks. EA-VFX-0003: tribulation splits into 4 layers (sky/bolt/impact/rain).
- EA-UI-0003: empty inventory slots always use the plain gray frame; scroll icon uses the blank-tag Phase 5 design.

## BACKLOGS (per department, bible §12–§21)
Characters: NPC variety, children/teen proportions, faction uniforms, mounts. Creatures: human enemies/rogue cultivators, mythical (endgame, last), elite variants. Environments: 9 more biomes, dungeon kits, interiors, weather/season variants. Items: saber/staff/bow/fan/flying sword, accessories, elixirs, ores, relics, breakthrough materials, chest. VFX: full elemental skill sets, shields, dash, impacts, death/soul, portals, weather. UI: dialogue box, quest tracker, shop, sect management, map, boss bar (bell motif), accessibility variants. Sect: 9+ canon kits pending developer doctrines.

## AUDIT NOTE (Phase 12)
Registry↔repo reconciliation run 2026-11-25: 43 unique EA-IDs, all files present. One defect found and fixed: EA-ENV-0001's registry filename now matches the repo file (environment_bamboo_sect_scene_reference.png). Filename-like strings in the bible's naming-convention examples (e.g. player_founder_idle_south.png) are illustrations of the convention, not assets.
