class_name ChunkManager
extends Node2D
## Seamless province streaming.
##
## One continuous overworld: no loading screens, no disconnected maps. Chunks
## are generated deterministically from the world seed, streamed in a ring
## around the player, and freed when they leave it.
##
## Payload generation (`ChunkGen`) is pure data and can run on worker threads;
## nodes are only ever created here, on the main thread, when a payload arrives.
## A chunk boundary therefore costs a cross-thread handoff instead of stalling
## the frame that crossed it.
##
## Chunks own their resources (herbs) as well as their decorations. Since a
## chunk regenerates identically, the only state it needs is a `WorldDelta`:
## which resources were taken, and on which day, so they stay gone until they
## regrow. That is also what makes a save file able to store only deltas.

const CHUNK_SIZE := 1024.0
const VIEW_RADIUS := 2
const PROVINCE_CHUNKS := 12

var world_seed: int = 0
## Build payloads on worker threads. Off by default so unit tests stream
## synchronously; the running game turns it on.
var threaded := false
## Current game day, used to evaluate regrow windows.
var today: int = 1
## Biome definitions by id, snapshotted from the registry so worker threads can
## read them without touching autoloads.
var biome_defs: Dictionary = {}
var delta: WorldDelta = null
var chunks: Dictionary = {}
var streamed_chunks: int = 0
## How many spent resources have regrown on stream-in since the last clear, and a
## signal so the owner can tell the player the wilds moved without them.
signal regrown(count: int)
var regrown_total: int = 0
## Where streamed props are parented. Props must share a parent with the player
## to Y-sort against it, so they live in the world layer rather than the chunk.
var prop_parent: Node = null
## Where chunk resources (interactables) are parented, and how the owner hears
## about them so prompts and saves keep one list.
var resource_parent: Node = null
var on_resource_spawned: Callable
var on_resource_freed: Callable
var props: Array = []
var props_visible := true

var _last_center := Vector2i(-9999, -9999)
var _needed: Dictionary = {}
var _tasks: Dictionary = {}
var _results: Dictionary = {}
var _mutex := Mutex.new()


func _process(_delta: float) -> void:
	if threaded:
		_drain()


func configure(seed_value: int) -> void:
	world_seed = seed_value
	clear_all()
	_last_center = Vector2i(-9999, -9999)


func clear_all() -> void:
	_await_tasks()
	_mutex.lock()
	_results.clear()
	_mutex.unlock()
	_needed.clear()
	for coord in chunks.keys():
		_free_chunk(coord)
	chunks.clear()
	props.clear()
	streamed_chunks = 0
	regrown_total = 0


## Streams the ring of chunks around a world position. Cheap to call every
## frame: it returns immediately when the centre chunk has not changed and
## nothing is pending.
func stream_around(world_position: Vector2) -> void:
	var center := world_to_chunk(world_position)
	if center == _last_center and not chunks.is_empty() and _tasks.is_empty():
		return
	_last_center = center

	_needed.clear()
	for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var coord := center + Vector2i(dx, dy)
			if not in_province(coord):
				continue
			_needed[coord] = true
			if not chunks.has(coord) and not _tasks.has(coord):
				_request(coord)

	for coord in chunks.keys():
		if not _needed.has(coord):
			_free_chunk(coord)


## Rebuilds the province around a position, abandoning everything resident.
## Used after a load, when the delta store changes.
func resync(world_position: Vector2) -> void:
	clear_all()
	_last_center = Vector2i(-9999, -9999)
	stream_around(world_position)
	settle()


## Blocks until every requested payload has been installed. Used at boot and
## before tests assert on the streamed ring.
func settle() -> void:
	if not threaded:
		return
	_await_tasks()
	_drain()


func _request(coord: Vector2i) -> void:
	if not threaded:
		_install(ChunkGen.payload_for(coord, world_seed, biome_defs))
		return
	var task := WorkerThreadPool.add_task(_generate.bind(coord), false, "chunk %d,%d" % [coord.x, coord.y])
	_tasks[coord] = task


