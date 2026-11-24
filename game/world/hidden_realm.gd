class_name HiddenRealm
extends Node2D
## Tomb of the Hollow Moon — the first hidden realm.
##
## A data-driven room grid filled from a seed: room roles, a spanning-tree of
## corridors plus a few loops, hazards, enemies, chests and an altar. The layout
## comes from `hidden_realm_templates.json`; connectivity is guaranteed by
## construction, and the unit suite flood-fills every template to prove that.

const ROOM_W := 420.0
const ROOM_H := 340.0
const GAP := 110.0
## The historic tomb size, kept as the fallback if content is missing.
const COLS := 5
const ROWS := 4
const HAZARD_DPS := 7.0
const DEFAULT_PALETTE := {
	"floor": "#241f30", "entry": "#1c2a2a", "inheritance": "#2b2440",
	"treasure": "#2a2620", "border": "#3b3350", "hazard": "#5a2030",
	"hazard_edge": "#c06070", "accent": "#8f7fd0",
}

var realm_seed: int = 0
var realm_name: String = "Tomb of the Hollow Moon"
var template_id: String = "template.tomb"
var family_id: String = ""
var family: Dictionary = {}
var profile: Dictionary = {}
var palette: Dictionary = DEFAULT_PALETTE.duplicate()
var instance_id: String = ""
var altar_enabled := true
var loot_table := "chest.sealed"
var hazard_dps := HAZARD_DPS
var cols: int = COLS
var rows: int = ROWS
var treasure_count: int = 2
var loop_count: int = 4
var hazard_chance: float = 1.0
var enemy_ilvl: int = 2
var enemies_per_room: int = 2
var enemy_roster: Array = []
var warden_id: String = "boss.tomb_warden"
var cells: Array[Vector2i] = []
var links: Array = []
var kinds: Dictionary = {}
var hazards: Array = []
var interactables: Array = []
var spawn_points: Array = []
var entry_cell := Vector2i(0, 3)
var altar_cell := Vector2i(4, 0)
var cleared := false
## Whether this visit puts the tomb's warden on guard. The scene root clears it
## when the warden is already dead in this save.
var spawn_warden := true
## The warden body, for the altar gate and for the phase adds.
var warden: Dummy = null
## Where entities are parented. The main scene points this at the Y-sorted world
## layer so realm enemies and chests sort against the player; standalone tests
## leave it null and entities stay children of the realm.
var entity_parent: Node = null
var detached: Array = []


