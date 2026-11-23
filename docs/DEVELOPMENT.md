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
  systems/    attributes, stat_block, cultivation, damage, itemgen, quests
  entities/   player, dummy, npc, interactable
  world/      chunk_manager, settlement, hidden_realm
  ui/         hud
  scenes/     main
  tests/      run_tests (unit + content), integration (real scene)
```
