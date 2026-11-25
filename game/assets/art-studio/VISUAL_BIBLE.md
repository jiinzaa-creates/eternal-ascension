# ETERNAL ASCENSION — VISUAL BIBLE v0.2 (DIRECTION B LOCKED 2026-11-25, WITH AMENDMENT 1)
Game: Eternal Ascension — 2D top-down open-world Xianxia action RPG, Godot 4.4.1
Status: Direction B APPROVED by Jawanza 2026-11-25 with one change (Amendment 1, below). This is now the permanent visual standard.
Scope note: This studio is art-only for Eternal Ascension. It is separate from Heavenfall and Project Ascension. It does not modify game code.

## AMENDMENT 1 — TILESET BACKGROUNDS ONLY (Jawanza, 2026-11-25)
Gameplay backgrounds are built from TILESETS, not big ornate background paintings.
- The game world is assembled in-engine from modular, seamless tiles: ground, transitions, cliffs, water, vegetation, props, building kits.
- NO large painted scene images may be delivered or used as gameplay backgrounds. A painted environment scene is a REFERENCE / mood piece only — it sets palette and architecture, then gets decomposed into tiles. It is never a production background.
- Tileset deliverables: individual tiles and/or gridded tileset sheets with seamless edges, matching directional transitions, and palette-consistent variations. No baked scene lighting, no baked shadows from a diorama view, no perspective scenery inside a tile.
- Dept. I storytelling art (loading screens, murals, boss intros) is unaffected — those are illustrations by design, not gameplay backgrounds.

## 1. THREE ART DIRECTIONS

### A — Ink-Wash Painterly (Shui-mo)
Soft watercolor edges, minimal outline, atmospheric washes, muted mineral palette.
Strengths: Beautiful key art, loading screens, murals.
Weaknesses: Poor readability at gameplay distance; silhouettes bleed into terrain; hardest to animate consistently; VFX and sprites blur together.
Verdict: Use ONLY for storytelling art (Dept. I), never for gameplay sprites.

### B — Spirit-Ink Cel Painterly [RECOMMENDED]
Hand-painted texture inside clean dark ink outlines, cel-assisted 2-step shading, strong silhouettes, saturated spiritual accents reserved for Qi/VFX/rarity.
Strengths: Reads at top-down distance; characters separate from ground; producible in batches; scales from mortal (matte, desaturated) to immortal (luminous, ornate) using the same base; suits Godot 2D Y-sort.
Weaknesses: Requires strict outline/palette discipline to stay cohesive.
Verdict: RECOMMENDED as the permanent gameplay standard.

### C — High-Detail Semi-Realistic Painted
Dense rendering, realistic materials, cinematic lighting.
Strengths: Impressive single illustrations.
Weaknesses: Fails at small sprite scale; slowest/costliest to produce; AI batch inconsistency highest; clashes with top-down readability rule.
Verdict: Rejected for production. Do not use.

RECOMMENDATION: Lock Direction B for all gameplay assets (Depts. A–H). Direction A is permitted only for Dept. I storytelling illustrations, re-outlined to B's ink color so the game never feels like two games.

## 2. VISUAL IDENTITY GUIDE (Direction B)
- Camera: Orthographic top-down oblique. Ground plane viewed from high angle; characters/buildings in 3/4 front view standing on the ground plane; north = screen up. Y-sort by feet baseline. No isometric diamond tiles unless the developer confirms otherwise (see Tech Requirements).
- Light: Single key light from upper-left (northwest) for every asset, every biome. Warm daylight default; biome tints change ambient color, never light direction.
- Outline: Ink #1E1B18, continuous outer silhouette, thinner interior lines. No pure-black fills except Void element.
- Shading: Base + one shadow step + one highlight step. Hand-painted texture only inside shapes; texture never breaks the silhouette.
- Proportions (humanoids): ~3 head-units tall in concept; sprite simplification keeps head, shoulders, robe triangle readable. Feet baseline is the anchor for all frames.
- Scale ladder: Mortal beasts ~0.7–1x human height; spirit beasts 1–1.5x; elites 1.5–2x; bosses 3–5x; world bosses 6x+ (multi-tile footprint, confirmed with developer).
- Readability rule: If an asset is not identifiable as a black silhouette at gameplay size, it fails QA regardless of detail.
- Power language: Power = light + ornament + aura, in that order. Low ranks: matte cloth, wood, iron. Mid: jade, bronze, silk trim. High: gold, floating elements, visible Qi aura, layered robes. Never communicate rank by size alone.

