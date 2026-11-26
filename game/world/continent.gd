class_name Continent
extends RefCounted
## The continent above the playable province.
##
## One province is all that is walkable so far; the continent is the geography
## above it. It is generated deterministically from the world seed, so it exists
## in every save without being stored and cannot drift between sessions.
##
## The cell at `CAPITAL` is the province the player walks in. Connectivity is
## enforced rather than hoped for: land that cannot be reached from the capital
## is drowned, so no named region is ever unreachable.

const COLS := 5
const ROWS := 4
const CAPITAL := Vector2i(2, 1)
## Chunks along one side of a region. The capital region occupies chunk
## window (0..11, 0..11), so every coordinate a save already holds keeps
## its meaning; the continent extends west and north into negatives.
const REGION_CHUNKS := 12
const CHUNK_PX := 1024.0
const GROWTH_CHANCE := 0.66
## A continent smaller than this would not be worth mapping.
const MIN_REGIONS := 7
const TERRAINS := ["plains", "forest", "mountains", "marsh", "desert", "coast"]
const NAME_A := ["Azure", "Verdant", "Hollow", "Crimson", "Jade", "Silver", "Dusk", "Ember", "Frost", "Golden"]
const NAME_B := ["Reach", "March", "Vale", "Basin", "Highlands", "Fringe", "Expanse", "Hollows", "Steps", "Shore"]
const CONTINENT_PARTS := ["Reaches", "Expanse", "Dominion", "Continent"]


static func index_of(coord: Vector2i) -> int:
	return coord.y * COLS + coord.x


static func coord_of(index: int) -> Vector2i:
	return Vector2i(index % COLS, index / COLS)


## The region cell a chunk belongs to. Pure arithmetic: the capital
## cell sits on chunk window (0..11, 0..11) by construction.
static func cell_for_chunk(coord: Vector2i) -> Vector2i:
	return CAPITAL + Vector2i(_floordiv(coord.x), _floordiv(coord.y))


static func _floordiv(value: int) -> int:
	return int(floor(float(value) / float(REGION_CHUNKS)))


## The north-west chunk of a region cell.
static func chunk_origin(cell: Vector2i) -> Vector2i:
	return (cell - CAPITAL) * REGION_CHUNKS


## The region a world position stands in, or -1 beyond the lattice.
static func region_for_world_position(world_position: Vector2) -> int:
	var chunk := Vector2i(
		int(floor(world_position.x / CHUNK_PX)),
		int(floor(world_position.y / CHUNK_PX)))
	var cell := cell_for_chunk(chunk)
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return -1
	return index_of(cell)


