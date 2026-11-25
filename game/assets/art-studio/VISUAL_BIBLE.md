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
EA-ENV-0001 environment_bamboo_sect_scene_reference.png — Dept C — Bamboo grove + training courtyard + pavilion + pond/waterfall scene — QC: REFERENCE ONLY per Amendment 1 (2026-11-25). It is NOT a production background and must never be shipped as one. Its only job is palette/architecture reference for the bamboo tileset kit (EA-ENV-0002 onward). View is oblique/diorama; tiles must be flat top-down.
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

## 15. PHASE 6 — COMBAT & CULTIVATION VFX KEY FRAMES (2026-11-25)
All four are KEY FRAMES (style frames), not finished sequences — production animates them as frame sequences / particle systems per the specs below.
EA-VFX-0002 vfx_breakthrough_pillar.png — Breakthrough. Colors: cyan + gold spiral pillar on the character, expanding ground rings. Shape: vertical double-helix column + concentric rings. Direction: upward + outward. Duration intent: long (multi-second ceremony, not a flash). Intensity: HIGH — this is the signature moment; it must never read like a normal level-up (level-ups get a brief single ring + small rise, spec in Dept. G backlog). Layers: ground decal (rings), additive pillar, particles. QC: PASS. Flag: the concept's ground array carries glyph-like marks — production array uses pure geometric rings/marks only, abstract, never glyph shapes that imply text.
EA-VFX-0003 vfx_tribulation_lightning.png — Heavenly Tribulation. Colors: black-purple vortex clouds, purple-white bolt. Shape: sky vortex + single massive jagged strike to a small ground point. Direction: downward. Duration intent: bolt flash is instant; the storm builds over seconds before each strike (dread = the telegraph). Intensity: MAXIMUM, dangerous — never reuse this language for player lightning skills (player lightning is thinner, cyan-white, no storm). Layers: sky overlay (clouds), bolt sequence, ground impact ring, rain. QC: PASS as key frame; production splits it into those four layers.
EA-VFX-0004 vfx_healing_motes.png — Healing. Colors: soft green + warm gold. Shape: narrow slow spiral of motes + leaf sparkles, single soft ground ring. Direction: gentle upward drift. Duration intent: sustained while channeling. Intensity: LOW — deliberately quieter and narrower than the breakthrough spiral so the two can never be confused: healing = thin, slow, leaf motes; breakthrough = thick, fast, full pillar. QC: PASS.
EA-VFX-0005 vfx_fire_projectile.png — Fire projectile (Ember Spirit spit + fire skills). Colors: white-hot core, orange body, vermilion trail, ember sparks, faint smoke. Shape: round core + tapering comet trail. Direction: horizontal; the asset is horizontally flippable in-engine for either travel direction. Duration intent: travel loop + separate impact burst (backlog). Layers: additive core/trail, particles (embers), normal-blend smoke. QC: PASS.
VFX backlog for later phases: sword qi wave, water/ice/earth/wind/lightning skill sets, shield/barrier, dash trail, hit impacts + elemental bursts, death/soul effects, poison, buffs/debuffs, teleport/portal, weather set, day/night + realm atmosphere.

