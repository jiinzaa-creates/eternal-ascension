# Development workflow

## Engine pin

| | |
|---|---|
| Engine | **Godot 4.4.1 stable** (standard build, not .NET) |
| Language | GDScript only (a .NET dependency would break headless CI) |
| Renderer | GL Compatibility |
| Project file | `game/project.godot` |

Upgrading the engine is a milestone-level change: it must be recorded here, in the
project README, and verified by the full test suite and a manual playtest, because
Godot's serialization and physics behaviour can shift between versions.

## Running the game

Open `game/project.godot` in the Godot editor and press **F5**. There is no build step
and no asset import step; all visuals are drawn in code, so the project opens instantly.

## Running the verification suite

```sh
godot --headless --path game --editor --quit                              # import check
godot --headless --path game res://tests/run_tests.tscn                   # unit + content
godot --headless --path game res://tests/integration.tscn                 # real-scene smoke
godot --headless --path game --quit-after 240                             # boot smoke
```

Every command must exit `0`. `run_tests` prints `RESULT: PASS n / FAIL n`; the gate is
**FAIL 0**, not a particular number. CI runs exactly these commands (`.github/workflows/ci.yml`).

Test suites live in `game/tests/`. New systems must ship with checks in the same commit:
a system that cannot be tested headlessly must still be reported as untested rather than
described as working.

## The determinism rule

Anything generated — items, chunks, rooms, NPCs, loot — must be a pure function of
`(world_seed, domain, key, counter)` through `Rng.stream()`.

- **Never** call `Array.shuffle()`, `randf()`, `randi_range()` or any other global-RNG
  function in generation code. Those read engine-global state, so results depend on call
  order and two identical seeds diverge. (This exact bug broke hidden-realm room roles.)
- Generated content has a **stable string ID**; saves reference IDs, never indices.
- Procedural world state is regenerated from the seed; saves store only deltas.

## Meridians, contamination and Qi density

- **Twelve primary meridians** (`data/meridians.json`) are opened in data order at the meridian hall for
  spirit stones plus `Meridians.OPEN_QI_PCT` (35%) of current Qi capacity. Each is permanent, adds one mod
  through `StatBlock.rebuild(..., meridian_mods)` and raises capacity by 4% (`Meridians.capacity_mult`).
  Realm gates (`realm` on the entry) are checked by `Meridians.can_open`; the hall only ever offers
  `next_available`, so you cannot skip into a high-realm channel.
- **Contamination** is a 0–100 value on `Cultivation`, saved with the character. It multiplies Qi gain and
  regeneration by `1 - contamination / 200`, i.e. at most −50%, never inverting. Sources: practising the
  Blood Sea (0.8/s while meditating) and a failed breakthrough (+12). The shrine purges it for
  `Meridians.CLEANSE_COST` (30 stones).
- **Qi density** is per-biome data (`qi_density`: verdant 1.0, marsh 1.15, ashen 0.8, frost 0.9) and is
  multiplied into `Player.environment_bonus()` with the weather. `Game.biome_density` is derived each frame
  from the chunk under the player and is never saved.
- `meridians` and `contamination` are optional save keys; legacy saves start with no open channels and clean
  Qi.

## Realms, sublevels and realm arts

- **The ladder is data** (`data/realms.json`): twelve realms, ten sublevels each, with `qi_mult`,
  `attr_mult`, `lifespan`, `color`, `tribulation`, `unlocks` and one `ability`. `Realms` is the only
  reader; `StatBlock` takes lifespan from `Realms.lifespan` and `Cultivation.base_qi` takes the
  sublevel curve from `Realms.sublevel_factor`, so data and rules cannot drift apart.
- **Sublevels are incremental.** Every sublevel multiplies Qi capacity by `1 + 0.35 * (sublevel - 1)`;
  1–3 are Early, 4–6 Middle, 7–9 Late and 10 Peak (`Realms.sublevel_label`). The HUD shows
  `Cultivation.stage_title()` ("Foundation Establishment 5 · Middle"); toasts keep `stage_label()`.
- **Realms are qualitative.** Each entry declares `unlocks` (`{id, name}`) and one realm art
  (`id`, `name`, `desc`, `flags`, `mods`). Unlocks are **cumulative** (`Realms.unlock_ids`); the art is
  **current realm only** (`Realms.ability_mods`), passed to `StatBlock.rebuild(..., realm_ability_mods)`
  after passives and before meridians. Twelve arts therefore never stack into nonsense.
- **Mechanically wired flags**: `dash_cancel` (Foundation, realm 2) lets `Player.try_dodge` abandon a
  swing — before it a committed attack cannot be dodged out of, and spent Qi is never refunded.
  `technique_weaving` (Spirit Transformation, realm 5) multiplies technique Qi cost and cooldown by
  `Realms.WEAVING_MULT` (0.9). The other flags (`flight`, `space_folding`, `domain_projection`, …) are
  declared capabilities that later milestones consume; they do not yet change behaviour.
