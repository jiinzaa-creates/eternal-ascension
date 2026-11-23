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
| Interact / talk / pick up | E |
| Select technique (slots 1–6) | 1 – 6 |
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
   techniques spend Qi on left-click, and poise, stagger, knockback, dodge i-frames all apply.
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
- 8 techniques with startup/active/recovery frames, arc hitboxes, Qi costs, poise, knockback, scaling.
- Deterministic item generation: 4 rarities, tiered prefixes/suffixes, stable IDs, auto-equip.
- Equipment and passives feed real combat stats through `StatBlock`.
- Seamless streaming over a 12×12-chunk province: pure payload generation on worker threads, nodes built on the main thread, and a deterministic seed identity for every chunk.
- Chunk deltas: harvested resources are remembered per chunk with the day they were taken, saved with the run, and restored when the chunk streams back in.
- Background regrowth: chunk herbs return a few days after being harvested, evaluated from the clock when the chunk reloads rather than ticked per frame.
- Qi and meridians: twelve permanent channels opened in order at the meridian hall for Qi and stones, each raising capacity and adding a stat; Qi contamination from blood practice and failed breakthroughs (up to −50% gain) purged at the shrine for 30 stones; and per-biome Qi density multiplying meditation (marsh rich, ash poor).
- Cultivation methods with real loops: seven methods differ by what feeds them (sitting, STR, recent combat, absorbed blood, kills, a nearby partner, the night sky), each builds its own insight for up to +20% cultivation, and a method stele lets you switch for 150 stones only to a method you qualify for.
- Technique mastery: five tiers earned by landing a technique, raising damage while cutting Qi cost and cooldown, shown per slot on the technique bar and saved per technique. Falling Petal Cut is hidden from the starting kit and can be bought from Instructor Rui (180 stones) or learned for free by watching the practising disciple three times, both gated on realm and DEX.
- Passives with rules: requirements on attributes/realm/physique/affinity, mutually exclusive passive pairs where the first acquired wins, situational activation (wounded or karma) rebuilt only on threshold crossing, pair synergies applied through the stat pipeline, and manuals by the shrine that teach three new passives.
- Physiques: seven weighted innate bodies (Mortal Frame to Chaotic Spirit Embryo) that add stats through the normal pipeline, rerollable at creation with P, shown on the creation screen and HUD, inherited once at the realm altar only when strictly better, and saved.
- Spiritual roots: a hidden purity bonus that only applies once the Root-Reading Pavilion appraises the root, Spirit Root Marrow found deterministically in mines and ruins, and one-tier root evolution paid in marrow and stones, all saved.
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
- One settlement, 19 scheduled NPCs, one sect questline with event-driven steps and rewards.
- One procedural hidden realm with hazards, chests and a one-time inheritance.
- Save/load with atomic writes, sha256 verification, 3 backups, corruption fallback, schema migration.
- Structured logging with an in-memory ring buffer (`Log.dump()`).

## Not implemented yet

Character appearance and backgrounds (all characters are still code-drawn shapes, now
animated procedurally); travel between provinces; flight, domain projection, space folding
and the other declared realm capabilities; alchemy, forging, professions and economy; NPC goals, memory,
relationships, parties and independent progression; the twelve sects and faction politics;
additional hidden-realm templates; dynamic world events; the main narrative and endgame;
UI screens beyond the HUD; audio.

The full 72-milestone status ledger lives in the design document (`§19 Authoritative roadmap`).
