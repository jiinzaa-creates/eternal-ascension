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