- **Apex guard**: `Cultivation.attempt_breakthrough` refuses with `reason == "apex"` at realm 12, and
  `from_dict` clamps a corrupt realm into 1–12. A successful attempt returns the new realm's `unlocks`
  and `ability`; `Player` turns them into an "Realm art awakened" toast.

## Combat architecture

- **One rules layer, two sides.** `Combat` owns frame-phase progression, phase timing, hitbox geometry and
  the interruption rule; `Poise` owns the stagger meter. The player and every enemy use both, so reach,
  facing, poise and stagger cannot drift between the two sides of a blow.
- **Frames.** `Combat.next_phase` is `idle → startup → active → recovery → idle`; `phase_seconds` converts a
  technique's 60 Hz frame counts to seconds with attack speed, applies recovery reduction to recovery only,
  and keeps a minimum so no phase vanishes at absurd speed. A strike resolves once, when startup ends.
- **Hitboxes.** `Combat.in_hitbox` supports `arc` (reach plus facing half-angle, the default) and `circle`
  (any angle of 360, used by enemy blows). Target radius extends reach, so a body is hit by its edge. All
  damage dealers share the same geometry, and a target at the attacker's origin is always struck.
- **Poise.** `Poise` is a guard meter; the blow that empties it staggers for `0.35 + poise_damage × 0.01`
  seconds (clamped 0.35–0.9), refills the meter and cannot chain-stagger. Enemies read their capacity from
  their level (`40 + 6·ilvl`); the player's comes from `Combat.poise_capacity(realm, STR)`. A staggered body
  cannot act; knockback impulses (`Combat.knock_impulse`, ×0.12, ×0.2 on a break) carry it.
- **Interruption.** Only startup is interruptible (`Combat.interrupts`): a stagger during a wind-up cancels
  the attack before it lands (the Qi is already spent), while an active swing is committed. Any damage also
  breaks meditation.
- **Why it is testable.** Every rule is a pure static or a small `RefCounted`; the entities only own timers,
  positions and the node tree, so the whole architecture runs headlessly without a viewport.

## Lifespan and aging

- **Age is derived, never ticked.** `Game.born_day` is the only saved aging field; age is
  `Aging.age_for(born_day, Clock.day)` — `START_AGE` (16) plus elapsed days. Because the clock is read each
  frame in `main._check_aging`, inn rest, fast travel and any jump in `Clock.day` all count in full, and a
  save cannot disagree with the calendar.
- **Compressed years.** The calendar runs 30-day seasons, but the body ages one year every
  `Aging.DAYS_PER_YEAR` (24) days. A realm-1 lifespan of 120 years is therefore 2,880 world days. The
  constant is the single tuning knob for the whole aging pace.
- **Decline.** Past 60% of the lifespan, STR, DEX and AGI fall on a straight line to
  `DECLINE_MAX` (35%) at the lifespan. `StatBlock.rebuild(..., aging)` scales the *total* of base and flat
  attributes in `get_attr`, so the raw sheet is untouched and the effect is fully reversible; WIS, INT and
  CHA are never reduced. The penalty is clamped to 0.9 even for corrupt input.
- **Stages and warnings.** `prime → middle (60%) → old (85%) → fading (95%) → ended (100%)`, or `ageless`
  for an unbounded lifespan (realm 12). `Game.age_warning_stage` records the highest announced stage, so each
  toast (`Aging.warning_for`) fires once, and it is saved.
- **Death ends the run.** At or past the lifespan `main._end_run` sets `phase = "ended"` and `Game.dead`,
  stops the body, clears any tribulation and shows the end screen (`HUD.draw_ended`): age, realm, kills,
  karma, stones and days lived. **ENTER** reloads the scene for a new run. An ended run refuses to save, and
  loading a dead save returns to the end screen instead of play. `born_day` and `dead` are optional save
  keys; a legacy save starts alive at the starting age.
- **HUD.** The vitals regeneration line now reads `Regen x/s   Age N/M · middle age`.

## Enlightenment and comprehension

- **Understanding is a meter** (`Cultivation.enlightenment_meter`, 0–`ENLIGHTENMENT_GOAL` = 100). It never
  decays. Sources are real play, funnelled through `Player.gain_comprehension`: meditation adds
  `delta * clamp(fit, 0, 2)`, every kill adds 2, surviving a tribulation adds 20, and a successful realm
  breakthrough adds 30.
- **One trigger.** When the meter fills, `gain_comprehension` rolls an epiphany: `Rng.stream("enlightenment",
  realm, enlightenment_attempts)` feeds `Enlightenments.pick`, a weighted choice among insights that are
  **eligible** (realm, method, and optional INT gate) and **not owned**. If nothing is in reach the meter
  stays full — understanding is never wasted — and nothing is rolled.
- **Insights are permanent and cumulative.** `data/enlightenments.json` holds thirteen insights with a
  weight, requirements and mods. Every learned insight contributes through
  `StatBlock.rebuild(..., enlightenment_mods)`; there is no activation state, because an insight cannot be
  forgotten. Every stat name is validated against `Attributes.KEYS`, `PERCENT_STATS` and `FLAT_STATS`.
