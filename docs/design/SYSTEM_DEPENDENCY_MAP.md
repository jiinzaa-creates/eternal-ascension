# ETERNAL ASCENSION — SYSTEM DEPENDENCY MAP

**Basis.** Derived from the actual code at the time of filing: `game/project.godot`
(autoload order), the folder layout under `game/` (`core/`, `systems/`, `world/`,
`entities/`, `ui/`, `scenes/`, `data/`), the compliance matrix M02 (core
architecture: "the strongest foundation area"), and the architecture rules recorded
in `docs/DEVELOPMENT.md`. Arrows read "depends on".

## Coupling rules (the architecture in one page)

1. **Autoloads are the foundation layer.** Everything may read them; they do not
   depend on scenes or entities.
2. **The event bus is the coupling layer.** Cross-system notification flows through
   `Bus` signals (e.g. toasts, `player_stats_changed`) rather than direct calls
   between peer systems — M02 records the event architecture as Bus signals.
3. **Data is data-driven and validated at boot.** 41 JSON files under `game/data/`
   are loaded through `DB`; `DB.validate()` runs at boot and content systems read
   definitions through their owning system (e.g. `Realms` is the only reader of
   `realms.json`, per DEVELOPMENT.md, so data and rules cannot drift apart).
4. **Stable string IDs everywhere.** Saves reference IDs, never indices (M02;
   DEVELOPMENT.md determinism rule).
5. **Generation is deterministic.** Anything generated — items, chunks, rooms,
   NPCs, loot — is a pure function of `(world_seed, domain, key, counter)` through
   `Rng.stream()` / `Rng.stream_from()`. Global-RNG calls in generation code are
   forbidden (they made hidden-realm room roles diverge; DEVELOPMENT.md).
6. **Procedural world state is regenerated from the seed; saves store only
   deltas** (WorldDelta for chunks; NPC memory is the only saved NPC state, per
   M47/M53 — NPC progression is recomputable, not stateful).

## Autoloads (in `project.godot` order)

| Autoload | File | Role | Depended on by |
|---|---|---|---|
| Log | `core/log.gd` | Dev ring-buffer logging | All systems (diagnostics) |
| Bus | `core/bus.gd` | Signal hub: toasts, stat-change and game events | UI, entities, main scene, most systems |
| Rng | `core/rng.gd` | Deterministic named streams `stream(domain, key, counter)` | Every generation system (items, chunks, NPCs, loot, realms, stories) |
| DB | `core/db.gd` | Loads and validates the 41 `data/*.json` definitions at boot | Every content system |
| Clock | `core/clock.gd` | Day/hour, 7-day week, 4×30-day seasons | Weather, schedules, aging, regrowth, autonomy, events |
| Weather | `systems/weather.gd` | 6 weather kinds, deterministic 6-hour blocks | Lighting, cultivation bonuses, HUD |
| Settings | `core/settings.gd` | Action bindings (incl. the 2026-11-25 no-F-key defaults) | Input everywhere, Settings page |
| Options | `core/options.gd` | Display/accessibility/volume options model | Settings page, Music, HUD |
| Music | `systems/music.gd` | Synthesized ambient score (autoload so it survives scene changes) | Title scene, main scene |
| Save | `core/save.gd` | Crash-safe save slots; serializes Game state + deltas | Main scene, title screen, Quit Game path |
| Game | `core/game.gd` | Run state: world seed, spirit stones, discovered sites, party ids, biome density (derived per frame, never saved), character state roots | Nearly everything |

## Domain dependency map

### World and streaming
- `scenes/main.gd` → `world/chunk_manager.gd` (ChunkManager) → `world/continent.gd`
  (5×4 cell lattice, region names/tiers), `world/biome.gd` (region-driven biome
  selection; continent cached via `Biome.prime(seed)` on the main thread),
  `world/chunk_gen.gd` (pure (seed, coord) payloads: features, herbs, POIs, water
  mask — safe on worker threads), `world/world_delta.gd` (spent/regrow deltas,
  saved).
- Chunk ground rendering → `systems/terrain_tiles.gd` (per-biome TileSets) when
  `project.godot [art_studio] use_tiles` is on; otherwise the original code-drawn
  painter.
- `world/settlement.gd` (data-driven; the Azure Cloud Market is the default spec)
  and `world/towns.gd` (one town spec per land region, pure in (continent, seed))
  → buildings (`world/building.gd`), doors and services as `entities/interactable.gd`.
- `world/hidden_realm.gd` + `systems/hidden_realms.gd`, `systems/realm_access.gd`
  → realm templates/families data; entry/exit orchestrated by `main.gd`.
- `systems/travel.gd` → Game.discovered + travel sites registered by settlements,
  towns and POIs; refused in realm/combat (per M14).

### Character and cultivation
- `entities/player.gd` → `systems/stat_block.gd` (the one aggregation pipeline:
  base attributes → passives → physique mods → realm ability mods → meridian mods
  → aging scaling, in the order DEVELOPMENT.md records) ← `systems/attributes.gd`,
  `systems/passives.gd`, `systems/physiques.gd`, `systems/meridians.gd`,
  `systems/realms.gd`, `systems/aging.gd`.
- `systems/cultivation.gd` → Realms (sublevel curve), Meridians (capacity),
  `systems/methods.gd` (method profiles reshape breakthrough/tribulation),
  biome Qi density via Game, contamination state (saved with the character).
- `systems/roots.gd` → `data/roots.json`; gates read by methods/techniques.
- `systems/tribulation.gd` + `world/tribulation_arena.gd` → cultivation state,
  method profiles, Clock.