static func is_land(data: Dictionary, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return false
	var cells: Array = data.get("cells", [])
	if cells.size() != COLS * ROWS:
		return false
	return bool(cells[index_of(cell)].get("land", false))


static func terrain_for_cell(data: Dictionary, cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return ""
	var cells: Array = data.get("cells", [])
	if cells.size() != COLS * ROWS:
		return ""
	return String(cells[index_of(cell)].get("terrain", ""))


## Everything the map and later travel need. Pure: same seed, same continent.
static func generate(seed_value: int) -> Dictionary:
	var r := Rng.stream_from(seed_value, "continent", 0)
	var cells: Array = []
	for y in ROWS:
		for x in COLS:
			cells.append({
				"coord": Vector2i(x, y),
				"land": false,
				"terrain": String(TERRAINS[r.randi_range(0, TERRAINS.size() - 1)]),
				"neighbours": [],
			})

	# Land grows outward from the capital, so the continent is connected by
	# construction instead of by repairing disconnected fragments afterwards.
	var capital_index := index_of(CAPITAL)
	var land := _grow(r, cells, capital_index)
	for i in cells.size():
		cells[i]["land"] = land.has(i)

	for i in cells.size():
		cells[i]["neighbours"] = _neighbours(i, cells) if bool(cells[i]["land"]) else []

	var tiers := _distances(capital_index, cells)
	var used_names: Dictionary = {}
	var regions: Array = []
	for i in cells.size():
		if not bool(cells[i]["land"]):
			continue
		regions.append({
			"index": i,
			"coord": cells[i]["coord"],
			"name": _unique_name(r, used_names),
			"terrain": String(cells[i]["terrain"]),
			"tier": int(tiers.get(i, 1)),
			"capital": i == capital_index,
			"neighbours": (cells[i]["neighbours"] as Array).duplicate(),
		})

	return {
		"seed": seed_value,
		"cols": COLS,
		"rows": ROWS,
		"name": _continent_name(seed_value),
		"cells": cells,
		"regions": regions,
		"capital": capital_index,
	}


static func region_by_index(data: Dictionary, index: int) -> Dictionary:
	for region in data.get("regions", []):
		if int(region["index"]) == index:
			return region
	return {}


## One region's rectangle inside a drawing area. Pure so map layout is testable
## without a Control.
static func map_rect(coord: Vector2i, area: Rect2) -> Rect2:
	var gap := 6.0
	var cell_size := Vector2(
		(area.size.x - gap * float(COLS - 1)) / float(COLS),
		(area.size.y - gap * float(ROWS - 1)) / float(ROWS)
	)
	return Rect2(area.position + Vector2(coord.x * (cell_size.x + gap), coord.y * (cell_size.y + gap)), cell_size)


static func _all_neighbours(index: int, cells: Array) -> Array:
	var coord: Vector2i = cells[index]["coord"]
	var out: Array = []
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in directions:
		var other := coord + dir
		if other.x < 0 or other.y < 0 or other.x >= COLS or other.y >= ROWS:
			continue
		out.append(index_of(other))
	return out


static func _neighbours(index: int, cells: Array) -> Array:
	var out: Array = []
	for neighbour in _all_neighbours(index, cells):
		if bool(cells[neighbour]["land"]):
			out.append(neighbour)
	return out


## Grows a connected landmass from the capital. A minimum size is forced so a
## run of unlucky rolls cannot produce a two-cell continent.
static func _grow(r: RandomNumberGenerator, cells: Array, capital_index: int) -> Dictionary:
	var land := {capital_index: true}
	var frontier: Array = [capital_index]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for next in _all_neighbours(current, cells):
			if land.has(next):
				continue
			if r.randf() < GROWTH_CHANCE:
				land[next] = true
				frontier.append(next)

	var guard := 0
	while land.size() < MIN_REGIONS and guard < 200:
		guard += 1
		var base: int = int(land.keys()[r.randi_range(0, land.size() - 1)])
		for next in _all_neighbours(base, cells):
			if not land.has(next):
				land[next] = true
				break
	return land


## Distance from the capital in cells, plus one: capital is tier 1.
static func _distances(start: int, cells: Array) -> Dictionary:
	var tiers := {start: 1}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next in _neighbours(current, cells):
			if not tiers.has(next):
				tiers[next] = int(tiers[current]) + 1
				queue.append(next)
	return tiers


static func _unique_name(r: RandomNumberGenerator, used: Dictionary) -> String:
	for attempt in 60:
		var candidate := "%s %s" % [
			String(NAME_A[r.randi_range(0, NAME_A.size() - 1)]),
			String(NAME_B[r.randi_range(0, NAME_B.size() - 1)]),
		]
		if not used.has(candidate):
			used[candidate] = true
			return candidate
	return "Nameless Reach %d" % used.size()


static func _continent_name(seed_value: int) -> String:
	var r := Rng.stream_from(seed_value, "continent_name", 0)
	return "The %s %s" % [
		String(NAME_A[r.randi_range(0, NAME_A.size() - 1)]),
		String(CONTINENT_PARTS[r.randi_range(0, CONTINENT_PARTS.size() - 1)]),
	]