- **Data integrity.** `DB.validate` checks ids, names/descriptions, weights, mods, stat names, realm gates
  and that a `requires.method` exists. `Player.from_dict` drops unknown or duplicated insight ids, so a
  corrupt save cannot inject phantom mods.
- **Persistence and HUD.** `enlightenments` is an optional player save key; the meter and attempt counter are
  optional cultivation keys (legacy saves start at zero). The HUD shows `Comprehension: N%   Insights: n/13`
  plus the learned names.

## Playable tribulations

- **One pure state machine** (`game/systems/tribulation.gd`). `setup(type_id, scale, centre, rng)` builds the
  trial from `data/tribulations.json`; `tick(delta, player_offset)` advances the schedule and returns
  `{struck, wave_finished, finished, broken}`. The node (`game/world/tribulation_arena.gd`) only ticks it,
  applies damage and draws, so the encounter is deterministic and testable without a display.
- **Waves are movement tests.** Every bolt is telegraphed for `TELEGRAPH` (0.9 s) at a position scattered
  within the trial's `radius` of the arena centre, and bolts inside a wave are staggered by `interval`.
  A bolt hits if the player is within `BOLT_RADIUS` (44) when it resolves. A wave with no hits is
  **perfect** and earns `COMPOSURE_PER_WAVE` (4%), capped at `MAX_COMPOSURE` (12%).
- **Damage is heaven's, not physical.** `Player.take_tribulation_damage` skips armour and evasion but still
  respects i-frames, so a well-timed dash slips between strikes. It does not call `_die`: hitting zero hp
  aborts the trial, and `Player.fail_breakthrough()` applies the M26 failure fallout without a success roll.
- **Flow.** `G` (`main._face_tribulation`) requires a peak, a non-apex realm and full Qi; it then starts the
  trial, and `Bus.tribulation_finished` routes to `player.attempt_breakthrough(composure)` or
  `player.fail_breakthrough()`. Below the peak or at the apex the key still falls through to
  `attempt_breakthrough`, which keeps its M25/M26 refusals and apex guard.
- **Not saved.** `_save` refuses while a trial runs ("The heavens do not pause for a save.") and `_load_game`
  frees a live arena. The arena seed mixes the world seed, realm and attempt count.
- Eleven trials are data: meridian (3×2) through lightning, heart demon, elemental, spatial, bloodline,
  heavenly judgment, grand, dao, sovereign and primordial (7×7). `DB.validate` checks each realm's declared
  tribulation exists; `Tribulation.for_realm` falls back to the meridian trial rather than an empty fight.

## Breakthrough preparation and method tribulations

- **One formula.** `Cultivation.estimated_chance()` is what the HUD shows and what `attempt_breakthrough`
  rolls: `base + WIS control + INT insight + (0.06 · preparation) + method chance − tribulation · 0.35`,
  clamped 0.02–0.97. `Cultivation.tribulation_with()` is
  `(0.25 + 0.06·realm + 0.002·kills + 0.003·|karma|) · method tribulation · (1 − 0.10 · preparation)`.
- **Preparation is a resource, not a buff.** The tribulation ground (`Kind.TRIBULATION`, id
  `tribulation.ground`, beside the shrine) banks one preparation for `Cultivation.PREP_COST` (60 stones),
  capped at `MAX_PREPARATION` (3). The attempt reads the bank and clears it **before** rolling, so a win
  does not refund it and a loss cannot be retried on the same bank. Each preparation adds 6% chance,
  removes 10% of Heaven's weight and 15% of failure's fallout. Saved as the optional `preparation` key;
  corrupt values clamp to 0–3.
- **Methods reshape Heaven** (`Methods.breakthrough_profile`, pure, like `meditation_multiplier`):
  traditional neutral; body +4% chance, ×1.1 tribulation, ×0.75 harm; sword +10% with recent combat and
  −6% without; blood +5% (and ×1.4 harm) with ≥20 charge, −4% (×1.2 harm) when dry; slaughter ×1.15
  tribulation and ×1.2 harm; dual +8% with a partner, −5% alone; heavenly +9% at night, −5% by day. The
  profile's `note` is shown on the HUD and in the failure toast.
- **Failure fallout** now scales with the profile: hp `clamp(0.35 · harm, 0.1, 0.6)`, contamination
  `DEVIATION_CONTAMINATION · harm`, and the realm-regression threshold `8% · (1 − 0.25 · preparation)`.
  Success wounds still come from the tribulation scale alone.
- The HUD adds a tribulation line only at a peak below realm 12: chance, banked preparation and the
  method's note. `Player.attempt_breakthrough()` passes `method_state()` (recent combat, partner, night,
  blood charge) so the live situation is what Heaven reads.

## Cultivation methods: fit, insight, switching

- Seven methods share one meditation loop and differ only by **mechanic** (`Methods.meditation_multiplier`):
  traditional is always 1.0; body scales with STR; sword is 0.3 while calm and 1.7 within 6 s of combat
  (`Player._combat_timer`); blood scales with `blood_charge`; slaughter with total kills; dual needs an NPC
  within 110 px; heavenly needs `Clock.is_night()`.
