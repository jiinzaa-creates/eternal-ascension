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

## Schedules

- **One list per routine, resolved by hour and weekday.** A schedule is an array of
  `{from, to, location, activity}` entries in `data/npcs.json`. `Schedules.resolve(entries, hour,
  weekday)` is the only resolver: `from` is inclusive, `to` exclusive, and a range whose end is
  before its start wraps past midnight (the 22→6 sleep needs no special case). Entries may also
  carry a `days` array; an entry without one applies every day. A later entry never wins over an
  earlier one because validation forbids overlaps, so array order cannot change the answer.
- **The week is code, the routines are data.** `Clock` owns a fixed seven-day week (Metalday →
  Restday) independent of the 30-day seasons; `Clock.weekday_for(day)` is pure and day 1 is a
  Metalday. `Npc.active_schedule()` reads the weekday table normally and swaps in the archetype's
  `rest_schedule` on the Restday, so a rest day changes the whole day rather than one entry.
- **Restday is a market day.** Disciples sleep in and then crowd the market, merchants start at
  05:00 and sell until 18:00, farmers visit the shrine, and guards keep only the gate before
  drinking. The Lightday drill is the other day-specific shape: guards train at the yard from
  12:00 instead of patrolling the plaza, expressed as two entries with disjoint `days` filters.
- **Validation is completeness, not vibes.** `Schedules.validate(entries, name, locations)` checks
  hour bounds, the location graph, non-empty activities, weekday indices and duplicates, then walks
  all 7 × 24 hours and requires exactly one owner for each. `DB.validate()` runs it on every
  shipped schedule and rejects an archetype whose `rest_schedule` does not exist, so a gap or an
  overlap fails at boot with the schedule's name rather than showing up as a stuck NPC.
- **Walking follows the path graph.** `Settlement.route_from(from, to)` returns `[to]` when either
  end is the plaza and `[plaza, to]` otherwise, because every path in the market radiates from the
  plaza. `Npc` keeps that route, advances a waypoint when it arrives, and only then heads for the
  destination; a snap clears the route. `Npc.travelling()` reports whether ground is still left to
  cover, which the nameplate and dossier read as `walking`.
- **The routine has consequences.** `Schedules.awake()` gates every conversation: a sleeping NPC
  refuses politely and records no memory, because a conversation that did not happen must not
  warm regard. `Schedules.can_teach(location, activity)` is the instructor's sole service gate
  (training yard, training block, 08:00–12:00); off duty he names where he is and charges nothing.
  Greetings come from `Schedules.small_talk(activity)`, so what an NPC says is a fact about the hour.
- **No new save state.** The clock already saves the day and hour, so the routine, the weekday and
  the route are all derived after a load. Memory remains the only NPC state a save carries.

## NPC intelligence

- **The mind is pure; the body acts.** `NpcAi` (`game/systems/npc_ai.gd`) never touches a node or
  the scene tree. `nearest_threat()` answers what is in reach, `decide()` answers what the trade
  does about it, `target_for()` answers where that sends the body, and `Npc` owns the timer and the
  walk. This is what lets a panicking market be tested headlessly.
- **The brain is data.** Every archetype carries an `ai` block: `nerve` (0–1), `alert_range`, a
  `response` of `confront`, `flee` or `shelter`, a `refuge` location and a `shout` flag.
  `NpcAi.profile()` clamps all of it, so a missing field degrades to a cautious resident rather
  than crashing. `DB.validate()` rejects an unknown response or refuge, an out-of-range nerve or
  alert range, and a non-boolean shout at boot.
- **Nerve is a rule, not a flavour number.** A body whose order is `confront` but whose nerve is
  below `CONFRONT_NERVE` (0.55) takes shelter instead. That is the one place the two fields
  interact: a frightened guard behaves like a shopkeeper, and the data decides how frightened.
- **Only the market's trouble counts.** `main._direct_npcs` collects `aggressive` bodies that are
  not dead, then `NpcAi.watched()` keeps the ones inside `WATCH_RADIUS` (360) of the plaza. Wild
  bodies spawn at 420+, so the wilds are the player's business until a chase brings a beast in. A
  training dummy or a sparring partner is not a threat: `aggressive == false` means furniture.
- **One shout, once.** A body raises an alarm only when its order changes; the scene then hands the
  warning to every simulated, waking body inside `SHOUT_RADIUS` (340). A listener keeps its **own**
  distance to the trouble, because a shout carries the warning, not the crier's eyesight — which is
  how a merchant 300 paces away with a 220 alert range still shuts the stall. The scan is throttled
  to `NPC_ALERT_TICK` (0.25 s) and is skipped inside a hidden realm.
- **Sleepers are exempt.** `is_awake()` gates the whole layer: a sleeping body is behind a door, so
  it neither sees nor answers. `Npc.sleep()` clears any reaction, so distance cannot leave a body
  permanently alarmed when it wakes.
- **The reaction outranks the routine for `ALARM_SECONDS` (12) and then ends.** `Npc.react()`
  sets the order and the clock, `_tick_reaction()` counts it down, and `stand_down()` walks the body
  back to whatever the schedule says now — no teleport, because a person who ran to the hall walks
  back out of it. `goal_position()` is the single answer to "where is this body going", and
  `travelling()` reads it, so the nameplate never calls a reacting body idle.
- **Alarm has consequences in conversation.** `_talk()` answers with `NpcAi.warning_line()` instead
  of small talk and records no memory: a body shouted at by a beast did not have a conversation
  worth remembering. The dossier replaces the routine line with the alarm and shows the nerve.
- **No new save state.** A reaction is live only: a threat does not survive a load, so neither does
  the alarm. The routine, the weekday and the position are all derived as before.
- **Tests must stand in the market.** `_simulate_npcs` sleeps the town beyond `NPC_SIM_RADIUS`, so
  the integration scenario moves the player to the plaza for the block and restores them after.

## Relationships

- **One graph, two kinds of edge.** `Relationships` (`game/systems/relationships.gd`) holds a
  directed graph over stable person ids. A **warmth** edge is a score in −100..100 read through the
  bands in `data/bonds.json`; a **tie** edge is a structural relation authored in the same file
  (mentor/student, kin). A tie names the edge (`Mentor of Instructor Rui`) while the band still
  decides behaviour, so description and rules never disagree. The band is what a person calls the
  bond; the score is what the simulation keeps.