## 16. PHASE 7 — UI ART DIRECTION (2026-11-25)
THE UI LANGUAGE (locked by these mockups): Panels = ink-brown (#241D18 family) with jade + bronze trim and cloud-pattern corners. Buttons = dark bronze plaques, geometric fret corners, gold serif labels; highlighted state adds a gold outer glow (component sheet). Bars = ornate end caps, HP red with scale texture, Qi cyan with wave texture; bars are segmented for chunk readability. Item frames = the rarity ladder in frame form: gray plain → blue corner gems → purple fuller gems → orange carved → red-gold scale + gems (component sheet) — frames escalate ORNAMENT with rarity, matching Dept. E's shape rule. Font direction: elegant serif for titles/labels (production font TBD — must be licensed for commercial use).
EA-UI-0001 ui_title_screen_mockup.png — Title screen. QC: PASS — title text verified letter-by-letter: "ETERNAL ASCENSION", buttons "New Game / Continue / Settings" all spelled correctly. Art matches the repo's existing title key art family (teal/gold floating sect palace). Production: title is set in-engine with a real font, never baked from this mockup.
EA-UI-0002 ui_hud_mockup.png — HUD over bamboo grove. Layout locked: portrait + HP/Qi bars top-left, round minimap top-right, 6-slot skill bar bottom-center, all in jade/bronze frames. QC: PASS as layout/language mockup. Note: the mockup's in-scene character is small/chibi for scene framing only — it is NOT a proportion reference (3-head rule stands).
EA-UI-0003 ui_inventory_panel_mockup.png — Inventory/character panel. Character pane left (ink silhouette placeholder), 4x4 grid right, rarity frames on filled slots (crystal/scroll/peach/sword icons consistent with Phase 5 items). QC: PASS. Production rules from this mockup: frame color = the ITEM's rarity; EMPTY slots always use the plain gray frame (the mockup shows colored empty frames for language display only). The scroll icon here carries tiny marks — production uses the Phase 5 blank-tag scroll.
EA-UI-0004 ui_component_sheet.png — Component reference: 3 button/panel states (normal / highlighted-glow / muted), HP + Qi bars with end caps, 5 rarity frames, minimap ring. QC: PASS — this sheet is the production reference for all UI drawing.
UI backlog: dialogue box, quest tracker, shop panel, sect management panel, map screen, settings, damage numbers, boss health bar (uses the guardian's bell motif), controller prompts, accessibility variants (colorblind-safe rarity = ornament already carries the signal).

## 17. PHASE 8 — ANIMATION PRODUCTION PLAN & TECHNICAL STANDARDS (2026-11-25)
STATUS KEY: [LOCKED] = set by art direction, safe to build on. [PROPOSED] = my recommendation, needs developer confirmation. [BLOCKED] = cannot start production without the developer spec.

### 17.1 Animation matrix (sets required per actor class) [LOCKED as scope]
PLAYER / HUMANOID NPC (per character, per direction): idle, walk, run, dodge-roll, basic attack combo (3), heavy attack, skill cast, channel/cultivate (seated), hurt, death, interact, breakthrough (uses EA-VFX-0002 + body rise), transformation/ascension variant of idle+walk at minimum. Mount/fly states if the design adds them.
QUADRUPED BEAST (wolf, boar): idle, walk, run/charge, bite/gore attack, pounce (wolf), hurt, death.
UNDEAD HUMANOID: idle sway, shamble, claw swipe, lunge, hurt (low-flinch variant), death-collapse.
ELEMENTAL: hover idle, drift, cast/spit, hurt-scatter, death-burst. (Fewer frames, more particle work — elementals animate by shader/particles as much as frames.)
BOSS (guardian class): dormant, awakening, walk, 2–3 attack patterns, phase-transition, hurt states, death-crumble. Bosses get unique sets; no sharing with normal enemies.
Frame counts and FPS per set: [PROPOSED] idle 4–6f, walk 6–8f, run 6f, attacks 5–8f with 1–2 anticipation + active + recovery readable at a glance; final numbers [BLOCKED] on developer FPS/animation spec.

### 17.2 Direction policy [PROPOSED — developer decision]
4-direction (S/E/N/W, diagonals reuse): ~40% less art, classic top-down feel, weaker diagonal combat read. 8-direction: best combat readability for an action RPG, roughly double the directional art of 4-dir. My recommendation for an action RPG with directional attacks: 8-dir for the PLAYER and bosses, 4-dir acceptable for minor NPCs/enemies if budget demands. Sprite mirroring: E/W mirror is allowed only for symmetric designs; asymmetric details (sword hand, crane motif) must be drawn, not flipped. [BLOCKED] until developer confirms.

### 17.3 Production pipeline [LOCKED]
1. Concept (Phases 1–7 outputs) → 2. Silhouette lock (black-fill test at gameplay size) → 3. Key poses per animation → 4. In-betweens → 5. Cleanup to locked palette + ink color → 6. Layer separation (body / weapon / aura-glow / shadow as separate exports) → 7. Atlas pack + export → 8. In-engine check (movement, sorting, readability vs. tilesets) → 9. Registry entry + QC verdict. AI-generated images feed step 1 ONLY; production sprites are drawn/derived frame work, never raw generations.
PILOT RULE: the Founder (EA-CHR-0002 design) gets the first complete animation set as the pilot. The pilot proves the pipeline and sets the real per-character cost before any batch production is scheduled.

### 17.4 Technical standards that hold regardless of pending specs [LOCKED]
Format: PNG with full alpha for sprites/VFX; no baked backgrounds on production assets. Color: sRGB, locked bible palette, ink #1E1B18. Lighting: upper-left on every frame of every set. Pivot [PROPOSED]: bottom-center (feet) for ground actors, center for flyers/elementals. Shadows: separate soft ellipse asset, never painted into frames. Glow/aura: always a separate additive layer. Naming: bible §8 convention, animation files as {actor}_{anim}_{dir}_{frame}. Atlas: one actor per atlas where practical; power-of-two sheets preferred pending engine spec.

### 17.5 BLOCKER LIST — specs required from the developer before production animation starts
1. TILE SIZE in pixels (blocks tileset production AND boss footprint sizing). 2. Sprite frame size / character canvas in pixels. 3. Direction count (4 or 8) + diagonal policy. 4. Animation FPS targets per animation type. 5. Max texture/atlas size + Godot import filter settings (nearest vs. linear — decides whether art is pixel-crisp or painterly-smooth at runtime). 6. Y-sort / pivot confirmation. 7. Target resolutions + UI scaling policy (blocks final UI production). 8. Performance budget for particles/lighting (blocks VFX density).
Until items 1–4 land, all further work stays at concept/prototype level — which is exactly where Phases 9–11 operate, so the studio is not idle waiting.

## 18. ASSET FOLDER STRUCTURE (Jawanza's directive, 2026-11-25) [LOCKED]
All game art lives under game/assets/art-studio/assets/ in this structure: characters/{player, npcs, companions} · enemies/{beasts, demons, bosses} · environments/{terrain, vegetation, buildings, props} · items/{weapons, armor, consumables, materials} · vfx/{combat, elements, cultivation} · ui/{icons, portraits, panels} · audio/. Applied 2026-11-25 (commit c0e0e0e): all 30 prototype assets moved with git mv (history preserved); empty categories hold .gitkeep. Mapping choices: undead + elemental enemies file under demons/ (supernatural bucket); the cultivation items sheet files under materials/ (stones/cores are its production payload); UI mockups file under ui/panels/. Studio process folders stay OUTSIDE assets/: VISUAL_BIBLE.md (art-studio root), reference/ (storytelling reference), rejected/, tests/. Every new asset is filed into this structure in the same commit that registers it.

## 19. PHASE 9 — CREATURE FAMILY EXPANSION (2026-11-25)
EA-ENE-0005 enemy_storm_crane.png (enemies/beasts) — Storm Crane. Type: Avian Spirit Beast. Size: L wingspan (body M). Palette: white/azure feathers, gold beak, thin cyan-white lightning arcs wing-to-wing (player-grade lightning language, NOT tribulation purple). Archetype: Flying Striker (dives, ranged feather bolts, never lands in combat). Element: Lightning/Wind. Animations: glide idle, flap move, dive attack, feather-bolt cast, hurt, death (fall + feather burst). VFX: arc sparks, feather projectiles. QC: PASS. Flag: trailing tail feathers shorten/cluster for sprite animation.
EA-ENE-0006 enemy_abyss_jade_carp.png (enemies/beasts) — Abyss Jade Carp. Type: Aquatic Spirit Beast. Size: L (long body). Palette: jade scales, translucent cyan ribbon fins, dotted cyan spine glow (spirit marker), small antler nubs (carp-toward-dragon, kept subtle). Archetype: Water Lancer (lunging bites, water-jet ranged, submerge/re-emerge). Element: Water. Animations: swim idle (sine body), lunge, jet cast, submerge, emerge, hurt, death. VFX: splash rings, water jet, droplets. QC: PASS.
EA-ENE-0007 enemy_spirit_mantis.png (enemies/beasts) — Spirit Mantis. Type: Insectoid Beast. Size: M tall (human height, thin). Palette: jade chitin, gold compound eyes, gold cloud-scroll engraving on plates. Archetype: Ambush Duelist (still camouflage idle, blink-fast double scythe combos, parry stance). Element: Wood/none. Animations: prayer idle, stalk walk, scythe combo x2, parry, leap, hurt, death. VFX: scythe arc trails, leaf scatter on ambush reveal. QC: PASS with flag — the concept's chitin carries small glyph-like marks; production strips them to plain cloud-scroll engraving only, no character-like marks (same rule as the breakthrough array).
EA-ENE-0008 enemy_corrupted_spirit_wolf.png (enemies/demons) — Corrupted Spirit Wolf (variant of EA-ENE-0001). THE CORRUPTION STANDARD, defined by this piece: same base silhouette and identity features (mane, antlers — blackened and twisted) + violet crack network across the body + dark crystal growths at joints/flank + eye color shift to violet + dark aura seeping from the tail/cracks. Structure changes, not recolor — the variant rule holds. Archetype: Elite Charger+ (wolf moveset + corruption burst). QC: PASS. Note: this concept is the HEAVY corruption end state (base palette mostly consumed); standard corrupted variants keep more base palette visible so the same-creature read is instant at gameplay size.
Creature coverage now: Beast, Avian, Aquatic, Insectoid, Undead, Elemental, Guardian/Boss, Corrupted — all eight proven. Remaining: Human enemies/rogue cultivators (Phase 9b candidate), Mythical (endgame, deliberately last).

## 20. PHASE 10 — SECT IDENTITY KITS (2026-11-25) [Dept. I — Sect Identity, EA-SEC]
IMPORTANT SCOPE NOTE: these are PATH-ARCHETYPE kits proving the kit system. They are NOT named canon sects. The game's 12 established sects receive their kits when the developer supplies names/doctrines; player-founded sects use the template kit.
THE KIT SYSTEM [LOCKED]: every sect kit = (1) EMBLEM: one motif inside a metal ring, readable at 32px; (2) BANNER: vertical, kit palette, emblem repeated at center — must read from across a courtyard; (3) UNIFORM: 2-color robe + metal trim (trim metal escalates with disciple rank: cloth → bronze → silver → gold); (4) ARCHITECTURE ACCENT: the motif carved into a roof-end ornament + gate plaque. One motif, four surfaces — that repetition IS the identity.
EA-SEC-0001 sect_kit_azure_sword.png — Azure Sword Path. Motif: sword through clouds. Palette: azure/white, silver trim, bronze ring. QC: PASS (all four surfaces cohere; banner emblem matches the crest exactly).
EA-SEC-0002 sect_kit_vermilion_flame.png — Vermilion Flame Path (alchemy). Motif: flame over cauldron, flame-lobed ring. Palette: vermilion/dark brown, gold trim. QC: PASS.
EA-SEC-0003 sect_kit_violet_shadow.png — Violet Shadow Path. Motif: crescent moon pierced by a needle. Palette: violet-black/silver. QC: PASS. DISTINCTION RULE [LOCKED]: shadow violet is CLEAN violet + silver + celestial motifs (moon/stars). Corruption violet is cracks + crystals + seeping aura (EA-ENE-0008). The two violets never share motifs — a player must never mistake a shadow disciple for a corrupted creature.
EA-SEC-0004 sect_kit_player_template.png — Player-Founded Template. Blank bronze crest frame + motif chip library (cloud, sword, flame, wave, leaf, star — expands in production) + palette swatch row. The player picks motif + 2 colors + trim; the system generates emblem/banner/uniform/architecture from the same four-surface rule. QC: PASS — the template proves player sects can look as authored as canon sects.
Files filed under assets/ui/icons/ (emblem-led identity); production splits each kit into icons, banner props (environments/props), and uniform colorways (characters).

## 21. PHASE 11 — KEY ART & MARKETING PROTOTYPES (2026-11-25) [Dept. J — Marketing, EA-MKT]
Marketing rules [LOCKED]: NO text is ever baked into key art — logos/titles are set in production with licensed fonts (the Phase 7 title mockup is the layout reference). Key art must use REGISTERED designs (characters/creatures from this bible), never one-off inventions. Files live in art-studio/marketing/ (outside assets/ — marketing is not a game asset).
EA-MKT-0001 keyart_capsule_vista.png — Store capsule / header art. Founder (jade/white, sword on back) + Azure Spirit Wolf overlooking the continent at dawn; upper third kept open for the logo. QC: PASS — composition, identity, and palette all on-register.
EA-MKT-0002 keyart_poster_ascension.png — Vertical poster. Ascended Founder in the breakthrough spiral (visual language consistent with EA-VFX-0002), heavenly light breaking the clouds. QC: PASS. Note: the figure's lower body merges into the energy pillar — intentional ascension imagery, poster-only.
EA-MKT-0003 keyart_character_lineup.png — Character lineup (Founder / Sword Cultivator / Elder). QC: PASS — identity carriers are exact (jade pendant; vermilion robe + red ribbons + crane hem motif; bronze-disc belt + staff + broad build). Faces drift slightly from the concepts, as redraws do; the registered CONCEPTS remain the production identity reference, this piece is marketing.
EA-MKT-0004 keyart_boss_confrontation.png — Boss confrontation scene. Guardian design reproduced faithfully (bells, jade eyes, cloud carving) at true XL scale against the Founder in mossy ruins. QC: PASS — doubles as the scale reference for the guardian's in-game presence.

## 22. PHASE 12 — FINAL QA AUDIT & HANDOFF (2026-11-25)
Audit performed: (1) registry↔repo reconciliation — 43 unique EA-IDs (CHR 5, ENE 8, BOS 1, ENV 6, WPN 4, ITM 2, VFX 5, UI 4, SEC 4, MKT 4); 45 art files in repo (38 assets/ + 4 marketing/ + 1 reference/ + 1 rejected/ + 1 tests/); every registered file present. (2) Defect found & fixed: EA-ENV-0001 registry filename corrected to environment_bamboo_sect_scene_reference.png to match the repo. (3) All open production flags collected into HANDOFF.md (art-studio root, beside this bible). (4) Locked decisions, folder structure, blocker list, and per-department backlogs consolidated in HANDOFF.md.
VERDICT: the prototype program (Phases 1–12) is COMPLETE and internally consistent. The studio's next action is gated on the developer spec list (§17.5) — tile size first. When specs land, production starts with the Founder pilot animation set (§17.3).

## 23. ADDENDUM — DEVELOPER SPEC SHEET FROM CODE (2026-11-25)
At Jawanza's request the studio read the codebase (HEAD 5890060) and compiled DEVELOPER_SPEC_SHEET.md (art-studio root). KEY FINDING: the game has no sprite/tile pipeline — actors are code-drawn primitives animated by the procedural pose Animator (docs/DEVELOPMENT.md states this as deliberate). §17.5's blockers are therefore RETIRED and replaced: confirmed specs (1280×720, zoom ladder 0.75–2.0, 1024-unit chunks, Y-sort World, body radii 10–22, pose rates 7/10/13 rad/s, Appearance palettes) are in the sheet, and the studio's derived recommendations (32px tiles, 64×64 frames / 128 bosses, feet pivot, 8 directions, sprites layered under the pose Animator) await a developer adoption decision. BONUS CANON: data/factions.json already fixes 4 houses with colours + mottos (Azure Cloud Sect #7fd3e0, Verdant Market League #d8c070, Market Watch #c08f8f, Hollow Moon Cult #a890d8) — the first canon sect kits should be built for these.