## 3. CHARACTER DESIGN LANGUAGE
- Silhouette first: robe triangle (wide hem, narrow shoulders), topknot/hair mass, one signature shape per character (sleeve, sash, weapon, ornament).
- Rank read (no color-only): (1) trim complexity plain → single band → double band → cloud pattern → floating trim; (2) belt: rope → cloth → leather → jade → gold/spirit; (3) one added ornament per tier band; (4) aura appears only at high tiers.
- Layers: inner tunic (off-white), outer robe (sect/root color), belt + pendant, footwear. Armor sits OVER the robe silhouette, never replaces it.
- Sect identity: each of the 12 sects gets one motif + one primary color + one metal; player-founded sects use the founder template with a custom motif slot (motif art TBD with developer).
- Hair: black default; white/silver only for age or specific cultivation states; dyed colors only via element/root language below.
- Concepts are NOT sprites. Every concept must be re-drawn simplified for sprite production; do not present a concept as an animation-ready sprite.

## 4. ENVIRONMENT DESIGN LANGUAGE
- TILESETS ONLY for gameplay backgrounds (Amendment 1). Modular tiles first — there are no production "scenes." Every environment reference must decompose into a tile/prop kit: ground, transition, cliff, water, vegetation, prop, building kits, delivered as seamless tiles or gridded tileset sheets.
- Ground: low-contrast, desaturated vs. characters (characters must pop). Paths are lighter/warmer than wild ground.
- Vegetation: clustered masses with ink outline on the cluster, not on every leaf. Bamboo, pine, peach/plum, spirit flora (glowing) as separate kits.
- Water: teal-blue base, white ink foam edge; animated variants are a production step, not a concept claim.
- Architecture: curved tile roofs, upturned eaves, wood warm-brown + stone gray base; sect buildings add the sect motif/color; mortal villages = thatch/wood, no gold; immortal realms = white jade, gold, floating geometry.
- Forbidden/corrupted zones: same kits, palette-shifted to ash/blood/void + cracked variants. No new geometry needed for corruption — recolor + damage overlays.
- Hidden realms: one dominant surreal element per realm (floating islands, inverted waterfall, giant tree) on the standard palette.

## 5. ENEMY & CREATURE DESIGN LANGUAGE
- Families: Beast (quadruped silhouette), Avian, Aquatic, Insectoid, Undead (tattered, desaturated), Elemental (form made of its element + ink core), Humanoid (uses character language, hostile trim), Guardian (stone/metal, symmetrical), Mythical (unique silhouette, never reskinned).
- Every creature entry requires: silhouette, size category (S/M/L/XL/World), palette, type, combat archetype (charger, spitter, ambusher, tank, summoner, etc.), element, animation list, VFX hooks.
- Variants by structure, not just color: Normal (base), Elite (+horns/armor mass + aura ring), Rare (unique marking + one extra feature), Champion (Elite + banner/standard or crown feature), Boss (size step + unique mechanic feature visible on the body).
- Corruption read: cracked skin, black veins, red/void eyes — applied as an overlay language across families.