- **Requirements are structured** in `methods.json` (`requires.attrs`, `kills`, `physique_tier`, `realm`), not
  parsed from the human-readable `requirement` line. `Methods.qualifies` is the single gate.
- **Insight** is a per-method float 0–100. `meditate_tick` adds `delta * clamp(fit, 0, 2)`, so focused
  method play builds it and idle wrong-method sitting barely does. It is stored fractionally (a per-frame
  slice must still add up) and gives at most +20% to the method's own multiplier
  (`effective_method_mult`).
- **Blood charge** is the Blood Sea's fuel: `Player.on_kill` adds it (called from `_on_enemy_died`), meditating
  spends it at 2/s. Capped at 100 and saved.
- **Switching** happens at the method stele (`Kind.METHOD`) for `Methods.SWITCH_COST` (150 stones). It cycles
  only through methods the character currently qualifies for, so a locked method cannot be bought by accident.
  Origins still set the starting method for free, once, at run start.
- `method_insight` and `blood_charge` are optional save keys; legacy saves start at zero insight and no charge.

## Techniques: mastery, teachers, observation

- **Mastery is one stored integer per technique** (`Player.technique_xp`, id → xp). Tiers, labels and
  multipliers are pure functions in `Mastery`, so balance changes are a code edit, not a save migration.
  Mastery improves damage, lowers Qi cost and shortens cooldowns; it never alters frame data, because
  timing is the technique's identity.
- XP is earned by landing the technique (`_strike`, 1 per swing) and cannot exceed the top tier. The
  technique bar shows each technique's tier label.
- **Grants vs. learning** mirrors passives: `learn_technique` is the grant path used by the starting kit,
  manuals, inheritances and quest rewards and never checks requirements; `try_learn_technique` is used by
  teachers and observation and enforces the technique's `requirements` (realm plus attribute minimums).
  `requirements.physique` is a legacy bloodline marker, not a physique id, and is not checked.
- **Teachers** are ordinary NPCs with a selling branch in `_talk` (Instructor Rui sells Falling Petal Cut
  for 180 stones). They check requirements, then price, and only then spend.
- **Observation**: a demonstration interactable (`Kind.DEMONSTRATION`) offers `observe_technique`, which
  requires the same qualifications and takes `Techniques.OBSERVE_REQUIRED` (3) watches. Progress is
  stored per technique in `Player.observed` and saved, so watching across sessions still finishes.
- Both `technique_xp` and `observed` are optional save keys; legacy saves start with untrained techniques
  and no observations.

## Passives: requirements, conflicts, conditions, synergies

- **Ownership and activation are separate.** `Player.add_passive` is a grant (quest, inheritance, origin)
  and never checks requirements; `Player.try_learn_passive` is voluntary learning (manuals, teachers) and
  refuses what the body cannot use yet. A granted passive the body cannot use is kept and dormant.
- `Passives.resolve(owned, state)` returns the ids that actually apply, in owned order. `rebuild_stats`
  passes exactly those to `StatBlock`, so the pipeline never sees a dormant passive.
- **Conflicts: first acquired wins.** The earlier id in the owned list stays active; the later one is
  dormant with a reason. Order is stable because it is the order the save stores. New content should
  therefore list the more physical passive first only if that is the intended priority.
- **Requirements** (`requires`): `min_attr`, `min_realm`, `min_physique_tier`, `affinity`. **Conditions**
  (`condition`): `wounded` (below 35% hp), `karma_above`, `karma_below`. Conditions are evaluated from
  `Player.passive_state()` and rebuilt only on threshold crossing (`_refresh_passive_conditions`), never
  per frame.
- **Synergies** (`synergy: {with, mods}`) add mods when both partners are active; `StatBlock.rebuild`
  applies them after the passives themselves, additively, so a synergy cannot break the stat floors.
- `DB.validate` checks requirement attribute keys, self-conflicts and synergies without partners.
- New passives are learned from manuals (`setup_passive_manual`), three of which stand by the shrine.

## Physiques

- Content lives in `data/physiques.json`; a physique is **mods only** (same keys as equipment and
  passives) and is applied in `StatBlock.rebuild(..., physique_id)`. There is no physique-specific
  stat code path, and there must not be one.
- `Physiques.roll(key)` is weighted and deterministic (`Rng.stream("physique", key)` mixes the world
  seed). The roll counter advances on creation rerolls (`P`), so rerolling the body is a new roll.
- **Inheritance is monotonic**: `best_of` and `Player.inherit_physique` accept only a strictly higher
  tier, ties keep the current body. The realm altar rolls with `realm_seed`, so the inheritance is
  repeatable per save and can never be a downgrade dressed as a reward.
- `Player.rebuild_stats()` passes the physique, so any path that changes equipment, passives or realm
  also re-applies it. Legacy saves default to `physique.mortal_frame` (empty mods), so nothing moves.
- Creation shows the rolled physique; HUD vitals show it permanently.

## Spiritual roots: appraisal, marrow, evolution

