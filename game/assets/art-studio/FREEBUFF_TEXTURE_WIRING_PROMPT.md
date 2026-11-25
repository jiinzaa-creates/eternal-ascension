# Task: Wire texture rendering into Eternal Ascension (Godot 4.4.1)

## Context
This Godot 4.4.1 project currently renders every actor as code-drawn `_draw()`
primitives with a procedural pose Animator — see `docs/DEVELOPMENT.md` ("There
are no sprite sheets: animation is a pose"). A complete production art set now
exists in the repo under `game/assets/art-studio/assets/` (800+ PNGs). Your job
is ONLY the rendering wiring: make the game display these textures, driven by
the existing game state. Do not change gameplay logic, systems, or data.

## Asset facts (verified from the art studio — rely on these, don't guess)
- Actor frames: 64×64 px, transparent PNG. Boss frames: 128×128 px.
- Pivot: ground contact — feet centred horizontally, at the BOTTOM of the
  frame. Set sprite offset/anchor accordingly (centred X, bottom Y).
- 8 directions, named: s, se, e, ne, n, nw, w, sw. Game facing is a continuous
  Vector2 — quantise to the nearest 45° direction.
- Tiles: 32×32 px. Viewport 1280×720, stretch canvas_items. Camera zoom
  ladder 0.75–2.0 (default 1.0) already exists in game/systems/camera_rig.gd.
- World node already has y_sort_enabled; ground layers use z_index −20/−15.
- Shadows are code-drawn ellipses today (at feet +6..+7, ~0.9× body radius,
  black 28–30%) — KEEP those exactly as they are.
- Body radii: player 14, NPC 11, enemy 13, boss ≈22, summon 10.

## Key asset locations (all under game/assets/art-studio/assets/)
- Founder (player): characters/player/ — player_founder_idle_{dir}.png,
  player_founder_walk_{dir}_{left,right}.png, player_founder_attack_{dir}.png,
  plus walk/attack sheets. Robe colourways pre-baked in
  characters/player/colourways/robe_{0..5}/ (robe_2 jade = master set);
  hair/skin variants in colourways/hair_{1..5}/ and skin_{1..4}/.
- NPCs: characters/npcs/ — npc_sword_cultivator_idle_/walk_,
  npc_elder_idle_, npc_merchant_idle_, npc_farmer_idle_ (same naming pattern).
- Companion: characters/companions/ — companion_spirit_wolf_idle_{dir}.png.
- Creatures/bosses: enemies/beasts/, enemies/demons/, enemies/bosses/
  (boss frames are 128×128). Human enemies: enemies/humans/ plus biome tint
  variants in enemies/humans/variants/{slug}/.
- Terrain: environments/terrain/ — tileset_v1_atlas.png, individual
  tile_{grass_v1..v4, dirt_v1..v2, flagstone, water, water_v2..v4, cliff_face,
  waterfall, waterfall_v2, waterfall_foam}.png, 16 transition tiles
  tile_grass_{dirt,water}_{dir}.png, and per-biome folders biome_{marsh,
  ashen, frost}/ with the same tile names graded per biome.
- Appearance palettes live in game/systems/appearance.gd (ROBES/HAIRS/SKINS
  hex arrays) — colourway folder indices match those array indices.

## What to build
1. Texture import: set project import defaults for these PNGs so sprites stay
   crisp at all camera zooms (nearest-neighbour filtering; the one existing
   texture import — title_key_art.jpg — uses compress mode 0, mipmaps off,
   fix_alpha_border on; follow that pattern where sensible).
2. A reusable actor sprite component (e.g. Sprite2D + a small controller
   script) that: takes a set name + direction + state (idle/walk/attack),
   picks the right frame file, and flips NOTHING (asymmetric designs are
   never mirrored — every direction has its own frame).
3. Animation timing from the EXISTING pose Animator: the Animator already
   computes walk phase (rates: walk 7.0 / run 10.0 / sprint 13.0 rad/s, bob
   2/3/4 units). The sprite node sits UNDER the Animator's transform — the
   Animator still drives position/bob/tilt; the sprite only swaps frames:
   idle frame as the passing pose, stride-left / stride-right alternating
   with the walk phase. Attack frames are single mid-swing poses driven by
   the existing combat frame data.
4. Wire it into the player first, prove it, then NPCs, companion, enemies,
   bosses (128px frames, same component, scale from frame size).
5. Appearance: player/NPC robe colour = colourways/robe_{index} folder
   matching appearance.gd ROBES index. (Hair/skin variant frames exist;
   wire them if the appearance system exposes those indices, else leave a
   clean hook.)
6. Terrain: build a TileSet from the terrain tiles (32×32) and paint the
   ground with TileMap layers under the existing z_index scheme; biome
   folders swap the tile set per biome. Keep the code-drawn ground as a
   fallback behind a toggle until tiles are proven.
7. Fallback: keep the primitive `_draw()` renderer intact behind a project
   setting / export toggle so the game still runs if a texture is missing.
   Missing frame for a direction/state → fall back to that actor's idle S
   frame, then to primitives; log a warning once.

## Verification (required before you report done)
- Run the project headless with no errors, then run an actual visible pass:
  open the web export (or editor play) in a browser and screenshot a scene
  showing: the Founder standing + walking in at least 4 directions, the
  Spirit Wolf beside him, one creature, and tiled ground with a water edge.
- Confirm sprites sit on their shadows, feet on the ground contact point,
  correct direction frames (walking north shows the back view), no mirroring.
- Report: files changed, how the toggle works, and the screenshots. If any
  asset named above is missing, say exactly which — do not substitute or
  generate replacements.
