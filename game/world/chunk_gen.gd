class_name ChunkGen
extends RefCounted
## Chunk payload generation as pure data.
##
## Nothing here touches the scene tree, autoload state or a node, so a payload
## can be built on a worker thread. `ChunkManager` instantiates the nodes on the
## main thread when the payload arrives. Determinism is unchanged: a payload is
## a pure function of (world_seed, chunk coordinate) plus the biome definition
## snapshot the owner passes in.
##
## Biome identity comes from `Biome` (seed + coordinate). Its palette, prop
## weights and resource table come from `data/biomes.json` through that snapshot,
## which is why a worker never has to read the content registry.

const SIZE := 1024.0
const FEATURES := 36
const HERB_CHANCE := 0.6
const HERBS_MAX := 2
const FEATURE_KINDS := ["tuft", "bush", "rock", "tree"]
const DEFAULT_FEATURES := {"tuft": 74, "bush": 10, "rock": 9, "tree": 7}
const DEFAULT_PALETTE: Array[Color] = [
	Color("#152218"), Color("#182619"), Color("#12201a"), Color("#1a241b"),
]
## Overworld sites: one possible per chunk, weighted by kind.
const POI_CHANCE := 0.5
const POI_KINDS := ["ruin", "mine", "deposit", "cave", "battlefield", "cache"]
const POI_WEIGHTS := [3, 3, 4, 2, 2, 2]
const TILE_PX := 32.0

const DEFAULT_RESOURCES := [
	{"name": "Spirit Herb", "weight": 6},
	{"name": "Azure Grass", "weight": 3},
	{"name": "Moon Dew Fern", "weight": 2},
]


static func signature_for(coord: Vector2i, seed_value: int) -> int:
	return Rng.mix_values(seed_value, coord.x * 7919 + coord.y * 104729)


static func herb_id(coord: Vector2i, index: int) -> String:
	return "herb.chunk.%d.%d.%d" % [coord.x, coord.y, index]


## Everything a chunk needs, as plain data. Safe to call off the main thread.
const OCEAN_PALETTE: Array[Color] = [
	Color("#0d2733"), Color("#0e2a38"), Color("#0c2430"), Color("#10303e"),
]


static func payload_for(coord: Vector2i, seed_value: int, biome_defs: Dictionary = {}) -> Dictionary:
	var biome_id := Biome.for_chunk(coord, seed_value)
	if biome_id == Biome.OCEAN:
		# Open sea: water to every horizon, nothing to gather or fight.
		return {
			"coord": coord,
			"signature": signature_for(coord, seed_value),
			"features": [],
			"herbs": [],
			"pois": [],
			"biome": biome_id,
			"palette": OCEAN_PALETTE.duplicate(),
		}
	var def: Dictionary = biome_defs.get(biome_id, {})

	var r := Rng.stream_from(seed_value, "chunk", coord.x * 31 + coord.y, 0)
	var feature_table: Dictionary = def.get("features", DEFAULT_FEATURES)
	var weights: Array = []
	for kind in FEATURE_KINDS:
		weights.append(maxi(0, int(feature_table.get(kind, 0))))
	if _total(weights) <= 0:
		for kind in FEATURE_KINDS:
			weights.append(maxi(0, int(DEFAULT_FEATURES.get(kind, 0))))

	var features: Array = []
	for i in FEATURES:
		var kind := String(FEATURE_KINDS[maxi(0, Rng.pick_weighted(weights, r))])
		features.append({
			"kind": kind,
			"pos": Vector2(r.randf_range(24.0, SIZE - 24.0), r.randf_range(24.0, SIZE - 24.0)),
			"scale": r.randf_range(0.7, 1.5),
		})
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["pos"].y) < float(b["pos"].y))

	# Resources are a separate stream so adding them never reshuffles the
	# decorations of an existing seed.
	var hr := Rng.stream_from(seed_value, "chunk_herb", coord.x * 31 + coord.y, 0)
	var resources: Array = def.get("resources", [])
	if resources.is_empty():
		resources = DEFAULT_RESOURCES
	var herbs: Array = []
	if hr.randf() < HERB_CHANCE:
		var count := hr.randi_range(1, HERBS_MAX)
		for i in count:
			var entry := Biome.pick_resource({"resources": resources}, hr)
			herbs.append({
				"id": herb_id(coord, i),
				"label": String(entry.get("name", "Spirit Herb")),
				"pos": Vector2(hr.randf_range(96.0, SIZE - 96.0), hr.randf_range(96.0, SIZE - 96.0)),
			})

	# Rivers and lakes are world-space features: a herb or site that
	# lands in one would be unreachable, so they are shifted to the
	# nearest dry ground (deterministic spiral) before the payload seals.
	var water := water_mask(coord, seed_value)
	for herb in herbs:
		herb["pos"] = _dry_pos(water, herb["pos"] as Vector2)
	var pois := _pois_for(coord, seed_value)
	for poi in pois:
		poi["pos"] = _dry_pos(water, poi["pos"] as Vector2)

	return {
		"coord": coord,
		"signature": signature_for(coord, seed_value),
		"features": features,
		"herbs": herbs,
		"pois": pois,
		"biome": biome_id,
		"palette": _palette_for(def),
		"water": water,
	}