- **Every edge is asymmetric by construction.** `base_score(a, b)` seeds `Rng` with the ordered
  pair, so A→B and B→A are separate draws, never two halves of one symmetric relation. An authored
  pair keeps its own number in each direction — the elder holds his student at 46, the student holds
  his teacher at 58 — which is exactly the asymmetry the design calls for, expressed as data rather
  than a symmetry-breaking hack.
- **The bands tile the range or the game will not boot.** `Relationships.validate()` sorts the bands
  and requires them to cover −100..100 with no gap and no overlap, every band to carry a label, a
  blurb and a greeting, every tie to name a reciprocal that names it back and a phrase with exactly
  one `%s`, and every authored pair to name a known tie, two different people and a score in range.
  `DB.validate()` runs it, so a score with two names — or none — is a startup error, not a person
  who cannot decide how they feel.
- **The player is a node, not a second ledger.** A body's feeling toward the player is
  `Relationships.toward_player(base_disposition, regard)` — M47's memory, read through the bands.
  `Npc.bond_to_player()` is that call and `bond_line()` is its one-line form. There is no parallel
  score to drift: raising regard raises the bond because they are the same number.
- **Bands have teeth.** `warns()` is true for friend and sworn friend: `main._warn_player()` picks
  the warmest waking resident within `WARN_RADIUS` (420) of the player and has them call a warning
  once per `WARN_COOLDOWN` (20 s), so friendship is audible without becoming a siren.
  `refuses()` is true for an enemy: `_talk()` ends the conversation before memory is written, so an
  enemy's talk count does not rise. `greeting(band)` colours ordinary conversation, which is why a
  friend's face is not a stranger's.
- **The dossier tells the truth in one line.** The relation line shows the band and the score beside
  the old regard (`Friend (+25) · regard +30 (warm)`), and the footnote becomes the authored ties
  (`Bonds: Mentor of Instructor Rui`) when a person has any. Stable ids resolve through
  `main.person_name()`, which records the name each body was actually spawned with.
- **Nothing new is saved.** The resident-to-resident fabric regenerates from the world seed, the
  ties come from data, and the player's standing is memory. Schema stays 2 and old saves load
  unchanged.

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

## Weapons

- Every weapon category lives in `data/weapons.json` and owns a **light-attack moveset**.
  `Weapons` is pure: it resolves categories, chains, scaled hitboxes and the attack payload;
  `Player` only owns the cursor and feeds the payload to the shared frame machine.
- A weapon item declares `weapon_type`. **Old saves predate that key**, so resolution falls back
  to the base id (`base.sword.iron_jian` -> sword) and then to `fist`. Never add a save-schema
  bump for a new weapon category; add a base prefix or the explicit key instead.
- `Weapons.attack_payload()` returns the same shape a technique does (`frames`, `hitbox`,
  `base_damage`, `damage_mult`, `poise_damage`, `knockback`, `speed_mult`, `lifesteal`).
  Keep it that way: a light strike must not grow a second timing or hitbox path.
- The payload bakes the category's `poise_mult` and `knock_mult` into the move so
  `Damage.poise_damage()` and `Damage.knockback()` stay weapon-agnostic. Damage is
  `(weapon_damage + move.base_damage) * physical_mult * move.damage_mult` via
  `Damage.weapon_strike()`; unarmed moves carry their own small `base_damage`.
- Chains: `Weapons.next_combo(cursor, since_last, window, length)` is the one rule. A cursor of
  `-1`, or a press after the window, starts at strike one; otherwise it advances and wraps.
  A technique cancels the chain, and equipping a different weapon resets the cursor.
- Inputs are deliberately separate: `attack` (LMB / gamepad X) is the selected technique and
  `light_attack` (RMB / D-pad right) is the weapon chain. Do not merge them.
- The HUD reads `Player.weapon_type_name()`, `next_move_name()` and `next_combo_step()`; it never
  duplicates chain logic.
- Any new mechanic here belongs in `Weapons` with checks in `run_tests`, and a scene-level check
  in `integration.gd` before it is called working.

## Defense

- **Guarding is a stance, not an ability.** `Defense` is pure: it maps
  `(holding, elapsed, broken)` to `none | parry | block | broken`, decides whether a blow is inside the
  ward's `GUARD_ARC` (140°, facing only), what the blow costs and what it leaves behind. `Player` owns
  only the timers and calls it from `take_hit`, so the HUD and the damage path cannot disagree.
- **Parry is the opening of the stance**, not a separate key: the first `PARRY_WINDOW` (0.22 s) of a held
  guard turns a frontal blow aside for free and throws `Defense.reflected_poise(stats)` back at the
  attacker. `Dummy.stagger()` spoils its wind-up and spends its poise meter, so a parry is a real turn.
  `take_hit(..., attacker)` is the only new argument on the damage path and defaults to `null`.
- **Blocking spends Qi, not poise.** `qi_cost = 3 + 0.8 × raw`; armour and resistances still apply to the
  `BLOCK_DAMAGE_MULT` (35%) that gets through. A block that cannot be paid for is not half-blocked: it
  **breaks** — `Poise.break_guard()` staggers whatever meter was left, the blow lands at
  `GUARD_BREAK_MULT` (125%) with extra knockback, all Qi is lost and the ward cannot be raised for
  `BREAK_RECOVERY` (1.6 s).
- **Only real blows are guardable.** A hazard (`can_evade = false`, no poise behind it), a tribulation
  bolt (`take_tribulation_damage`), or anything arriving outside the arc goes through untouched. A blow
  with no origin is never covered, which is why `Defense.covers` rejects a zero vector.
- **What it costs in play:** a raised guard cannot attack, meditate or sprint, and it walks at 45%
  speed; dodging drops the ward, and a stagger refuses to raise it. Nothing here is saved — a stance is
  transient, so there is no schema bump.
- Inputs: `block` is `CTRL` / middle mouse / gamepad left-stick click (`core/settings.gd`). Keep the
  guard on a hold; do not turn it into a toggle, because the parry window is defined by when it rose.
- Any new defensive rule belongs in `Defense` (or `Poise` for the meter) with checks in `run_tests`, and
  a scene-level check in `integration.gd` before it is called working.

