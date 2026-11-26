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
const POI_KINDS := ["ruin", "mine", "deposit"]
const POI_WEIGHTS := [3, 3, 4]

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

	return {
		"coord": coord,
		"signature": signature_for(coord, seed_value),
		"features": features,
		"herbs": herbs,
		"pois": _pois_for(coord, seed_value),
		"biome": biome_id,
		"palette": _palette_for(def),
	}


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
