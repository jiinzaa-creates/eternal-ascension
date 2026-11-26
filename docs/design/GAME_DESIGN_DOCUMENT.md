# ETERNAL ASCENSION — GAME DESIGN DOCUMENT

**Basis.** This document states the design as required by the Master Design Directive
(supplied by Jawanza Martindale 2026-11-24; filed verbatim at
`docs/MASTER_DESIGN_DIRECTIVE.md`) and the Master Development Roadmap M00–M72
(`docs/MASTER_DEVELOPMENT_ROADMAP.md`). Every section separates **Requirement** (what
the directive/roadmap demands) from **Implementation status (2026-11-26)** (what the
compliance matrix v2, its 2026-11-26 addendum, and subsequent verified commits record).
Nothing here resolves the twelve open contradictions (C1–C12); they are listed where
they bite.

## 1. Vision

**Requirement (Directive §1).** A 2D open-world sandbox action RPG centred on Chinese
cultivation fantasy (Xianxia): seamless exploration across a massive continent,
real-time action combat, deep character progression, procedurally generated equipment
and techniques, cultivation/breakthroughs/tribulations/enlightenment, independent
sects with competing interests, NPCs with routines, personalities, ambitions and
relationships, hidden realms and ancient inheritances, forging, crafting, stealing,
trading and experimentation, player-founded sects, emergent events, faction warfare
and world simulation, and multiple paths to immortality and supremacy. Explicitly not
a linear RPG, survival game, menu simulator, idle cultivation game, or conventional
dungeon crawler. Design references (not systems to copy): Skyrim (exploration,
discoverable locations, fast travel), Path of Exile 2 (itemization, affixes, build
diversity), Terraria (exploration, secrets, crafting), Kenshi (emergent stories,
factions, consequences), cultivation novels (realms, roots, physiques, techniques,
inheritance, tribulations, sect politics).