## Technique combat

- A technique declares a `kind` in `data/techniques.json`. `TechniqueCombat` is pure and owns every
  kind rule; the player only dispatches. **The default is `melee`**, so a technique written before the
  key existed behaves exactly as it did, and no save migration is needed.
- The kinds and their payload keys (the key is the kind's own name):
  - `melee` — `hitbox` (`radius`, `angle`), resolved on the active frame, the original path.
  - `projectile` — `projectile: {speed, radius, range, pierce}`. `Projectile` travels its own reach,
    touches each body once, stops after `pierce + 1` bodies and frees itself at `range`.
  - `spell` — `spell: {range, radius, delay}`. `SpellZone` opens at `spell_center()` (straight along
    the caster's aim), telegraphs for `delay`, then resolves once over its circle.
  - `summon` — `summon: {count, duration, speed, reach, interval, damage_mult}`. `Summon`s appear on
    a ring around the caster, seek the nearest enemy, and each carries `damage_mult` of the blow.
  - `buff` — `buff: {duration, mods}`. The live entry's mods are passed to `StatBlock.rebuild()` as
    its `transient_mods` (last argument, default empty), i.e. the one stat pipeline. Recasting
    refreshes the clock instead of stacking; buffs are transient and never saved.
  - `movement` — `movement: {distance, iframes}`. The body is carried along the aim and gains the
    art's own brief i-frames. It is still a technique: it costs Qi, follows the frame machine and
    sets the same cooldown.
- One resolved blow: `Player._resolve_strike()` computes amount, crit, poise, knockback, penetration
  and lifesteal once; melee, projectile, spell and summon all deliver those same numbers through
  `take_hit`. Never add a parallel damage path for a new delivery.
- `DB.validate` checks every kind's payload (`_validate_technique_kind`): a projectile without speed
  or range, a buff with no mods or an unknown stat, a summon with no count, or a movement art that
  does not move is a content error, not a silent no-op.
- Effects (`Projectile`, `SpellZone`, `Summon`) join the world layer and add themselves to the
  `projectile`, `spell_zone` and `summon` groups so a scene test can assert they exist and expire.
- Input: `Q` (`cycle_bar`) walks the whole known technique list, because the bars hold eighteen slots
  and a learned art belongs to no bar until it is placed. Cycling follows the art onto its bar, so the
  HUD shows the bar the selected art actually sits on.
- Any new technique rule belongs in `TechniqueCombat` with checks in `run_tests`, plus a scene-level
  check in `integration.gd` before it is called working.

## Skill bars

- `SkillBar` is pure and owns the whole layout model: three bars of six, `default_layout()` (known
  arts in learned order), `reconcile()` (drop unknown ids and duplicates, keep deliberate gaps),
  `assign()` (one art, one slot — placing an art empties any slot it already held), `swap()` (drag and
  drop), `unplaced()`, `wrap_bar()` and the cooldown helpers. It never mutates its input array.
- The player owns the state: `bars` (18 technique ids), `active_bar`, and `tech_cooldowns`
  (technique id → seconds left). Cooldowns are **transient and never saved**; they are cleared on load.
- Cooldowns are per technique. Finishing a technique sets `_cooldown = SkillBar.SWING_PAUSE` (a short
  shared pause so two presses cannot blur) and starts that art's own `technique_cooldown()`, which is
  the same formula as before (mastery × gear CDR × realm weaving). `try_attack()` refuses an art
  whose own timer is running; a different ready art can follow it. The HUD reads
  `slot_cooldown_left()` / `slot_cooldown_ratio()`, so a slot can never display a timer the gate does
  not honour.
- Keys: 1–6 select within the active bar (`select_bar_slot`), `[` / `]` (`bar_prev` / `bar_next`)
  switch and wrap (`cycle_bar`), `B` (`open_bars`) toggles the arrangement panel. An empty slot emits a
  toast naming the bar and slot instead of failing silently.
- `SkillBarPanel` is the only editor and the run is frozen while it is open (like the map and travel
  overlay), so a drag cannot become an attack. It turns mouse positions into slot indices and calls the
  player's `assign_slot` / `move_slot` / `clear_slot` / `select_slot`; all rules stay in `SkillBar` and
  the player, which is what the headless suites exercise.
- Save compatibility: `bars` and `active_bar` are optional keys. A save without them (pre-M34) gets
  `default_layout(technique_ids)`; a corrupt or over-long layout is reconciled to known, unique arts.
  No schema bump and no migration step are needed.

## Enemy AI

- `EnemyAI` is pure and owns the whole mind: archetype profiles, perception, leash, group slots,
  the state decision and steering. `Dummy` owns the node, the timers and the blow; it never decides
  anything the tests cannot reproduce headlessly.
- An archetype is a dictionary in `data/enemy_archetypes.json`, passed through
  `EnemyAI.profile()` so a missing field takes a sane default and a malformed one is clamped.
  `DB.validate` checks the ids, the geometries, the clocks and a ranged body's bolt, and every biome
  enemy must name an existing archetype. NPC archetypes (`npcs.json`, `DB.archetypes()`) are a
  different table — the enemy accessor is `DB.enemy_archetype(id)`.
- States and the order `EnemyAI.think()` applies them:
  1. `return` — past `leash` from `home`. This beats everything.
  2. `flee` / `retreat` — a running clock is honoured before a new decision.
  3. Unseen with no `memory` left: `patrol` at home, `return` away from it.
  4. `flee` — a wounded body whose archetype has `flee_below` and that has not fled yet
     (`flee_used` makes the courage one-shot, so a fight cannot become an endless chase).
  5. `retreat` — a ranged body closer than its `keep_range`.
  6. In reach: `windup` when ready and the group allows a turn, `recover` while cooling.
  7. Out of reach: `circle` when the group's attack slots are full, otherwise `chase`.
- Perception is `aggro_range` plus a `vision_degrees` cone (`perceives`). Damage sets `_provoked`, so
  being shot from behind turns a body around even when the cone did not see it. `memory` is how long
  it keeps walking to the last seen point after losing sight; reaching that point with nothing there
  gives up and the body goes home.
- Group coordination: `_allies_committed` counts enemies within `GROUP_RADIUS` already in `windup`,
  and `may_commit` allows fewer than `group_limit`. Bodies also apply `EnemyAI.separation`, so five
  bodies around a player cannot occupy one point.
- `AT_HOME` is one constant used both for "this body is home" and for "this body has arrived". They
  were once 8.0 and 6.0, which created a dead band: a returning body stepped inside 8, the brain chose
  `patrol`, and it never reached the arrival branch to mend. Never give one rule two thresholds.
- Facing is locked at the start of a wind-up, so the telegraph is a real dodge window: stepping out of
  the arc avoids the blow. Poise still owns staggering: a stagger cancels the wind-up and overrides
  every state for its duration, and a parry spoils it exactly as before.
- A ranged archetype fires an enemy `Projectile` (`faction = "enemy"`), which scans the `player`
  group instead of `enemy` and lands through the player's own `take_hit` with the bolt's origin, so a
  raised guard or a parry meets it like a melee blow. The player's arts keep the default faction.
- `aggressive = false` keeps a body inert (standing, still strikable) for scenario tests and sparring;
  the training-dummy behaviour is preserved by that flag, not by a second code path.
- Nothing new is saved. An enemy's archetype, state, memory, home, timers and flee courage are all
  world state: they belong to a spawned body, and a reload spawns fresh ones from the biome table.
- Any new archetype rule belongs in `EnemyAI` with checks in `run_tests`, plus a scene-level check in
  `integration.gd` before it is called working.

## Spirit beasts and bosses

- **A beast is a species, not a new body.** `Beasts` reads `data/spirit_beasts.json` and normalises each
  entry exactly the way `EnemyAI.profile()` normalises an archetype: id, name, an archetype chosen from
  the same four, a habitat map, level offset, health/damage multipliers, speed, colour, the status its
  bite carries, the core it drops and a `pack` flag. `Dummy.become_beast(species, realm)` converts the
  species into the same entry shape `apply_biome_enemy()` already took, so a wolf and a wild cultivator
  go through one stat path; the behaviour is still the archetype's (a wolf circles and retreats, a boar
  holds its short leash, a crane keeps its firing band).
- **Habitat is the spawn table.** A species' `biomes` map is `{biome_id: weight}`; a biome that is not
  listed never spawns it, and `Beasts.roll()` makes exactly one `Rng.pick_weighted()` call, so a given
  `(world_seed, domain, key, counter)` always produces the same beast. `DB.validate` rejects an unknown
  biome, an unknown archetype, an empty habitat, a missing core and a malformed status.
- Wild spawns are 45% beasts: the yes/no comes from a separate `wild_beast` stream and the species from
  the existing `wild_dummy` stream, so tuning the share cannot reshuffle which humanoid or beast a seed
  produces.
- A beast leaves a **core** — `slot: "material"`, rarity 2, no affixes, worth its species' value —
  dropped at its feet through `Bus.beast_slain` and drawn from the species, not from `ItemGen`. The
  ordinary kill still pays through `enemy_died`, so quests and normal loot are unchanged.
- **A boss is a body with a phase table.** `Boss` reads `data/bosses.json`: thresholds in descending
  fractions of maximum health, exactly one more phase than thresholds, each phase's damage/speed/cooldown
  multipliers, its status and the species it calls. `phase_index()` is pure and reads at or below a
  threshold, so a body at 66% is already in the second phase. `Dummy.become_boss()` stores the table and
  the body reads `_phase_mult()` at use time; the live `damage`/`speed` values are never mutated, which is
  why a phase cannot compound when health hovers on a threshold.
- The body only **announces** a phase change (`Bus.boss_phase_changed`). The scene root spawns that
  phase's adds through the realm and toasts the phase name; a boss in a unit test needs no scene at all.
  Adds are ordinary beasts, parented like the realm's guards, so leaving the tomb frees them.
- **Death is paid once by stable id.** `Bus.boss_defeated(id, at)` is handled in `main.gd`, which adds
  the boss' stones, generates one guaranteed item at its declared rarity and records the id in
  `bosses_slain`. That dictionary is a new optional save key (legacy saves load `{}`), and the tomb only
  spawns its warden when the id is absent — a cleared tomb stays clear across a save.
- The warden guards the inheritance altar: `main._warden_blocks_altar()` refuses the claim while
  `HiddenRealm.has_warden()` is true. This is the whole gate; there is no second rule anywhere.
- The HUD draws one wide boss bar with the phase name and a mark at every threshold, scanning the
  `boss` group. A boss also scales its body by 1.7× in `_draw` and marks its bar, so it reads as one at
  a glance without touching collision or reach.
- Add a species or a boss in data and validate it; the only code that may need touching is the boss id
  the tomb looks for (`main.WARDEN_ID`) and, for a new gate, the guard function beside the altar.

## Combat polish

- **Hitstop** (`Hitstop`) is a real-time timer, not `Engine.time_scale` and not
  `get_tree().paused`: a global clock change would stall the HUD and make a headless suite wait on
  frames that never tick. `Game.hitstop` is ticked in `Game._process`; `Player`, `Dummy`,
  `Projectile`, `SpellZone` and `Summon` return early while it is frozen. Attack timers, cooldowns,
  statuses and the AI pause with the bodies, which is what a freeze frame is. `duration_for()` is pure
  (damage plus critical/heavy bonuses, clamped to `[MIN, MAX]`), `request()` keeps the longest freeze
  and never shortens a running one, and `clear()` runs on death and on load. A hitstop must not freeze
  input for long; the cap is `0.12 s`.
- **Damage numbers** are split into pure rules (`CombatText`) and a world-space node (`DamageNumbers`).
  `CombatText` formats (rounding, `12k` above ten thousand, nothing below half a point), picks the tint
  (`""` ink, `crit` gold, or a status colour), and owns the rise/fade (`offset`, `alpha`). The node
  listens to `Bus.hit_landed` and `Bus.status_ticked`, stores entries with a world position and draws
  with `ThemeDB.fallback_font`; the entry cap is 48.
- **Statuses** (`Status`) are pure: `apply()` returns a new array, refreshes a status' clock and
  magnitude, adds one stack (cap 3) and never mutates its input; `advance()` returns the survivors plus
  one hit per due damage tick. Burn and bleed tick unblockable damage every `TICK` (0.5 s); chill
  reduces movement (`speed_multiplier`), shock raises damage taken (`taken_multiplier`), both capped.
  DoT bypasses armour, evasion and guard by design: those are for blows. Entries are transient and
  never saved; death, load and a dead body clear them.
- Status payloads are data: `"status": {"id", "duration", "magnitude", "stacks"}` on a technique or an
  enemy archetype. `DB.validate` (`_validate_status_payload`) rejects an unknown id, a zero clock or
  magnitude and an out-of-range stack count. `Player._tick_statuses` and `Dummy._tick_statuses` are the
  only tick sites; they report through `Bus.status_ticked`, which is why a burn shows numbers without
  sounding like a fresh hit.
- One damage path still holds: `Player.take_hit()` and `Dummy.take_hit()` now **return the damage
  actually dealt** (`0.0` on a dodge, parry, i-frame or dead body) and take an optional final status
  payload. Every attacker emits `Bus.hit_landed(target, dealt, critical, tint)` only when that return
  is above zero, so a parried or evaded blow produces neither a number nor a sound. Do not emit from
  inside `take_hit`: the attacker is the only side that knows whether the blow was an art and how heavy
  it was.
- **Audio** (`Sfx` + `CombatAudio`) ships no assets. `Sfx.build(kind)` synthesizes a 22 050 Hz 16-bit
  mono `AudioStreamWAV` from a deterministic noise generator and one or two sine partials; the same kind
  always yields identical bytes. `CombatAudio` prebuilds every kind at startup, keeps an eight-voice
  pool and listens to `Bus.hit_landed`, `enemy_died`, `swing_made`, `technique_cast` and `guard_met`.
  `play()` returns false when muted or unknown and still counts a muted dispatch; `F2` (`mute_audio`)
  toggles mute. A headless run has no output device, so tests can only assert stream shape, determinism
  and dispatch — never that a sound was heard.
- Any new combat feel belongs in these pure layers with unit checks, plus one scene-level check that the
  node exists and a real blow produces the effect.

## Items, durability and stacks

- **One canonical record.** `Items.normalize_item()` is the only shape an item is allowed to have:
  a fixed key order, a stable `item.*` id, a known slot, a clamped rarity/level/value, normalised
  mods, a `count` of at least one and durability only for weapons and armour. Unknown fields are
  dropped; a record without a stable id cannot exist. Every route into a player's possession
  (`pick_up`, a save, a load, a shop) goes through it, so two equal items are byte-identical.
- **Stable ids are enforced, not assumed.** `is_stable_id()` requires an `item.` prefix with at
  least one non-empty segment, and `is_valid_item()` calls it. A save references items by id; an
  item that cannot be referenced is not an item.
- **Durability** is deliberately blunt. Weapons hold 300 points, armour 400; a weapon loses one per
  swing and armour loses one per damaging blow (`Items.WEAR_PER_STRIKE` / `WEAR_PER_HIT`). A worn
  piece still works. A **broken** piece still occupies its slot but multiplies its contribution by
  `Items.BROKEN_MULT` (zero). That multiplication happens in `Player.rebuild_stats()` *after* the
  stat pipeline has summed every source, so a rebuild can never compound it and a broken piece can
  never be half-counted. `_wear()` keeps the equipped copy and the satchel copy in step by id and
  rebuilds only when a piece actually breaks.
- **Repair** is stones: `Items.repair_cost()` charges per missing point, weighted by rarity, and
  `Player.repair_gear()` restores every durable slot. The inn pays it out of the same rest visit when
  the purse covers rest plus repair; a player who cannot afford the rest is refused whole rather than
  half-healed.
- **Stacks** only exist for materials (20) and consumables (10). `stack_key()` is
  `slot|base|name`, so two rolls of the same ore merge and two swords never do. `add_to_inventory()`
  fills existing stacks, spills into new ones, and returns a new array; `normalize_inventory()`
  sanitises and merges on load. Selling sells a whole stack, so `Economy.sell_value()` scales the
  unit price by `count`; the HUD labels a stack `Name xN` and the satchel counts items and kinds.
- **Serialization guarantee.** The save form *is* the canonical form (`Items.to_save()`), and
  `Items.from_save()` refuses anything that is not an item. Schema 2 introduced counts and
  durability; `Save._migrate()` normalises schema-1 player inventory and equipment on load, so the
  player loader only ever sees the current shape. `Player.to_dict()` writes canonical arrays/maps and
  `Player.from_dict()` normalises, merges and drops invalid entries rather than trusting the file.
- Adding a new item field means adding it to `Items.FIELDS` and normalising it; that single change
  covers generation, pickup, shops, saves and loads.

## Procedural generation

- **One stream, nothing else.** `ItemGen.generate()` draws base, rarity, affixes and values from the
  `Rng` stream for `(seed, key, counter)` and from nothing else. Affix selection used to call
  `Array.shuffle()`, which consumes the *engine-global* RNG — the item you got depended on how many
  items had been generated before it. The pool is now picked with `Rng.pick_weighted()` on the item's
  own stream, so generation is reproducible in isolation and the unit suite asserts that a roll
  repeated after a dozen other rolls is byte-identical.
- **Tiers are data, not a formula.** Every affix in `data/items.json` carries `tiers`, each with its
  own `ilvl` and `min`/`max`. `ItemGen.tier_for()` returns the highest tier the item's level has
  unlocked (`tier_data()` reads it), the value is rolled inside that tier, and the mod records which
  tier it came from. `describe()` appends `(T2)` for anything above the first. The legacy flat
  `min`/`max` remain as the fallback for affix data written without tiers and are validated to agree
  with tier one, so old data and new data cannot disagree silently.
- **Weighting controls.** `weight` sets how often an affix is considered; an optional `slot_weights`
  beats the base weight on the slots it names (`of the Tiger` favours weapons and rings over armour).
  A weight of zero removes the affix from that pool entirely. Selection is weighted *without
  replacement*, so six rolls never repeat an affix and a pool smaller than the requested count simply
  yields what exists.
- **Validation is the contract.** `DB._validate_affix()` rejects duplicate or missing ids, an unknown
  kind/stat/slot, negative weights, malformed tiers, tiers out of order or weaker than the tier below,
  a first tier below the affix's own unlock level, and a flat range that disagrees with tier one.
  `DB.validate()` also requires every equipment slot to have at least one positive-weight prefix and
  suffix, because a rarity's affix count is a promise the pool has to be able to keep.
- **Tiers survive the save.** `Items.normalize_item()` keeps a mod's `tier` (defaulting to one for
  legacy items), so the canonical save form and the item that generated are the same record.