## 6. COLOR PALETTE SYSTEM
Core: Ink #1E1B18 · Paper #F2EDE4 · Jade #2E7D6B · Deep Jade #1F5C4D · Stone #8A8D84 · Wood #7A5230 · Gold #C9A227 · Vermilion #C0392B · Spirit Cyan #4FD8D0 · Void Purple #3B2A5D
Elements: Metal #E8E4D8/gold · Wood jade green · Water #256D85 · Fire vermilion/orange · Earth ochre #B07A2A · Lightning violet-white · Ice pale cyan #BFEFFF · Wind mint · Poison acid green · Blood crimson · Soul ghost teal · Void black-purple
Cultivation visual tiers (12, names to be confirmed from design doc — do NOT invent canon names): T01–T02 matte earth/cloth, no glow · T03–T04 jade/bronze, faint trim glow · T05–T06 gold core accents, visible weapon Qi · T07–T08 violet/soul accents, light aura · T09–T10 strong aura, floating ornaments · T11–T12 white-gold luminous, immortal geometry, tribulation lightning language.
Rarity (shape + color, never color alone): Common (no ornament, gray-brown) · Uncommon (1 notch/band, green) · Rare (engraving, blue) · Epic (inlay + tassel, purple) · Legendary (unique guard/feature + glow, gold) · Mythic (floating element + aura, red-gold) · Ancient (patina + cracks + teal) · Unique (named silhouette, white/prismatic accent)
Biomes: each biome = core palette + 1 accent + 1 danger color. Bamboo/sect lands: jade/stone/warm wood. Desert: ochre/bone/vermillion. Snow: white/ice cyan/stone. Volcanic: charcoal/ash/lava orange. Immortal: white/gold/spirit cyan.