- A root rolls a tier at creation plus a **hidden purity bonus** (`purity_bonus`, 0–0.25) from
  `Rng.stream("root_purity", counter)`. The tier's own purity always applies; the bonus applies only
  once `identified`. This makes appraisal pure upside, so ignorance cannot trap a build.
- `Cultivation.effective_purity()` is the single place purity is computed — `qi_max` and
  `qi_regen_per_sec` read it. Do not read `root_data().purity` directly anywhere else.
- The pavilion (`root.pavilion`, `Interactable.Kind.ROOT`) appraises for `Roots.IDENTIFY_COST` (40),
  then evolves one tier for one Spirit Root Marrow plus `Roots.evolve_cost(tier)`. It is repeatable
  and every refusal names its reason (`max_tier`, `no_marrow`, `no_stones`).
- **Marrow is discovered, not bought**: `Roots.marrow_found(coord, site)` is deterministic per site
  (35%), rolled by mines and ruins. The same mine always either holds it or does not, so a save
  cannot reroll a site by reloading.
- Evolution keeps the purity bonus and clamps Qi to the new maximum; it does not touch realm,
  sublevel or method.
- Legacy saves default to `identified = true` (they were played with a visible root) and add no
  hidden purity, so their numbers do not move.

## Secondary stats

- New modifier keys: percent `evasion`, `penetration`, `cooldown_reduction`, `crit_damage`; flat
  `health_regen` (hp/s) and `lifespan` (years). They live in `PERCENT_STATS`/`FLAT_STATS`, so
  affixes, passives and equipment all reach them through the same pipeline.
- Caps and floors are constants on `StatBlock` (`EVASION_CAP` 0.55, `PENETRATION_CAP` 0.6,
  `COOLDOWN_CAP` 0.5, crit damage 1.2–3.0). A stack of affixes must not make a character
  untouchable or immortal.
- **Evasion is rolled by the victim**, in `Player.take_hit`, from the `"evade"` Rng stream keyed by
  kills and a private counter. `take_hit(..., can_evade)` is false for floor hazards: a hazard is not
  an attack. `StatBlock.evades(roll)` is the pure decision, strict `<` so 0% never evades.
- **Armour lives on `Dummy`** (`armor_value = 8 + 5*ilvl`) and `take_hit` now applies
  `Damage.mitigate_armor`. Penetration reduces that armour before mitigation; without armour on the
  target, penetration would be a stat with no effect.
- **Cooldown reduction** multiplies the technique cooldown when a swing finishes; **crit damage**
  replaces the old constant `CRIT_MULTIPLIER` in `Player` (the DEX curve lands at ~1.8 at DEX 10, so
  tuning did not shift).
- **Regen** is `Player.regenerate(delta)`: no regen while attacking or within `_hurt_flash`, so a
  fight cannot be won by out-healing it. Lifespan is display/data only until aging exists; realm 12
  declares 0 years, meaning unbounded.
- Affixes for all six exist in `data/items.json` (Piercing, Hasty, Ruinous, of Evasion, of Vitality,
  of Longevity) so the stats are reachable from loot rather than only from test code.

## Attributes and extreme values

- Raw attributes floor at **zero** in `Attributes.add`/`from_dict`. Debuffs can take a mortal to
  nothing, but a negative primary would leak into every formula.
- `StatBlock.factor(percent)` is the only percent conversion: `max(0, 1 + pct/100)`. A cursed item
  can cripple a stat but must never invert it — negative movement walks backwards, negative Qi
  capacity divides by a negative.
- Every derived stat has a floor: damage x0.05, movement 24, attack speed 0.2, Qi capacity x0.1,
  Qi regen 0, cultivation x0.05, comprehension/crafting x0.1. Caps: crit 0.95, resist 0.85
  (also the incoming-resistance cap), lifesteal 0.5, recovery reduction 0.35, accuracy 1.0.
- `Damage.mitigate_armor` ignores negative armour. The raw fraction would otherwise give a cursed
  item up to 75% mitigation (`armor = -60` → `-60/1` → clamp 0.75).
- `Attributes.attr_cost` clamps its exponent (level ≤ 400, price ≤ 9e15) so an absurd level cannot
  overflow into a free or negative price.
- Realm `attr_mult` must be positive; `DB.validate` rejects data that would zero every attribute.

## Character creation

- Two screens, one flag: `main.creation_stage` 0 is formation points, 1 is identity. ENTER advances,
  BACKSPACE goes back, and only stage 1 starts the run.
- Origins are content (`data/origins.json`) and small on purpose: a purse, a starting method and at
  most one passive. A background that decided the build would make formation points pointless.
  `Origin.effects` clamps stones and `DB.validate` checks every method/passive reference.
- `_apply_origin()` runs **once**, from `_begin_run()`; a loaded save already holds the effects, so
  loading must never re-apply them. This is why origin is not applied in `Game.from_dict`.
- Appearance is palette indices (`Appearance`), never colours in the save: reordering a palette would
  silently restyle every existing character, so append only. Out-of-range indices are clamped.
