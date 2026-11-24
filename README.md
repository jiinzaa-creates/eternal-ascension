# Eternal Ascension

A 2D top-down open-world xianxia cultivation action RPG, built with **Godot 4.4** (GDScript).

Current build: **0.2.0**. It contains a playable slice: a streamed province, a populated
settlement with scheduled NPCs, a sect initiation quest, real-time frame-data combat,
cultivation with breakthroughs, deterministic procedural items, a procedural hidden realm with
an inheritance, and a crash-safe save system.

## Run it in the Godot editor

1. Install [Godot 4.4](https://godotengine.org/download) (standard build, not .NET).
2. Open `game/project.godot` as a project.
3. Press **F5**.

## Controls

| Action | Key |
|---|---|
| Move | W A S D |
| Sprint (hold) | Shift |
| Weapon strike (chain) | Right mouse |
| Attack with selected technique | Left mouse |
| Aim | Mouse or right stick |
| Guard / parry (hold) | Ctrl (or middle mouse) |
| Dodge (i-frames) | Space |
| Meditate / cultivate | F |
| Realm breakthrough (at peak, full Qi) | G |
| Interact / talk / pick up / use the storehouse | E |
| Satchel grid (wear, sort) | I, then arrows, R, ENTER |
| Forge: recipes / refine / disassemble | E at the forge, then TAB, arrows, ENTER |
| Brew a pill / drink a pill | E at the cauldron then arrows + ENTER; I, select, U |
| Select technique (slots 1–6) | 1 – 6 |
| Cycle every known technique | Q |
| Quick save / quick load | F5 / F9 |
| Zoom camera in / out | Mouse wheel, `=` / `-` |
| Creation: origin / robe / hair / skin / presentation | TAB / Z / X / C / N |
| Shop: buy / switch mode / close | 1–6 / TAB / E |
| Routes: travel / set waypoint | T, then 1–6 then ENTER / V |
| Continent map | M |
| Toggle help | F1 |

Gamepad: left stick moves, right stick aims, **X** performs the selected technique, **D-pad
right** strikes with the equipped weapon, **LS click** guards, **A** dodges, **B** interacts, **Y**
meditates, **RB** sprints, **D-pad up** attempts a breakthrough.

On the creation screen: **1–6** allocate a point to STR / DEX / AGI / INT / WIS / CHA,
**Backspace** refunds the last point, **R** rerolls your spiritual root, **Enter** begins.

## The playable loop

1. **Create a character** — a random name, a weighted spiritual root (Mortal → Primordial),
   and six free attribute points.
2. **Azure Cloud Market** — a settlement of ~19 NPCs with daily schedules. Elder Bai stands by
   the sect hall and starts *The Azure Cloud Invitation*: talk, slay 3 beasts, gather 2 spirit
   herbs, attune at the shrine, return. Reward: a technique, a passive, spirit stones.
3. **Fight** — enemies telegraph, then strike. Your weapon's own moveset chains on right-click,
   techniques spend Qi on left-click and come in six deliveries: melee arcs, travelling sword-Qi
   bolts, telegraphed area spells, summoned beasts, timed body arts and movement steps. Poise,
   stagger, knockback and dodge i-frames apply to all of them.
   Hold guard to meet a blow: the opening moments parry it for free, and a held block spends Qi until
   the reserve fails and the ward breaks. Kills drop generated items you can pick up and auto-equip.
4. **Cultivate** — meditate to gather Qi, advance through 10 sublevels, then face a
   breakthrough at the peak. Failure causes Qi deviation, meridian damage, or regression.
5. **The Rift** — east of the market, a portal opens the *Tomb of the Hollow Moon*, a seeded
   5×4 hidden realm with corridors, hazards, chests, and an inheritance altar. Saves are
   blocked inside; exit to save.
6. **Save/load** — F5/F9. Saves are atomic, checksummed, backed up three deep, and recover
   automatically from a corrupted newest file.

## Verification

```sh
godot --headless --path game --editor --quit                              # import check
godot --headless --path game res://tests/run_tests.tscn                   # unit + content
godot --headless --path game res://tests/integration.tscn                 # real-scene smoke
godot --headless --path game --quit-after 240                             # boot smoke
```

Each suite prints `RESULT: PASS n / FAIL 0` and exits `0` on success. CI runs the same
commands (`.github/workflows/ci.yml`). The unit suite covers content validation, attribute
formulas, the stat pipeline, RNG determinism, item generation, cultivation, combat curves,
world/chunk streaming, NPC schedules, quests, hidden-realm generation and save/load including
corruption recovery and schema migration. The integration suite drives the real main scene:
allocating attributes, attacking through the frame state machine, killing, looting,
meditating, breaking through, entering/exiting the hidden realm, and saving/loading.

## Layout

```
game/
  core/       autoloads: log, bus, rng, db, clock, settings, save, game
  data/       JSON: realms, roots, methods, techniques, items, passives, quests, npcs
  systems/    attributes, stat_block, cultivation, damage, itemgen, quests
  entities/   player, dummy, npc, interactable
  world/      chunk_manager (12x12 streamed province), settlement, hidden_realm
  ui/         hud
  scenes/     main
  tests/      run_tests, integration
docs/         DEVELOPMENT.md — engine pin, determinism rule, save compatibility, conventions
```

## Implemented

- Six uncapped attributes; one `StatBlock` pipeline (attributes → flat → percent → equipment → realm).
- 12 spiritual root tiers with weighted generation, purity, affinities, cultivation multipliers.
- 12 realms × 10 sublevels as one data-driven ladder: every sublevel raises Qi capacity (1 → 4.15×, banded Early/Middle/Late/Peak), every realm is a multiplier with cumulative unlocks and one realm art, breakthroughs scale with behaviour and their failures cost something, and the twelfth realm is a guarded apex.
- Realm arts and unlocks: each realm declares what it opens (Qi Sense, Dash Cancel, Meridian Opening, Technique Weaving, Flight, …) and one art whose mods feed the stat pipeline; dash cancel (realm 2) really lets a dodge abandon a swing, and technique weaving (realm 5) really cuts Qi cost and cooldown by 10%.
- Weapon framework: every weapon category — sword, saber, staff, whip and bare hands — owns its own light-attack moveset. Each category carries its own chain of strikes (frame data, arc, damage multiplier, poise and knockback), its own reach, speed and weight, and a chain window; the equipped weapon picks the moveset, chains advance and wrap while the window is open, and a weapon strike costs no Qi while techniques stay on their own press. Weapon categories load from `data/weapons.json`, generated weapons carry their category, and old items resolve through their base id to the same moveset.
- Defense: hold guard for a frontal ward. Its first moments are a parry window that turns a blow aside
  for free and throws the force back at the attacker; past it, a block spends Qi per absorbed blow while
  armour and resistances still soften the rest. Guard only covers the front, never a hazard or a
  tribulation bolt, and an unpaid block breaks instead: the blow lands harder, poise is emptied, the
  reserve is lost and the ward cannot be raised again for a moment. A raised guard cannot attack or
  sprint, and a dodge drops it.
- Combat architecture: one shared rules layer (`Combat` + `Poise`) for both the player and every enemy — 60 Hz frame phases with attack-speed timing, arc or full-circle hitbox geometry that honours facing, reach and body radius, poise meters that stagger on the breaking blow, knockback impulses, and interruption of a wind-up but not a committed swing. The player now has poise and stagger of his own, and enemy blows carry poise and knockback; a stagger cancels meditation and can cancel an attack in startup.
- Lifespan and aging: the body has an age read from the world calendar (one year every 24 days of play). Past 60% of its realm's lifespan it enters middle age, old age and fading years; STR, DEX and AGI decline up to 35% while WIS, INT and CHA are spared, with a one-time warning at each stage. At the lifespan the run ends with a quiet summary screen (ENTER begins a new life), an ended run cannot be saved, and a dead save loads back into that screen. Realm 12 is ageless.
- Enlightenment: understanding accrues from real play — meditating with a method, every kill, surviving a tribulation, breaking through — and fills a comprehension meter. A full meter rolls a deterministic, weighted epiphany among insights you qualify for (by realm and practised method); an insight is permanent and adds its mods to the one stat pipeline, with thirteen in `data/enlightenments.json` from Still Water Clarity to Primordial Glimpse. The meter and learned insights are shown on the HUD and saved.
- Playable tribulations: pressing G at the peak starts the realm's own heavenly trial — a telegraphed, staggered bolt pattern in a bounded circle. Dodge bolts to survive each wave (i-frames work, armour and evasion do not), earn a perfect-wave composure bonus of up to +12% on the breakthrough roll, or fall inside the circle and take the failure fallout without a roll. Eleven data-driven trials (`data/tribulations.json`) run from a three-wave meridian test to the seven-wave primordial sky, each with its own colour, bolt count, pacing, scatter and damage. Saves are refused mid-trial; loading abandons it.
- Breakthrough preparation and method tribulations: a scorched tribulation ground beside the shrine banks up to three preparations (60 stones each) which raise the roll by 6% apiece, lighten Heaven by 10% and soften failure's wound and corruption — all spent by the attempt, win or lose. Each of the seven methods reshapes the tribulation itself: sword intent needs recent combat, dual cultivation needs a partner, the celestial path needs night, a conditioned body trades a heavier heaven for gentler failure, and the Blood Sea lends chance while making failure bite harder.
- Technique combat: six deliveries share one frame machine, one Qi cost and one damage path — melee arcs, projectiles that pierce and die at their range, spells that telegraph and bloom at a point ahead of the caster, summons that hunt for a duration and carry a share of the blow, timed body arts whose mods enter the one stat pipeline, and movement steps with their own i-frames. Eleven techniques live in `data/techniques.json` — Piercing Thrust carries sword Qi, the Ninefold Sealing Array is a spell, Nine Beast Stampede calls a pack, Golden Bell Cover is a body art and Cloud Step is a movement art — `TechniqueCombat` is pure, `DB.validate` checks each kind's payload, and Q cycles every known art so one learned after the six-slot bar is full is never stranded.
- Deterministic item generation: 4 rarities, tiered prefixes/suffixes, stable IDs, auto-equip.
- Equipment and passives feed real combat stats through `StatBlock`.
- Seamless streaming over a 12×12-chunk province: pure payload generation on worker threads, nodes built on the main thread, and a deterministic seed identity for every chunk.
- Chunk deltas: harvested resources are remembered per chunk with the day they were taken, saved with the run, and restored when the chunk streams back in.
- Background regrowth: chunk herbs return a few days after being harvested, evaluated from the clock when the chunk reloads rather than ticked per frame.
- Qi and meridians: twelve permanent channels opened in order at the meridian hall for Qi and stones, each raising capacity and adding a stat; Qi contamination from blood practice and failed breakthroughs (up to −50% gain) purged at the shrine for 30 stones; and per-biome Qi density multiplying meditation (marsh rich, ash poor).
- Cultivation methods with real loops: seven methods differ by what feeds them (sitting, STR, recent combat, absorbed blood, kills, a nearby partner, the night sky), each builds its own insight for up to +20% cultivation, and a method stele lets you switch for 150 stones only to a method you qualify for.
- Technique mastery: five tiers earned by landing a technique, raising damage while cutting Qi cost and cooldown, shown per slot on the technique bar and saved per technique. Falling Petal Cut is hidden from the starting kit and can be bought from Instructor Rui (180 stones) or learned for free by watching the practising disciple three times, both gated on realm and DEX.
- Item architecture: every item is one canonical record — fixed fields, a stable `item.*` id, a known slot, clamped rarity/level/value and a count — and every route into the satchel (drops, shops, saves, loads) passes through it. Weapons hold 300 points of durability and armour 400; a swing wears the weapon, a damaging blow wears the armour, worn gear still works and broken gear contributes nothing at all until it is mended. The inn mends every worn piece for stones priced by what is missing and how rare the piece is. Materials stack to 20 and consumables to 10 by slot, base and name, so two heaps of spirit ore are one line and two swords never are; stacks sell whole and read as `Name xN`. Saves carry the exact condition and count, schema 2 migrates older saves by filling both, and the loader drops any item it cannot represent instead of trusting the file.
- Spirit beasts & bosses: four species in `data/spirit_beasts.json` — Moonfang Wolf, Stoneback Boar, Thundercrane and Gloom Serpent — live in the biomes their habitat map names, wear their own name, colour, numbers, bite status and core, and fight through the same behaviour archetypes as humanoids (a wolf circles and retreats, a boar holds its ground). Wild spawns are about half beast, and a beast drops a material core worth selling on top of ordinary loot. The Tomb of the Hollow Moon is guarded by the **Warden of the Hollow Moon**, a boss with a long bar at the top of the screen, three health phases (Hollow Guard, Moon's Wrath, Last Light), phase multipliers read live so it hits harder, moves faster and strikes sooner as it loses health, a status on its later blows, and beasts it calls when it changes phase. The inheritance altar refuses to yield while the warden lives; killing it pays spirit stones and one guaranteed treasure-grade item, and the kill is saved by id so a cleared tomb stays cleared and a loaded save never respawns it. Phase thresholds are data, the phase rules are pure, and `DB.validate` checks thresholds, phases, adds and statuses.
- Combat polish: a landed blow freezes the fight for a few hundredths of a second through a real-time `Hitstop` timer — no engine clock is touched, a critical or heavy blow holds longer, and a second blow never extends a freeze it did not ask for — while the damage floats up as tinted numbers drawn in world space (critical hits larger and gold, status ticks in their own colour). Four data-driven statuses (burn, bleed, chill, shock) stack up to three times and refresh rather than replace: burn and bleed tick unblockable damage every half second, chill slows movement and shock raises damage taken. Fire, blood and formation arts carry them, three enemy archetypes apply them, they show on the HUD and above the body, and `DB.validate` rejects an unknown status. Combat sound is synthesized at startup — eight short 16-bit streams built from deterministic envelopes, no audio assets — and dispatched from bus signals for swings, hits, criticals, guards, parries, hurts, deaths and arts, with F2 muting. Statuses and numbers are transient and never saved.
- Enemy AI: four behaviour archetypes in `data/enemy_archetypes.json` — brawler, skirmisher, sentinel and Qi archer — share one pure brain (`EnemyAI`). A body patrols a circuit around its spawn until the player enters its aggro range and vision cone, then chases and remembers where the target was last seen; past its leash it walks home, loses interest and mends. Only so many bodies commit to a blow at once (the rest circle, and bodies push apart so a pack cannot stack), a skirmisher backs off after each strike and runs once when badly hurt, a sentinel guards a short leash behind a 140° arc, and an archer holds its firing band and shoots telegraphed Qi bolts through the same `Projectile` and the player's own `take_hit`. Every blow still winds up, so a stagger or a parry cancels it and stepping out of the arc dodges it; biome enemy tables and hidden-realm guards assign the archetype, and a non-aggressive body keeps the old training-dummy behaviour.
- Skill bars: three bars of six slots (`SkillBar`, 18 in all) hold the arts a body knows. Keys 1–6 pick from the active bar, `[` and `]` switch bars, and `Q` still reaches an art that sits on no bar or was learned after every slot was filled. `B` opens a drag-and-drop arrangement panel that freezes the run — drag a slot onto another to move or swap, drag one off the panel to clear it, drag an unplaced art in from the roster, or right-click to empty a slot. Every slot shows its own art's cooldown as a sweep and a tenth-second timer, so one art gathering never hides another that is ready. The layout is saved; a pre-M34 save derives one from the known kit, and unknown or duplicated ids are pruned rather than trusted.
- Passives with rules: requirements on attributes/realm/physique/affinity, mutually exclusive passive pairs where the first acquired wins, situational activation (wounded or karma) rebuilt only on threshold crossing, pair synergies applied through the stat pipeline, and manuals by the shrine that teach three new passives.
- Physiques: seven weighted innate bodies (Mortal Frame to Chaotic Spirit Embryo) that add stats through the normal pipeline, rerollable at creation with P, shown on the creation screen and HUD, inherited once at the realm altar only when strictly better, and saved.
- Spiritual roots: a hidden purity bonus that only applies once the Root-Reading Pavilion appraises the root, Spirit Root Marrow found deterministically in mines and ruins, and one-tier root evolution paid in marrow and stones, all saved.
- Procedural loot: base, rarity, affixes and values come only from the item's own `(seed, key, counter)` stream, so the same seed reproduces an item no matter what was generated before it. Every affix has three tiers gated by item level (a level-twelve treasure rolls the top tier, level-one gear cannot), affix pools are weighted with per-slot overrides and a zero weight removes an affix, selection never repeats an affix on one item, and the rolled tier is kept in the item's canonical save form and named in its description.
- Equipment rules: bases can require attributes or a realm and carry tags that conflict across slots — a wind charm refuses heavy plate and an INT 14 rod refuses an INT 10 body — enforced by one gate that auto-equip and manual wearing both call, with the refusal reason shown. `I` opens a gear screen that freezes play, lists worn slots and bagged pieces and shows a stat-by-stat comparison (base power plus every affix, read exactly as the stat pipeline reads it) before ENTER wears the piece.
- Unique relics: two hand-authored items with fixed rolls, lore and one source each — the Hollow Moon Blade from the Warden (returns Qi per kill) and the Cloudstep Sash from the inheritance altar (returns health per kill). They are never rolled by loot, are granted once per save by their source, read gold with a ◆ in every list, show their lore in the gear comparison, keep their flag and lore through a save, and a broken relic returns nothing just as it contributes no stats.
- Satchel grid, sorting and a storehouse: `I` opens everything carried as a 6×5 grid, one page holding thirty kinds, with the worn slots and the selected piece's stat-by-stat comparison beside it and ENTER wearing through the same rules a pickup does. `R` cycles five orders (stored, slot, rarity, value, name); sorting rewrites the satchel itself so the HUD strip, the shop and the grid cannot disagree about an index, and every order is total — ties break on name, stable id and insertion order, so the same satchel always lays out the same way. The market's storehouse (`E`) is a second container with sixty shelves: the cursor picks a side, ENTER moves a whole stack across, a full storehouse refuses a new kind with a reason but still accepts a stack that merges, and a stored deposit survives a save. Shelf contents and the chosen order are saved with the run and validated on load.
- Crafting at the forge: the Azure Forge is a real station in the settlement with a recipe list in `data/crafting.json` — five authored recipes from `base` to spirit iron, each with materials, stones, a realm gate and a failure chance. **Forge** spends the materials and stones and produces the authored base through `ItemGen` (which gained a `force_base` pin, so a recipe names exactly what it makes), **refine** rerolls every affix on a piece while keeping its base, level, rarity and wear, and **disassemble** breaks a piece into spirit ore scaled by its rarity and level; relics and materials refuse all three. A failed forge loses its cost, a failed refine leaves the piece untouched, and INT raises the quality roll that can lift a result one rarity step. Every attempt advances the attempt counter — failures included — so a retry rolls a fresh stream rather than repeating a failed one. Materials now carry their kind in the canonical item (`ore`, `herb`, `core`, `marrow`) with an id-prefix fallback for older saves, so costs are exact counts across stacks, and the attempt counter saves with the run under schema 2.
- Alchemy at the cauldron: `data/alchemy.json` names the Herb-Garden Cauldron and three pills — Qi Gathering, Mending and Cleansing — each with its herbs and cores, stone cost, realm gate, failure chance and one effect (restore Qi, mend wounds, purge contamination). `Alchemy.brew()` is pure in its stream and makes the authored consumable, and because a pill has no rarity, quality shows as **potency** instead: INT raises it continuously, the quality roll adds a discrete jump, and the result is stored on the item, so two pills of one base can differ. Potency is part of a pill's stack identity, so a strong pill never disappears into a weak stack. A found pill is drinkable exactly like a brewed one (the effect is looked up by base), and pills are drunk from the satchel with `U`; the pill is spent even at full health. A spoiled brew costs its herbs and makes nothing.
- Professions: the forge and the cauldron are not free skills. Each is a rank earned by finishing work — **Smith** and **Alchemist** begin at Apprentice and rise through Journeyman, Adept and Master to Grandmaster at 4, 10, 20 and 34 completed pieces. Every successful forge, refine or brew is one point of practice; a failure or a locked recipe earns nothing, and breaking gear down is free so it never levels anyone. Rank is spent on two things: a bonus to the quality roll (on top of INT, so a master smith reaches results an apprentice cannot) and a reduction of the recipe's failure chance, with a floor so no work is ever risk-free. Recipes and pills name the rank they need — the Jade Ring and Wind Charm want a Journeyman, the Spirit Iron Ring and the Cleansing Pill an Adept — and the panels list locked work with the rank it requires instead of hiding it. Only practice points are saved; the rank is always derived from them, and an older save is simply an untrained one.
- NPC database: every body carries a whole generated record, not just a name. `data/npcs.json` gives each archetype an attribute template and growth, a root-tier band, a physique pool, an art pool, a gear pool and a set of ambitions from the goal catalogue; `NpcDb.sheet(archetype, id)` derives attributes, a root, a body, up to two arts, worn pieces and two goals purely from the world seed and the person's stable id, so a save stores none of it. Arts are filtered through `Techniques.can_learn` and gear is generated through `ItemGen` and passed through the same `Equipment` gate the player uses, so a record can never claim a body knows or wears what it could not. Walking near anyone shows their dossier on the HUD — realm, six attributes, root and purity, body, arts, gear, ambitions, and what they remember of you. Talking records the meeting (`met`, count, day, regard) in `Game.npc_memory`; base disposition plus earned regard gives a standing from hostile to warm, and that memory is the only NPC state a save carries.
- Daily schedules: every resident follows a routine from `data/npcs.json` across a seven-day week. Day 1 is a Metalday and the last day is the **Restday**, when each archetype switches to its own `rest_schedule` instead of repeating the weekday — disciples sleep in, merchants keep a longer market, farmers visit the shrine. An entry may carry a `days` filter (guards drill on Lightday instead of patrolling the plaza), a range may wrap past midnight, and `Schedules.validate()` proves every hour of every day has exactly one owner, so a gap or an overlap is a boot-time data error rather than a body frozen mid-routine. Bodies route through the plaza when walking between spokes instead of cutting through walls; the HUD clock names the weekday and the dossier shows the current routine (`Training at the training yard until 12:00`) and whether the body is still walking. Routines have teeth: a sleeping NPC cannot be spoken to, greetings are drawn from the activity, and Instructor Rui only teaches in the training yard during the 08:00–12:00 block. This also uncovered and fixed Rui's schedule key, which had pointed at a nonexistent table since his introduction.
- Loot tables: every source of loot is one data-driven table in `data/loot_tables.json` — wild kills, elites, bosses, ordinary containers, sealed chests, ruin caches and the inheritance altar — each owning its roll count, empty chance, rarity weights, slot weights, item-level bonus, minimum rarity and stone purse. `ItemGen` still decides what an item is; `Loot` only decides which roll is asked for, on its own stream, so the same kill always drops the same pieces and editing one weight cannot reshuffle another source. About one wild humanoid in eight turns up as an **elite**: a gold-ringed, tougher, harder-hitting body with its own `elite_died` death channel, its own table and a purse, so a rank can never roll twice. Sealed chests, containers and ruins now draw from their own tables instead of a hard-coded rarity, the boss pays two assured spirit-or-better pieces, and the inheritance altar adds one assured piece of its own on top of the relic and the technique. `DB.validate()` rejects a table with a bad weight, a malformed roll or stone range, a missing source, or a slot that no item base can fill.
- Secondary stats: evasion (rolled by the victim, capped at 55%), armour penetration against real enemy armour, cooldown reduction, crit damage replacing the old constant, out-of-combat health regen that stops when attacking, and realm-based lifespan — all reachable through new loot affixes and shown on the HUD.
- Attribute robustness: raw attributes floor at zero, every percent modifier is floored so cursed gear cripples instead of inverting (movement, attack speed, damage, Qi, cultivation), negative armour is ignored, crit/resist/lifesteal/recovery cap, and attribute costs cannot overflow.
- Character creation: a second screen for origin (Sect Orphan, Merchant's Child, Hunter's Child, Fallen Clan Heir) with a purse, starting method and at most one passive, plus a code-drawn appearance (robe, hair, skin palettes and a presentation line) saved with the character.
- Off-screen simulation: NPCs sleep beyond 1500 units (and inside hidden realms) with no per-frame cost, then wake snapped to the schedule that passed, reporting what changed while the player was away; chunk resources that regrew while unloaded are counted and reported too.
- Navigation and fast travel: a route list of settlement landmarks and discovered sites (T), travel that costs in-game time instead of stones, a waypoint with a HUD compass and distance, waypoint arrival detection, and saved routes and waypoints.
- World locations: deterministic overworld sites per chunk — collapsed ruins (one-shot loot, permanent), spirit ore veins (ore, refills after 10 days) and spirit stone deposits (stones, refill after 7 days) — each carrying its own regrow window in the chunk delta.
- Discovery rewards: the first visit to any site pays spirit stones once and is remembered in the save, so a site cannot be farmed for its discovery.
- Settlement services and economy: a merchant with deterministic daily stock and remembered purchases, buy/sell pricing on one value curve (sell pays 40%), a code-drawn shop overlay (1–6, TAB, E), and an inn that sells eight hours of rest for spirit stones.
- Biomes: four defined biomes in `data/biomes.json` (palette, prop weights, herb resources, enemy tables), assigned per chunk by smooth value noise seeded from the world, with the settlement's surroundings pinned to the starting biome; chunk props, herb species and the creatures that spawn nearby all come from the biome under them.
- Continent geography: a seeded 5×4 lattice of named land regions with terrain, distance tiers from the capital, enforced connectivity, and a code-drawn map (M) that shows where the playable province sits; nothing about it is stored.
- Weather and seasons: four 30-day seasons, six weather kinds drawn from a per-season table, deterministic weather per six-hour block of a given seed, weather-driven ambient light and storm flashes, and a cultivation rate that rain thins and storms charge.
- Interaction: doors that open a building's interior, one-shot containers with deterministic loot, technique manuals, and repeatable examination of scenery.
- Procedural animation: nine clips (idle, walk, run, sprint, attack, dodge, hurt, meditate, dead) with bob, lean, squash and limb swing on the player, NPCs and enemies.
- Attack animation is driven by the same startup/active/recovery frame data as the hit window, so the strike pose cannot drift off the damaging frame.
- Acceleration-based movement (2 400 u/s² accelerating, 3 000 braking), so turns plant instead of snapping.
- Hold-to-sprint at 1.45×, and right-stick aiming that falls back to the mouse.
- One input layer for keyboard, mouse and gamepad; rebinding a key never drops its gamepad button.
- Camera with world bounds (province and realm), five zoom levels, and smoothed follow.
- Y-sorted world: trees, rocks, bushes, buildings, NPCs and the player draw in depth order.
- Roof occlusion: a building fades while the player walks behind it, then returns to full opacity.
- Day/night lighting: `CanvasModulate` ambient tint plus shrine, rift and altar point lights.
- Resolution scaling: 1280×720 canvas, integer stretch on exact multiples, EXPAND otherwise.
- One settlement, 19 scheduled NPCs with generated records, one sect questline with event-driven steps and rewards.
- One procedural hidden realm with hazards, chests and a one-time inheritance.
- Save/load with atomic writes, sha256 verification, 3 backups, corruption fallback, schema migration.
- Structured logging with an in-memory ring buffer (`Log.dump()`).

## Not implemented yet

Character appearance and backgrounds (all characters are still code-drawn shapes, now
animated procedurally); travel between provinces; flight, domain projection, space folding
and the other declared realm capabilities; profession tools, masters and the deeper economy; NPC
relationships, parties and independent progression; the twelve sects and faction politics;
additional hidden-realm templates; dynamic world events; the main narrative and endgame;
UI screens beyond the HUD; audio.

The full 72-milestone status ledger lives in the design document (`§19 Authoritative roadmap`).
