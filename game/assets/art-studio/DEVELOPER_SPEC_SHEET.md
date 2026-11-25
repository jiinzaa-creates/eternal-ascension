# ETERNAL ASCENSION — DEVELOPER SPEC SHEET (derived from the codebase)
Compiled 2026-11-25 by the Art Studio from a read of the repo at HEAD 5890060. Every item is labelled: CONFIRMED (stated in code/docs, with source), NOT IN CODE (searched, absent), or DERIVED (studio recommendation from code measurements — a proposal, not a fact).

## THE HEADLINE FINDING
The game currently has NO sprite or tile pipeline. All actors are code-drawn primitives (`_draw()` circles) driven by data palettes and a procedural pose animator. There are no TileMaps, TileSets, sprite sheets, or AnimatedSprite2D nodes anywhere in the project, and docs/DEVELOPMENT.md states this as deliberate architecture: "There are no sprite sheets: animation is a pose." The art studio's sprite/tileset production therefore needs a developer decision to adopt textured actors/tiles at all — the specs below give that decision concrete numbers.

## CONFIRMED FROM CODE
- Viewport: 1280×720; stretch mode canvas_items (game/project.godot).
- Renderer: gl_compatibility (desktop + mobile) — the only perf signal in code; no particle/poly budget is stated anywhere.
- World unit = 1 px at zoom 1.0. Camera zoom ladder: 0.75 / 1.0 / 1.25 / 1.5 / 2.0, default 1.0 (game/systems/camera_rig.gd).
- World structure: procedural chunks of 1024×1024 units (game/world/chunk_gen.gd SIZE, chunk_manager.gd CHUNK_SIZE). Ground layers: province chunks z_index −20, settlement apron −15.
- Sorting: the World node has y_sort_enabled — everything standing on the ground sorts by world Y; actor origin is the body centre, shadow drawn as an ellipse at (0, +6..+7) (docs/DEVELOPMENT.md "Rendering and camera"; entities/*.gd _draw).
- Body radii (world units): Player 14, NPC 11, Enemy/Dummy 13, Boss = enemy ×1.7 (≈22), Summon 10 (game/entities/*.gd RADIUS consts). Melee arc radius default 70.
- Animation: procedural poses, NOT frames (game/systems/animator.gd). Clips: idle/walk/run/sprint/attack/dodge/hurt/meditate/dead (priority death > hurt > dodge > attack > meditation > sprint > run > walk > idle). Motion is continuous sin() functions — walk rate 7.0, run 10.0, sprint 13.0 rad/s; bob amplitude 2 / 3 / 4 units (MAX_BOB 4.0). Attack poses are driven by combat frame data (startup/active/recovery) — an attack visual must never run on its own timer.
- Facing: continuous Vector2 (player.facing_direction()); aiming via stick/mouse. No discrete direction system exists.
- Actor appearance is palette-indexed data (game/systems/appearance.gd — append-only, indices are saved): ROBES #3f6fa8, #7d4a9c, #3d8a68, #a8563f, #4c5560, #b08b3d; HAIRS #1d1f22, #3a2a1e, #6b4a2c, #c9b48a, #8b1f1f, #dcdcdc; SKINS #e6c9a8, #d6ab84, #b9865e, #8d5a3b, #6a452e.
- Texture import (only sample: title_key_art.jpg.import): importer texture, compress/mode 0, mipmaps off, fix_alpha_border on. No texture filter override in project.godot (engine default applies). No atlas in use.
- Factions in data ALREADY have names, colours, mottos (game/data/factions.json): Azure Cloud Sect #7fd3e0 "Climb, and do not look down." · Verdant Market League #d8c070 "Every road ends at a stall." · Market Watch #c08f8f "The gate holds while we stand." · Hollow Moon Cult #a890d8 "What the moon takes, it keeps." — these are 4 of the game's houses/sects with art hooks ready-made.

## NOT IN CODE (searched: *.gd, *.tscn, *.tres, project.godot, docs)
Tile size · sprite frame size · direction count · animation FPS · atlas size · pivot convention for sprites · particle budget. None exist because no textured-actor system exists yet.

## ADOPTED — TEXTURED ART STANDARDS (Jawanza's decision, 2026-11-25: "Adopt textured art on those numbers")
The derived recommendations below are now the project's adopted production standards. Any change needs Jawanza's explicit ruling.
1. TILE SIZE: 32×32 px. 1024-unit chunks divide exactly (32 tiles/chunk per side); at default zoom a tile reads clearly, and 64 px source tiles drawn at 32 give headroom for the 2.0 zoom level. (Alternative: 64×64, 16/chunk — chunkier read, fewer tiles to author.)
2. SPRITE FRAMES: standard actors 64×64 (body diameter 22–28 units, ~3-head figure ≈ 56–64 units tall standing on the shadow point); bosses 128×128 (diameter ≈44, figure ≈110). Pivot at ground contact (feet), centred X, bottom Y — matching the code's shadow offset (0, +6) and Y-sort origin.
3. DIRECTIONS: 8. Facing is a continuous vector; 4-way would visibly snap against it, and the studio's asymmetric designs must not be mirrored (bible §17.2).
4. ANIMATION TIMING: do NOT replace the pose Animator — layer sprites UNDER its bob/squash/lean transforms (draw_set_transform already wraps actor drawing). If frame sequences are ever added, sync to the existing rates (walk 7.0 / run 10.0 / sprint 13.0 rad/s ≈ 1.1 / 1.6 / 2.1 steps per second) and to combat frame data for attacks, per DEVELOPMENT.md.
5. PALETTE BRIDGE: the Appearance robe palette (#3f6fa8 azure, #7d4a9c violet, #3d8a68 jade…) already harmonises with the bible's sect colours; sprite robe colourways should extend these hexes, not replace them (indices are saved — append only).
6. SECT KITS: build the first canon kits for the four data factions above — their colours/mottos are fixed canon. Azure Cloud ≈ the studio's Azure Sword archetype; Hollow Moon ≈ the Violet Shadow archetype. The remaining sects still need developer names/doctrines.

## WHAT THIS CHANGES FOR THE STUDIO
Bible §17.5's blocker list is retired: the answers were "not yet built," not "unknown." On 2026-11-25 Jawanza adopted textured art on the derived numbers above. Production is unblocked: first job = the Founder pilot set (bible §17.3), validated at the adopted 64×64 frame on 32×32 tiles (tests/founder_64px_scale_test.png). The concept registry stands as the design source for all frame work.