## 7. ASSET NAMING CONVENTION
Filenames: {dept}_{subject}_{variant}_{state}_{direction}.png — all lowercase snake_case, no spaces.
Examples: player_founder_idle_south.png · enemy_spirit_wolf_idle.png · boss_ancient_dragon.png · weapon_spiritual_sword_legendary.png · item_heavenly_spirit_pill.png · environment_bamboo_forest_ground.png · vfx_lightning_sword_slash.png · ui_skill_fire_dragon.png
Asset IDs: EA-{DEPT}-{####} — CHR (player/NPC), ENE (enemy/creature), ENV (environment), BLD (building), WPN (weapon/equipment), ITM (item/material), VFX, UI, STY (storytelling).
Registry fields per asset: ID, name, department, description, game use, visual requirements, format, target dimensions (TBD until tech specs confirmed), transparency, reference asset, generation prompt, production status, QC status.

## 8. PRIORITIZED PRODUCTION ROADMAP
P1 Art direction + visual bible (THIS BATCH) → approval gate
P2 Protagonist + founder character prototypes (concept → sprite test)
P3 Starting-area environment + terrain prototype kit (bamboo/sect lands)
P4 First creature prototypes (spirit wolf family + 1 mortal beast + 1 undead)
P5 Weapons/equipment/items prototypes (sword family, pill, spirit stone, scroll)
P6 Combat + cultivation VFX prototypes (sword slash, breakthrough, tribulation)
P7 UI + icon library prototype (skill icons, bars, inventory frame)
P8 Full environment library (all biomes, sect territories)
P9 Expanded NPC/enemy/boss + animation library
P10 Hidden realms + late-game/immortal assets
P11 Missing-asset audit + replacements
P12 Final consistency + QC review
Rule: No phase expands until the prior phase passes QC and Jawanza approves the direction gate at P1.

## 9. TECHNICAL REQUIREMENTS — MUST OBTAIN FROM DEVELOPER (do not invent)
1. Tile size in pixels (e.g., 32/48/64) and tileset grid/atlas layout used in Godot.
2. Character sprite frame dimensions and in-game character height in pixels.
3. Animation directions: 4 or 8? Frame counts per action and FPS.
4. Pivot/anchor convention (feet-center?) and Y-sort offset.
5. Godot import settings: texture filter (linear vs nearest), compression, mipmaps.
6. Max texture/atlas page size and naming/folder structure in res://.
7. Base game resolution / camera zoom for UI sizing and icon resolution.
8. VFX delivery: sprite sequences vs. Godot particles/shaders — which effects are art, which are engine?
9. UI font(s) and whether icon text is ever baked in (default: never).
10. Palette/color-space confirmation (sRGB) and any performance budget per scene.
Known already (verified): Engine Godot 4.4.1, top-down 2D, one seamless continent, 12 realms x10 stages, 12 root tiers, 12 sects + player-founded sects. Everything else above is UNCONFIRMED.

## 10. PROTOTYPE BATCH 01 — REGISTRY + QC (2026-11-25)
EA-CHR-0001 player_founder_concept.png — Dept A — Sect Founder protagonist concept, jade/white/gold — PNG, plain background (concept only, NOT transparent sprite) — QC: PASS as concept. Silhouette, anatomy, palette on-standard. Note: wide sleeves must simplify for sprite.
EA-ENE-0001 enemy_spirit_wolf_concept.png — Dept B — Azure Spirit Wolf, jade mane, antlers, cyan shoulder rune, mist tail — QC: PASS as concept. Distinct silhouette, anatomy clean, no text/watermark.
EA-ENV-0001 environment_bamboo_sect_scene.png — Dept C — Bamboo grove + training courtyard + pavilion + pond/waterfall scene — QC: REFERENCE ONLY per Amendment 1 (2026-11-25). It is NOT a production background and must never be shipped as one. Its only job is palette/architecture reference for the bamboo tileset kit (EA-ENV-0002 onward). View is oblique/diorama; tiles must be flat top-down.
EA-WPN-0001 weapon_spiritual_sword_legendary.png — Dept E — Legendary jian, gold blade, jade cloud guard, cyan Qi edge, red tassel — QC: PASS. Isolated, readable at small size, rarity shown by unique guard + glow, not color alone.
EA-ITM-0001 item_heavenly_spirit_pill.png — Dept F — Heavenly Spirit Pill, jade pill + gold swirl core + cyan Qi wisps — QC: PASS as icon concept (2026-11-25). Reads at small size. Production note: glow/wisps must be a separate layer from the pill body for icon use.
EA-VFX-0001 vfx_lightning_sword_slash.png — Dept G — Lightning sword slash arc, violet-white lightning + cyan edge, on black — QC: PASS as effect concept (2026-11-25). Production note: NOT sprite-ready — needs transparent/additive export and a frame sequence; black background is presentation only.
EA-ENV-0002 environment_bamboo_tileset_prototype.png — Dept C — First tileset sheet under Amendment 1: 8 tiles (grass, dirt, stone path, grass→dirt transition, water, water edge, bamboo floor, cliff) — QC: PASS as tileset STYLE prototype with 3 production flags: (1) shown as framed panels with gaps — production atlas must be edge-to-edge, no frames; (2) seamlessness NOT yet verified — edges require a tile test + cleanup (grass tile overhang will not tile cleanly as-is); (3) cliff tile reads side-view — must flatten to the top-down cliff convention. Palette/ink on-standard.
No asset in this batch is a finished animated sprite. All are concept prototypes for direction approval only.

## 11. PHASE 2 — CHARACTER PROTOTYPES + ANIMATION PLAN (2026-11-25)
EA-CHR-0002 player_founder_sprite_prototype_south.png — Founder sprite-style prototype v1 — QC: REJECTED (proportion fail, chibi ~2 head-units). Archived as a readability test only; do not build on it.
PROPORTION RULING (Jawanza, 2026-11-25): HOLD 3 HEADS. The bible's ~3 head-unit adult proportion is the standard; chibi is rejected for this game.
EA-CHR-0002 v2 player_founder_sprite_v2_south.png — Founder sprite prototype regenerated at bible proportions — QC: PASS (2026-11-25). Measured ~3.5 head-units (head ≈27% of height, inside the ~3-head stylized band, no longer chibi); same face/pin/pendant identity as CHR-0001, simplified bold robe shapes, reads at small size. Still a single-pose prototype — NOT a production sprite sheet (no frames, background not transparent).
EA-CHR-0003 player_female_sword_cultivator_concept.png — Female sword cultivator, vermilion/white, high ponytail + ribbon, crane hem motif, jian at side — QC: PASS as concept. Animation flag: long ribbons must shorten/simplify in sprite form.
EA-CHR-0004 player_elder_cultivator_concept.png — Elder cultivator, broad/heavy body type, gray beard/topknot, earth-brown/ochre, bronze-disc belt, wooden staff — QC: PASS as concept. Silhouette clearly distinct from CHR-0001/0003 — body-type language works.
EA-CHR-0005 player_founder_ascended_concept.png — Founder, ascended/high-tier transformation of CHR-0001 — QC: PASS as concept. Identity continuity verified (face, jade lotus pin, pendant, tassel); white-gold robes + halo + floating ornaments + cyan aura match T11–T12 language. Flags: floating talisman glyphs must stay abstract in production (no accidental text); aura ships as a separate VFX layer, never baked into the sprite.
ANIMATION PLAN (per character, directions + FPS UNCONFIRMED — pending developer tech specs): idle, walk, run, dodge, jump (only if engine supports), light attack, heavy attack, weapon combo set, cast, channel, hurt, death, interact, cultivate (seated), breakthrough, transformation. Frames must be drawn per-pose; never duplicate a pose and call it a new frame. No sprite is production-ready until frame dimensions, direction count, and pivot are confirmed.

## 12. PHASE 3 — STARTING-AREA TERRAIN TILESETS (2026-11-25)
EA-ENV-0003 environment_grass_tile_seamless.png — Single grass ground tile, 1600x1600 — SEAM TEST RUN (real, not visual-only): tiled 3x3 and edge strips measured. L–R edge mean abs diff 7.29/255, T–B 10.97/255 — tones are continuous, no hard seam line. BUT the 3x3 repeat shows a visible repeating lattice pattern. QC: CONDITIONAL PASS — production requires 3–4 grass variant tiles + flip/rotation in the TileMap to break repetition. Test evidence: tests/grass_tile_3x3_test.png.
EA-ENV-0004 environment_ground_path_tileset.png — Grass/dirt/transition/stone sheet — QC: SPLIT VERDICT. Grass variants, dirt, and grass→dirt transitions PASS as prototype. Stone path rows FAIL: they drift into plank/arrow patterns, not flagstone — regenerate as proper stone slabs in the production pass. Thin grid lines between tiles must also be removed for the edge-to-edge production atlas.
EA-ENV-0005 environment_water_cliff_tileset.png — Water/cliff sheet — QC: PASS for water tiles and cliff tiles as style prototype — cliff convention is now correct (grass top + vertical rock face band, top-down). Shoreline and waterfall rows read as scene strips, not discrete tiles — they need discrete-tile rework in production.
EA-ENV-0006 environment_prop_building_kit.png — Prop kit reference: bamboo cluster, pine, rock group, grass tuft, glowing spirit herb, wooden fence, stone lantern, training pavilion — QC: PASS as prop reference set. All 8 props consistent in ink/palette/light. Production = individual transparent sprites with shadows separated, never cut from this sheet as-is.
REPO: Assets live in the game repo at game/assets/art-studio/ (prototypes/, reference/, rejected/, tests/) with the bible alongside as VISUAL_BIBLE.md. Local working copies remain in ~/workspace/eternal-ascension-art-studio/.

## 13. PHASE 4 — ENEMY & CREATURE PROTOTYPES (2026-11-25)
EA-ENE-0002 enemy_iron_tusk_boar.png — Iron-Tusk Boar. Type: Mortal Beast. Size: M (~0.7x human height, long body). Palette: matte dark brown, iron-gray tusks, NO glow (mortal rule). Archetype: Charger (telegraphed straight-line charge, tusk gore). Element: none. Animations: idle (pawing/snort), walk, charge wind-up, charge, gore attack, hurt, death. VFX: dust burst on charge, dirt kick-up. QC: PASS as concept. Note: concept pose is mid-charge; sprite idle is a standing redraw.
EA-ENE-0003 enemy_hungry_corpse.png — Hungry Corpse. Type: Undead. Size: M (human height, gaunt). Palette: desaturated gray-green, tattered gray burial robe, sickly green eye glow (only glow on the body, per undead language). Archetype: Shambling Tank (slow, high poise, claw swipes, lunge-grab). Element: Yin/corpse (soul-adjacent). Animations: idle sway, shamble walk, claw swipe, lunge, hurt (low flinch), death (collapse + soul wisp). VFX: faint corpse-qi wisps, green eye flare on lunge telegraph. QC: PASS as concept. Note: face is full skeletal horror at concept detail; sprite simplification softens it. No gore.
EA-ENE-0004 enemy_ember_spirit.png — Ember Spirit. Type: Elemental (Fire). Size: S (~0.5x human). Palette: vermilion/orange flame body, INK-BLACK core (curled ember-fox form), bright orange eyes — the elemental rule made visible: body = its element, core = ink. Archetype: Ranged Spitter (hovers, spits ember bolts, teleports short hops when cornered). Element: Fire. Animations: hover idle (flame flicker), drift move, spit wind-up (core glows), spit, hurt (flame scatter), death (ember burst + smoke). VFX: ember particles, heat shimmer, fire bolt (shared with Dept. G fire set). QC: PASS as concept. Flag: wispy flame edges need a tighter core silhouette at sprite size or it will vanish against bright terrain.
EA-BOS-0001 boss_ancient_stone_guardian.png — Ancient Stone Guardian. Type: Guardian / Boss. Size: XL (3–4x human height, multi-tile footprint — exact tiles pending tile-size spec). Palette: stone gray, carved cloud patterns, moss in cracks, jade inlay + glowing jade eyes, bronze shoulder bells. Archetype: Boss Tank (slow slam combos; bells ring as the slam telegraph — the mechanic is visible/audible on the body, per boss rule). Element: Earth. Animations: dormant statue idle (still, moss), awakening (cracks glow, stone shed), walk (heavy steps), fist slam, bell-shoulder charge, phase-2 (jade core exposed, eyes flare), hurt (chip cracks), death (crumble into rubble + jade core drop). VFX: ground crack decal on slam, dust shockwave, jade light from cracks at phase 2. QC: PASS as concept.
Creature coverage after Phase 4: Beast (wolf, boar), Undead, Elemental, Guardian/Boss proven. Still unproven for Phase 9: Avian, Aquatic, Insectoid, Human enemies/rogue cultivators, Corrupted variants, Mythical.

## 14. PHASE 5 — WEAPONS, EQUIPMENT & ITEMS (2026-11-25)
EA-WPN-0002 weapon_sword_rarity_ladder.png — Jian rarity ladder reference: Common / Rare / Epic / Mythic. QC: PASS — the rarity rule is PROVEN. Read in shape alone (mentally desaturate): Common = plain blade, flat wooden guard, zero ornament. Rare = engraved blade, shaped bronze guard, wrapped grip. Epic = inlaid gems on blade + ornate gem guard + beaded tassel (added silhouette element). Mythic = flame-pattern red blade, elaborate gold guard, floating glow ring + aura (added floating element). Color agrees with shape at every step but is never the only signal. This sheet is the standing reference for all future rarity work.
EA-WPN-0003 weapon_spirit_spear_epic.png — Spirit Spear (Epic). Jade leaf spearhead with cyan edge glow, triple gold collar, red tassel, dark wood shaft. QC: PASS. Note: spearhead is deliberately oversized vs. the shaft — stylized for small-size readability; keep this proportion in the spear family.
EA-WPN-0004 equipment_sect_guardian_armor.png — Sect Guardian armor set. Lamellar bronze over dark teal robe; cloud-pattern pauldrons and vambraces, jade belt buckle, cloth leg wraps with bronze greaves. QC: PASS — armor sits OVER the robe and the robe silhouette survives underneath, per the character design rule. Presented headless on a stand, correct for equipment.
EA-ITM-0002 item_cultivation_items_sheet.png — Cultivation items reference: spirit stone cluster (cyan crystal fan), technique scroll (rolled, red cord, BLANK wooden tag — no accidental text), spiritual peach (red fruit, leaf, faint gold glow), monster core (faceted purple sphere, inner light). QC: PASS — four silhouettes are instantly distinguishable at icon size, which is the item rule. Production: each item ships as an individual icon, glow on a separate layer.
Still open in Depts. E/F for later phases: saber, staff, bow, dagger, fan, flying sword, shield, rings/necklace/belt/boots accessories, elixirs, manuals/scriptures, herbs, blood essence, ores, relics, tribulation/breakthrough materials, treasure chest.
