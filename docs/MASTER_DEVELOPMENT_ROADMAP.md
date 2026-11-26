# MASTER DEVELOPMENT ROADMAP — ETERNAL ASCENSION (M00–M72)

> **Provenance and basis (added 2026-11-26).** The original roadmap was supplied by Jawanza Martindale on 2026-11-24 in the same chat paste as the Master Design Directive; it was not previously filed in this repository. This document has two parts:
>
> 1. A **summary table** (below): milestone titles taken from the roadmap headings in that paste (cross-checked against `git log` commit subjects, which follow the `M##:` convention from M03 onward), with status and findings as recorded in the Compliance Matrix v2 (2026-11-24, static audit at HEAD `92610e6`). Statuses are the matrix's, not new verdicts.
> 2. An **appendix** reproducing the roadmap portion of the 2026-11-24 paste **verbatim**, so the requirement text itself is now on file.
>
> Status updates after 2026-11-24 (art integration, HUD/controls, World Scale) are recorded in the compliance addendum of 2026-11-26 and are not folded into the table's status column.

## Summary table (titles: roadmap paste; status/findings: Compliance Matrix v2)

| Milestone | Title | Matrix status (2026-11-24) | Findings (matrix, condensed) |
|---|---|---|---|
| M00 | Complete Repository Audit | PARTIALLY IMPLEMENTED | Dev process deliverables (audit, baseline test report, risk assessment as documents) not in repo. |
| M01 | Complete Game Design and Technical Specification | PARTIALLY IMPLEMENTED | Of the 16 required documents, only technical/system specs partially exist. No standalone GDD, art direction, audio direction, UI/UX spec, narrative spec, dependency map as documents. |
| M02 | Core Architecture and Data Design | IMPLEMENTED, NOT FULLY VERIFIED | Strongest foundation area. Event architecture = Bus signals. |
| M03 | Development Infrastructure and Automated Testing | IMPLEMENTED, NOT FULLY VERIFIED | CI run/pass never observed (RELEASE_NOTES admits). No M00–M02 labelled commits. Duplicates M35/M54/M58, M36/M37 out of order. |
| M04 | 2D Rendering and Camera | IMPLEMENTED, NOT FULLY VERIFIED | Code-drawn presentation, not sprites/tiles — see M72. |
| M05 | Player Controller and Movement | IMPLEMENTED, NOT FULLY VERIFIED | 8-direction movement is free-vector movement. Collision is Godot physics layers 1/2/3. |
| M06 | Animation and Character Presentation | PARTIALLY IMPLEMENTED | Missing distinct clips: blocking, casting, staggering, interacting. No sprite animation, no blending system, no directional sprite variations — procedural transforms only. |
| M07 | Interaction and Environmental Systems | IMPLEMENTED, NOT FULLY VERIFIED | Prompts/range/restrictions in main.gd (not fully read — unreviewed in depth). |
| M08 | Time, Weather, and Day/Night | IMPLEMENTED, NOT FULLY VERIFIED | Snow/fog/wind as distinct weather kinds not confirmed in the 6 — weather list not fully enumerated in this pass. |
| M09 | World Coordinate and Streaming Architecture | PARTIALLY IMPLEMENTED | Enormous continent: only 12×12 chunks (one province) exist. No loading screens inside the province — true. Continent-scale streaming does not exist to test. |
| M10 | Continent Geography and World Map | PARTIALLY IMPLEMENTED | PLACEHOLDER for 19 of 20 cells: geography only, region_for_world_position() always returns CAPITAL. No rivers, lakes, coastlines, ranges as traversable geography. Local maps = the one province map. |
| M11 | Biome and Environmental Generation | PARTIALLY IMPLEMENTED | Roadmap lists 12 biome types. Missing: ancient forest, snow region as distinct from frost, desert, spiritual valley, volcanic, sacred, corrupted, forbidden. Content per biome is 2 enemy entries each. |
| M12 | Settlements and Mortal Civilization | PARTIALLY IMPLEMENTED | No villages/towns/cities plural, no blacksmith/alchemy *shops* as distinct establishments, no farms as working settlement systems (farmers are NPC archetypes), no guard post/government buildings, no second settlement of any kind. |
| M13 | World Locations and Exploration | IMPLEMENTED, NOT FULLY VERIFIED | Caves/tombs as overworld locations, treasure locations, ancient battlefields as locations — not in POI list read. |
| M14 | Navigation, Fast Travel, and World Discovery | PARTIALLY IMPLEMENTED | MISSING: random encounters interrupting travel (travel is instant teleport + clock advance), map fog, special cultivation movement (flight/space folding declared, not implemented). Skyrim-style = province-only. |
| M15 | World Persistence and Simulation | PARTIALLY IMPLEMENTED | No beast migration, no faction activity simulation in unloaded regions, no persistent region states beyond chunk resource deltas. |
| M16 | Character Creation and Identity | IMPLEMENTED, NOT FULLY VERIFIED | Single starting location. No later appearance customization. Physique at creation conflicts with Directive §5 — see Contradictions C1. |
| M17 | Six Primary Attributes | IMPLEMENTED, NOT FULLY VERIFIED | RULING NEEDED: Attributes.soft() logarithmic saturation (allowed as diminishing returns by Directive §2.1) vs attr_cost() hard clamp at level 400 / 9e15 price. Cost clamp caps *cost growth*, not the attribute. |
| M18 | Secondary Statistics and Derived Attributes | PARTIALLY IMPLEMENTED | No distinct spiritual attack stat (technique damage scales from physical pipeline + attribute scaling), max health is Player BASE_HP logic outside StatBlock.derived(), no separate technique-power stat. |
| M19 | Spiritual Roots and 12 Tiers | IMPLEMENTED, NOT FULLY VERIFIED | Root *modification* beyond 1-tier-at-a-time evolution not present. Otherwise the cleanest full match to spec. |
| M20 | Physiques and Body Constitutions | PARTIALLY IMPLEMENTED | MISSING: weaknesses/tradeoffs (DEVELOPMENT.md mandates "mods only… there must not be a physique-specific stat code path"), awakening stages, evolution (inheritance *replaces* with a higher tier; the body itself never evolves/awakens), acquisition via training/environment/tribulation (only creatio... |
| M21 | Passive Ability System | PARTIALLY IMPLEMENTED | MISSING categories: Elemental, Mental. MISSING sources: titles, achievements (no such systems), physiques/roots/methods as passive *sources* (physique is parallel mods, enlightenments are a parallel system, not passives). 13 passives is thin for an uncapped collection system. |
| M22 | Technique Learning and Mastery | PARTIALLY IMPLEMENTED | MISSING kinds: healing, transformation, passive techniques. MISSING: technique evolution, specialization, stronger variations through experimentation (mastery is numeric only and deliberately never changes frame data). Only 11 techniques total for 120 sublevels. Suspected S1: creation grants all ... |
| M23 | Cultivation Methods | PARTIALLY IMPLEMENTED | MISSING archetypes from roadmap list of 12: Beast, Alchemy, Elemental, Formation, Forbidden. MISSING: combining methods (single method_id; switching replaces), customizing methods. |
| M24 | Qi, Meridian, and Energy Management | IMPLEMENTED, NOT FULLY VERIFIED | Qi *refinement* as a distinct step from accumulation is not a separate mechanic. |
| M25 | Twelve Realms and 120 Sublevels | PARTIALLY IMPLEMENTED | PLACEHOLDER unlocks: flight, space_folding, domain_projection, spirit_scan, elemental_conversion, physique_awakening, ascension_attempt, plane_manipulation, dao_comprehension — declared flags, no behaviour (DEVELOPMENT.md admits for the flag set). No per-realm visual effects beyond a colour strin... |
| M26 | Breakthroughs and Bottlenecks | IMPLEMENTED, NOT FULLY VERIFIED | Resource/environment requirements are stones + preparation + method state; no material-item requirements for breakthrough. |
| M27 | Tribulations and Heavenly Trials | IMPLEMENTED, NOT FULLY VERIFIED | "Spiritual" trial as a distinct type not in the 11 (heart demon covers mental). Scale factors: realm/kills/karma/method/preparation — physique does not feed tribulation scale in the formula read. |
| M28 | Enlightenment and Dao Comprehension | PARTIALLY IMPLEMENTED | Not Dao paths: no Sword/Blade/Alchemy/Formation/Body/Beast/Space/Time/Elemental Dao as distinct paths with progression. Sources missing: teachers, manuals, observation, environmental phenomena. Insights are generic stat mods. |
| M29 | Lifespan, Aging, and Immortality | PARTIALLY IMPLEMENTED | MISSING: lifespan pills (only 3 pills exist, none for lifespan), lifespan sacrifice, NPC mortality by age (README: NPC deaths not implemented), resurrection, soul transfer, possession, rebirth, succession consequences. |
| M30 | Combat Architecture | IMPLEMENTED, NOT FULLY VERIFIED | Hurtboxes are radius-based geometry in Combat.in_hitbox, not separate hurtbox nodes — acceptable architecture, noted for accuracy. |
| M31 | Basic Combat and Weapon Framework | PARTIALLY IMPLEMENTED | MISSING categories: spears (GitHub search: 0), ranged weapons as weapons (projectiles exist only as techniques / enemy Qi bolts), heavy weapons as a distinct category (saber is heavy-*flavoured*), spiritual weapons as a category. |
| M32 | Dodging, Blocking, and Defensive Combat | IMPLEMENTED, NOT FULLY VERIFIED | Directional evasion beyond facing-based guard not distinct. |
| M33 | Technique Combat and Skill Execution | PARTIALLY IMPLEMENTED | MISSING: healing delivery, transformation delivery. 11 techniques across 6 kinds = 1–3 per kind. |
| M34 | Skill Bar and Loadout Interface | PARTIALLY IMPLEMENTED | NOT VERIFIED / likely missing: Qi cost indicators on slots (cooldown + mastery tier are shown; Qi cost display not in evidence read), animation previews (none — code-drawn, no preview system), skill descriptions in the panel (not in evidence read). Learned count uncapped — true. |
| M35 | Enemy AI and Combat Behaviors | IMPLEMENTED, NOT FULLY VERIFIED | Archetype roster is 4 behaviours reskinning all enemies; casters/assassins/defensive as distinct archetypes are parameter variants, reinforcements only via boss adds. |
| M36 | Spirit Beasts and Bosses | PARTIALLY IMPLEMENTED | MISSING: taming (Beast Taming Instinct passive is a stat mod only), beast migration, rare bloodlines, beast ranks as a system. 4 species for a continent. Boss = hidden-realm wardens only; no overworld bosses in evidence. |
| M37 | Combat Balance and Feedback | IMPLEMENTED, NOT FULLY VERIFIED | No combat log UI (Log is a dev ring buffer). No screen shake/effects beyond hitstop + flashes in evidence. Balance = developer tuning, unverified by play. |
| M38 | Item Database and Item Architecture | IMPLEMENTED, NOT FULLY VERIFIED | — |
| M39 | Procedural Item Generation | IMPLEMENTED, NOT FULLY VERIFIED | Only 4 rarity tiers. Set interactions (Directive §12) not in generation. Elemental properties are affix stats, not an elemental damage system on items beyond lightning_damage_pct. |
| M40 | Equipment and Modifier Aggregation | PARTIALLY IMPLEMENTED | Slots are weapon / armor / ring / talisman only. MISSING slots: necklace, artifact (talisman fills the accessory role partially). No second ring/accessory slots in evidence. |
| M41 | Unique Items and Legendary Treasures | PARTIALLY IMPLEMENTED | MISSING: set items (none), sect heirlooms, divine artifacts, legendary accessories, named manuals as uniques. 2 uniques total for the whole game. |
| M42 | Inventory, Storage, and Loot | IMPLEMENTED, NOT FULLY VERIFIED | Filtering not in evidence (sorting only). Item dropping not in evidence read. |
| M43 | Loot Tables and Reward Architecture | IMPLEMENTED, NOT FULLY VERIFIED | Design note: warden kill pays a *guaranteed* Treasure item — Directive §14.2 says a dungeon completion must not guarantee its boss's rare drop; boss-drop vs completion streams are separate here, but the guaranteed boss item itself needs your ruling. Quest rewards are authored per quest, separate ... |
| M44 | Forging, Refinement, and Equipment Modification | PARTIALLY IMPLEMENTED | MISSING: fusion (search: 0), enchanting (search: 0), upgrading item level, personalization. Refine is the only affix modification. |
| M45 | Alchemy and Consumables | PARTIALLY IMPLEMENTED | Only 3 consumables total. MISSING: potions, elixirs, poisons, breakthrough-aid pills, lifespan pills, ingredient compatibility system. |
| M46 | Professions, Resources, and Crafting Economy | PARTIALLY IMPLEMENTED | MISSING as professions: mining, herbalism, formation crafting, artifact crafting, beast processing, resource refining — no ranks, no mastery, no recipes. Single currency (spirit stones) — no mortal money, no multiple currencies, no supply/demand, no auctions/black markets (search: 0). Merchant st... |
| M47 | NPC Generation and Character Database | IMPLEMENTED, NOT FULLY VERIFIED | Personality/background are archetype-level, not individual; NPC cultivation *method* is not part of the sheet in evidence (progression simulates realm, not method). |
| M48 | NPC Schedules and Daily Routines | IMPLEMENTED, NOT FULLY VERIFIED | Eating as a scheduled activity is inside routine labels, not a needs system. Schedules do not react to world events (alarm reaction is the exception, M49). |
| M49 | NPC Intelligence and Decision-Making | PARTIALLY IMPLEMENTED | This is a *threat-reaction* brain only. MISSING general decision-making: needs, fears, opportunity seeking, risk evaluation, relationship decisions, faction-loyalty decisions. Ambitions are data tags consumed by Stories, not an NPC decision engine. |
| M50 | Relationships, Dialogue, and Social Interaction | PARTIALLY IMPLEMENTED | MISSING: romance (search: 0), marriage (0), family formation, betrayal as a system, dialogue trees/choices, social checks beyond standing thresholds. |
| M51 | Party, Companions, and Recruitment | PARTIALLY IMPLEMENTED | Divergences: companions *cannot die* (roadmap: companion deaths where appropriate); no party commands (follow/engage is automatic); no companion quests; player cannot give equipment or teach techniques to companions (Directive §10.2 requires both). |
| M52 | Captivity, Slavery, and Prison Systems | IMPLEMENTED, NOT FULLY VERIFIED | Rescue of captives by third parties not implemented; ransom is approximated by watch bounty handover. Player-as-captive explicitly out of scope (RELEASE_NOTES). |
| M53 | NPC Cultivation and Independent Progression | PARTIALLY IMPLEMENTED | NPCs do not learn techniques, find manuals/resources, develop physiques, or change methods — realm change *regenerates* a sheet from pools. NPCs cannot die from progression. Archetype realm caps (farmer 2, master 8) are hard caps on NPC growth. "Persistent" = recomputable, not stateful. |
| M54 | NPC Memory and Emergent Stories | IMPLEMENTED, NOT FULLY VERIFIED | Promises, grudges, family histories as distinct memory types not present — memory is a regard counter + talk count. |
| M55 | Faction and Sect Architecture | PARTIALLY IMPLEMENTED | Factions ≠ the 12 sects (only Azure Cloud overlaps). No faction territory, resources, goals, diplomacy, or conflicts as simulation — standing is a meter with two mechanical effects. |
| M56 | Twelve Established Sects | PARTIALLY IMPLEMENTED | PLACEHOLDER for 11: only Azure Cloud is local/playable; most signature method/technique IDs are empty strings; no headquarters you can visit, no NPC population, no leadership/hierarchy *in the world*, no territory, no manuals/resources for 11 sects. Storylines (M68) are their only other presence. |
| M57 | Sect Hierarchy and Advancement | PARTIALLY IMPLEMENTED | NPCs do not pursue advancement — rank is an assignment table, not a career simulation. No disciplinary system, no internal competition, succession only for the player's seat path. Applies to Azure Cloud only. |
| M58 | Sect Economy and Administration | PARTIALLY IMPLEMENTED | MISSING for established sects: treasury as simulated funds, buildings, training facilities, libraries, alchemy/forging halls, formations, defensive structures, research, missions board (quests/story requests partially fill missions), sect development. |
| M59 | Sect Politics, Diplomacy, and Warfare | PARTIALLY IMPLEMENTED | MISSING entirely: inter-sect diplomacy, alliances/treaties between sects, espionage, assassinations, sect wars, territorial conflict, surrenders, destruction, absorption (warfare search: 0). What exists is one sect's internal council. |
| M60 | Player-Founded Sect | PARTIALLY IMPLEMENTED | Player does NOT choose: name (doctrine presets give name/motto/hall), location, laws, hierarchy, recruitment policies beyond doctrine. MISSING: appointing elders (steward is auto-derived strongest member), branches/subsidiaries, buildings, research, territory, expansion, succession, internal-conf... |
| M61 | Sect NPC Autonomy and Competition | PARTIALLY IMPLEMENTED | Established sects have NO autonomy: no independent recruitment, training, expansion, diplomacy, war, decline, or succession for the 12. Autonomy = treasury arithmetic for the player's hall only. |
| M62 | Hidden Realm Generation Framework | IMPLEMENTED, NOT FULLY VERIFIED | Realm persistence = claims/deltas + saved tomb seed; non-tomb realms regenerate from seed by design. |
| M63 | Hidden Realm Discovery and Access | IMPLEMENTED, NOT FULLY VERIFIED | MISSING discovery sources: treasure maps, ancient artifacts, sect assignments (storylines send you to realms as chapter tests, partially). Entry competition = inheritance rival only. |
| M64 | Hidden Realm Content and Encounters | IMPLEMENTED, NOT FULLY VERIFIED | Trials are combat (kill echoes); puzzles are not a distinct mechanic in evidence. |
| M65 | Inheritance and Ancient Legacy System | IMPLEMENTED, NOT FULLY VERIFIED | Root *upgrades* and crafting-recipe inheritances not in the grant types read. Bloodline transformation ≈ physique grant. |
| M66 | Random Events, Rumors, and Opportunities | PARTIALLY IMPLEMENTED | Events are calendar modifiers, not simulated occurrences: no beast invasion as an event with actors, no wandering master, no sect expedition, no competition, no political crisis with participants. NPCs/sects do not pursue events independently. |
| M67 | Quest and Story Architecture | PARTIALLY IMPLEMENTED | Only 4 quests. MISSING types: companion quests, dynamic/procedural quests, bounty quests as quests (hunt *requests* in Stories are a parallel system), quest failure/expiration for quests, branching *decisions* inside quests (choices live in M68 storylines). |
| M68 | Twelve Sect Storylines and Inheritance Campaigns | PARTIALLY IMPLEMENTED | Structural conflict with roadmap: all 12 share ONE ladder (welcome/fault/reckoning) — roadmap says do not make all twelve structurally identical. Storylines do not let you *join* the other 11 sects, advance in them, or take a high-ranking position in them; "unique inheritance" = stance grants, no... |
| M69 | Main Narrative and World History | IMPLEMENTED, NOT FULLY VERIFIED | Narrative is a record-collection/archive system — no narrative scenes, characters, or dialogue carry the history. Within its own chosen form it is complete in structure; scope is narrower than "overarching story" implies. |
| M70 | Endgame and Transcendence | PARTIALLY IMPLEMENTED | Of the roadmap's 8+ endgame paths, ~3 are approximated (knowledge, sect leadership, refusal/transcendence). MISSING as playable endgame: continental dominance, forbidden cultivation path, legendary craftsmanship path, new civilization, high-level endgame enemies/events/trials. Progression effecti... |
| M71 | Complete UI/UX and Accessibility | PARTIALLY IMPLEMENTED | No dedicated cultivation screen, realm-progression screen, root/physique screens (data lives on sheet/HUD lines), passive collection screen, technique library screen, quest journal screen (HUD tracker only), party management screen, dialogue UI. No tooltips system in evidence. Typography is code-... |
| M72 | Final Art, Audio, Optimization, and Release | PARTIALLY IMPLEMENTED | FINAL ART criteria NOT met: game is code-drawn except title key art — no sprites, tiles, building/sect architecture art, weapon/equipment visuals, technique effect art (Directive §17: avoid placeholder graphics in the final build). Audio/visuals never seen or heard in the build environment (RELEA... |

## Appendix — the roadmap as supplied (verbatim, 2026-11-24 paste)

# ETERNAL ASCENSION
# MASTER DEVELOPMENT ROADMAP
## 72 Milestones — From Repository Audit to Final Release

PROJECT TYPE: 2D Top-Down Open-World Xianxia Action RPG

DEVELOPMENT MODEL: Sequential, audited, test-driven milestone delivery.

---

# PHASE 0 — PROJECT DISCOVERY AND ARCHITECTURE

## MILESTONE 00 — Complete Repository Audit

Inspect the entire existing project before changing anything.

Tasks:
- Identify engine, version, language, frameworks, and dependencies.
- Inventory all folders, scripts, scenes, resources, assets, and configuration files.
- Identify existing gameplay systems.
- Identify existing UI and art.
- Inspect the save system.
- Inspect current performance.
- Identify incomplete, duplicated, broken, and unused code.
- Run existing tests.
- Record the current Git branch, HEAD commit, and working-tree status.
- Identify existing technical debt.

Deliverables:
- Repository audit.
- Existing functionality inventory.
- Dependency inventory.
- Technical risk assessment.
- Baseline test report.
- Recommended implementation strategy.

Do not modify the project during the audit.

## MILESTONE 01 — Complete Game Design and Technical Specification

Translate the entire Eternal Ascension concept into detailed production documentation.

Create:
- Complete Game Design Document.
- Technical Design Document.
- System dependency map.
- Gameplay loop documentation.
- Character progression specification.
- Cultivation progression specification.
- Combat specification.
- World simulation specification.
- NPC simulation specification.
- Itemization specification.
- Sect system specification.
- Narrative and quest specification.
- UI/UX specification.
- Art direction document.
- Audio direction document.
- QA and acceptance strategy.

Identify unresolved design decisions and recommend solutions.

## MILESTONE 02 — Core Architecture and Data Design

Establish the foundation for all game systems.

Implement:
- Modular system architecture.
- Data-driven content definitions.
- Stable unique IDs.
- Resource and database organization.
- Event and signal architecture.
- Dependency management.
- Gameplay configuration system.
- Logging and debugging framework.
- Error handling.
- Developer documentation.

Ensure future systems can be expanded without repeatedly rewriting foundational architecture.

## MILESTONE 03 — Development Infrastructure and Automated Testing

Establish a reliable development pipeline.

Implement:
- Git repository organization.
- Branching and commit conventions.
- Automated test discovery.
- Unit testing.
- Integration testing.
- Regression testing.
- Build validation.
- Asset validation.
- Debug logging.
- Test reports.
- Version tagging.
- Backup procedures.

Create a repeatable development and verification workflow.

---

# PHASE 1 — GAME FOUNDATION

## MILESTONE 04 — 2D Rendering and Camera

Build the actual top-down 2D presentation.

Implement:
- Top-down camera.
- Smooth camera following.
- Camera boundaries.
- Camera zoom.
- World-space rendering.
- Sprite layering.
- Y-sorting.
- Occlusion.
- Lighting support.
- Environmental depth.
- Resolution scaling.

Do not use isometric or 2.5D presentation.

## MILESTONE 05 — Player Controller and Movement

Implement the complete player movement system.

Controls:
- W: Up.
- A: Left.
- S: Down.
- D: Right.
- Mouse: Aiming and targeting.

Implement:
- Eight-direction movement.
- Directional sprite animations.
- Acceleration and deceleration.
- Movement responsiveness.
- Collision.
- Interaction detection.
- Sprinting where appropriate.
- Movement modifiers.
- Input customization.
- Controller support as an optional future-compatible input layer.

## MILESTONE 06 — Animation and Character Presentation

Build the animation framework.

Implement:
- Idle.
- Walking.
- Running.
- Attacking.
- Dodging.
- Blocking.
- Casting.
- Taking damage.
- Staggering.
- Death.
- Interaction.
- Cultivation.
- Environmental animations.

Support animation blending, animation events, timing, and directional variations.

## MILESTONE 07 — Interaction and Environmental Systems

Implement player interactions.

Include:
- NPC interaction.
- Object interaction.
- Doors.
- Chests.
- Resource gathering.
- Pickups.
- Containers.
- Reading manuals.
- Environmental examination.
- Contextual interaction prompts.
- Interaction range.
- Interaction restrictions.

## MILESTONE 08 — Time, Weather, and Day/Night

Implement:
- World clock.
- Day/night cycle.
- Seasonal framework.
- Weather.
- Rain.
- Snow.
- Fog.
- Wind.
- Environmental lighting.
- Weather-dependent gameplay effects.
- Time-dependent NPC activities.

World time must continue independently of the player.

---

# PHASE 2 — SEAMLESS OPEN WORLD

## MILESTONE 09 — World Coordinate and Streaming Architecture

Build the foundation for one enormous continuous continent.

Implement:
- Persistent world coordinates.
- Chunk-based world streaming.
- Dynamic loading.
- Dynamic unloading.
- Chunk boundaries.
- World persistence.
- Background simulation.
- Seamless terrain transitions.
- Streaming performance controls.

Ordinary overworld travel must not require loading separate regional maps.

## MILESTONE 10 — Continent Geography and World Map

Create the complete continent layout.

Design:
- Major geographical regions.
- Mountain ranges.
- Forests.
- Plains.
- Deserts.
- Rivers.
- Lakes.
- Coastlines where appropriate.
- Spiritual mountain ranges.
- Forbidden territories.
- Ancient battlefields.
- Remote wilderness.

Create a world map and discoverable local maps.

Handcraft important geography and landmarks.

## MILESTONE 11 — Biome and Environmental Generation

Implement biome systems.

Include:
- Mortal forests.
- Spirit beast forests.
- Ancient forests.
- Mountains.
- Snow regions.
- Deserts.
- Wetlands.
- Spiritual valleys.
- Volcanic areas.
- Sacred locations.
- Corrupted regions.
- Forbidden zones.

Each biome needs its own environmental identity, resources, enemies, NPC encounters, and visual presentation.

## MILESTONE 12 — Settlements and Mortal Civilization

Create populated mortal settlements.

Implement:
- Villages.
- Towns.
- Cities.
- Markets.
- Inns.
- Blacksmiths.
- Alchemy shops.
- Residential buildings.
- Farms.
- Guard posts.
- Government buildings.
- Merchant districts.
- Public spaces.

Settlements must contain functional NPCs, services, schedules, and economies.

## MILESTONE 13 — World Locations and Exploration

Implement discoverable locations.

Include:
- Ancient ruins.
- Caves.
- Tombs.
- Abandoned settlements.
- Mines.
- Resource deposits.
- Training grounds.
- Hidden entrances.
- Shrines.
- Ancient battlefields.
- Treasure locations.
- Dangerous territories.

Create environmental storytelling and exploration rewards.

## MILESTONE 14 — Navigation, Fast Travel, and World Discovery

Implement:
- Discoverable map markers.
- Fast-travel locations.
- Travel restrictions.
- Time advancement during travel.
- Travel encounters.
- Travel interruption.
- Map fog.
- Location tracking.
- Compass and navigation assistance.
- Special cultivation-based movement.

Fast travel must require discovering locations first.

## MILESTONE 15 — World Persistence and Simulation

Make the world function outside the player's immediate view.

Implement:
- Persistent region states.
- Resource regeneration.
- NPC movement.
- Beast migration.
- Settlement activity.
- Faction activity.
- World events.
- Unloaded-region simulation.
- World-state persistence.

Ensure streaming does not erase important world changes.

---

# PHASE 3 — CHARACTER AND CULTIVATION

## MILESTONE 16 — Character Creation and Identity

Implement character creation.

Include:
- Name.
- Appearance.
- Gender presentation options.
- Sprite customization.
- Starting background.
- Starting location.
- Initial attributes.
- Starting circumstances.

Do not force the player into a conventional RPG class.

Character creation must allow future appearance customization where supported.

## MILESTONE 17 — Six Primary Attributes

Implement:
- DEX.
- STR.
- AGI.
- INT.
- WIS.
- CHAR.

Attributes must be uncapped.

Create meaningful formulas for:
- Physical damage.
- Accuracy.
- Attack speed.
- Movement.
- Dodge.
- Qi capacity.
- Qi recovery.
- Cultivation speed.
- Technique comprehension.
- Crafting.
- Social interaction.
- Breakthrough assistance.
- Resistance.

Ensure attribute scaling remains functional at extremely high values.

## MILESTONE 18 — Secondary Statistics and Derived Attributes

Implement:
- Maximum health.
- Health regeneration.
- Maximum Qi.
- Qi regeneration.
- Physical attack.
- Spiritual attack.
- Defense.
- Resistance.
- Critical chance.
- Critical damage.
- Attack speed.
- Movement speed.
- Accuracy.
- Evasion.
- Penetration.
- Technique cooldown.
- Lifespan.
- Cultivation efficiency.

Create a transparent modifier aggregation system.

## MILESTONE 19 — Spiritual Roots and 12 Tiers

Implement all twelve spiritual root tiers.

Include:
- Root generation.
- Root discovery.
- Root identification.
- Elemental affinities.
- Multiple affinities.
- Root quality.
- Root compatibility.
- Cultivation bonuses.
- Method requirements.
- Root evolution.
- Root modification where appropriate.

The system must support extraordinary rarity at the highest tiers.

## MILESTONE 20 — Physiques and Body Constitutions

Implement the physique framework.

Include:
- Physique acquisition.
- Physique rarity.
- Physique identification.
- Physique passives.
- Physique requirements.
- Physique weaknesses.
- Physique compatibility.
- Awakening.
- Evolution.
- Transformation.

Create an initial collection of distinctive physiques.

Physiques must be obtainable through gameplay rather than only character creation.

## MILESTONE 21 — Passive Ability System

Implement an uncapped passive collection system.

Sources:
- Physiques.
- Roots.
- Cultivation methods.
- Techniques.
- Titles.
- Achievements.
- Inheritances.
- Training.
- Events.
- Special discoveries.

Implement:
- Passive categories.
- Passive requirements.
- Passive activation.
- Conditional effects.
- Passive synergies.
- Passive conflicts.
- Stacking rules.
- Modifier priorities.
- Passive descriptions.

No arbitrary passive learning cap.

## MILESTONE 22 — Technique Learning and Mastery

Build the technique system.

Include:
- Manual-based learning.
- Teacher instruction.
- Observation.
- Inheritance learning.
- Technique requirements.
- Technique mastery.
- Technique upgrades.
- Technique specialization.
- Technique evolution.
- Technique compatibility.
- Technique replacement and experimentation.

Support active and passive techniques.

## MILESTONE 23 — Cultivation Methods

Implement cultivation methods as actual gameplay systems.

Each method must define:
- Cultivation behavior.
- Qi absorption.
- Qi refinement.
- Progression requirements.
- Realm compatibility.
- Root compatibility.
- Physique compatibility.
- Special resources.
- Bottlenecks.
- Risks.
- Unique benefits.

Implement multiple cultivation archetypes, including:
- Traditional.
- Body.
- Sword.
- Blood.
- Beast.
- Alchemy.
- Elemental.
- Dual cultivation.
- Slaughter.
- Formation.
- Heavenly.
- Forbidden.

Methods must have genuinely different progression requirements.

## MILESTONE 24 — Qi, Meridian, and Energy Management

Implement:
- Qi accumulation.
- Qi absorption.
- Qi refinement.
- Qi circulation.
- Qi capacity.
- Qi recovery.
- Meridian conditions.
- Meridian damage.
- Qi deviation.
- Energy contamination.
- Spiritual energy environments.
- Qi consumption.
- Energy efficiency.

Different methods and constitutions must change how energy works.

## MILESTONE 25 — Twelve Realms and 120 Sublevels

Implement all twelve cultivation realms.

Each realm contains ten sublevels.

Build:
- Realm definitions.
- Sublevel progression.
- Realm stat bonuses.
- Realm abilities.
- Realm requirements.
- Realm-specific effects.
- Lifespan changes.
- Visual progression.
- Enemy progression.
- World interaction changes.
- Realm compatibility.

Each major breakthrough must produce a substantial increase in power.

Individual sublevels must provide smaller improvements.

Do not impose a conventional character-level cap.

## MILESTONE 26 — Breakthroughs and Bottlenecks

Implement:
- Cultivation thresholds.
- Breakthrough preparation.
- Resource requirements.
- Bottleneck detection.
- Breakthrough attempts.
- Success probabilities.
- Failure consequences.
- Qi deviation.
- Injuries.
- Special breakthroughs.
- Breakthrough bonuses.
- Breakthrough notifications.

Different cultivation methods must have different breakthrough mechanics.

## MILESTONE 27 — Tribulations and Heavenly Trials

Implement:
- Lightning tribulations.
- Heart demons.
- Elemental trials.
- Spiritual trials.
- Bloodline tribulations.
- Spatial tribulations.
- Heavenly judgment.
- Special realm trials.

Tribulations must scale based on relevant character progression, behavior, cultivation method, and accumulated power.

Make them playable encounters with actual consequences.

## MILESTONE 28 — Enlightenment and Dao Comprehension

Implement:
- Sword Dao.
- Blade Dao.
- Alchemy Dao.
- Formation Dao.
- Body Dao.
- Beast Dao.
- Weapon Dao.
- Space Dao.
- Time Dao.
- Elemental Dao.
- Other discoverable paths.

Allow comprehension through:
- Practice.
- Meditation.
- Combat.
- Teachers.
- Manuals.
- Observation.
- Environmental phenomena.
- Rare enlightenment events.

Enlightenment must unlock mechanical benefits and unique development opportunities.

## MILESTONE 29 — Lifespan, Aging, and Immortality

Implement:
- Natural aging.
- Lifespan by realm.
- Lifespan extension.
- Longevity pills.
- Lifespan sacrifices.
- Aging effects.
- NPC mortality.
- Immortality progression.
- Special resurrection methods.
- Soul transfer.
- Possession.
- Rebirth where supported.

Ensure death and succession have meaningful consequences.

---

# PHASE 4 — ACTION COMBAT AND ENEMIES

## MILESTONE 30 — Combat Architecture

Build the real-time combat foundation.

Implement:
- Combat states.
- Attack states.
- Hitboxes.
- Hurtboxes.
- Damage calculation.
- Collision.
- Targeting.
- Combat events.
- Attack interruption.
- Stagger.
- Knockback.
- Combat modifiers.

Ensure combat reads attributes, techniques, passives, equipment, and cultivation.

## MILESTONE 31 — Basic Combat and Weapon Framework

Implement:
- Unarmed combat.
- Swords.
- Spears.
- Blades.
- Staffs.
- Heavy weapons.
- Ranged weapons.
- Spiritual weapons.

Include weapon-specific animations, attack properties, and scaling.

## MILESTONE 32 — Dodging, Blocking, and Defensive Combat

Implement:
- Dodging.
- Directional evasion.
- Blocking.
- Parrying.
- Defensive techniques.
- Damage mitigation.
- Stagger resistance.
- Invulnerability windows where appropriate.
- Defensive recovery.

Make defensive actions responsive and skill-based.

## MILESTONE 33 — Technique Combat and Skill Execution

Connect learned techniques to actual combat.

Implement:
- Melee attacks.
- Spells.
- Projectiles.
- Area attacks.
- Summons.
- Defensive skills.
- Healing.
- Movement abilities.
- Transformations.
- Buffs and debuffs.

Support animation timing, aiming, resource costs, cooldowns, and scaling.

## MILESTONE 34 — Skill Bar and Loadout Interface

Implement:
- Three skill bars.
- Six slots per bar.
- Eighteen equipped slots.
- Bar switching.
- Customizable key bindings.
- Drag-and-drop configuration.
- Cooldown displays.
- Qi costs.
- Skill descriptions.
- Skill previews.
- Invalid-action feedback.

The number of learned techniques must not be limited by equipped capacity.

## MILESTONE 35 — Enemy AI and Combat Behaviors

Implement enemy archetypes and behaviors.

Include:
- Basic enemies.
- Ranged enemies.
- Melee enemies.
- Defensive enemies.
- Casters.
- Assassins.
- Beast enemies.
- Elite cultivators.
- Bosses.

Implement:
- Detection.
- Aggression.
- Target selection.
- Movement.
- Attack selection.
- Retreat.
- Group behavior.
- Reinforcements.
- Combat memory where appropriate.

## MILESTONE 36 — Spirit Beasts and Bosses

Build the spirit beast ecosystem.

Implement:
- Beast species.
- Beast ranks.
- Territorial behavior.
- Aggression.
- Migration.
- Hunting.
- Rare bloodlines.
- Beast abilities.
- Beast bosses.
- Unique drops.
- Taming potential.
- Beast materials.

Create distinctive boss encounters with multiple phases and recognizable mechanics.

## MILESTONE 37 — Combat Balance and Feedback

Polish the combat experience.

Implement:
- Hit feedback.
- Impact effects.
- Screen effects.
- Combat audio.
- Damage indicators.
- Boss telegraphs.
- Status effects.
- Combat log.
- Combat balance.
- Enemy difficulty scaling.
- Performance optimization.

Verify that animation timing and positioning remain important at every cultivation realm.

---

# PHASE 5 — ITEMS, EQUIPMENT, AND PROFESSIONS

## MILESTONE 38 — Item Database and Item Architecture

Create the complete item framework.

Implement:
- Base item definitions.
- Unique IDs.
- Item categories.
- Item properties.
- Item rarity.
- Item requirements.
- Item metadata.
- Item stacking.
- Item durability.
- Item persistence.
- Item serialization.

Support future expansion without hardcoding individual items into gameplay scripts.

## MILESTONE 39 — Procedural Item Generation

Implement a Path of Exile-inspired generation framework.

Include:
- Base item types.
- Rarity tiers.
- Implicit modifiers.
- Prefixes.
- Suffixes.
- Affix pools.
- Weighted generation.
- Modifier ranges.
- Item requirements.
- Item power calculations.
- Deterministic random seeds.

Generate items that create meaningful build differences.

## MILESTONE 40 — Equipment and Modifier Aggregation

Implement:
- Weapon slots.
- Armor slots.
- Accessories.
- Rings.
- Necklaces.
- Talismans.
- Artifacts.
- Equipment requirements.
- Equipment bonuses.
- Equipment conflicts.
- Modifier stacking.
- Equipment comparison.
- Equipment effects in combat.

Verify all equipment modifiers affect actual gameplay.

## MILESTONE 41 — Unique Items and Legendary Treasures

Create handcrafted special equipment.

Include:
- Unique weapons.
- Divine artifacts.
- Ancient treasures.
- Sect heirlooms.
- Named equipment.
- Set items.
- Legendary accessories.
- Special cultivation artifacts.

Give each special item distinctive properties, lore, and acquisition conditions.

## MILESTONE 42 — Inventory, Storage, and Loot

Implement:
- Inventory.
- Equipment inventory.
- Grid or structured inventory presentation.
- Storage containers.
- Stacking.
- Sorting.
- Filtering.
- Item comparison.
- Loot pickup.
- Loot notifications.
- Item transfer.
- Item dropping.
- Item selling.

Ensure inventory works with generated and handcrafted items.

## MILESTONE 43 — Loot Tables and Reward Architecture

Create separate loot systems for:
- Ordinary enemies.
- Elite enemies.
- Bosses.
- Spirit beasts.
- Chests.
- Exploration.
- Hidden realms.
- Quest rewards.
- Dungeon completion.
- Inheritances.
- Resource gathering.

Use weighted random probabilities.

Do not guarantee rare drops unless explicitly designed as guaranteed rewards.

Keep boss drops, dungeon rewards, quest rewards, and exploration rewards logically separate.

## MILESTONE 44 — Forging, Refinement, and Equipment Modification

Implement:
- Forging.
- Refinement.
- Enchanting.
- Affix modification.
- Item upgrading.
- Item personalization.
- Reforging.
- Item fusion.
- Disassembly.
- Repair.
- Failure conditions.
- Special crafting outcomes.

Allow meaningful experimentation without making every item upgrade guaranteed.

## MILESTONE 45 — Alchemy and Consumables

Implement:
- Pills.
- Potions.
- Elixirs.
- Poisons.
- Recovery items.
- Breakthrough aids.
- Lifespan items.
- Special cultivation medicines.
- Recipes.
- Ingredient compatibility.
- Quality levels.
- Refinement failures.
- Rare discoveries.

Create an alchemy profession with its own progression.

## MILESTONE 46 — Professions, Resources, and Crafting Economy

Implement:
- Mining.
- Herbalism.
- Gathering.
- Forging.
- Alchemy.
- Formation crafting.
- Artifact crafting.
- Beast material processing.
- Resource refining.
- Crafting recipes.
- Profession mastery.
- Resource rarity.

Each profession must have practical gameplay applications.

---

# PHASE 6 — NPCS AND SOCIAL SYSTEMS

## MILESTONE 47 — NPC Generation and Character Database

Create the NPC framework.

Every significant NPC should support:
- Identity.
- Name.
- Attributes.
- Root.
- Physique.
- Realm.
- Cultivation method.
- Techniques.
- Passives.
- Equipment.
- Personality.
- Background.
- Goals.
- Allegiance.
- Relationships.
- Memory.
- Current state.

Generate distinct NPC builds.

## MILESTONE 48 — NPC Schedules and Daily Routines

Implement:
- Sleeping.
- Eating.
- Working.
- Training.
- Cultivating.
- Shopping.
- Traveling.
- Hunting.
- Teaching.
- Socializing.
- Resting.
- Combat activities.

Schedules must react to world conditions and NPC responsibilities.

## MILESTONE 49 — NPC Intelligence and Decision-Making

Implement:
- Decision-making.
- Needs.
- Ambitions.
- Fears.
- Personality traits.
- Memory.
- Reputation awareness.
- Opportunity seeking.
- Risk evaluation.
- Independent cultivation.
- Relationship decisions.
- Faction loyalty.

NPCs must not simply wait for player interaction.

## MILESTONE 50 — Relationships, Dialogue, and Social Interaction

Implement:
- Friendship.
- Rivalry.
- Hostility.
- Mentorship.
- Romance.
- Marriage.
- Family.
- Loyalty.
- Betrayal.
- Trust.
- Reputation.

Create contextual dialogue, social checks, relationship progression, and persistent interaction consequences.

## MILESTONE 51 — Party, Companions, and Recruitment

Implement:
- Companion recruitment.
- Party creation.
- Party management.
- Companion AI.
- Party combat.
- Companion equipment.
- Companion techniques.
- Party commands.
- Companion loyalty.
- Companion progression.
- Companion quests.
- Companion deaths where appropriate.

Companions must use actual character builds.

## MILESTONE 52 — Captivity, Slavery, and Prison Systems

Implement optional world systems for:
- Capture.
- Imprisonment.
- Forced labor.
- Captive management.
- Escape attempts.
- Rebellion.
- Rescue.
- Release.
- Ransom.
- Reputation consequences.
- Faction retaliation.
- Morality and legal consequences.

NPCs retain personalities, goals, memories, and agency.

## MILESTONE 53 — NPC Cultivation and Independent Progression

Allow NPCs to:
- Train.
- Learn techniques.
- Obtain manuals.
- Discover resources.
- Acquire equipment.
- Develop physiques.
- Change cultivation methods.
- Break through realms.
- Attempt tribulations.
- Fail breakthroughs.
- Die.
- Become legendary cultivators.

Ensure NPC progression is persistent and computationally scalable.

## MILESTONE 54 — NPC Memory and Emergent Stories

Implement:
- Interaction memories.
- Reputation history.
- Personal grudges.
- Promises.
- Rivalries.
- Shared events.
- Family histories.
- Personal ambitions.
- NPC-generated conflicts.
- Emergent story events.

The world should produce stories without requiring manually authored quest triggers for every interaction.

---

# PHASE 7 — SECTS AND WORLD POLITICS

## MILESTONE 55 — Faction and Sect Architecture

Build the general faction framework.

Implement:
- Faction identities.
- Faction membership.
- Leadership.
- Territory.
- Resources.
- Reputation.
- Alliances.
- Rivalries.
- Diplomacy.
- Conflicts.
- Faction goals.
- Faction relationships.

Support both established and player-created organizations.

## MILESTONE 56 — Twelve Established Sects

Create all twelve unique established sects:

1. Heavenly Sword Sect.
2. Azure Cloud Sect.
3. Crimson Lotus Sect.
4. Thousand Beast Sect.
5. Celestial Formation Sect.
6. Blood Moon Palace.
7. Eternal Medicine Valley.
8. Shadow Veil Sect.
9. Thunder Sovereign Sect.
10. Frozen Heaven Palace.
11. Golden Cauldron Sect.
12. Void Scripture Pavilion.

Each needs:
- Unique territory.
- Headquarters.
- Architecture.
- NPC population.
- Leadership.
- Hierarchy.
- Cultivation specialty.
- Techniques.
- Manuals.
- Methods.
- Resources.
- Internal politics.
- Relationships.
- Questline.
- Inheritance.

Do not make the sects cosmetic variations of one another.

## MILESTONE 57 — Sect Hierarchy and Advancement

Implement:
- Outer disciples.
- Inner disciples.
- Core disciples.
- Elders.
- Deputy leaders.
- Sect masters.
- Guardians.
- Specialized department leaders.
- Servants.
- Instructors.

Implement:
- Promotion requirements.
- Sect contribution.
- Missions.
- Disciplinary systems.
- Sect reputation.
- Internal competition.
- Leadership succession.

NPCs must occupy positions and pursue advancement.

## MILESTONE 58 — Sect Economy and Administration

Implement:
- Sect treasury.
- Spirit stone income.
- Resource management.
- Buildings.
- Training facilities.
- Libraries.
- Alchemy halls.
- Forging halls.
- Formations.
- Defensive structures.
- Disciple maintenance.
- Recruitment.
- Research.
- Missions.
- Sect development.

## MILESTONE 59 — Sect Politics, Diplomacy, and Warfare

Implement:
- Alliances.
- Treaties.
- Hostility.
- Espionage.
- Assassinations.
- Negotiations.
- Sect wars.
- Territorial conflicts.
- Resource disputes.
- Leadership challenges.
- Betrayals.
- Surrenders.
- Sect destruction.
- Sect absorption.

Make faction actions affect the persistent world.

## MILESTONE 60 — Player-Founded Sect

Implement the complete player sect creation system.

Allow:
- Naming.
- Founding.
- Location selection.
- Philosophy.
- Recruitment rules.
- Hierarchy.
- Sect specialization.
- Laws.
- Alliances.
- Resource management.
- Buildings.
- Research.
- Expansion.
- Territory.
- Succession.

Support:
- Recruiting disciples.
- Appointing elders.
- Assigning positions.
- Creating branches.
- Establishing subsidiaries.
- Training members.
- Managing internal conflicts.

The player must be able to grow from independent cultivator to sect founder and leader.

## MILESTONE 61 — Sect NPC Autonomy and Competition

Allow all sects to function independently.

Implement:
- Independent recruitment.
- Independent training.
- Sect expansion.
- Leadership competition.
- Resource acquisition.
- Intelligence gathering.
- Inheritance expeditions.
- Diplomatic decisions.
- War decisions.
- Sect decline.
- Sect recovery.
- Sect succession.

Sect activity must continue without player intervention.

---

# PHASE 8 — HIDDEN REALMS AND INHERITANCES

## MILESTONE 62 — Hidden Realm Generation Framework

Create the procedural hidden realm architecture.

Implement:
- Realm templates.
- Procedural layouts.
- Environment generation.
- Enemy generation.
- Resource generation.
- Treasure placement.
- Boss placement.
- Difficulty settings.
- Random seeds.
- Realm persistence.
- Entry and exit systems.

Hidden realms are separate environments, not ordinary disconnected overworld regions.

## MILESTONE 63 — Hidden Realm Discovery and Access

Implement discovery through:
- Exploration.
- Rumors.
- Manuals.
- Treasure maps.
- NPC information.
- Sect missions.
- World events.
- Environmental anomalies.
- Ancient artifacts.

Include:
- Temporary openings.
- Restricted entrances.
- Realm requirements.
- Entry competition.
- Time limits.
- Special access methods.

## MILESTONE 64 — Hidden Realm Content and Encounters

Create unique templates for:
- Ancient Immortal Ruins.
- Forgotten Battlefields.
- Secret Beast Realms.
- Heavenly Gardens.
- Abandoned Sects.
- Ancient Tombs.
- Trial Realms.
- Spatial Fractures.
- Forbidden Domains.

Each template needs distinctive hazards, enemies, exploration, puzzles or trials, and rewards.

## MILESTONE 65 — Inheritance and Ancient Legacy System

Implement:
- Cultivation inheritances.
- Technique inheritances.
- Physique inheritances.
- Root-related inheritances.
- Bloodline inheritances.
- Artifact inheritances.
- Special crafting inheritances.
- Ancient knowledge.
- Unique passives.
- Legacy trials.

Create acquisition conditions, competition, inheritance compatibility, and rarity.

## MILESTONE 66 — Random Events, Rumors, and Opportunities

Implement dynamic world events.

Include:
- Treasure discoveries.
- Secret realm openings.
- Wandering masters.
- Beast invasions.
- Sect expeditions.
- Ancient ruins appearing.
- Rare resource discoveries.
- Cultivator competitions.
- Tribulations.
- NPC emergencies.
- Political crises.
- Hidden inheritance opportunities.

NPCs and sects must be able to discover and pursue these events independently.

---

# PHASE 9 — QUESTS AND NARRATIVE

## MILESTONE 67 — Quest and Story Architecture

Build the complete quest framework.

Implement:
- Main quests.
- Side quests.
- Sect quests.
- Companion quests.
- Dynamic quests.
- Exploration quests.
- Bounty quests.
- Hidden inheritance quests.
- Procedural objectives.
- Quest prerequisites.
- Branching decisions.
- Persistent consequences.
- Quest tracking.
- Quest failure and expiration.

## MILESTONE 68 — Twelve Sect Storylines and Inheritance Campaigns

Create a distinct major questline for each established sect.

Every storyline must include:
- Introduction.
- Recruitment opportunity.
- Initial tests.
- Advancement.
- Character relationships.
- Internal conflicts.
- Political developments.
- Major trials.
- Rival characters.
- Meaningful decisions.
- Unique inheritance.
- High-ranking sect position opportunity.

Do not make all twelve questlines structurally identical.

Allow different endings and consequences.

## MILESTONE 69 — Main Narrative and World History

Develop the overarching story.

Establish:
- The ancient history of the continent.
- The origins of cultivation.
- The history of spiritual roots.
- The origin of extraordinary physiques.
- Ancient sect conflicts.
- Lost civilizations.
- The nature of immortality.
- The relationship between hidden realms.
- Primordial forces.
- Major historical mysteries.

Create an overarching narrative that connects the world's major systems.

The player must be free to ignore the central narrative and pursue personal ambitions.

## MILESTONE 70 — Endgame and Transcendence

Create the complete endgame.

Include paths toward:
- Immortality.
- Supreme sect leadership.
- Continental dominance.
- Ancient knowledge.
- Forbidden cultivation.
- Ultimate Dao comprehension.
- Legendary craftsmanship.
- Independent transcendence.
- Creation of a new cultivation civilization.

Create high-level enemies, events, trials, and progression opportunities.

Do not end meaningful progression simply because the player reaches the twelfth realm.

---

# PHASE 10 — UI, ART, AUDIO, AND PRESENTATION

## MILESTONE 71 — Complete UI/UX and Accessibility

Create and polish all interfaces.

Include:
- Character sheet.
- Attribute screen.
- Cultivation screen.
- Realm progression.
- Root information.
- Physique information.
- Passive collection.
- Technique library.
- Skill loadout.
- Inventory.
- Equipment.
- Crafting.
- Alchemy.
- World map.
- Local map.
- Quest journal.
- NPC relationships.
- Party management.
- Sect management.
- Dialogue.
- Merchant interface.
- Settings.
- Save/load.
- Notifications.
- Debug tools.

Include:
- Readable typography.
- Scalable interface.
- Customizable controls.
- Audio settings.
- Display settings.
- Accessibility options.
- Clear status indicators.
- Tooltips.
- Confirmation dialogs.

## MILESTONE 72 — Final Art, Audio, Optimization, and Release

Complete the production presentation and prepare the release.

ART:
- Final player sprites.
- NPC sprites.
- Enemy sprites.
- Beast sprites.
- Boss sprites.
- Environment tiles.
- Buildings.
- Sect architecture.
- Weapon sprites.
- Equipment visuals.
- Technique effects.
- Weather effects.
- Lighting.
- UI assets.
- Animation polish.

AUDIO:
- Ambient audio.
- Biome audio.
- Town audio.
- Weather.
- Combat.
- Weapons.
- Techniques.
- Cultivation.
- Boss music.
- Sect music.
- Hidden realm music.
- UI sounds.

OPTIMIZATION:
- World streaming.
- NPC simulation.
- Combat performance.
- Sprite rendering.
- Memory usage.
- Save performance.
- Loading performance.
- Asset loading.
- Long-session stability.

FINAL QA:
- Full gameplay regression.
- All twelve realms.
- All 120 sublevels.
- All twelve root tiers.
- Physique acquisition.
- Passive acquisition.
- Technique learning.
- Cultivation methods.
- Breakthroughs.
- Tribulations.
- Combat.
- Procedural loot.
- Crafting.
- NPC routines.
- Relationships.
- Companions.
- All twelve sects.
- Player-founded sects.
- Sect warfare.
- Hidden realm generation.
- All sect storylines.
- Save/load.
- Long-term world simulation.
- Performance and stability.

RELEASE:
- Final production build.
- Versioning.
- Release notes.
- Installation testing.
- New-game testing.
- Save migration testing.
- Known-issues report.
- Final technical documentation.
- Final content inventory.
- Release candidate.
- Final acceptance report.

The project is complete only when the entire game is playable, tested, stable, content-complete, and ready for distribution.

---

# GLOBAL MILESTONE EXECUTION RULES

These rules apply to every milestone.

1. Execute only the milestone I explicitly authorize.
2. Audit existing functionality before implementation.
3. Never duplicate existing working systems.
4. Preserve all previously accepted functionality.
5. Never silently remove content or systems.
6. Never fabricate implementation or test results.
7. Never substitute mockups for working gameplay.
8. Use automated tests wherever practical.
9. Test actual gameplay, not merely data structures.
10. Test all affected systems for regressions.
11. Maintain documentation.
12. Maintain save compatibility.
13. Commit accepted milestones to Git.
14. Report all incomplete tasks honestly.
15. Identify blockers before proceeding.
16. Do not claim a milestone is complete until its acceptance criteria pass.

# REQUIRED MILESTONE REPORT

After every milestone, provide:

**1. Milestone identity**
- Number.
- Name.
- Status.

**2. Initial audit**
- Existing systems.
- Missing functionality.
- Relevant dependencies.

**3. Implementation**
- Features completed.
- Files created.
- Files modified.
- Files removed, with justification.

**4. Verification**
- Unit tests.
- Integration tests.
- Regression tests.
- Actual gameplay tests.
- Results.

**5. Acceptance criteria**
- Passed.
- Failed.
- Deferred.

**6. Remaining issues**
- Bugs.
- Technical debt.
- Performance problems.
- Missing content.

**7. Version control**
- Git commit.
- Current branch.
- Current HEAD.
- Working-tree status.

**8. Final milestone status**

Use only:
- NOT STARTED.
- IN PROGRESS.
- BLOCKED.
- PARTIALLY COMPLETE.
- COMPLETE.

A milestone cannot be marked COMPLETE while mandatory acceptance criteria remain unmet.

Do not begin the next milestone automatically.

Wait for my authorization.

# FINAL DEFINITION OF DONE

ETERNAL ASCENSION is finished when:

- The entire continent is seamlessly explorable.
- All core gameplay systems function.
- The complete cultivation progression works.
- All twelve realms and 120 sublevels are implemented.
- All twelve root tiers work.
- Attributes and passives are uncapped.
- Techniques and physiques work.
- Cultivation methods have distinct progression mechanics.
- Real-time action combat is fully playable.
- All three skill bars work.
- Procedural itemization works.
- Crafting and professions work.
- NPCs live independently.
- Companions and relationships work.
- Twelve established sects are fully implemented.
- Player-founded sects are fully functional.
- Sect politics and warfare work.
- Hidden realms generate playable content.
- Inheritances work.
- All twelve sect questlines are playable.
- The overarching narrative and endgame are implemented.
- The world persists through saving and loading.
- Performance is acceptable on the declared minimum hardware.
- No critical or release-blocking defects remain.
- A complete production build has been tested.

This roadmap is the authoritative development sequence for Eternal Ascension. Changes to its scope require explicit documentation and approval.

END OF MASTER ROADMAP.
