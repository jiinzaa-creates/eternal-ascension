class_name ChunkGen
extends RefCounted
## Chunk payload generation as pure data.
##
## Nothing here touches the scene tree, autoload state or a node, so a payload
## can be built on a worker thread. `ChunkManager` instantiates the nodes on the
## main thread when the payload arrives. Determinism is unchanged: a payload is
## a pure function of (world_seed, chunk coordinate).

const SIZE := 1024.0
const FEATURES := 36
const HERB_CHANCE := 0.6
const HERBS_MAX := 2
const HERB_NAMES := ["Spirit Herb", "Azure Grass", "Blood Lotus", "Moon Dew Fern"]


static func signature_for(coord: Vector2i, seed_value: int) -> int:
	return Rng.mix_values(seed_value, coord.x * 7919 + coord.y * 104729)


static func herb_id(coord: Vector2i, index: int) -> String:
	return "herb.chunk.%d.%d.%d" % [coord.x, coord.y, index]


## Everything a chunk needs, as plain data. Safe to call off the main thread.
static func payload_for(coord: Vector2i, seed_value: int) -> Dictionary:
	var r := Rng.stream_from(seed_value, "chunk", coord.x * 31 + coord.y, 0)
	var features: Array = []
	for i in FEATURES:
		var roll := r.randf()
		var kind := "tuft"
		if roll > 0.93:
			kind = "tree"
		elif roll > 0.84:
			kind = "rock"
		elif roll > 0.74:
			kind = "bush"
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
	var herbs: Array = []
	if hr.randf() < HERB_CHANCE:
		var count := hr.randi_range(1, HERBS_MAX)
		for i in count:
			herbs.append({
				"id": herb_id(coord, i),
				"label": String(HERB_NAMES[hr.randi_range(0, HERB_NAMES.size() - 1)]),
				"pos": Vector2(hr.randf_range(96.0, SIZE - 96.0), hr.randf_range(96.0, SIZE - 96.0)),
			})

	return {
		"coord": coord,
		"signature": signature_for(coord, seed_value),
		"features": features,
		"herbs": herbs,
	}
