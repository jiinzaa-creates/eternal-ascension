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

## INTEGRATION — TEXTURE WIRING DONE IN-HOUSE (2026-11-25, supersedes the Freebuff brief)
Jawanza reassigned the integration from Freebuff to the studio. The game now renders the art:
- `game/systems/actor_sprite.gd` (ActorSprite): frame swapper driven by the existing pose Animator (idle / walk stride by swing phase / attack), 8-direction quantise, never flips frames, mirrors the pose bob/lean/squash. Fallback chain: missing frame -> idle of that direction -> idle south -> component inactive and the entity keeps its code-drawn body. One warning per missing set.
- Wiring: Player (Founder set; robe colourway follows `appearance.robe`, robe 2 = master at root, others from colourways/robe_{i}/), Npc (role first — Elder/Sword Cultivator/Merchant/Farmer/Guard->Sentinel/Outer Disciple->Founder — then archetype fallback), Dummy (spirit beasts by species_id: moonfang->Spirit Wolf set, stoneback->Boar, thundercrane->Crane, gloomserpent->Serpent centre-anchored; bosses by archetype at 1.7x scale with a 30% tint toward the boss colour; biome humans by name-variant folder when one exists, else the archetype set; a body with no identity applied keeps its shapes).
- `game/systems/terrain_tiles.gd` (TerrainTiles): one runtime TileSet per biome from the terrain tiles (grass/dirt/flagstone/water/cliff/waterfall/transitions as sources). Chunk ground paints a TileMapLayer (z -20, 32x32 cells, hash-varied grass + ~7% dirt) and skips its flat rect while tiles are on. Overworld chunk data has no water features, so water/transitions are in the set but unpainted in the overworld.
- Toggles (project.godot [art_studio]): `use_sprites`, `use_tiles`, both default true. Off = the original code-drawn renderer, untouched.
- Deliberately not wired: hair/skin variant frames (idle-only full frames; a clean hook exists via ActorSprite.configure), technique Summons (generic tinted shapes by design, no set was ever produced for them), props/buildings/interactables (still shapes), the Ancient Stone Guardian set (no boss in data/bosses.json uses it — all nine are humanoid archetypes), corpse/ember/carp/mantis sets (no species in data/spirit_beasts.json spawns them).
- Verification: unit suite 4330 PASS / 0 FAIL after the change; headless boot clean; Linux export boots clean; Xvfb live run of the real game (title -> New Game -> settlement) screenshotted with sprites + tiled ground; `game/tests/visual_check.gd` is the repeatable harness (real input, texture-path reports per actor).

## Props / buildings / herbs (2026-11-25, later)
Prop, Building and chunk-herb rendering now use Art Studio textures the same way actors do (see VISUAL_BIBLE §76): props pick biome-graded variants, buildings are per-location sprites anchored to their footprints, herbs show their resource-node art and hide it when harvested. All keep primitive fallbacks under `art_studio/use_sprites`. The visual harness scans the live world and screenshots props, herbs and the settlement (stages 6-8).

## Appearance overlays (2026-11-25, later)
Hair and skin colourways are no longer idle-only: 288 overlay frames under `colourways/hair_{i}/overlay/` and `colourways/skin_{i}/overlay/` stack over any robe set at runtime (ActorSprite child layers; Player configures them from `appearance`). The full 180-combination appearance matrix renders in motion. See VISUAL_BIBLE §77 for method and measured mask accuracy.

## UI frame language (2026-11-25, later)
All HUD panels, pages, menus, the title screen, skill bar, shop/travel panels and the world map now draw through `ui/ui_frame.gd` (UiFrame): bronze corner ticks, bronze-dim rules, jade hairlines, plaques — the studio's UI lock expressed in the game's code-drawn style. The authored + high-contrast palettes are untouched. See VISUAL_BIBLE §78.

## HUD diet, minimap, menu hub (2026-11-25, later still)
Per Jawanza's spec the ambient HUD is now only: HP/Qi orbs top-left, skill slots bottom-left, a live circular minimap bottom-right, and a MENU button beside it that opens a grouped, keyboard-navigable hub for every system (Esc). Everything else moved to its page. See VISUAL_BIBLE §79.

- §80 (2026-11-25): F-keys fully remapped (help ?, mute `, save 8, load 9, council 7, my sect 0, stories ., archive ,, endgame Z, settings X); HUD mouse live (hub hover/wheel/click, clickable MENU plaque, list-page wheel/click via shared hit table); HUD skill-slot click opens the arrange panel, which gained click-to-place and wheel-swap; all 14 hud pages clamp to the viewport via _page_rect. Suite 4330/0; mouse paths probe- and screenshot-verified; fit verified at 1024x576.

- §81 (2026-11-25): KEYBINDS tab made a proper spot (plaque tabs, hub Keybinds entry, full mouse incl. capture); Quit Game added to the hub (saves, then exits; probe-verified); cultivation trap FIXED — the meditating physics branch returned before input, so F/movement could never stop it; stop inputs now read first (F/step/dodge/interact), plus a CULTIVATING plaque with the stop hint. Suite 4330/0.