- The player draws robe, skin and hair from `appearance`; hurt and i-frame tints still override the
  robe, so state always reads over cosmetics.
- Presentation is currently a pronoun line (`she/her`, `he/him`, `they/them`) and is cosmetic by
  design. Nothing gates on it.

## Off-screen simulation

- An `Npc` is either `simulated` or asleep. `sleep()` stops `_physics_process` entirely, so an
  unobserved town costs nothing per frame; `wake()` snaps the NPC to the schedule for the current
  hour (`snap_to_schedule`) instead of walking it back, and any activity change is remembered.
- `main._simulate_npcs` owns the rule: NPCs sleep beyond `NPC_SIM_RADIUS` (1500) and inside a hidden
  realm. Do not add per-NPC distance checks elsewhere; one rule keeps the town coherent.
- Waking must be reachable from every path that changes the player's position (travel, realm exit,
  load), which is why this lives in `_process` rather than in the travel code.
- Changes wait in `_away_notes` and are flushed only when the player is back near the plaza, at most
  three at a time. `_npc_seen` holds the activity each NPC had when it last slept.
- `ChunkManager` counts resources that `prune` expired while a chunk was unloaded (`regrown_total`)
  and emits `regrown`; the host sums it into `_wilds_recovered` and reports it once on return.
  Regrowth is still clock-evaluated on stream-in, never ticked.
- Sleeping NPCs are not saved specially: the schedule and the clock are the state.

## Navigation and fast travel

- `Travel` is pure maths (hours, bearing, metres, destination list). The host moves the player and
  advances the clock; nothing in `Travel` touches the scene.
- **Travel is paid in time, not currency**: `Clock.advance(hours)` moves schedules, weather and
  regrowth together. Do not add a second travel currency without also deciding what time means.
- Destinations are settlement landmarks plus `travel_sites`, which records discovered sites with
  their positions so they stay reachable after their chunk unloads. The list is capped at
  `Travel.MAX_ROWS` (6) and sorted by id; landmarks always come first.
- Waypoints are `waypoint_name` + `waypoint_position` on the host, drawn by `Hud.draw_waypoint` as a
  rotated arrow with distance. `Travel.has_arrived` clears it within `ARRIVE_RADIUS`.
- Travel is blocked inside a hidden realm (`Travel.can_travel`), and the panel freezes both player
  loops like the map and shop. Restore them on every close path.
- After moving the player, re-stream and `settle()` before showing anything: the destination may be
  outside the current ring.

## World locations

- Overworld sites (ruins, ore veins, deposits) are generated per chunk by `ChunkGen._pois_for` from
  their own RNG stream, so adding sites cannot reshuffle decorations or herbs of an existing seed.
  One site per chunk at most, id `poi.<kind>.<cx>.<cy>`.
- **Every chunk resource carries its own regrow window.** `WorldDelta` entries are
  `{day, window}`; `mark_spent(..., window_days)` chooses it and `is_spent`/`prune` read it per
  entry. Herbs use 3 days, deposits 7, veins 10, and ruins `WorldDelta.PERMANENT`.
  Never hard-code a single regrow constant again: pass the window with the spend.
- `WorldDelta.from_dict` still accepts the earliest day-only format, so pre-M13 saves load.
- Discovery is `Game.discover(id)` (saved with the run) and pays spirit stones exactly once per
  site instance. Do not pay again on regrow — regrown sites are ordinary resources.
- New site kinds need four places: the `Interactable.Kind` value, `poi_kind`/`poi_label`/
  `poi_regrow` mappings, a `_draw` branch, and a handler in `Main._use_interactable`.

## Settlement services and economy

- **One value curve**: `ItemGen` already stamps `value` (base × rarity × ilvl). `Economy` only derives
  `buy_price` (that value) and `sell_price` (40%, minimum 1). Do not add a second worth scale; add
  to item generation instead.
- Selling is always lossy, so buy→sell can never be a profit loop. Keep `SELL_RATE < 1`.
- `Merchant` stock is a pure function of (world seed, merchant id, day) through `ItemGen`. Only
  **sold item ids for the current day** are saved (`shop.day` + `shop.sold`); the goods themselves
  are regenerated. A new day clears the record and stocks a full shop.
- Buying goes through `Player.pick_up`, so auto-equip and stat rebuild happen as with any loot.
  Selling must erase the equipment entry when the sold item is the worn one — otherwise the stat
  pipeline keeps a budget for an item the player no longer owns.
- Services are ordinary `Interactable`s (`SHOP`, `INN`) so the prompt, distance rule and one-shot
  state keep working. The shop overlay freezes the player like the map does; never open a modal
  overlay without restoring both player loops on close.
- Resting advances `Clock.advance(8.0)`; schedules, weather and regrowth all follow from that, so do
  not add a separate "sleep" timer.

## Biomes

- Definitions live in `data/biomes.json` and are validated by `DB.validate()`: id, name, palette,
  prop weights, resources and enemies are all required. Add a biome here, not in code.
