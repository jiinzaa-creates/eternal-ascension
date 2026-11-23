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
