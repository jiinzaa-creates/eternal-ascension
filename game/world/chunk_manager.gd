class_name ChunkManager
extends Node2D
## Seamless province streaming.
##
## One continuous overworld: no loading screens, no disconnected maps. Chunks
## are generated deterministically from the world seed, streamed in a ring
## around the player, and freed when they leave it. Because generation is a pure
## function of (seed, chunk coordinate), a chunk that unloads and reloads is
## identical — which is what makes a save file able to store only deltas.

const CHUNK_SIZE := 1024.0
const VIEW_RADIUS := 2
const PROVINCE_CHUNKS := 12

var world_seed: int = 0
var chunks: Dictionary = {}
var streamed_chunks: int = 0
var _last_center := Vector2i(-9999, -9999)


func configure(seed_value: int) -> void:
	world_seed = seed_value
	clear_all()
	_last_center = Vector2i(-9999, -9999)


func clear_all() -> void:
	for coord in chunks.keys():
		var node: Node = chunks[coord]
		if is_instance_valid(node):
			node.queue_free()
	chunks.clear()
	streamed_chunks = 0


## Streams the ring of chunks around a world position. Cheap to call every
## frame: it returns immediately when the centre chunk has not changed.
func stream_around(world_position: Vector2) -> void:
	var center := world_to_chunk(world_position)
	if center == _last_center and not chunks.is_empty():
		return
	_last_center = center

	var needed: Dictionary = {}
	for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var coord := center + Vector2i(dx, dy)
			if not in_province(coord):
				continue
			needed[coord] = true
			if not chunks.has(coord):
				_load_chunk(coord)

	for coord in chunks.keys():
		if not needed.has(coord):
			var node: Node = chunks[coord]
			if is_instance_valid(node):
				node.queue_free()
			chunks.erase(coord)


func _load_chunk(coord: Vector2i) -> void:
	var chunk := ProvinceChunk.new()
	chunk.setup(coord, world_seed)
	chunk.position = Vector2(coord) * CHUNK_SIZE
	add_child(chunk)
	chunks[coord] = chunk
	streamed_chunks += 1


func world_to_chunk(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / CHUNK_SIZE)), int(floor(world_position.y / CHUNK_SIZE)))


func in_province(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < PROVINCE_CHUNKS and coord.y < PROVINCE_CHUNKS


func chunk_count() -> int:
	return chunks.size()


func signature_at(coord: Vector2i) -> int:
	if chunks.has(coord):
		return int(chunks[coord].signature)
	var probe := ProvinceChunk.new()
	probe.setup(coord, world_seed)
	var value: int = probe.signature
	probe.free()
	return value


## A single streamed chunk. Terrain is drawn in code so the province can exist
## before an art pipeline does; the feature list is the data a tileset will
## eventually render instead.
class ProvinceChunk:
	extends Node2D

	const SIZE := 1024.0
	const PALETTES: Array[Color] = [
		Color("#152218"), Color("#182619"), Color("#12201a"), Color("#1a241b"),
	]

	var coord: Vector2i = Vector2i.ZERO
	var signature: int = 0
	var features: Array = []


	func setup(chunk_coord: Vector2i, seed_value: int) -> void:
		coord = chunk_coord
		signature = Rng.mix(seed_value, chunk_coord.x * 7919 + chunk_coord.y * 104729)
		var r := Rng.stream("chunk", chunk_coord.x * 31 + chunk_coord.y, 0)
		for i in 36:
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


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), PALETTES[abs(coord.x + coord.y) % PALETTES.size()])
		# A faint boundary makes streaming invisible glitches obvious during play.
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(1, 1, 1, 0.015), false, 1.0)

		for feature in features:
			var pos: Vector2 = feature["pos"]
			var scale: float = float(feature["scale"])
			match String(feature["kind"]):
				"tree":
					draw_line(pos, pos + Vector2(0, 16.0 * scale), Color("#2a2118"), 4.0)
					draw_circle(pos + Vector2(0, -6.0 * scale), 16.0 * scale, Color("#1d3a26"))
					draw_circle(pos + Vector2(-5.0, -10.0 * scale), 9.0 * scale, Color("#25492f"))
				"rock":
					draw_colored_polygon(PackedVector2Array([
						pos + Vector2(-10, 6) * scale, pos + Vector2(-4, -8) * scale,
						pos + Vector2(9, -5) * scale, pos + Vector2(11, 5) * scale,
					]), Color("#2c3335"))
				"bush":
					draw_circle(pos, 8.0 * scale, Color("#20361f"))
				_:
					draw_line(pos, pos + Vector2(-3, -7) * scale, Color("#2b4a2b"), 1.5)
					draw_line(pos, pos + Vector2(2, -8) * scale, Color("#2b4a2b"), 1.5)