**Pillars (derived from §1's own priority sentence).** Systemic depth; player agency;
replayability; meaningful progression.

**Implementation status (2026-11-26):** The sandbox core exists and is playable
(streamed world, scheduled NPC settlement life, frame-data combat, cultivation,
hidden realms, sects, narrative archive, one irreversible ending — per README and
matrix). The Final Definition of Done is **not met** (addendum verdict): twelve fully
implemented sects, sect warfare, twelve distinct playable sect questlines, and a
browser-tested production presentation remain open, alongside the missing systems
listed in §10 below.

## 2. Core loop

**Requirement.** The roadmap's M01 list requires gameplay-loop documentation; the
directive implies the loop rather than naming it: explore the continent → discover
locations, resources and people → fight, gather, trade and craft → cultivate (Qi,
meridians, methods) → attempt breakthroughs and survive tribulations → gain standing,
techniques, equipment and sect power → reach deeper realms, hidden realms and
inheritances → repeat at a higher order of power, with lifespan as the long clock.

**Implementation status (2026-11-26):** The loop is implemented end to end in code
(matrix M09–M15, M24–M27, M62–M65). Travel is discovery-gated with a time cost
(per M14), but cannot be interrupted by random encounters (contradiction C8, open).

## 3. Character identity

**Requirement (Directive §2).** Identity emerges from interacting systems, not a
class: (1) six primary attributes, (2) passives, (3) techniques, (4) physiques,
(5) spiritual roots, (6) cultivation realm and sublevel, (7) cultivation method,
(8) equipment and artifacts, (9) titles, achievements and acquired traits. No
conventional hard character-level cap.

- **Attributes (§2.1).** DEX, STR, AGI, INT, WIS, CHAR — all uncapped, mechanically
  interacting (each attribute's field is listed in the directive: e.g. WIS governs Qi
  control/recovery, cultivation comprehension, enlightenment opportunities, mental
  resistance; CHAR governs negotiation, recruitment, leadership, sect management).
  Attributes also feed cultivation speed, Qi capacity/recovery, breakthrough success,
  tribulation survival, technique mastery and lifespan. Formulas must support
  specialization, hybrid builds and diminishing returns — and must not impose hard caps.
- **Passives (§3).** Permanent or conditionally active properties; no arbitrary
  acquisition cap. Sources: physiques, roots, methods, titles, achievements, rare
  encounters, enlightenment, manuals, inheritances, special events, training, unique
  items. Ten categories: Physical, Spiritual, Elemental, Combat, Cultivation, Mental,
  Social, Crafting, Exploration, Special/Unique. Synergies and conflicts required.
- **Techniques (§4).** Acquired via manuals, teachers, sect instruction, inheritances,
  observation, combat experience, exploration, special events. Kinds include active
  attacks, spells, defensive, movement, healing, summons, formations, transformations,
  passive and cultivation techniques. Each carries rank, requirements, Qi cost,
  cooldown, animation, startup/active/recovery frames, range, damage/effect, scaling
  attributes and passives, upgrade paths and mastery. No arbitrary limit on learned
  techniques; stronger variations discoverable through experimentation and mastery.
- **Physiques (§5).** Rare, character-defining constitutions, acquired through rare
  methods, extreme training, environment, bloodline, tribulations, hidden realms,
  special encounters — **discoverable rather than selected from a character creation
  menu**. Each has unique passives, attribute interactions, cultivation bonuses,
  combat benefits, potential weaknesses, evolution requirements and possible
  awakening stages.
- **Spiritual roots (§6, per matrix M19).** Twelve tiers, Mortal → Primordial.
- **Realms (§7, per matrix M25).** Twelve realms × ten sublevels.
- **Titles and achievements (§2 item 9; §3 passive sources).** Required as identity
  components and as passive sources.

**Implementation status (2026-11-26):**
- Attributes: implemented (per M17) with cross-axis formulas; the attr-cost clamp at
  level 400 and secondary-stat caps are open under contradiction C3.
- Passives: 13 implemented (per M21); Elemental and Mental categories missing;
  titles/achievements/physiques/roots/methods do not exist as passive *sources*.
- Techniques: 11 implemented across 6 delivery kinds (per M22/M33); healing and
  transformation kinds missing; no technique evolution; the creation grant of all
  non-hidden techniques is contradiction C12 (open).
- Physiques: 7 implemented as mods (per M20); no weaknesses, awakening or evolution;
  shown at creation, contradicting §5 (C1, C2 — open).
- Roots: the cleanest full match to spec (per M19): 12 tiers, weights, affinities,
  purity, appraisal, marrow, 1-tier evolution.
- Titles and achievements: **missing entirely** (verified zero in the addendum).

## 4. Cultivation

**Requirement (Directive §7).** Cultivation methods with distinct mechanics,
combinable where compatible and potentially customizable (§7.1, as cited in matrix
C9); breakthroughs and tribulations (§7.2); Qi and meridians (per M24); enlightenment
and Dao comprehension (per M28); lifespan, aging and immortality (per M29), including
lifespan extension and the possibility space of resurrection/soul transfer/rebirth
that the matrix records as required by M29's scope.

**Implementation status (2026-11-26):** Qi/meridians/contamination implemented
(per M24); breakthroughs and tribulations implemented (per M26/M27); 7 of 12 method
archetypes (Beast, Alchemy, Elemental, Formation, Forbidden missing; per M23) and
methods are single-active, not combinable (C9, open); enlightenment is 13 generic
insights, not Dao paths (per M28); realm unlock flags (flight, space folding, domain
projection, spirit scan, elemental conversion, ascension, plane manipulation, dao
comprehension) are declared, not behaviours (per M25); lifespan pills, resurrection,
soul transfer, possession and rebirth are **missing entirely** (addendum).

## 5. Combat

**Requirement (Directive §11).** Real-time action combat on shared frame data;
three skill bars (§11.1; per M34: 3 bars × 6 slots); weapon categories including
spears, ranged and spiritual weapons (per M31's roadmap scope); defence including
guard/parry/dodge (per M32); combat quality/feedback (per M37).

**Implementation status (2026-11-26):** Combat architecture, guard/parry/dodge,
statuses, hitstop and damage numbers implemented (per M30/M32/M37). Five weapon
categories exist (sword, saber, staff, whip, fist/unarmed); **spears, ranged and
spiritual weapon categories are missing** (per M31). Eleven techniques total for 120
sublevels (per M22). Skill-bar slots do not display Qi costs (per M34/addendum).
Four spirit-beast species; no taming, migration or bloodlines (per M36).

## 6. World

**Requirement (Directive §8).** One enormous continuous continent, explorable on
foot; ordinary regions are not disconnected maps — only hidden realms sit outside
the overworld. Contents include mortal towns, cities, villages, markets, farms,
mountains, forests, beast territories, ruins, wilderness, rivers and lakes, spiritual
mountains, mining regions, resource locations, sect territories, forbidden regions,
ancient battlefields, abandoned settlements, hidden entrances, dungeons. Exploration
must reward (§8.1): environmental storytelling, treasure, rare nodes, encounters,
wandering cultivators, hidden caves, manuals, secret entrances, treasure maps.
Fast travel is Skyrim-style (§8.2): discovery-gated, via the world map, time passes,
random encounters can interrupt, special access exists, cultivation abilities may
unlock advanced travel. Twelve biome types (per M11's roadmap list).

**Implementation status (2026-11-26):** At matrix time this was the largest gap:
1 of 20 continent cells playable, 4 of 12 biomes, 1 settlement, no rivers/lakes as
traversable geography (per M09–M12). **The World Scale pass (2026-11-26, after the
addendum) materially changed this:** commit `82de311` made the whole 5×4 continent
stream (ocean chunks, continent rim, region-driven biomes — all 12 biomes now in
`data/biomes.json`), and commit `160b5d1` added one generated town per land region
with residents, services and discovery-based travel registration, plus shore
enforcement (the player cannot walk on water). Still open after that pass, per the
World Scale plan's own staging: rivers/lakes and new POI kinds (caves, battlefields,
treasure caches) were Stage D, and continent-map fog/visited-region tracking Stage E
— neither is recorded as landed in the sources used here. Travel still has no
random-encounter interruptions (C8) and flight is not implemented (per M14/M25).

## 7. Sects

**Requirement (Directive §9).** Twelve unique established sects plus the sect the
player can found. Each established sect: distinct philosophy, cultivation specialty,
territory, leadership, internal hierarchy, unique techniques and methods, unique
resources, an NPC population, relationships with other sects, internal conflicts,
questlines and a unique inheritance (§9; §16). Hierarchy and advancement (§9.1);
the player-founded sect is player-determined — name, philosophy, location, laws,
hierarchy (per matrix C6, citing §9.2/M60). Sect politics, diplomacy and warfare are
required systems (per M59); established sects act autonomously (per M61).

**Implementation status (2026-11-26):** All 12 sects exist as data matching the
roadmap list (per M56), but 11 are codex entries only — no visitable headquarters,
population, territory or signature arts. Politics is one sect's internal council;
**inter-sect diplomacy, espionage, assassination and sect warfare are missing
entirely** (addendum). The player sect offers 3 preset doctrines — no chosen name,
location, laws or appointed elders (C6, open). Established sects have no autonomy
(per M61).

## 8. NPCs and society

**Requirement (Directive §10).** NPCs with routines, personalities, ambitions and
relationships (§1, §10); relationships including romance, marriage and family
formation (per M50's roadmap scope, cited in matrix §D); recruitment and a party
system in which companions can be given equipment and taught techniques (§10.2, per
matrix M51) and can die where appropriate (per M51); captivity (§10.3, per M52);
NPC cultivation and independent progression (per M53); memory and emergent stories
(per M54).

**Implementation status (2026-11-26):** Generation, 7-day schedules, threat-reaction
intelligence, a directed relationship graph (−100..100, six warmth bands), party
recruitment, captivity and daily progression simulation are implemented (per
M47–M54). Missing: **romance, marriage and family formation entirely**; dialogue
trees/choices; a general decision-making brain (needs, goals, risk, loyalty);
companion death (designed out — C7, open), party commands, and giving companions
gear or techniques. NPC progression regenerates sheets rather than learning
(per M53); NPCs cannot die of age (per M29).

## 9. Items, economy and professions

**Requirement (Directive §12–§13).** Procedural itemization with affixes and build
diversity (§1, §12); special items including set items and legendary treasures
(§12.1, per M41); item manipulation including fusion and enchanting (§12.2, per M44);
an economy with multiple currencies, trading, auctions and black markets (§13, per
matrix §D/M46); professions beyond smithing and alchemy (per M46); alchemy breadth
including potions, elixirs, poisons, breakthrough-aid and lifespan pills (per M45).

**Implementation status (2026-11-26):** Item architecture, procedural generation
(4 rarities, tiered affixes), equipment gating, loot tables, forging/refine/
disassemble and two professions (Smith, Alchemist) are implemented (per M38–M46).
Missing entirely: **item fusion, enchanting, stealing, auctions, black markets,
multiple currencies and supply/demand** (addendum, verified zero). Only 3 pills
exist; only 2 uniques and no set items; equipment lacks necklace/artifact slots;
selling is a flat 40% (per M42–M46).

## 10. Hidden realms, inheritances, events

**Requirement (Directive §14–§15).** Hidden realms outside the overworld with
discovery and access rules (§14.1); inheritances as ancient legacies (§14.2), with
the rule that a dungeon completion must not guarantee its boss's rare drop;
dynamic world events, rumours and opportunities (§15, per M66).

**Implementation status (2026-11-26):** One of the strongest areas (per M62–M65):
9 realm families matching the roadmap templates, deterministic generation, access
cycles and rumours, 27 inheritances with compatibility and trials. The warden kill's
guaranteed Treasure-grade item is contradiction C11 (open, against §14.2). World
events are calendar modifiers (8 tidings), not simulated occurrences with actors
(per M66).

## 11. Endgame

**Requirement (Directive §16.1).** Multiple endgame directions without one forced
ending: become an immortal; found the strongest sect; conquer the continent;
discover the origin of cultivation; become a legendary artifact creator; master
forbidden cultivation; establish a new cultivation civilization; pursue an
alternative transcendence. Progression must not simply end at realm 12 (per M70).

**Implementation status (2026-11-26):** Four resolutions on the "blank page"
(per M70); roughly 3 of the roadmap's 8+ paths are approximated (knowledge, sect
leadership, refusal/transcendence). Continental dominance, forbidden cultivation,
legendary craftsmanship and new-civilization paths are not playable endgames.

## 12. Open contradictions (author rulings required)

C1 physiques at creation vs discoverable · C2 physique tradeoffs vs the mods-only
mandate in DEVELOPMENT.md · C3 hard caps in code vs the no-hard-caps directive ·
C4 continent scope (largely addressed by the 2026-11-26 World Scale pass; the
directive's full Definition of Done still governs) · C5 shared storyline ladder vs
structurally distinct questlines · C6 player-sect presets vs self-determination ·
C7 companion deaths · C8 travel interruptions · C9 combinable methods · C10 final
art (largely closed by the 2026-11-25 art integration) · C11 guaranteed boss
treasure · C12 starting-techniques grant. Full text: compliance matrix §C and the
2026-11-26 addendum.