func generate(seed_value: int, wanted_template: String = "", wanted_family: String = "", realm_instance_id: String = "") -> void:
	realm_seed = seed_value
	instance_id = realm_instance_id
	family_id = wanted_family
	family = HiddenRealms.family(family_id) if family_id != "" else {}
	if not family.is_empty() and wanted_template == "":
		wanted_template = String(family.get("template", ""))
	var id := wanted_template if wanted_template != "" else HiddenRealms.default_id()
	profile = HiddenRealms.template(id)
	if profile.is_empty():
		profile = HiddenRealms.default_template()
	template_id = String(profile.get("id", "template.tomb"))
	cols = clampi(int(profile.get("cols", COLS)), 3, 8)
	rows = clampi(int(profile.get("rows", ROWS)), 3, 8)
	realm_name = String(profile.get("name", realm_name))
	treasure_count = maxi(1, int(profile.get("treasures", 2)))
	loop_count = maxi(0, int(profile.get("loops", 4)))
	hazard_chance = clampf(float(profile.get("hazard_chance", 1.0)), 0.0, 1.0)
	enemy_ilvl = clampi(int(profile.get("enemy_ilvl", 2)), 1, 12)
	enemies_per_room = clampi(int(profile.get("enemies_per_room", 2)), 1, 6)
	enemy_roster = (profile.get("enemy_roster", []) as Array).duplicate()
	warden_id = String(profile.get("warden", ""))
	altar_enabled = true
	loot_table = "chest.sealed"
	hazard_dps = HAZARD_DPS
	palette = DEFAULT_PALETTE.duplicate()
	if not family.is_empty():
		realm_name = String(family.get("name", realm_name))
		altar_enabled = bool(family.get("inheritance", false))
		loot_table = String(family.get("loot_table", loot_table))
		hazard_dps = float(family.get("hazard_dps", hazard_dps))
		palette = (family.get("palette", palette) as Dictionary).duplicate(true)
		enemy_ilvl = clampi(int(family.get("enemy_ilvl", enemy_ilvl)), 1, 12)
		enemies_per_room = clampi(int(family.get("enemies_per_room", enemies_per_room)), 1, 6)
		enemy_roster = (family.get("enemy_roster", enemy_roster) as Array).duplicate()
		warden_id = String(family.get("warden", warden_id))
	var stream_index := maxi(0, HiddenRealms.index_of(template_id))
	var r: RandomNumberGenerator = Rng.stream("hidden_realm", seed_value, stream_index)
	cells.clear()
	links.clear()
	kinds.clear()
	hazards.clear()
	interactables.clear()
	spawn_points.clear()

	for y in rows:
		for x in cols:
			cells.append(Vector2i(x, y))
	entry_cell = HiddenRealms.corner(String(profile.get("entry", "southwest")), cols, rows)
	altar_cell = HiddenRealms.corner(String(profile.get("altar", "northeast")), cols, rows)
	if entry_cell == altar_cell:
		altar_cell = Vector2i(cols - 1, 0)

	_assign_kinds(r)
	_build_links(r)
	_build_hazards(r)
	_build_interactables()
	_spawn_enemies(r)
	_spawn_warden()
	queue_redraw()


func _assign_kinds(r: RandomNumberGenerator) -> void:
	for cell in cells:
		kinds[cell] = "combat"
	kinds[entry_cell] = "entry"
	kinds[altar_cell] = "inheritance" if altar_enabled else "combat"
	var treasure_candidates: Array[Vector2i] = []
	for cell in cells:
		if String(kinds[cell]) == "combat":
			treasure_candidates.append(cell)
	# Determinism: pick from the seeded stream. Array.shuffle() would consume the
	# engine-global RNG, so two realms generated from the same seed would differ.
	for _i in mini(treasure_count, treasure_candidates.size()):
		var pick := r.randi_range(0, treasure_candidates.size() - 1)
		kinds[treasure_candidates[pick]] = "treasure"
		treasure_candidates.remove_at(pick)


func _build_links(r: RandomNumberGenerator) -> void:
	var visited: Dictionary = {entry_cell: true}
	var stack: Array[Vector2i] = [entry_cell]
	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = current + offset
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= cols or neighbor.y >= rows:
				continue
			if visited.has(neighbor):
				continue
			options.append(neighbor)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = options[r.randi_range(0, options.size() - 1)]
		links.append([current, pick])
		visited[pick] = true
		stack.append(pick)

	# A few extra edges turn the maze into a looping tomb rather than a tree.
	for i in loop_count:
		var a: Vector2i = cells[r.randi_range(0, cells.size() - 1)]
		var b: Vector2i = cells[r.randi_range(0, cells.size() - 1)]
		if a != b and not are_linked(a, b):
			links.append([a, b])


func are_linked(a: Vector2i, b: Vector2i) -> bool:
	for link in links:
		if (link[0] == a and link[1] == b) or (link[0] == b and link[1] == a):
			return true
	return false


## The world rectangle the room grid occupies, used for camera bounds.
func world_bounds() -> Rect2:
	var width := float(cols - 1) * (ROOM_W + GAP) + ROOM_W
	var height := float(rows - 1) * (ROOM_H + GAP) + ROOM_H
	return Rect2(Vector2(-ROOM_W * 0.5, -ROOM_H * 0.5), Vector2(width, height))