- `systems/enlightenments.gd` → meditation/kill/tribulation/breakthrough events
  via Bus; permanent mods feed StatBlock.

### Combat
- `systems/combat.gd` + `systems/poise.gd` are shared by `entities/player.gd` and
  every enemy (one damage path, per M30).
- `systems/technique_combat.gd` → `systems/techniques.gd`, `systems/mastery.gd`,
  `systems/skill_bar.gd` (3 bars × 6 slots, pure layout) → `ui/skill_bar_panel.gd`,
  HUD slots.
- `systems/enemy_ai.gd`, `systems/boss.gd`, `systems/beasts.gd` → archetype/beast/
  boss data; `systems/status.gd`, `systems/hitstop.gd`, `ui/damage_numbers.gd`,
  `ui/combat_audio.gd` + `systems/sfx.gd` are presentation leaves (no dependents).

### Items and economy
- `systems/items.gd` (canonical record) ← `systems/itemgen.gd` (pure
  (seed, key, counter) generation) ← `systems/loot.gd` + `data/loot_tables.json`.
- `systems/equipment.gd` (the one equip gate) → StatBlock aggregation.
- `systems/inventory.gd`, `systems/storage.gd` → items; satchel/storehouse UI in
  `ui/hud.gd`.
- `systems/crafting.gd` (forge/refine/disassemble), `systems/alchemy.gd` (pills),
  `systems/professions.gd` (ranks gate recipes) → items + `data/crafting.json`,
  `data/alchemy.json`, `data/professions.json`.
- `systems/economy.gd` + `systems/merchant.gd` → Game.spirit_stones (the single
  currency), Clock (deterministic daily stock).

### NPCs and society
- `systems/npc_db.gd` (generated sheets: ItemGen + Equipment gate for gear) →
  `entities/npc.gd`.
- `systems/schedules.gd` → Clock + settlement locations (schedule location ids are
  the contract town specs must also satisfy); `systems/npc_ai.gd` (threat
  reaction), `systems/npc_progress.gd` (pure (seed, archetype, id, day)
  simulation; nothing saved).
- `systems/relationships.gd` (directed graph) → dialogue/greeting behaviour in
  main; `systems/party.gd` → NPC sheets (companions build real StatBlocks);
  `systems/captivity.gd` → relationships/notoriety; `systems/stories.gd` →
  schedules, ambitions, chronicle.

### Sects and politics
- `systems/sects.gd` → `data/sects.json` (12 sects; `validate()` proves 12 +
  exactly 1 local). `systems/hierarchy.gd`, `systems/sect_economy.gd`,
  `systems/sect_politics.gd` → Azure Cloud state + contribution.
- `systems/player_sect.gd` + `systems/sect_autonomy.gd` → treasury settlement on
  Clock day rollover; reports kept in memory.
- `systems/factions.gd` is a **separate** standing system (4 factions; only Azure
  Cloud overlaps the 12 sects) → prices and disposition.

### Narrative and endgame
- `systems/quests.gd` → `data/quests.json`, single `report()` event channel.
- `systems/sect_storylines.gd` → `data/sect_storylines.json`, relationships/faction
  standing effects.
- `systems/main_narrative.gd` → `data/main_narrative.json`, gated by real game
  state (realm discoveries, claims).
- `systems/world_events.gd` → Clock (5-day cycle), price/spawn/cultivation
  modifiers via Bus.
- `systems/endgame.gd` → `data/endgame.json`, narrative archive completeness,
  writes the irreversible resolution into the save.

### Presentation
- `systems/actor_sprite.gd` (ActorSprite) → art-studio sprite sets, under the
  existing pose `systems/animator.gd`; used by Player/Npc/Dummy when
  `[art_studio] use_sprites` is on, with the code-drawn renderer as fallback.
- `ui/hud.gd` → Bus events, Game state, UiFrame (`ui/ui_frame.gd`); `ui/world_map.gd`
  → Continent data; `ui/shop_panel.gd`, `ui/travel_panel.gd` → economy/travel.
- `systems/camera_rig.gd`, `systems/lighting.gd`, `systems/display_policy.gd` →
  Clock/Weather for day/night and weather presentation.

## Data files by owning system (all under `game/data/`)

| Area | Files |
|---|---|
| Character/cultivation | `roots.json`, `physiques.json`, `passives.json`, `techniques.json`, `methods.json`, `meridians.json`, `realms.json`, `tribulations.json`, `enlightenments.json`, `origins.json` |
| Combat | `weapons.json`, `enemy_archetypes.json`, `spirit_beasts.json`, `bosses.json` |
| Items/economy | `items.json`, `loot_tables.json`, `uniques.json`, `crafting.json`, `alchemy.json`, `professions.json` |
| World | `biomes.json`, `hidden_realm_families.json`, `hidden_realm_templates.json`, `realm_access.json`, `world_events.json` |
| NPC/social | `npcs.json`, `bonds.json`, `captivity.json`, `stories.json` |
| Sects | `sects.json`, `factions.json`, `hierarchy.json`, `sect_economy.json`, `politics.json`, `player_sect.json`, `sect_autonomy.json`, `sect_storylines.json` |
| Narrative | `quests.json`, `main_narrative.json`, `endgame.json`, `inheritances.json` |

## Save flow

`Save` writes Game's run state (seed, character, stones, discovered, party,
captives, claims, used one-shot interactables, endgame epilogue) plus WorldDelta
chunk deltas and NPC memory. On load, `main.gd` rebuilds the continent and chunk
manager **from the save's seed** before resyncing (a mismatch here was a real bug
found and fixed 2026-11-26: continued games previously played in a world generated
from a throwaway roll). Everything else about the world is regenerated
deterministically from the seed.