## Equipment rules and comparison

- **Rules live on the base, not the instance.** `data/items.json` gives each base optional
  `requires` (`str`, `dex`, `agi`, `int`, `wis`, `char`, or `realm`), `tags` and `conflicts`. The
  instance carries no rules, so a save never has to store them and old saves inherit new rules
  automatically. A piece whose base is unknown is unrestricted rather than locked out.
- **One equip gate.** `Equipment.can_equip()` checks requirements against `Player.attrs` and
  `cultivation.realm`, then walks the other equipped slots: a conflict fires when the candidate's
  `conflicts` meet a worn piece's `tags` *or* a worn piece's `conflicts` meet the candidate's tags,
  so the rule is symmetric. `Player.equip()` is the only voluntary route and returns
  `{ok, reason}`; `pick_up()`'s auto-equip calls the same method and simply leaves refused loot in
  the satchel. Requirements are read live, so consuming a stat potion or breaking through opens
  gear that was refused a minute ago.
- **Comparison is the pipeline's own shape.** `Equipment.stat_map()` reads an item exactly as
  `StatBlock.rebuild()` does — base `base_damage` as `weapon_damage`, `armor` as `armor`, affixes
  summed per stat — and `compare()` returns `{deltas, before, after}` with zero differences dropped.
  The panel therefore cannot promise a gain the stat block will not deliver. `label_for()` /
  `unit_for()` turn stat keys into the words the rest of the UI uses.