- **Identity is pure and thread-safe.** `Biome.for_chunk(coord, seed)` is smooth value noise over a
  coarse grid, so neighbouring chunks usually share a biome; it reads no files and no autoloads.
  The settlement's 3×3 chunk block is pinned to `BANDS[0]`, so the opening area never becomes ash.
- Chunk payloads take a **snapshot** of the biome table (`DB.biome_table()`) because they are built
  on worker threads. Never pass `DB` itself, and never mutate the snapshot during play.
- A biome owns four things a chunk uses: ground palette, prop weight table, herb species table and
  the enemy table used by spawns at that position. Add a new resource or enemy species by editing
  the biome entry; the code paths already read it.
- Enemy definitions only carry multipliers (`hp_mult`, `damage_mult`, `ilvl_bonus`, `speed`, colour);
  `Dummy.apply_biome_enemy` applies them after `_ready`, which derives the base stats from `ilvl`.

## Continent

- `Continent.generate(seed)` is pure and builds the whole geography as data: cells, land mask,
  terrain, unique region names, neighbours and distance tiers.
- **Connectivity is built in, not repaired afterwards**: land grows outward from `CAPITAL`, so no
  region can ever be stranded, and a minimum region count is forced so unlucky rolls cannot make a
  two-cell continent. Any change to generation must preserve both properties.
- Only `CAPITAL` is playable; every other region is geography until travel exists. `region_for_world_position`
  is the single place that assumption lives — travel will replace it, not the map.
- Nothing about the continent is saved: it is a function of the world seed, like the province.
- `WorldMap` reads `Continent` data only and draws; it never generates. Layout maths lives in
  `Continent.map_rect` so it is testable without a `Control`.
- While the map is open, play is frozen by disabling both player loops. Do not render an opaque
  overlay without doing this.

## Streaming

- Generation is split in two: `ChunkGen.payload_for(coord, seed)` returns **plain data only**
  (features, resources, signature) and may run on any thread; `ChunkManager` creates every node,
  on the main thread, when the payload arrives. Never create nodes, touch the scene tree or read
  autoload state from `ChunkGen` or from any other worker body.
- Threading is opt-in (`ChunkManager.threaded`); unit tests leave it off so streaming is
  synchronous and assertions read top-to-bottom. The running game turns it on and calls
  `settle()` at boot so the first frame has ground.
- Chunks own their resources (herbs). When a chunk is freed its resources are freed and the owner
  is told through `on_resource_freed`, so nothing keeps a dangling node in `main.interactables`.
- Resource state lives in `WorldDelta`, keyed by `"cx,cy"` and then by stable resource id. It is
  saved as `chunk_deltas`; missing entries mean "pristine", which is why old saves need no
  migration.
- **Regrowth is background simulation without a loop**: nothing ticks off-screen. A resource is
  spent only while `today - spent_day < HERB_REGROW_DAYS`, and expired entries are pruned when
  the chunk streams in. Do not add per-frame simulation for unloaded chunks.

## Climate

- `Climate` is pure static data and functions; `Weather` (autoload) is the only stateful half.
- **Weather is not saved.** The day is cut into six-hour blocks and the block's weather is a
  pure function of `(world_seed, day, block)` via `Rng.stream("weather", ...)`. Reloading the
  same save at the same hour therefore produces the same sky, and no schema bump was needed.
- Seasons are 30 days each, four per year, derived from `Clock.day`; the per-season weight table
  is what makes it snow in winter and storm in summer. Do not branch on season anywhere else.
- Weather changes two gameplay-visible things only: `Climate.cultivation_bonus` (via
  `Player.environment_bonus`) and the ambient light in `WorldLighting`. Anything else that reads
  weather should go through `Climate` too, so it stays testable without a scene.
- `Weather` recomputes only when the day or block changes, and emits `changed` when the sky turns;
  the HUD reads `Weather.label()` and `Weather.current` directly, as it does with `Clock`.

## Interaction

- `Interactable` carries the kind: herb, shrine, portal, chest, altar, door, container, manual,
  examine. Kind-specific data lives on small setup helpers (`setup_door`, `setup_container`,
  `setup_manual`, `setup_examine`) rather than in a loose dictionary.
- **`can_interact()` is the single rule** the prompt and the handler share. A spent node must
  return false; a node that still offers feedback (altar, shrine, door, examination) returns true.
- One-shot nodes (herb, chest, container, manual) record their stable id in `used_interactables`,
  which is saved and re-applied on load. Because ids are strings this needs no schema bump.
- Doors toggle `Building.interior_open`, which forces that building's roof transparent so the
  interior reads as entered. Door open/closed state is **session-only**: persisting it would require
  a save-schema bump, so do not add it silently.
- Container loot is generated from `hash(stable id)`, so the same crate yields the same item after
  a reload rather than rerolling.

## Animation

- There are no sprite sheets: animation is a **pose**. `Animator` picks a clip from
  `(speed_ratio, sprinting, attacking, dodging, hurt, meditating, dead)` and returns bob, squash,
  limb swing and lean from `Animator.pose(clip, time)`. Actors apply those around their drawing only;
  shadows and ground rings stay in world space.