## The chunk's river/lake water as 1024 bytes, one per ground tile.
static func water_mask(coord: Vector2i, seed_value: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(1024)
	for ty in 32:
		for tx in 32:
			var tile := Vector2i(coord.x * 32 + tx, coord.y * 32 + ty)
			if ground_water_at_tile(tile, seed_value):
				mask[ty * 32 + tx] = 1
	return mask


## Is this world tile (32px) water, counting rivers, lakes and the sea?
## Pure in (tile, seed): shores and crossings agree across chunk borders
## because every chunk asks the same question of the same world.
static func ground_water_at_tile(tile: Vector2i, seed_value: int) -> bool:
	var chunk := Vector2i(
		int(floor(float(tile.x) / 32.0)), int(floor(float(tile.y) / 32.0)))
	if Biome.for_chunk(chunk, seed_value) == Biome.OCEAN:
		return true
	return water_at_tile(tile, seed_value)


## Rivers and lakes only: one winding river and up to two lakes per
## region, kept out of the market's home chunks and off the sea.
static func water_at_tile(tile: Vector2i, seed_value: int) -> bool:
	var chunk := Vector2i(
		int(floor(float(tile.x) / 32.0)), int(floor(float(tile.y) / 32.0)))
	if absi(chunk.x - Biome.HOME_CHUNK.x) <= 1 and absi(chunk.y - Biome.HOME_CHUNK.y) <= 1:
		return false
	var continent := Biome.continent_for(seed_value)
	var cell := Continent.cell_for_chunk(chunk)
	if not Continent.is_land(continent, cell):
		return false
	var region_index := Continent.index_of(cell)
	var px := (float(tile.x) + 0.5) * TILE_PX
	var py := (float(tile.y) + 0.5) * TILE_PX
	var origin := Vector2(Continent.chunk_origin(cell)) * SIZE

	var rr := Rng.stream_from(seed_value, "river", region_index)
	var base_y := origin.y + rr.randf_range(0.3, 0.7) * 12.0 * SIZE
	var phase := rr.randf_range(0.0, TAU)
	var amp := rr.randf_range(180.0, 340.0)
	var width := rr.randf_range(24.0, 40.0)
	if rr.randf() < 0.85:
		var centre_y := base_y + sin(px * 0.00042 + phase) * amp
		var half := width * (0.8 + 0.3 * sin(px * 0.0011 + phase * 2.0))
		if absf(py - centre_y) < half:
			# Fords: dry crossings at deterministic intervals, so a
			# river divides a region without sealing it.
			if fmod(px + float(region_index) * 977.0, 2500.0) > 110.0:
				return true

	var lr := Rng.stream_from(seed_value, "lake", region_index)
	var lakes := lr.randi_range(0, 2)
	for i in lakes:
		var c := Vector2(
			origin.x + lr.randf_range(0.15, 0.85) * 12.0 * SIZE,
			origin.y + lr.randf_range(0.15, 0.85) * 12.0 * SIZE)
		var rad := Vector2(lr.randf_range(130.0, 300.0), lr.randf_range(110.0, 240.0))
		var d := Vector2((px - c.x) / rad.x, (py - c.y) / rad.y)
		if d.length() < 1.0:
			return true
	return false


## Moves a point out of this chunk's water to the nearest dry tile
## centre, spiralling outward; gives up after 8 tiles and keeps the
## original point (a point that deep in a lake is a design smell, not
## a crash).
static func _dry_pos(water: PackedByteArray, pos: Vector2) -> Vector2:
	var tile := Vector2i(int(pos.x / TILE_PX), int(pos.y / TILE_PX))
	if tile.x < 0 or tile.y < 0 or tile.x >= 32 or tile.y >= 32:
		return pos
	if water[tile.y * 32 + tile.x] == 0:
		return pos
	for radius in range(1, 9):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var t := tile + Vector2i(dx, dy)
				if t.x < 0 or t.y < 0 or t.x >= 32 or t.y >= 32:
					continue
				if water[t.y * 32 + t.x] == 0:
					return Vector2(t) * TILE_PX + Vector2(16, 16)
	return pos


## At most one overworld site per chunk, from its own stream so adding sites
## cannot reshuffle decorations or herbs of an existing seed.
static func _pois_for(coord: Vector2i, seed_value: int) -> Array:
	var pr := Rng.stream_from(seed_value, "chunk_poi", coord.x * 31 + coord.y, 0)
	var pois: Array = []
	if pr.randf() >= POI_CHANCE:
		return pois
	var index := Rng.pick_weighted(POI_WEIGHTS, pr)
	var kind := String(POI_KINDS[maxi(0, index)])
	pois.append({
		"id": "poi.%s.%d.%d" % [kind, coord.x, coord.y],
		"kind": kind,
		"pos": Vector2(pr.randf_range(120.0, SIZE - 120.0), pr.randf_range(120.0, SIZE - 120.0)),
	})
	return pois


static func _palette_for(def: Dictionary) -> Array:
	var raw: Array = def.get("palette", [])
	if raw.is_empty():
		return DEFAULT_PALETTE.duplicate()
	var out: Array = []
	for entry in raw:
		out.append(Color(String(entry)))
	if out.is_empty():
		return DEFAULT_PALETTE.duplicate()
	return out


static func _total(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total