- **The gear screen** (`I`, `main.toggle_gear()`) freezes play, lists the four worn slots, the satchel
  pieces not currently worn, and for the highlighted piece the stat-by-stat deltas plus the equip
  verdict. `ENTER` wears through `Player.equip()`, `↑/↓` moves and `I`/`ESC` closes; a refused piece
  says why ("Requires STR 12", "Conflicts with Iron-Scaled Plate").
- **Validation.** `DB._validate_affix`-style checks cover bases too: requirements must name a real
  attribute or `realm` and be positive, tags and conflicts must be non-empty, and every conflict tag
  must be carried by some base, so a restriction cannot silently refer to nothing.

## Uniques

- **Authored, not generated.** `data/uniques.json` holds hand-written relics: a stable
  `item.unique.*` id, a base, a fixed set of affixes and values, a value, lore, one acquisition
  source and one effect. `Uniques.make()` builds the canonical item from the base's numbers and the
  data's affixes, so the same relic is byte-identical every time and `ItemGen` never produces one
  (the unit suite rolls 80 items and asserts none is unique).
- **One source each, one per save.** Sources are named strings: a boss id (`boss.tomb_warden`) or
  `site.inheritance_altar`. `main._grant_unique(source)` is the single grant path; it collects the
  ids already worn and bagged (`Uniques.owned_ids`) and returns without granting if the relic is
  owned. The Warden's fall calls it with its own id, the inheritance altar with its source constant,
  and the existing `bosses_slain` / `inheritance_taken` flags mean neither place can be farmed.