func _entity_owner() -> Node:
	return entity_parent if entity_parent != null else self


func _attach(node: Node) -> void:
	var owner_node := _entity_owner()
	owner_node.add_child(node)
	if owner_node != self:
		detached.append(node)


## Frees entities that live outside the realm node (the Y-sorted world layer).
func cleanup() -> void:
	for node in detached:
		if is_instance_valid(node):
			node.queue_free()
	detached.clear()


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * (ROOM_W + GAP), float(cell.y) * (ROOM_H + GAP))


func entry_position() -> Vector2:
	return cell_center(entry_cell)


func altar_position() -> Vector2:
	return cell_center(altar_cell)


## Flood fill over the corridor graph. The unit suite asserts this is true for
## every generated realm, which is what stops a loot room spawning unreachable.
func all_rooms_reachable() -> bool:
	if cells.is_empty():
		return false
	var seen: Dictionary = {entry_cell: true}
	var queue: Array[Vector2i] = [entry_cell]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for link in links:
			var next: Vector2i = link[1] if link[0] == current else (link[0] if link[1] == current else Vector2i(-99, -99))
			if next == Vector2i(-99, -99) or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen.size() == cells.size()


func _build_hazards(r: RandomNumberGenerator) -> void:
	for cell in cells:
		if String(kinds[cell]) != "combat":
			continue
		if hazard_chance < 1.0 and r.randf() > hazard_chance:
			continue
		var center := cell_center(cell)
		var offset := Vector2(r.randf_range(-90.0, 90.0), r.randf_range(-70.0, 70.0))
		hazards.append({
			"rect": Rect2(center + offset - Vector2(48, 48), Vector2(96, 96)),
			"dps": hazard_dps,
		})


func _build_interactables() -> void:
	var exit := Interactable.new()
	exit.setup(Interactable.Kind.PORTAL, "realm.exit", "Return to the Verdant Fringe")
	exit.position = cell_center(entry_cell) + Vector2(0, 90)
	_attach(exit)
	interactables.append(exit)

	if altar_enabled:
		var altar := Interactable.new()
		altar.setup(Interactable.Kind.ALTAR, "realm.altar", "Inheritance Altar")
		altar.position = cell_center(altar_cell)
		_attach(altar)
		interactables.append(altar)

	for cell in cells:
		if String(kinds[cell]) == "treasure":
			var chest := Interactable.new()
			var chest_id := "realm.chest.%d.%d" % [cell.x, cell.y]
			if instance_id != "":
				chest_id = "%s.chest.%d.%d" % [instance_id, cell.x, cell.y]
			chest.setup(Interactable.Kind.CHEST, chest_id, "Sealed Chest")
			chest.position = cell_center(cell) + Vector2(0, -40)
			_attach(chest)
			interactables.append(chest)


## The realm's guards are not one uniform body: the roster is fixed, so the mix
## is the same on every visit to a given realm.
const ENEMY_ROSTER: Array[String] = ["sentinel", "skirmisher", "archer", "brawler"]


func _spawn_enemies(r: RandomNumberGenerator) -> void:
	var roster: Array = enemy_roster
	if roster.is_empty():
		roster = ENEMY_ROSTER
	for cell in cells:
		var kind := String(kinds[cell])
		if kind != "combat" and kind != "treasure":
			continue
		var count := enemies_per_room if kind == "combat" else 1
		for i in count:
			var offset := Vector2(r.randf_range(-120.0, 120.0), r.randf_range(-90.0, 90.0))
			var pos: Vector2 = cell_center(cell) + offset
			spawn_points.append(pos)
			var dummy := Dummy.new()
			dummy.ilvl = enemy_ilvl
			dummy.position = pos
			var slot := (absi(cell.x) * 3 + absi(cell.y) * 5 + i) % roster.size()
			dummy.archetype = String(roster[slot])
			_attach(dummy)


