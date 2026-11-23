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
| Attack with selected technique | Left mouse |
| Aim | Mouse or right stick |
| Dodge (i-frames) | Space |
| Meditate / cultivate | F |
| Realm breakthrough (at peak, full Qi) | G |
| Interact / talk / pick up | E |
| Select technique (slots 1–6) | 1 – 6 |
| Quick save / quick load | F5 / F9 |
| Zoom camera in / out | Mouse wheel, `=` / `-` |
| Toggle help | F1 |

Gamepad: left stick moves, right stick aims, **X** attacks, **A** dodges, **B** interacts,
**Y** meditates, **RB** sprints, **D-pad up** attempts a breakthrough.

On the creation screen: **1–6** allocate a point to STR / DEX / AGI / INT / WIS / CHA,
**Backspace** refunds the last point, **R** rerolls your spiritual root, **Enter** begins.

## The playable loop

1. **Create a character** — a random name, a weighted spiritual root (Mortal → Primordial),
   and six free attribute points.
2. **Azure Cloud Market** — a settlement of ~19 NPCs with daily schedules. Elder Bai stands by
   the sect hall and starts *The Azure Cloud Invitation*: talk, slay 3 beasts, gather 2 spirit
   herbs, attune at the shrine, return. Reward: a technique, a passive, spirit stones.
3. **Fight** — enemies telegraph, then strike. Poise, stagger, knockback, dodge i-frames and
   Qi costs all apply. Kills drop generated items you can pick up and auto-equip.
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
- 12 realms × 10 sublevels; Qi accumulation, breakthroughs, tribulation scaling, failure consequences.
- 8 techniques with startup/active/recovery frames, arc hitboxes, Qi costs, poise, knockback, scaling.
- Deterministic item generation: 4 rarities, tiered prefixes/suffixes, stable IDs, auto-equip.
- Equipment and passives feed real combat stats through `StatBlock`.
- Seamless streaming over a 12×12-chunk province with deterministic chunk regeneration.
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

Character appearance and backgrounds; weather and seasons; animation (all characters are
code-drawn shapes); fast travel and maps; physiques; method-specific cultivation
loops; mastery and manuals; alchemy, forging, professions and economy; NPC goals, memory,
relationships, parties and independent progression; the twelve sects and faction politics;
additional hidden-realm templates; dynamic world events; the main narrative and endgame;
UI screens beyond the HUD; audio.

The full 72-milestone status ledger lives in the design document (`§19 Authoritative roadmap`).