## Runs on a worker thread. Reads only `world_seed`, which is never mutated while
## tasks are in flight, and writes into a mutex-guarded result map.
func _generate(coord: Vector2i) -> void:
	var payload := ChunkGen.payload_for(coord, world_seed, biome_defs)
	_mutex.lock()
	_results[coord] = payload
	_mutex.unlock()


func _await_tasks() -> void:
	for coord in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[coord])
		_tasks.erase(coord)


func _drain() -> void:
	_await_tasks()
	_mutex.lock()
	var ready_payloads := _results.duplicate()
	_results.clear()
	_mutex.unlock()
	for coord in ready_payloads.keys():
		if _needed.has(coord) and not chunks.has(coord):
			_install(ready_payloads[coord])
	# Payloads for chunks the ring no longer needs are simply dropped.


func _install(payload: Dictionary) -> void:
	var coord: Vector2i = payload.get("coord", Vector2i.ZERO)
	if chunks.has(coord):
		return
	var chunk := ProvinceChunk.new()
	chunk.apply(payload)
	chunk.position = Vector2(coord) * CHUNK_SIZE
	add_child(chunk)
	chunks[coord] = chunk
	_spawn_props(chunk)
	_spawn_resources(chunk)
	streamed_chunks += 1


## Places a chunk's decorations in the Y-sorted layer. Without a prop parent
## (content tests, headless probes) no nodes are created.
func _spawn_props(chunk) -> void:
	if prop_parent == null:
		return
	var origin := Vector2(chunk.coord) * CHUNK_SIZE
	for feature in chunk.features:
		var prop := Prop.new()
		prop.setup(String(feature["kind"]), float(feature["scale"]))
		prop_parent.add_child(prop)
		prop.global_position = origin + (feature["pos"] as Vector2)
		prop.visible = props_visible
		chunk.props.append(prop)
		props.append(prop)


## Streams a chunk's herbs, skipping any the delta still considers spent.
func _spawn_resources(chunk) -> void:
	if resource_parent == null:
		return
	if delta != null:
		var recovered: int = delta.prune(chunk.coord, today)
		if recovered > 0:
			regrown_total += recovered
			regrown.emit(recovered)
	var origin := Vector2(chunk.coord) * CHUNK_SIZE
	for entry in chunk.herbs:
		var id := String(entry["id"])
		if delta != null and delta.is_spent(chunk.coord, id, today):
			continue
		var herb := Interactable.new()
		herb.setup_chunk_herb(id, String(entry["label"]), chunk.coord)
		resource_parent.add_child(herb)
		herb.global_position = origin + (entry["pos"] as Vector2)
		chunk.interactables.append(herb)
		if on_resource_spawned.is_valid():
			on_resource_spawned.call(herb)

	for entry in chunk.pois:
		var poi_id := String(entry["id"])
		if delta != null and delta.is_spent(chunk.coord, poi_id, today):
			continue
		var site := Interactable.new()
		site.setup_poi(poi_id, String(entry["kind"]), chunk.coord)
		resource_parent.add_child(site)
		site.global_position = origin + (entry["pos"] as Vector2)
		chunk.interactables.append(site)
		if on_resource_spawned.is_valid():
			on_resource_spawned.call(site)


func _free_chunk(coord: Vector2i) -> void:
	if not chunks.has(coord):
		return
	var chunk = chunks[coord]
	if is_instance_valid(chunk):
		for node in chunk.interactables:
			if is_instance_valid(node):
				if on_resource_freed.is_valid():
					on_resource_freed.call(node)
				node.queue_free()
		chunk.interactables.clear()
		for prop in chunk.props:
			props.erase(prop)
			if is_instance_valid(prop):
				prop.queue_free()
		chunk.queue_free()
	chunks.erase(coord)


func set_prop_parent(node: Node) -> void:
	prop_parent = node


