class_name TerrainTiles
extends RefCounted
## Builds one TileSet per biome from the Art Studio terrain tiles for the
## chunk ground painter. Each tile PNG is its own atlas source with a
## single 32x32 tile, so source ids are stable indices into NAMES.
## `art_studio/use_tiles` (default true) keeps the code-drawn chunk
## ground as the fallback.

const ROOT := "res://assets/art-studio/assets/environments/terrain/"
const NAMES := ["grass_v1", "grass_v2", "grass_v3", "grass_v4",
	"dirt_v1", "dirt_v2", "flagstone", "water", "cliff_face",
	"waterfall", "waterfall_foam",
	"grass_dirt_n", "grass_dirt_ne", "grass_dirt_e", "grass_dirt_se",
	"grass_dirt_s", "grass_dirt_sw", "grass_dirt_w", "grass_dirt_nw",
	"grass_water_n", "grass_water_ne", "grass_water_e", "grass_water_se",
	"grass_water_s", "grass_water_sw", "grass_water_w", "grass_water_nw"]
const GRASS := [0, 1, 2, 3]
const DIRT := [4, 5]
const WATER := 7
## Tiles a body cannot walk through: open water and falling water.
const SOLID := ["water", "waterfall"]

static var _cache := {}


static func tiles_enabled() -> bool:
	return bool(ProjectSettings.get_setting("art_studio/use_tiles", true))


static func tileset_for(biome_id: String) -> TileSet:
	if _cache.has(biome_id):
		return _cache[biome_id]
	var folder := ROOT
	if biome_id != "" and biome_id != "biome.verdant" and biome_id != Biome.OCEAN:
		folder += "biome_" + biome_id.trim_prefix("biome.") + "/"
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	for i in NAMES.size():
		var path: String = folder + "tile_" + NAMES[i] + ".png"
		if not ResourceLoader.exists(path):
			continue
		var src := TileSetAtlasSource.new()
		src.texture = load(path) as Texture2D
		src.texture_region_size = Vector2i(32, 32)
		src.create_tile(Vector2i.ZERO)
		if SOLID.has(NAMES[i]):
			var data := src.get_tile_data(Vector2i.ZERO, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
		ts.add_source(src, i)
	_cache[biome_id] = ts
	return ts