- **Effects are real, and broken relics are not.** `effect.id` is one of `Uniques.EFFECTS`
  (`qi_on_kill`, `mend_on_kill`) with an amount and a player-facing line. `Uniques.kill_effects()`
  sums the effects of worn relics and `Player.on_kill()` applies them — health is capped at
  `hp_max`, Qi at the body's capacity — and a relic with zero durability contributes nothing, the
  same rule its stats follow. Adding an effect means adding it to `EFFECTS`, to `kill_effects()` and
  to a call site; the data cannot name an effect the code does not implement (`DB.validate()`).
- **They save and they read as relics.** `Items.FIELDS` gained `unique` and `lore`, so a relic keeps
  both through a save, and `Items.label()` prefixes a diamond. The HUD draws relic names gold in the
  satchel, the gear screen and the worn list, and the gear comparison shows the lore line above the
  deltas. Schema stays 2: both fields are optional and default to `false`/`""` for older items.
- **Validation.** Every unique must be a stable `item.unique.*` id with a name and lore, a base whose
  slot agrees, a known source (a real boss id or the altar), a known effect with a positive amount,
  real mods and a positive value.

## Crafting at the forge

- **Recipes are data.** `data/crafting.json` holds one station (`station.forge`, placed at the
  settlement's forge building), five recipes and two actions. A recipe names its station, an
  authored output `base` and rarity, the materials it eats, a stone cost, a realm gate and a
  failure chance. `DB.validate()` rejects a missing station or base, a non-equipment output, a
  bad rarity, a negative cost, an invalid failure chance, an unknown material or a station with
  no recipes.
- **Three verbs, not eleven.** `Crafting.craft()` **forges** a recipe through
  `ItemGen.generate(..., force_base)`; `Crafting.refine()` rerolls a piece's affixes while keeping
  base, level, rarity and current durability; `Crafting.disassemble_ore()` prices breaking a piece
  back into ore from its rarity and level. Relics and materials are refused by refine and
  disassemble: authored items are not smithing stock.
- **Costs are exact.** `Crafting.material_counts()` sums stacks by unit, `Crafting.check()` names
  everything missing at once (materials, stones, realm) and `Crafting.consume()` refuses to
  half-pay: an unaffordable cost returns the satchel unchanged, and a paid one removes only what
  was asked for.
- **Determinism and failure.** A forge attempt is a pure function of
  `(recipe, ilvl, key, counter, quality_mult)`. The scene keys it on `Game.crafts_made`, which
  advances on every attempt including failures — otherwise a retry would replay the same failed
  stream forever. A failed forge consumes its cost and makes nothing; a failed refine consumes its
  cost and leaves the piece untouched.
- **Quality is INT.** `StatBlock.crafting_quality_mult()` feeds `Crafting.quality_chance()`, a
  bounded chance to lift the result one rarity step (never past the shipped top). A plain smith has
  no chance at all, so authored rarity is the floor.
- **Materials carry their kind.** `Items.FIELDS` gained an optional `material`, set by ore, herb,
  marrow and beast-core creation; `Items.material_key()` falls back to the old stable id prefixes
  (`item.ore.`, `item.herb.`, `item.marrow.`, `item.core.`) so pre-M44 saves still craft.
- **The screen freezes play.** `E` at the forge opens `draw_forge()`: TAB cycles forge / refine /
  disassemble, arrows choose and ENTER commits, with the cost line, the refusal reason, the
  forge's `desc` and the yield shown before the key is pressed.
- **Save.** Crafted items are ordinary canonical items. The only new state is `Game.crafts_made`,
  an optional save key defaulting to 0; schema stays 2.

## Alchemy at the cauldron

- **Recipes are data.** `data/alchemy.json` holds one station (`station.alchemy`, at the herb
  garden) and three potions, each naming a consumable base, its materials, a stone cost, a realm
  gate, a failure chance and exactly one effect (`qi`, `heal` or `cleanse`). `DB.validate()`
  rejects a missing or unknown station location, a missing name, a potion whose base is absent
  or not a consumable, a base two potions share, an unknown or non-positive effect, and a
  negative cost.
- **Brewing is a pure roll.** `Alchemy.brew()` is a function of
  `(recipe, ilvl, key, counter, quality_mult)`. The scene keys it on `Game.crafts_made` with a
  `70000 +` offset, advances that counter on every attempt (failures included) and shares the
  forge's spend path, so a failed brew costs its herbs and the retry rolls a fresh stream.
- **Potency carries quality.** A consumable has no rarity, so INT's `crafting_quality_mult()`
  becomes potency: `1 + max(0, mult - 1) * 0.35`, plus a discrete `0.25` when the quality roll
  lands. Potency is clamped to `0.1…5.0` and written to the item, so a brew keeps its strength
  through a save.
- **Pills do not blend.** `Items.stack_key()` appends potency for consumables, so a strong pill
  never merges into a weak stack. Two pills of identical base, name and potency still stack.
- **Effects are looked up by base.** `Alchemy.recipe_for_item()` finds the potion for any
  consumable of that base, so a pill found in the world is drinkable with the same rule as a
  brewed one. `Alchemy.effect_amount()` scales the recipe amount by the item's potency.
- **Drinking.** `U` in the satchel turns the selected stack into its effect: Qi is raised toward
  the cap, health goes through `Player.heal()`, contamination through `Cultivation.cleanse()`.
  One unit is spent even at full health or Qi — a pill swallowed at the wrong moment is still
  swallowed.
- **The screen freezes play.** `E` at the cauldron opens `draw_alchemy()` with the effect, the
  potency your insight would produce, the exact cost and the refusal reason; ENTER brews.
- **Save.** No new run state: potency is ordinary item data and the attempt counter is the one
  the forge already uses. Schema stays 2.

## Professions

- **Two trades, one curve.** `data/professions.json` names **Smith** (station `station.forge`) and
  **Alchemist** (`station.alchemy`), each with a `quality_bonus` and a `failure_reduction` per
  rank. The rank curve is shared code, not data per profession: `[0, 4, 10, 20, 34]` points for
  Apprentice → Journeyman → Adept → Master → Grandmaster.
- **Practice, not payment.** `Professions.award()` is the only way practice is earned, and the
  scene calls it only after a *completed* forge, refine or brew. A failure earns nothing, and
  disassembly earns nothing because it is free. `Game.professions` stores only
  `{profession.id: {xp}}`; `Professions.level_for()` derives the rank, exactly the way age is
  derived from the calendar.
- **What rank buys.** `quality_bonus` is added to INT's quality multiplier before the roll, so a
  master smith can reach results an apprentice cannot; `failure_mult` scales the recipe's failure
  chance and is clamped at `0.35`, so even a grandmaster keeps a real risk.
- **Gates are data.** Every recipe and potion names a `profession` and a `level`.
  `Professions.gate()` answers whether the run may take it, and the scene checks the gate
  *before* the cost or the attempt counter, so locked work spends nothing and does not advance
  the stream. `Crafting.check()` deliberately stays gate-agnostic: it answers cost questions, not
  character ones.
- **The panels say so.** Forge and alchemy headers show `Smith — Journeyman (6/10 xp)`, locked
  rows are marked `(locked)`, and the detail pane gives the required rank instead of a generic
  refusal.
- **Save.** One optional key, `professions`, read through `Professions.sanitize()`: unknown ids,
  malformed entries and negative practice are dropped, so an edited save cannot buy a rank.
  Schema stays 2.
- **Validation.** `DB.validate()` rejects a missing or empty profession list, unknown or duplicate
  ids, a station that does not exist, a negative quality bonus, an out-of-range failure reduction,
  and a recipe or potion whose profession is unknown or whose level is outside `0…4`.

## NPC database

- **A person is a generated record.** `data/npcs.json` holds the goal catalogue and, for each
  archetype, an attribute template plus `attr_growth`, a `root` tier band, a `physiques` pool, a
  `techniques` pool, a `gear` pool, a starting `disposition` and a goal pool. `NpcDb.sheet(archetype,
  npc_id, realm)` is the only generator: it draws every field from
  `Rng.stream("npc_sheet", hash(npc_id))`, so the same seed and id always rebuild the same person.
  Authored characters pass their realm explicitly and keep their own name, role and schedule; only
  the record comes from the template.
- **What a sheet contains.** Six attributes (template + one growth step per realm above the first,
  plus a deterministic 0–1 jitter), a root id and its tier inside the archetype's band, a physique
  id from the pool, up to `technique_count` arts, one generated piece per gear slot, and
  `goal_count` ambitions.
- **Legality is enforced at generation.** Arts are filtered through `Techniques.can_learn` against
  the generated realm and attributes, and each generated piece goes through `Equipment.can_equip`
  against the same body; a piece the person could not wear is dropped, never worn. `DB.validate()`
  checks every pool id, the root band, the attribute block, the schedule and the goal references, so
  a typo cannot create a hollow person.
- **Memory is separate from identity.** `Game.npc_memory` maps a stable NPC id to
  `{met, talks, last_day, regard}`. `NpcDb.remember()` is the only write and `_talk()` is its only
  caller; regard rises by `REGARD_PER_TALK` to `REGARD_MAX`, and `standing()` is the archetype's base
  disposition plus regard, labelled hostile → wary → neutral → friendly → warm. Memory is never
  derived from the sheet, so changing a person's gear cannot rewrite a friendship.
- **Saving.** The memory dictionary is one optional key, read through
  `NpcDb.sanitize_memory()`: non-dictionaries, empty ids, negative counts and out-of-range regard are
  discarded or clamped. Sheets are never saved; the seed regenerates them. Schema stays 2.
- **Reading it.** Standing within 150 units of an NPC draws the dossier on the HUD: identity, realm,
  all six attributes, root with purity, physique, arts, worn gear, ambitions and the memory line
  (stranger, or met ×N / last day / regard / standing). It needs no key and pauses nothing.

## Loot tables

- **One table per source, all in data.** `data/loot_tables.json` holds `kill.wild`,
  `kill.elite`, `kill.boss`, `chest.common`, `chest.sealed`, `chest.ruin` and
  `inheritance.altar`. Each entry owns `rolls` (min/max pieces, capped by `Loot.MAX_ROLLS`),
  `empty_chance`, `rarity_weights` (one per shipped rarity), `slot_weights`,
  `ilvl_bonus`, `min_rarity` and a `stones` range. `Loot.roll(source, ilvl, key,
  counter)` is the only entry point the scene uses; an unknown source falls back to the
  wild table rather than deleting loot silently.
- **Loot chooses the roll, ItemGen chooses the item.** `Loot` picks the slot and
  rarity from the table's weights and calls `ItemGen.generate(ilvl, key, counter + i,
  rarity, slot)`. The table's decisions run on a `loot.<source>` stream while each item
  keeps its own `itemgen` stream, so changing a weight cannot reshuffle existing items and
  the same `(source, key, counter)` always produces the same pieces. Pieces within one
  roll get distinct counters, which keeps their stable ids unique.
- **Only slots with bases are legal.** Loot tables roll equipment and consumables because
  those are the bases that exist; materials still come from mining, ruins and gathering.
  `DB._validate_loot()` fails validation if a table weights a slot with no item base, which
  is what a missing material base looks like from the data side.
- **Elite is a rank, not a species.** One wild humanoid in eight (`main.ELITE_SHARE`,
  drawn from the `wild_elite` stream so tuning it cannot move spawns) is promoted by
  `Dummy.make_elite()`: elite health, damage and poise multipliers applied inside
  `_recompute_stats()` (never compounded into live numbers), an `Elite` name prefix, a
  gold ring and membership in the `elite` group. Bosses and beasts refuse promotion. An
  elite emits `elite_died` *instead of* `enemy_died`, so the scene pays the elite table once
  and the ordinary wild table never rolls on top; the death sound listens to both.
- **Every call site names its table.** `main._loot()` powers containers, sealed chests and
  ruins from `chest.*`; `main._drop_loot()` lays wild and elite pieces on the ground and
  banks an elite's purse; `_on_boss_defeated()` picks up `kill.boss` spoils beside the boss's
  own stones and relic; `_claim_inheritance()` rolls `inheritance.altar` on top of the
  technique, passive, physique and relic it already grants.
- **Validation.** `DB.validate()` requires every `Loot.REQUIRED_SOURCES` table, unique ids,
  a full rarity weight list with at least one positive entry, a `min_rarity` in range, an
  empty chance in 0–1, a non-negative level bonus, a two-number roll and stone range, and
  slot weights that name known, base-backed slots.

## Inventory, sorting and the storehouse

- **The grid is a view; the satchel is the array.** `Inventory` (pure, static) gives the flat
  `player.inventory` a 6×5 page grid: `page_count`, `page_slice`, `page_of`, `cell_of`,
  `index_at`, `move_cursor` and `slot_rank`. One page is thirty kinds; an empty satchel still has
  one page so the cursor arithmetic never divides by zero. The screen draws the page and the
  cursor, but nothing about the grid is stored.
- **Sorting rewrites the order itself.** `Inventory.sort_entries(entries, mode)` decorate-sorts a
  copy and `Player.sort_inventory(mode)` assigns the result back to the satchel. Keeping a parallel
  view array would let the HUD strip, the sell list and the grid disagree about what index 4 is.
  The orders are `recent` (the stored order, unchanged), `slot`, `rarity`, `value` and `name`, and
  every comparison is total: after its own key it falls back to rarity, item level, lower-case name,
  stable id and finally insertion index, so equal items cannot swap between runs.
- **The storehouse is a container with a limit.** `Storage` holds canonical items like the satchel,
  but capped at `Storage.CAPACITY` kinds (60). A move always transfers a whole stack. `deposit()`
  and `withdraw()` return `{ok, reason, inventory, item}` and never mutate the player's array, so
  the scene replaces `player.inventory` with the returned bag. A full storehouse refuses a new
  kind with a reason but still accepts a stack that merges into an existing shelf, and every entry
  is re-normalised on load, so a hand-edited save cannot smuggle in a malformed item.
- **Two screens, both freezing play.** `I` opens the satchel grid (`draw_gear`): grid, worn slots,
  value and sell price, and — for equipment — the same delta comparison and equip gate as before;
  `R` cycles the order. The storehouse (`draw_storage`) shows the satchel and the shelves side by
  side; `←`/`→` or TAB switches side, `↑`/`↓` chooses and ENTER moves the stack. Neither screen
  equips or sells implicitly.
- **Save.** The player carries `inventory_sort` (optional, defaulting to `recent`, unknown values
  load as `recent`) and the run carries a top-level `storage` block of canonical items. Schema
  stays 2: both keys are optional, and an older save loads with an empty storehouse and stored
  order.

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
  data/       JSON content (realms, roots, methods, techniques, items, passives, quests, npcs,
              biomes, enemy_archetypes, spirit_beasts, bosses)
  systems/    attributes, stat_block, cultivation, damage, itemgen, quests, motion, animator,
              camera_rig, lighting, display_policy, technique_combat, enemy_ai, beasts, boss,
              items, hitstop, status, sfx
  entities/   player, dummy, npc, interactable, projectile, spell_zone, summon
  world/      chunk_manager, settlement, hidden_realm, prop, building, occluder
  ui/         hud, world_map, shop_panel, travel_panel, skill_bar_panel, damage_numbers,
              combat_text, combat_audio
  scenes/     main
  tests/      run_tests (unit + content), integration (real scene)
```