func set_resource_parent(node: Node) -> void:
	resource_parent = node


func set_delta(value: WorldDelta) -> void:
	delta = value


func set_props_visible(value: bool) -> void:
	props_visible = value
	for prop in props:
		if is_instance_valid(prop):
			prop.visible = value
	for chunk in chunks.values():
		for node in chunk.interactables:
			if is_instance_valid(node):
				node.visible = value


func world_to_chunk(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / CHUNK_SIZE)), int(floor(world_position.y / CHUNK_SIZE)))


func in_province(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < PROVINCE_CHUNKS and coord.y < PROVINCE_CHUNKS


func chunk_count() -> int:
	return chunks.size()


## How many streamed resources are alive right now.
func resource_count() -> int:
	var total := 0
	for chunk in chunks.values():
		total += chunk.interactables.size()
	return total


## The whole province in world coordinates, for camera bounds.
static func world_bounds() -> Rect2:
	var span := CHUNK_SIZE * PROVINCE_CHUNKS
	return Rect2(Vector2.ZERO, Vector2(span, span))


func signature_at(coord: Vector2i) -> int:
	return ChunkGen.signature_for(coord, world_seed)


## A single streamed chunk. Terrain is drawn in code so the province can exist
## before an art pipeline does; the feature list is the data a tileset will
## eventually render instead.
class ProvinceChunk:
	extends Node2D

	const SIZE := 1024.0
	const FEATURES := 36
	const PALETTES: Array[Color] = [
		Color("#152218"), Color("#182619"), Color("#12201a"), Color("#1a241b"),
	]

	var coord: Vector2i = Vector2i.ZERO
	var signature: int = 0
	var biome: String = ""
	var palette: Array = []
	var features: Array = []
	var herbs: Array = []
	var pois: Array = []
	var props: Array = []
	var interactables: Array = []


	## Takes a generated payload; never generates on its own.
	func apply(payload: Dictionary) -> void:
		coord = payload.get("coord", Vector2i.ZERO)
		signature = int(payload.get("signature", 0))
		biome = String(payload.get("biome", ""))
		var incoming: Array = payload.get("palette", [])
		palette = incoming if not incoming.is_empty() else PALETTES.duplicate()
		features = payload.get("features", [])
		herbs = payload.get("herbs", [])
		pois = payload.get("pois", [])
		_paint_ground()


	## Paints the Art Studio ground for this chunk: 32x32 tiles from
	## the biome folder, hash-varied grass with a dirt sprinkle. Runs
	## once per payload; the TileMapLayer is reused on re-apply.
	func _paint_ground() -> void:
		if not TerrainTiles.tiles_enabled():
			return
		var layer := get_node_or_null("GroundTiles") as TileMapLayer
		if layer == null:
			layer = TileMapLayer.new()
			layer.name = "GroundTiles"
			layer.z_index = -20
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(layer)
		layer.tile_set = TerrainTiles.tileset_for(biome)
		for cx in 32:
			for cy in 32:
				var h := absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ (cx * 83492791) ^ (cy * 297121507) ^ signature)
				var src: int = TerrainTiles.GRASS[(h / 100) % TerrainTiles.GRASS.size()]
				if h % 100 < 7:
					src = TerrainTiles.DIRT[(h / 7) % TerrainTiles.DIRT.size()]
				layer.set_cell(Vector2i(cx, cy), src, Vector2i.ZERO)


	func _draw() -> void:
		if TerrainTiles.tiles_enabled():
			return
		var colors: Array = palette if not palette.is_empty() else PALETTES
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), colors[abs(coord.x + coord.y) % colors.size()])
		# A faint boundary makes streaming invisible glitches obvious during play.
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(1, 1, 1, 0.015), false, 1.0)

		# Decorations are separate Y-sorted nodes (see Prop): a whole 1024x1024
		# chunk must not sort as one object, or the player would always draw
		# over the trees in front of him and under the ones behind.