- Clip priority is fixed: death > hurt > dodge > attack > meditation > sprint > run > walk > idle.
  Sprint still requires movement.
- **Attack poses come from combat frame data.** `Animator.attack_swing(phase, ratio)` takes the
  technique's startup/active/recovery phase and the phase progress the player tracks, so the visual
  strike cannot drift off the frame that deals damage. Do not add an attack animation with its own
  timer.
- Any new actor should own an `Animator`, call `update()` once per frame, and wrap its drawing in
  `draw_set_transform(pose.bob, pose.lean, pose.squash)`.
- Poses are pure functions and are tested; rendering output is not, and reports must say so.

## Input and movement

- All bindings live in `core/settings.gd`: `KEY_BINDINGS`, `MOUSE_BINDINGS`, `JOY_AXIS_BINDINGS`
  and `JOY_BUTTON_BINDINGS`. Actions are registered in code so headless runs have the same map.
- `Settings.rebind()` replaces the keyboard event only and leaves mouse and gamepad events alone;
  a test guards that.
- Movement feel is `Motion` (pure): `approach()` accelerates at 2 400 u/s² and brakes at 3 000 u/s²,
  treating a reversal as braking; `sprint_speed()` applies the 1.45× modifier; `deadzone()`
  rescales stick travel so leaving the deadzone starts from zero.
- The player never assigns velocity directly while walking — it asks `Motion.approach()`. Dodge is
  the one deliberate exception (it sets a burst velocity, which then decelerates through the same
  curve).
- Aiming prefers the right stick when it is pushed past `AIM_DEADZONE`, then the mouse.
- New movement rules belong in `Motion` with checks in `run_tests`, not inline in `Player`.

## Rendering and camera

- The scene root builds a **`World` node with `y_sort_enabled`**. Everything that stands on the
  ground — props, buildings, NPCs, enemies, interactables, the player — is a child of it, so draw
  order follows world Y, not node creation order. Ground layers use `z_index` instead
  (province chunks `-20`, settlement apron `-15`).
- A new visual must therefore join the `World` layer to sort correctly. If it belongs to a chunk
  (props), the chunk manager owns it so unloading frees it.
- Camera framing lives in `CameraRig`: world bounds become `Camera2D` limits and `clamp_center()`
  is the pure rule; zoom is a fixed ladder (`0.75 → 2.0`), never a free float.
- Occlusion is `Occluder.alpha_for()`: a pure function of player position, footprint and roof
  height. Buildings apply it; nothing about the rule needs a GPU.
- Lighting is `WorldLighting` (a `CanvasModulate`): ambient tint and point-light energy are pure
  functions of the clock hour, so night is testable at 23:00 in a headless run.
- Resolution scaling is `DisplayPolicy`: authored at 1280×720, integer stretch on exact multiples,
  fractional + `EXPAND` otherwise. Re-applied on every window resize.
- **Rule:** a visual system must expose its decision as a static pure function and get checks in
  `run_tests`. Rendering output itself cannot be verified headlessly; the report must say so.

## Save compatibility

- `Save.CURRENT_SCHEMA` is bumped whenever the save shape changes.
- Add a migration step in `Save._migrate()` for every bump, and a test that loads a
  hand-written older payload (`schema 0`) and asserts the migrated result.
- Never delete a migration step: old saves in the wild depend on the whole chain.
- Saves are written atomically (temp → checksum → rename) with three rotating backups;
  corrupt files must fall back to a backup rather than load partially.
- A milestone that changes save state must demonstrate: save, quit, reload, state intact —
  plus the corrupt-file recovery test still passing.

## Branching and commits

- One milestone per branch is preferred: `milestone/NN-short-name`.
- Work happens on a chat branch (`freebuff/...`) otherwise; never commit to `main` directly.
- Commit subject: `MNN: <what changed>` (e.g. `M03: fix hidden-realm determinism, add CI`).
- Commit body: what changed, why, and the test commands run with their results.
- A milestone is committed **only after** its acceptance criteria pass; the commit is the
  record of the verified state, not a checkpoint of unfinished work.
- Release tags: `vMAJOR.MINOR.PATCH` on a verified, playable build with release notes.

## Backup policy

- Git is the source of truth and must contain every accepted milestone.
- A remote must exist before long work continues; local-only history has already been lost
  once in this project.
- Before any milestone that rewrites save format or core data, tag the last good commit.

## Definition of "working"

A system is working only when it is exercised in gameplay or by an automated test that calls
the real code path. A menu, a data file, or a method that returns a plausible number is not a
working system. Reports must list unverified items as unverified.

## Layout

```
game/
  core/       bus, rng, db, clock, log, settings, save, game (autoloads)
  data/       JSON content (realms, roots, methods, techniques, items, passives, quests, npcs)
  systems/    attributes, stat_block, cultivation, damage, itemgen, quests, motion, animator,
              camera_rig, lighting, display_policy
  entities/   player, dummy, npc, interactable
  world/      chunk_manager, settlement, hidden_realm, prop, building, occluder
  ui/         hud
  scenes/     main
  tests/      run_tests (unit + content), integration (real scene)
```