## The warden stands between the entry hall and the altar. It is placed before
## the realm's other guards so its silhouette is never lost among them.
func _spawn_warden() -> void:
	if not spawn_warden or warden_id == "":
		return
	var entry: Dictionary = DB.boss(warden_id)
	if entry.is_empty():
		return
	var body := Dummy.new()
	body.ilvl = enemy_ilvl
	body.global_position = cell_center(altar_cell) + Vector2(0, 130)
	_attach(body)
	body.become_boss(entry, enemy_ilvl)
	warden = body


## Whether the warden still holds the altar. A dead warden frees itself, so an
## invalid reference and a body at zero health both count as gone.
func has_warden() -> bool:
	if warden == null or not is_instance_valid(warden):
		return false
	return float(warden.hp) > 0.0


## Remove a warden that a save has already killed. Generation runs before the
## scene checks `bosses_slain`, so a cleared tomb takes this path rather than a
## second gate rule.
func clear_warden() -> void:
	spawn_warden = false
	if is_instance_valid(warden):
		warden.queue_free()
	warden = null


## Spawns one spirit beast of a species at a position, parented like the rest of
## the realm's creatures so leaving the tomb frees it.
func spawn_beast(species_id: String, at: Vector2, realm: int) -> Dummy:
	var entry: Dictionary = DB.spirit_beast(species_id)
	if entry.is_empty():
		return null
	var beast := Dummy.new()
	beast.ilvl = 1
	beast.global_position = at
	_attach(beast)
	beast.become_beast(entry, realm)
	return beast


func mark_cleared() -> void:
	cleared = true
	for node in interactables:
		if node.id == "realm.altar":
			node.used = true
	queue_redraw()


## Total damage per second from hazards covering a world position.
func hazard_dps_at(world_position: Vector2) -> float:
	for hazard in hazards:
		var rect: Rect2 = hazard["rect"]
		if rect.has_point(world_position):
			return float(hazard["dps"])
	return 0.0


func _draw() -> void:
	# Corridors first, rooms on top: openings read as doorways.
	var border := Color(String(palette.get("border", "#3b3350")))
	for link in links:
		var a: Vector2 = cell_center(link[0])
		var b: Vector2 = cell_center(link[1])
		draw_line(a, b, border.darkened(0.25), 56.0)
		draw_line(a, b, border.darkened(0.55), 40.0)

	for cell in cells:
		var center: Vector2 = cell_center(cell)
		var rect := Rect2(center - Vector2(ROOM_W, ROOM_H) * 0.5, Vector2(ROOM_W, ROOM_H))
		var kind := String(kinds[cell])
		var floor_color := Color(String(palette.get("floor", "#241f30")))
		if kind == "entry":
			floor_color = Color(String(palette.get("entry", "#1c2a2a")))
		elif kind == "inheritance":
			floor_color = Color(String(palette.get("inheritance", "#2b2440")))
		elif kind == "treasure":
			floor_color = Color(String(palette.get("treasure", "#2a2620")))
		draw_rect(rect, floor_color)
		draw_rect(rect, border, false, 6.0)

	var hazard_color := Color(String(palette.get("hazard", "#5a2030")))
	var hazard_edge := Color(String(palette.get("hazard_edge", "#c06070")))
	for hazard in hazards:
		var rect: Rect2 = hazard["rect"]
		draw_rect(rect, Color(hazard_color, 0.55))
		draw_rect(rect, Color(hazard_edge, 0.7), false, 2.0)

	var accent := Color(String(palette.get("accent", "#8f7fd0")))
	for cell in cells:
		if String(kinds[cell]) == "inheritance":
			var center := cell_center(cell)
			draw_arc(center, 150.0, 0.0, TAU, 48, Color(accent, 0.4), 2.0)
			draw_arc(center, 110.0, 0.0, TAU, 40, Color(accent, 0.25), 1.5)
