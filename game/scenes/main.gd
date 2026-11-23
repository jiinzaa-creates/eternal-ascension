extends Node2D
## Scene root.
##
## Owns the run: the province streamer, the settlement and its scheduled NPCs,
## the Azure Cloud questline state, the hidden realm transition, loot, and
## save/load. The player node owns only the player.

const SPAWN := Vector2(5632, 5632)
const FORMATION_POINTS := 6
const WILD_DUMMY_TARGET := 4
const RESPAWN_INTERVAL := 8.0

var phase := "creation"  # creation | play | realm
## Character creation is two screens: formation points, then identity.
var creation_stage := 0
var player: Player
var hud: Hud
var chunks: ChunkManager
var settlement: Settlement
var npcs: Array = []
var elder: Npc
## Y-sorted layer: props, buildings, NPCs, the player and enemies all share it
## so draw order follows world Y instead of node creation order.
var world: Node2D
var camera_rig: CameraRig
var lighting: WorldLighting
## Continent geography, derived from the seed and never saved.
var continent: Dictionary = {}
var world_map: WorldMap
## Settlement services: the merchant's stock and the shop overlay.
var merchant := Merchant.new()
var shop_panel: ShopPanel
var shop_open := false
var _shop_mode := "buy"
var _sell_base := 0
## Navigation: known destinations, the travel overlay and the current waypoint.
var travel_panel: TravelPanel
var travel_open := false
var travel_index := 0
var waypoint_name := ""
var waypoint_position := Vector2.ZERO
## Discovered sites, recorded with a position so they stay travel destinations
## after their chunk unloads.
var travel_sites: Dictionary = {}
## Off-screen simulation: NPCs sleep beyond this distance, and changes they lived
## through wait in a short report shown when the player is back in the settlement.
const NPC_SIM_RADIUS := 1500.0
var _npc_seen: Dictionary = {}
var _away_notes: Array = []
var _wilds_recovered := 0
var interactables: Array = []
var ground_items: Array = []
var quests: QuestLog
var realm_instance: HiddenRealm = null
var realm_seed := 0
var realm_cleared := false
var inheritance_taken := false
var portal_position := Vector2.ZERO
var used_interactables: Array = []
## Per-chunk state the seed cannot reproduce: harvested resources and their day.
var world_delta := WorldDelta.new()

var _allocation_spent := 0
var _allocation_history: Array = []
var _root_rng: RandomNumberGenerator
var _name_rng: RandomNumberGenerator
var _used_names: Dictionary = {}
var _spawn_timer := 0.0
var _help_visible := true
var _hazard_accum := 0.0
var _npc_index := 0
var _root_rolls := 0
var _physique_rolls := 0


func _ready() -> void:
	Game.new_run()
	continent = Continent.generate(Game.world_seed)
	DisplayPolicy.apply(get_window())
	get_window().size_changed.connect(_on_window_resized)
	_root_rng = Rng.stream("root_roll", 0)
	_name_rng = Rng.stream("npc_names", 0)
	quests = QuestLog.new()
	_build_world()
	_spawn_player()
	_build_hud()
	Bus.enemy_died.connect(_on_enemy_died)
	Weather.changed.connect(_on_weather_changed)
	Bus.toast.emit("A new path opens. Assign your attributes, then press ENTER.")


# ---------------------------------------------------------------- world ----

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	lighting = WorldLighting.new()
	lighting.name = "Lighting"
	add_child(lighting)

	# Ground layers sort below everything by z_index; the Y-sort only orders
	# things that stand on the ground.
	chunks = ChunkManager.new()
	chunks.name = "Province"
	chunks.z_index = -20
	world.add_child(chunks)
	# Payloads generate on worker threads; nodes are still built here.
	chunks.threaded = true
	chunks.delta = world_delta
	chunks.biome_defs = DB.biome_table()
	chunks.set_resource_parent(world)
	chunks.on_resource_spawned = func(node: Interactable) -> void: interactables.append(node)
	chunks.on_resource_freed = func(node: Interactable) -> void: interactables.erase(node)
	chunks.regrown.connect(_on_wilds_regrown)
	chunks.configure(Game.world_seed)
	chunks.set_prop_parent(world)
	chunks.stream_around(SPAWN)
	# The first frame must show ground, not a hole: wait for the initial ring.
	chunks.settle()

	settlement = Settlement.new()
	settlement.name = "AzureCloudMarket"
	settlement.position = SPAWN
	settlement.z_index = -15
	world.add_child(settlement)
	settlement.build_buildings(world)

	_spawn_npcs()
	_spawn_interactables()


func _spawn_player() -> void:
	player = Player.new()
	player.position = SPAWN + Vector2(0, 60)
	world.add_child(player)
	player.display_name = _random_name()
	player.cultivation.root_tier = _roll_root()
	player.cultivation.purity_bonus = _roll_purity()
	player.cultivation.identified = false
	player.physique_id = Physiques.roll(_physique_rolls)
	player.spawn_point = player.position

	camera_rig = CameraRig.new()
	camera_rig.name = "Camera"
	camera_rig.set_bounds(ChunkManager.world_bounds())
	player.add_child(camera_rig)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = Hud.new()
	hud.host = self
	layer.add_child(hud)
	world_map = WorldMap.new()
	layer.add_child(world_map)
	world_map.setup(continent, Continent.region_for_world_position(player.global_position))
	shop_panel = ShopPanel.new()
	layer.add_child(shop_panel)
	travel_panel = TravelPanel.new()
	layer.add_child(travel_panel)


func _spawn_npcs() -> void:
	var schedules: Dictionary = DB.schedules()
	elder = _make_npc("elder_bai", "Elder Bai Qing", "Elder", "sect.azure_cloud",
		4, schedules.get("elder", []), Vector2(-30, 40))
	_make_npc("instructor_rui", "Instructor Rui", "Sword Instructor", "sect.azure_cloud",
		3, schedules.get("inner_disciple", []), Vector2(64, 120))

	var plan := [
		["sect_master", 1],
		["inner_disciple", 5],
		["outer_disciple", 6],
		["merchant", 2],
		["guard", 2],
		["farmer", 2],
	]
	for entry in plan:
		var archetype := _archetype(String(entry[0]))
		if archetype.is_empty():
			continue
		var count := int(entry[1])
		for i in count:
			var offset := Vector2(_name_rng.randf_range(-140.0, 140.0), _name_rng.randf_range(-100.0, 160.0))
			_make_npc(
				"npc.%s.%d" % [String(entry[0]), _npc_index],
				_random_name(),
				String(archetype.get("role", "Wanderer")),
				String(archetype.get("sect", "")),
				int(archetype.get("realm", 1)),
				schedules.get(String(archetype.get("schedule", "disciple")), []),
				offset
			)


func _archetype(id: String) -> Dictionary:
	for archetype in DB.archetypes():
		if String(archetype.get("id", "")) == id:
			return archetype
	return {}


func _make_npc(id: String, display: String, role: String, sect: String, realm: int,
		schedule: Array, offset: Vector2) -> Npc:
	var npc := Npc.new()
	npc.name = "Npc_" + id
	npc.setup(id, display, role, sect, realm, schedule, settlement)
	npc.root_tier = int(_name_rng.randi_range(2, 7))
	world.add_child(npc)
	npc.global_position = settlement.position_for("plaza") + offset
	npcs.append(npc)
	_npc_index += 1
	return npc


func _random_name() -> String:
	var surnames: Array = DB.npc_data.get("surnames", ["Bai"])
	var given: Array = DB.npc_data.get("given", ["Qing"])
	for attempt in 60:
		var surname := String(surnames[_name_rng.randi_range(0, surnames.size() - 1)])
		var personal := String(given[_name_rng.randi_range(0, given.size() - 1)])
		var full := "%s %s" % [surname, personal]
		if not _used_names.has(full):
			_used_names[full] = true
			return full
	return "Wanderer %d" % _used_names.size()


func _spawn_interactables() -> void:
	var shrine := Interactable.new()
	shrine.setup(Interactable.Kind.SHRINE, "shrine.azure", "Azure Cloud Shrine — attune")
	shrine.position = settlement.position_for("shrine")
	world.add_child(shrine)
	interactables.append(shrine)

	for i in 3:
		var herb := Interactable.new()
		herb.setup(Interactable.Kind.HERB, "herb.%d" % i, "Spirit Herb")
		herb.position = settlement.position_for("herb_garden") + Vector2(-40.0 + float(i) * 40.0, 0.0)
		world.add_child(herb)
		interactables.append(herb)

	portal_position = SPAWN + Vector2(820, -520)
	var portal := Interactable.new()
	portal.setup(Interactable.Kind.PORTAL, "portal.hollow_moon", "Rift — Tomb of the Hollow Moon")
	portal.position = portal_position
	world.add_child(portal)
	interactables.append(portal)

	# Night lighting: the shrine and the rift stay readable after dusk.
	lighting.add_light(world, shrine.position, Color("#ffd9a0"), 220.0, 0.9)
	lighting.add_light(world, portal.position, Color("#b48cff"), 260.0, 1.0)

	# A door for every building, at the doorway the building draws.
	for spec in Settlement.BUILDINGS:
		var location := String(spec["location"])
		var building := settlement.building_for(location)
		if building == null:
			continue
		var door := Interactable.new()
		door.setup_door("door.%s" % location, "%s door" % location.capitalize(), building)
		door.position = building.global_position + Vector2(0, (spec["size"] as Vector2).y * 0.5 + 8.0)
		world.add_child(door)
		interactables.append(door)

	# Containers: one-shot loot, deterministic from their stable id.
	var crate_spots := [
		["crate.market.0", "Market crate", "market", Vector2(-58, 44)],
		["crate.tavern.0", "Tavern crate", "tavern", Vector2(52, 48)],
		["crate.dorms.0", "Dormitory chest", "dorms", Vector2(0, 54)],
	]
	for spot in crate_spots:
		var crate := Interactable.new()
		crate.setup_container(String(spot[0]), String(spot[1]), hash(String(spot[0])))
		crate.position = settlement.position_for(String(spot[2])) + (spot[3] as Vector2)
		world.add_child(crate)
		interactables.append(crate)

	# A manual teaches a technique that is otherwise hidden from character start.
	var manual := Interactable.new()
	manual.setup_manual("manual.crimson_moon", "Forbidden manual — Crimson Moon Devour", "tech.blood.crimson_moon")
	manual.position = settlement.position_for("sect_hall") + Vector2(-46, 12)
	world.add_child(manual)
	interactables.append(manual)

	# A disciple practising a technique nobody wrote down: watch and learn.
	var demonstration := Interactable.new()
	demonstration.setup_demonstration("training.falling_petal", "Practising disciple — Falling Petal Cut",
		"tech.sword.falling_petal")
	demonstration.position = settlement.position_for("plaza") + Vector2(-58, 148)
	world.add_child(demonstration)
	interactables.append(demonstration)

	# Passive manuals: voluntary learning, gated by what the body can use.
	var manual_specs := [
		["manual.jade_skin", "Body-Refining Manual — Jade Skin", "passive.jade_skin", Vector2(40, 54)],
		["manual.battle_trance", "Blood-Refining Manual — Battle Trance", "passive.battle_trance", Vector2(86, 40)],
		["manual.flowing_water", "Water-Step Manual — Flowing Water", "passive.flowing_water", Vector2(-18, 88)],
	]
	for spec in manual_specs:
		var passive_manual := Interactable.new()
		passive_manual.setup_passive_manual(String(spec[0]), String(spec[1]), String(spec[2]))
		passive_manual.position = settlement.position_for("shrine") + (spec[3] as Vector2)
		world.add_child(passive_manual)
		interactables.append(passive_manual)

	# Examination: scenery that rewards looking, repeatable and inconsumable.
	var stele := Interactable.new()
	stele.setup_examine("stele.azure", "Azure Cloud stele",
		"The stele reads: the sect was founded on a promise to teach the rootless. The lower names are worn away.")
	stele.position = settlement.position_for("shrine") + Vector2(64, 18)
	world.add_child(stele)
	interactables.append(stele)

	# Root appraisal and evolution, beside the shrine that reads meridians.
	var pavilion := Interactable.new()
	pavilion.setup(Interactable.Kind.ROOT, "root.pavilion", "Root-Reading Pavilion — appraise or evolve")
	pavilion.position = settlement.position_for("shrine") + Vector2(-84, 62)
	world.add_child(pavilion)
	interactables.append(pavilion)

	var board := Interactable.new()
	board.setup_examine("board.market", "Market notice board",
		"Notices: a bounty on marsh boars, a lost jade comb, and a warning not to enter the eastern rift.")
	board.position = settlement.position_for("market") + Vector2(-96, -18)
	world.add_child(board)
	interactables.append(board)

	# Settlement services: a merchant stall and an inn counter.
	var stall := Interactable.new()
	stall.setup(Interactable.Kind.SHOP, "shop.market", "Merchant stall — trade")
	stall.position = settlement.position_for("market") + Vector2(74, 42)
	world.add_child(stall)
	interactables.append(stall)

	var inn := Interactable.new()
	inn.setup(Interactable.Kind.INN, "inn.tavern", "Inn counter — rest")
	inn.position = settlement.position_for("tavern") + Vector2(-74, 46)
	world.add_child(inn)
	interactables.append(inn)


func _roll_purity() -> float:
	_root_rolls += 1
	return Roots.roll_purity_bonus(_root_rolls)


func _roll_root() -> int:
	var weights: Array = []
	for root in DB.roots:
		weights.append(int(root.get("weight", 1)))
	var index: int = int(Rng.pick_weighted(weights, _root_rng))
	if index < 0:
		return 3
	return int(DB.roots[index].get("tier", 3))


# ----------------------------------------------------------- creation ----

func allocation_remaining() -> int:
	return FORMATION_POINTS - _allocation_spent


func allocate_attribute(key: String) -> bool:
	if phase != "creation" or allocation_remaining() <= 0:
		return false
	if not Attributes.KEYS.has(key):
		return false
	player.attrs.add(key, 1)
	_allocation_spent += 1
	_allocation_history.append(key)
	player.rebuild_stats()
	player.hp = player.hp_max
	Bus.player_stats_changed.emit()
	return true


func refund_attribute() -> bool:
	if phase != "creation" or _allocation_history.is_empty():
		return false
	var key: String = _allocation_history.pop_back()
	player.attrs.add(key, -1)
	_allocation_spent -= 1
	player.rebuild_stats()
	player.hp = player.hp_max
	Bus.player_stats_changed.emit()
	return true


func _begin_run() -> void:
	_apply_origin()
	phase = "play"
	player.rebuild_stats()
	player.hp = player.hp_max
	player.spawn_point = settlement.position_for("plaza")
	Bus.toast.emit("Azure Cloud Market. Elder Bai waits by the sect hall.")


func creation_origins() -> Array:
	return DB.origins


func selected_origin() -> Dictionary:
	var origin: Dictionary = DB.origin(Game.origin_id)
	if origin.is_empty() and not DB.origins.is_empty():
		return DB.origins[0]
	return origin


## Starting circumstances: a purse, a starting method and at most one passive.
## Applied once when the run begins; a loaded save already contains the result.
func _apply_origin() -> void:
	var origin: Dictionary = DB.origin(Game.origin_id)
	if origin.is_empty():
		return
	var fx := Origin.effects(origin)
	Game.spirit_stones += int(fx["stones"])
	var method_id := String(fx["method_id"])
	if method_id != "" and DB.has("method", method_id):
		player.cultivation.method_id = method_id
	var passive := String(fx["passive"])
	if passive != "":
		player.add_passive(passive)
	Bus.toast.emit("Origin — %s. %s" % [String(fx["name"]), String(fx["condition"])])


# --------------------------------------------------------------- loop ----

func _process(delta: float) -> void:
	if player == null:
		return
	# The continent map is a reading screen: it freezes play instead of letting
	# the player walk blind behind an opaque overlay.
	if (world_map != null and world_map.visible) or shop_open or travel_open:
		return

	_simulate_npcs()
	_flush_away_report()

	if Travel.has_arrived(player.global_position, waypoint_position):
		Bus.toast.emit("You have reached %s." % waypoint_name)
		waypoint_name = ""
		waypoint_position = Vector2.ZERO

	# The province is hidden inside a realm: streaming there would load chunks
	# for tomb coordinates and spawn props under the tomb floor.
	chunks.today = Clock.day
	if realm_instance == null:
		chunks.stream_around(player.global_position)
	if phase == "creation":
		return

	var limit := ChunkManager.CHUNK_SIZE * ChunkManager.PROVINCE_CHUNKS - 40.0
	player.global_position = Vector2(
		clampf(player.global_position.x, 40.0, limit),
		clampf(player.global_position.y, 40.0, limit)
	)

	if phase == "realm":
		if realm_instance != null:
			var dps := realm_instance.hazard_dps_at(player.global_position)
			if dps > 0.0:
				_hazard_accum += dps * delta
				if _hazard_accum >= 5.0:
					# Floor hazards are not dodgeable: evasion is for attacks.
					player.take_hit(_hazard_accum, player.global_position, false)
					_hazard_accum = 0.0
		return

	for i in mini(6, player.technique_ids.size()):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			player.selected_technique = i
			Bus.cultivation_changed.emit()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	_spawn_timer += delta
	if _spawn_timer >= RESPAWN_INTERVAL:
		_spawn_timer = 0.0
		if _wild_dummy_count() < WILD_DUMMY_TARGET:
			_spawn_wild_dummy()


func _wild_dummy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


func _spawn_wild_dummy() -> void:
	var r: RandomNumberGenerator = Rng.stream("wild_dummy", Game.kills + 1, _wild_dummy_count())
	var angle := r.randf_range(0.0, TAU)
	var distance := r.randf_range(420.0, 760.0)
	var spawn := settlement.position_for("plaza") + Vector2(cos(angle), sin(angle)) * distance
	var dummy := Dummy.new()
	dummy.ilvl = maxi(1, player.cultivation.realm)
	dummy.position = spawn
	world.add_child(dummy)
	# The biome at the spawn point decides which creature turns up, not a global table.
	var biome: Dictionary = DB.biome(Biome.for_chunk(chunks.world_to_chunk(spawn), Game.world_seed))
	var enemy := Biome.pick_enemy(biome, r)
	dummy.apply_biome_enemy(enemy, player.cultivation.realm)


func current_biome_name() -> String:
	if player == null:
		return ""
	var id := Biome.for_chunk(chunks.world_to_chunk(player.global_position), Game.world_seed)
	return String(DB.biome(id).get("name", "Wilds"))


func _on_window_resized() -> void:
	DisplayPolicy.apply(get_window())


# --------------------------------------------------------------- services ----

func _open_shop() -> void:
	if shop_panel == null or player == null:
		return
	merchant.refresh(DB, Rng, Clock.day)
	shop_open = true
	player.set_physics_process(false)
	player.set_process(false)
	_show_shop("buy")


func _close_shop() -> void:
	shop_open = false
	if shop_panel != null:
		shop_panel.hide_panel()
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func _show_shop(mode: String) -> void:
	if shop_panel == null or player == null:
		return
	_shop_mode = mode
	var rows: Array = []
	if mode == "buy":
		for item in merchant.stock:
			rows.append({
				"name": String(item.get("name", "?")),
				"price": Economy.buy_price(item),
				"color": ItemGen.RARITY_COLORS[int(item.get("rarity", 0))],
			})
		_sell_base = 0
	else:
		_sell_base = maxi(0, player.inventory.size() - 6)
		for i in range(_sell_base, player.inventory.size()):
			var item: Dictionary = player.inventory[i]
			rows.append({
				"name": String(item.get("name", "?")),
				"price": Economy.sell_price(item),
				"color": ItemGen.RARITY_COLORS[int(item.get("rarity", 0))],
			})
	shop_panel.setup(mode, "Azure Cloud Market — Merchant", rows, Game.spirit_stones)


func _buy_index(index: int) -> void:
	if index < 0 or index >= merchant.stock.size():
		return
	var item: Dictionary = merchant.stock[index]
	var price := Economy.buy_price(item)
	if not Economy.can_afford(Game.spirit_stones, price):
		Bus.toast.emit("Not enough spirit stones: %d needed." % price)
		return
	Game.spirit_stones -= price
	merchant.take(index)
	player.pick_up(item)
	Bus.toast.emit("Bought %s for %d spirit stones." % [String(item.get("name", "item")), price])
	_show_shop("buy")


func _sell_index(index: int) -> void:
	if index < 0 or index >= player.inventory.size():
		return
	var item: Dictionary = player.inventory[index]
	var price := Economy.sell_price(item)
	player.inventory.remove_at(index)
	# Selling worn gear must not leave the stat pipeline holding a ghost.
	var slot := String(item.get("slot", ""))
	var worn: Dictionary = player.equipment.get(slot, {})
	if not worn.is_empty() and String(worn.get("id", "")) == String(item.get("id", "")):
		player.equipment.erase(slot)
		player.rebuild_stats()
	Game.spirit_stones += price
	Bus.player_stats_changed.emit()
	Bus.toast.emit("Sold %s for %d spirit stones." % [String(item.get("name", "item")), price])
	_show_shop("sell")


func _rest_at_inn() -> void:
	var cost := Economy.rest_cost()
	if not Economy.can_afford(Game.spirit_stones, cost):
		Bus.toast.emit("A night at the inn costs %d spirit stones. You have %d." % [cost, Game.spirit_stones])
		return
	Game.spirit_stones -= cost
	player.hp = player.hp_max
	cultivation_restore()
	Clock.advance(8.0)
	Bus.player_stats_changed.emit()
	Bus.toast.emit("You sleep for eight hours and wake restored. (-%d stones)" % cost)


# ---------------------------------------------------------- simulation ----

## Sleeps every NPC the player cannot see and wakes the ones nearby. Waking snaps
## an NPC to the schedule that passed while it slept, and any change in activity
## is remembered for the return report.
func _simulate_npcs() -> void:
	var in_realm := realm_instance != null
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var node := npc as Npc
		var near := not in_realm and node.global_position.distance_to(player.global_position) <= NPC_SIM_RADIUS
		if near:
			if not node.simulated:
				var before := String(_npc_seen.get(node.npc_id, ""))
				node.wake()
				if before != "" and before != node.current_activity:
					_away_notes.append("%s was %s while you were away, and is now %s." % [node.display_name, before, node.current_activity])
					if _away_notes.size() > 6:
						_away_notes.pop_front()
				_npc_seen[node.npc_id] = node.current_activity
		elif node.simulated:
			_npc_seen[node.npc_id] = node.current_activity
			node.sleep()


func _flush_away_report() -> void:
	if _wilds_recovered > 0 and realm_instance == null:
		Bus.toast.emit("The wilds recover while you were away (%d)." % _wilds_recovered)
		_wilds_recovered = 0
	if _away_notes.is_empty() or phase != "play":
		return
	if player.global_position.distance_to(settlement.position_for("plaza")) > 600.0:
		return
	var shown := mini(3, _away_notes.size())
	for i in shown:
		Bus.toast.emit(String(_away_notes[i]))
	if _away_notes.size() > shown:
		Bus.toast.emit("...and %d more changes while you were away." % (_away_notes.size() - shown))
	_away_notes.clear()


func _on_wilds_regrown(count: int) -> void:
	_wilds_recovered += count


# --------------------------------------------------------------- travel ----

func _travel_landmarks() -> Array:
	return [
		{"id": "landmark.plaza", "name": "Azure Cloud plaza", "position": settlement.position_for("plaza")},
		{"id": "landmark.shrine", "name": "Azure Cloud shrine", "position": settlement.position_for("shrine")},
		{"id": "landmark.tavern", "name": "Tavern inn", "position": settlement.position_for("tavern")},
		{"id": "landmark.rift", "name": "Rift to the Hollow Moon", "position": portal_position},
	]


func travel_destinations() -> Array:
	return Travel.destinations(_travel_landmarks(), travel_sites, Travel.MAX_ROWS)


func _open_travel() -> void:
	if travel_panel == null or player == null:
		return
	if realm_instance != null:
		Bus.toast.emit("No route can be charted inside a hidden realm.")
		return
	travel_index = 0
	travel_open = true
	player.set_physics_process(false)
	player.set_process(false)
	_show_travel()


func _close_travel() -> void:
	travel_open = false
	if travel_panel != null:
		travel_panel.hide_panel()
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func _show_travel() -> void:
	if travel_panel == null or player == null:
		return
	var destinations := travel_destinations()
	if travel_index >= destinations.size():
		travel_index = maxi(0, destinations.size() - 1)
	var rows: Array = []
	for destination in destinations:
		var target: Vector2 = destination["position"]
		var distance := target.distance_to(player.global_position)
		rows.append({
			"name": String(destination["name"]),
			"detail": "%s · %.1f h" % [Travel.distance_label(distance), Travel.hours_for(distance)],
			"color": "#9fe0c0" if waypoint_name == String(destination["name"]) else "#e6eef2",
		})
	travel_panel.setup(rows, travel_index)


func _travel_to(index: int) -> void:
	var destinations := travel_destinations()
	if index < 0 or index >= destinations.size():
		return
	if not Travel.can_travel(true, realm_instance != null, false):
		return
	var destination: Dictionary = destinations[index]
	var target: Vector2 = destination["position"]
	var hours := Travel.hours_for(target.distance_to(player.global_position))
	player.global_position = target + Vector2(0, 44)
	player.spawn_point = player.global_position
	Clock.advance(hours)
	chunks.today = Clock.day
	chunks.stream_around(player.global_position)
	chunks.settle()
	camera_rig.reset_smoothing()
	waypoint_name = ""
	waypoint_position = Vector2.ZERO
	_close_travel()
	Bus.toast.emit("Travelled to %s (%.1f hours)." % [String(destination["name"]), hours])


func _set_waypoint(index: int) -> void:
	var destinations := travel_destinations()
	if index < 0 or index >= destinations.size():
		return
	var destination: Dictionary = destinations[index]
	waypoint_name = String(destination["name"])
	waypoint_position = destination["position"]
	_close_travel()
	Bus.toast.emit("Waypoint set: %s." % waypoint_name)


func toggle_map() -> void:
	if world_map == null or player == null or phase == "creation":
		return
	world_map.toggle()
	if world_map.visible:
		world_map.setup(continent, Continent.region_for_world_position(player.global_position))
	# Freeze both loops, so an open map is not a blind walk.
	player.set_physics_process(not world_map.visible)
	player.set_process(not world_map.visible)


func _unhandled_input(event: InputEvent) -> void:
	if phase == "creation":
		if event.is_action_pressed("accept"):
			if creation_stage == 0:
				creation_stage = 1
			else:
				_begin_run()
			return
		if event.is_action_pressed("undo_point"):
			if creation_stage == 1:
				creation_stage = 0
			else:
				refund_attribute()
			return
		if event.is_action_pressed("reroll"):
			player.cultivation.root_tier = _roll_root()
			player.cultivation.purity_bonus = _roll_purity()
			player.cultivation.identified = false
			player.rebuild_stats()
			Bus.cultivation_changed.emit()
			Bus.toast.emit("Your root shifts.")
			return
		if event.is_action_pressed("creation_origin"):
			Game.origin_id = Origin.next(DB.origins, Game.origin_id, 1)
			return
		if event.is_action_pressed("creation_robe"):
			player.appearance.cycle("robe")
			return
		if event.is_action_pressed("creation_hair"):
			player.appearance.cycle("hair")
			return
		if event.is_action_pressed("creation_skin"):
			player.appearance.cycle("skin")
			return
		if event.is_action_pressed("creation_presentation"):
			player.appearance.cycle("presentation")
			return
		if event.is_action_pressed("creation_physique"):
			_physique_rolls += 1
			player.physique_id = Physiques.roll(_physique_rolls)
			player.rebuild_stats()
			Bus.player_stats_changed.emit()
			Bus.toast.emit("Your body reshapes — %s." % Physiques.name_of(player.physique_id))
			return
		if creation_stage == 0:
			for i in Attributes.KEYS.size():
				if event.is_action_pressed("skill_%d" % (i + 1)):
					allocate_attribute(Attributes.KEYS[i])
					return
		return

	if travel_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_close_travel()
			return
		if event.is_action_pressed("accept"):
			_travel_to(travel_index)
			return
		if event.is_action_pressed("travel_waypoint"):
			_set_waypoint(travel_index)
			return
		for i in 6:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				travel_index = i
				_show_travel()
				return
		return

	if event.is_action_pressed("open_travel"):
		_open_travel()
		return

	if shop_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_close_shop()
			return
		if event.is_action_pressed("shop_mode"):
			_show_shop("sell" if _shop_mode == "buy" else "buy")
			return
		for i in 6:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				if _shop_mode == "buy":
					_buy_index(i)
				else:
					_sell_index(_sell_base + i)
				return
		return

	if event.is_action_pressed("quick_save"):
		_save(1)
	elif event.is_action_pressed("map"):
		toggle_map()
	elif event.is_action_pressed("quick_load"):
		_load_game(1)
	elif event.is_action_pressed("toggle_help"):
		_help_visible = not _help_visible
		Bus.help_toggled.emit(_help_visible)
	elif event.is_action_pressed("breakthrough"):
		player.attempt_breakthrough()


# ----------------------------------------------------------- interaction ----

func _active_interactables() -> Array:
	if realm_instance != null:
		return realm_instance.interactables
	return interactables


func _nearest_interactable() -> Node:
	var best: Node = null
	var best_dist := 96.0
	for npc in npcs:
		if realm_instance != null:
			break
		if not is_instance_valid(npc):
			continue
		var dist: float = (npc as Node2D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	for node in _active_interactables():
		if not is_instance_valid(node) or not node.can_interact():
			continue
		var dist: float = (node as Node2D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


func interaction_prompt() -> String:
	if player == null or phase == "creation":
		return ""
	var best := _nearest_interactable()
	if best == null:
		return ""
	if best is Npc:
		var npc := best as Npc
		return "E  Talk to %s (%s)" % [npc.display_name, npc.role]
	var interactable := best as Interactable
	return "E  %s" % interactable.display_label()


func _try_interact() -> void:
	var best := _nearest_interactable()
	if best == null:
		return
	if best is Npc:
		_talk(best as Npc)
	elif best is Interactable:
		_use_interactable(best as Interactable)


## Rui sells one cut to anyone who meets its requirements and can pay.
func _teach_technique() -> void:
	var tech_id := "tech.sword.falling_petal"
	var price := 180
	var tech: Dictionary = DB.technique(tech_id)
	if player.technique_ids.has(tech_id):
		Bus.toast.emit("Instructor Rui: \"You already carry that cut. Show it to me one day.\"")
		return
	var check := Techniques.can_learn(tech_id, player.technique_state())
	if not bool(check["ok"]):
		Bus.toast.emit("Instructor Rui: \"Come back when you are %s.\"" % String(check["reason"]))
		return
	if Game.spirit_stones < price:
		Bus.toast.emit("Instructor Rui: \"%d stones, and not one less.\"" % price)
		return
	var learned := player.try_learn_technique(tech_id)
	if not bool(learned["ok"]):
		Bus.toast.emit("Instructor Rui: \"%s.\"" % String(learned["reason"]))
		return
	Game.spirit_stones -= price
	Bus.toast.emit("Instructor Rui teaches %s. (-%d stones)" % [String(tech.get("name", tech_id)), price])
	Bus.cultivation_changed.emit()


func _talk(npc: Npc) -> void:
	if npc.npc_id == "instructor_rui":
		_teach_technique()
		return
	if npc.npc_id != "elder_bai":
		Bus.toast.emit("%s (%s): \"The Qi is thin today.\"" % [npc.display_name, npc.role])
		return

	if quests.completed:
		Bus.toast.emit("Elder Bai: \"You are Azure Cloud now. Climb, and do not look down.\"")
		return

	var advanced := quests.track("talk", "elder_bai")
	advanced = quests.track("return", "elder_bai") or advanced
	if quests.completed:
		_grant_reward()
	elif advanced:
		_toast_new_objective()
	else:
		Bus.toast.emit("Elder Bai: \"%s\"" % quests.objective_text())


func _use_interactable(node: Interactable) -> void:
	match node.kind:
		Interactable.Kind.HERB:
			if node.used:
				return
			_mark_spent(node)
			var herb := _make_herb()
			player.inventory.append(herb)
			Bus.item_picked.emit(herb)
			var before := quests.step_index
			quests.track("collect", "spirit_herb", 1)
			Bus.toast.emit("Gathered a spirit herb.")
			if quests.step_index != before:
				_toast_new_objective()
		Interactable.Kind.SHRINE:
			var before := quests.step_index
			quests.track("channel", "shrine")
			if quests.step_index != before:
				_toast_new_objective()
			else:
				Bus.toast.emit("The shrine hums. Your meridians settle.")
			cultivation_restore()
		Interactable.Kind.PORTAL:
			if node.id == "realm.exit":
				_exit_realm()
			else:
				_enter_realm()
		Interactable.Kind.CHEST:
			if node.used:
				return
			_loot(node, 6, "sealed chest", 2)
		Interactable.Kind.ALTAR:
			_claim_inheritance()
		Interactable.Kind.DOOR:
			node.open = not node.open
			if node.building != null:
				node.building.set_interior_open(node.open)
			Bus.toast.emit("%s %s." % [node.label, "opens" if node.open else "closes"])
		Interactable.Kind.CONTAINER:
			if node.used:
				return
			_loot(node, maxi(2, player.cultivation.realm + 1), node.label.to_lower(), 0)
		Interactable.Kind.MANUAL:
			if node.used:
				return
			if node.manual_passive != "":
				var learned := player.try_learn_passive(node.manual_passive)
				if not bool(learned["ok"]):
					Bus.toast.emit("The manual will not open to you: %s required." % String(learned["reason"]))
					return
				node.used = true
				var passive: Dictionary = DB.passive(node.manual_passive)
				Bus.toast.emit("You study the manual. Passive learned: %s." % String(passive.get("name", node.manual_passive)))
				Bus.player_stats_changed.emit()
				return
			if player.learn_technique(node.manual_technique):
				node.used = true
				var tech: Dictionary = DB.technique(node.manual_technique)
				Bus.toast.emit("You study the manual. Technique learned: %s." % String(tech.get("name", node.manual_technique)))
				Bus.cultivation_changed.emit()
			else:
				Bus.toast.emit("You already know what this manual teaches.")
		Interactable.Kind.DEMONSTRATION:
			var watched := player.observe_technique(node.demo_technique)
			var demo: Dictionary = DB.technique(node.demo_technique)
			if bool(watched.get("learned", false)):
				Bus.toast.emit("You have watched the cut often enough. Technique learned: %s." % String(demo.get("name", node.demo_technique)))
				Bus.cultivation_changed.emit()
			elif bool(watched["ok"]):
				Bus.toast.emit("You watch the cut. Understanding %d%%." % roundi(float(watched["progress"]) * 100.0))
			elif String(watched["reason"]) == "already known":
				Bus.toast.emit("You already know the cut; there is nothing left to watch.")
			else:
				Bus.toast.emit("The disciple's cut is beyond you: %s required." % String(watched["reason"]))
		Interactable.Kind.EXAMINE:
			Bus.toast.emit(node.examine_text)
		Interactable.Kind.SHOP:
			_open_shop()
		Interactable.Kind.INN:
			_rest_at_inn()
		Interactable.Kind.RUIN:
			if node.used:
				return
			_loot(node, 5, "ruin cache", 1)
			if Roots.marrow_found(node.chunk_coord, "ruin"):
				player.pick_up(_make_marrow())
				Bus.toast.emit("Among the rubble: a knot of root marrow.")
			_award_discovery(node, 40)
		Interactable.Kind.MINE:
			if node.used:
				return
			_mark_spent(node)
			player.pick_up(_make_ore())
			Bus.toast.emit("Mined spirit ore from the vein.")
			if Roots.marrow_found(node.chunk_coord, "mine"):
				player.pick_up(_make_marrow())
				Bus.toast.emit("A knot of root marrow comes loose from the rock.")
			_award_discovery(node, 25)
		Interactable.Kind.DEPOSIT:
			if node.used:
				return
			_mark_spent(node)
			Game.spirit_stones += 25
			Bus.player_stats_changed.emit()
			Bus.toast.emit("Gathered 25 spirit stones from the deposit.")
			_award_discovery(node, 15)
		Interactable.Kind.ROOT:
			_use_root_pavilion()


## Spends a node: streamed resources record a chunk delta with their own regrow
## window, unique world nodes go into the saved one-shot list.
func _mark_spent(node: Interactable) -> void:
	node.used = true
	if node.chunk_owned:
		world_delta.mark_spent(node.chunk_coord, node.id, Clock.day, node.regrow_days)
	elif not used_interactables.has(node.id):
		used_interactables.append(node.id)


## One-shot loot shared by chests, containers and ruins. The item is generated
## from the node's stable id, so looting it again after a reload is impossible.
func _loot(node: Interactable, ilvl: int, verb: String, forced_rarity: int = 0) -> void:
	_mark_spent(node)
	var generator := ItemGen.new(DB, Rng)
	var item := generator.generate(maxi(1, ilvl), hash(node.id), ground_items.size(), forced_rarity)
	if item.is_empty():
		Bus.toast.emit("The %s is empty." % verb)
		return
	ground_items.append({"x": node.global_position.x, "y": node.global_position.y + 30.0, "item": item})
	Bus.item_dropped.emit(item, node.global_position)
	Bus.toast.emit("The %s holds %s." % [verb, String(item.get("name", "?"))])


func cultivation_restore() -> void:
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	Bus.cultivation_changed.emit()


## First visit to a site pays once, ever: `Game.discovered` is saved with the run.
func _award_discovery(node: Interactable, reward: int) -> void:
	if not Game.discover(node.id):
		return
	travel_sites[node.id] = {
		"name": node.label,
		"x": node.global_position.x,
		"y": node.global_position.y,
	}
	Game.spirit_stones += reward
	Bus.toast.emit("Discovery — %s (+%d spirit stones)." % [node.label, reward])


# ------------------------------------------------------------- roots ----

## Appraises an unread root, then evolves it one tier for marrow and stones.
## Repeatable: the pavilion is not consumed, and the prompt is honest about why a
## step is unavailable.
func _use_root_pavilion() -> void:
	if player == null:
		return
	var cultivation := player.cultivation
	if not cultivation.identified:
		if Game.spirit_stones < Roots.IDENTIFY_COST:
			Bus.toast.emit("Appraisal costs %d spirit stones. You have %d." % [Roots.IDENTIFY_COST, Game.spirit_stones])
			return
		Game.spirit_stones -= Roots.IDENTIFY_COST
		cultivation.identified = true
		var before := cultivation.qi_max(player.stats)
		player.rebuild_stats()
		cultivation.qi = minf(cultivation.qi, cultivation.qi_max(player.stats))
		Bus.player_stats_changed.emit()
		Bus.cultivation_changed.emit()
		Bus.toast.emit("The pavilion reads your root: %s. Qi capacity %d -> %d." % [
			Roots.describe(cultivation.root_data(), cultivation.effective_purity()),
			int(before), int(cultivation.qi_max(player.stats)),
		])
		return

	var tier := cultivation.root_tier
	var check := Roots.can_evolve(tier, _marrow_count(), Game.spirit_stones)
	if not bool(check["ok"]):
		match String(check["reason"]):
			"max_tier":
				Bus.toast.emit("Your root is already at the twelfth tier.")
			"no_marrow":
				Bus.toast.emit("Evolution needs Spirit Root Marrow. Mines and ruins sometimes hold it.")
			"no_stones":
				Bus.toast.emit("Evolution costs %d spirit stones. You have %d." % [int(check["cost"]), Game.spirit_stones])
		return
	_consume_marrow()
	Game.spirit_stones -= int(check["cost"])
	cultivation.root_tier = mini(Roots.MAX_TIER, tier + 1)
	player.rebuild_stats()
	cultivation.qi = minf(cultivation.qi, cultivation.qi_max(player.stats))
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()
	Bus.toast.emit("Your root evolves — %s." % Roots.describe(cultivation.root_data(), cultivation.effective_purity()))


func _make_marrow() -> Dictionary:
	return {
		"id": "item.marrow.spirit.%d" % player.inventory.size(),
		"name": "Spirit Root Marrow",
		"base_name": "Spirit Root Marrow",
		"slot": "material",
		"ilvl": 3,
		"rarity": 2,
		"rarity_name": "Rare",
		"implicit": "Root evolution reagent",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 60,
	}


func _marrow_count() -> int:
	var count := 0
	for item in player.inventory:
		if String(item.get("id", "")).begins_with("item.marrow"):
			count += 1
	return count


func _consume_marrow() -> void:
	for i in player.inventory.size():
		if String(player.inventory[i].get("id", "")).begins_with("item.marrow"):
			player.inventory.remove_at(i)
			return


func _make_ore() -> Dictionary:
	return {
		"id": "item.ore.spirit.%d" % player.inventory.size(),
		"name": "Spirit Ore",
		"base_name": "Spirit Ore",
		"slot": "material",
		"ilvl": 2,
		"rarity": 1,
		"rarity_name": "Refined",
		"implicit": "Forging ingredient",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 22,
	}


func _make_herb() -> Dictionary:
	return {
		"id": "item.herb.spirit.%d" % player.inventory.size(),
		"name": "Spirit Herb",
		"base_name": "Spirit Herb",
		"slot": "material",
		"ilvl": 1,
		"rarity": 1,
		"rarity_name": "Refined",
		"implicit": "Alchemy ingredient",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 12,
	}


func _toast_new_objective() -> void:
	Bus.toast.emit("Quest — %s" % quests.objective_text())


func _grant_reward() -> void:
	if quests.rewarded:
		return
	quests.rewarded = true
	var reward: Dictionary = quests.quest.get("reward", {})
	var technique_id := String(reward.get("technique", ""))
	if player.learn_technique(technique_id):
		var tech: Dictionary = DB.technique(technique_id)
		Bus.toast.emit("Inherited technique: %s" % String(tech.get("name", technique_id)))
	var passive_id := String(reward.get("passive", ""))
	if player.add_passive(passive_id):
		var passive: Dictionary = DB.passive(passive_id)
		Bus.toast.emit("Passive awakened: %s" % String(passive.get("name", passive_id)))
	Game.spirit_stones += int(reward.get("spirit_stones", 0))
	Bus.player_stats_changed.emit()


func _claim_inheritance() -> void:
	if inheritance_taken:
		Bus.toast.emit("The altar is cold. Someone already took what it held.")
		return
	inheritance_taken = true
	realm_cleared = true
	if realm_instance != null:
		realm_instance.mark_cleared()
	var learned := player.learn_technique("tech.palm.thousand_petals")
	var gained := player.add_passive("passive.void_affinity")
	if learned:
		Bus.toast.emit("Inheritance: the Thousand Petal Illusion is yours.")
	if gained:
		Bus.toast.emit("Inheritance: Void Affinity awakens in your meridians.")
	var inherited := Physiques.inherited_for(player.physique_id, realm_seed)
	if player.inherit_physique(inherited):
		Bus.toast.emit("Inheritance: %s awakens in your bones." % Physiques.name_of(player.physique_id))
	elif not inherited.is_empty() and inherited == player.physique_id:
		Bus.toast.emit("The altar's body is no greater than the one you already carry.")
	if not learned and not gained:
		Bus.toast.emit("The altar yields nothing you can still use.")
	Bus.cultivation_changed.emit()


# --------------------------------------------------------- hidden realm ----

func _set_overworld_active(active: bool) -> void:
	chunks.visible = active
	chunks.set_props_visible(active)
	settlement.visible = active
	settlement.set_buildings_visible(active)
	for npc in npcs:
		if is_instance_valid(npc):
			npc.visible = active
			npc.set_physics_process(active)
	for node in interactables:
		if is_instance_valid(node):
			node.visible = active


func _enter_realm() -> void:
	if realm_instance != null:
		return
	if realm_seed == 0:
		var roll := float(Rng.roll_float("realm_seed", Game.kills, 0))
		realm_seed = 100000 + int(roll * 900000.0)
	_set_overworld_active(false)
	realm_instance = HiddenRealm.new()
	realm_instance.name = "HiddenRealm"
	realm_instance.entity_parent = world
	world.add_child(realm_instance)
	realm_instance.generate(realm_seed)
	if realm_cleared:
		realm_instance.mark_cleared()
	player.global_position = realm_instance.entry_position() + Vector2(0, 60)
	player.spawn_point = player.global_position
	phase = "realm"
	camera_rig.set_bounds(realm_instance.world_bounds())
	camera_rig.reset_smoothing()
	lighting.add_light(realm_instance, realm_instance.altar_position(), Color("#c9b6ff"), 320.0, 1.0)
	Bus.toast.emit("The rift closes behind you. The tomb does not want you here.")


func _exit_realm() -> void:
	if realm_instance == null:
		return
	realm_instance.cleanup()
	realm_instance.queue_free()
	realm_instance = null
	_set_overworld_active(true)
	phase = "play"
	player.global_position = portal_position + Vector2(-80, 40)
	player.spawn_point = player.global_position
	camera_rig.set_bounds(ChunkManager.world_bounds())
	camera_rig.reset_smoothing()
	Bus.toast.emit("You return to the Verdant Fringe.")


# ----------------------------------------------------------------- loot ----

func _try_pickup() -> void:
	var best_index := -1
	var best_dist := 70.0
	for i in ground_items.size():
		var entry: Dictionary = ground_items[i]
		var pos := Vector2(float(entry["x"]), float(entry["y"]))
		var dist := pos.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	if best_index < 0:
		return
	var picked: Dictionary = ground_items[best_index]
	ground_items.remove_at(best_index)
	player.pick_up(picked["item"])
	Bus.toast.emit("Picked up %s." % String(picked["item"].get("name", "item")))


func _on_weather_changed(weather: Dictionary) -> void:
	if player == null or phase == "creation":
		return
	Bus.toast.emit("The weather turns: %s." % String(weather.get("kind", "clear")).capitalize())


func _on_enemy_died(at: Vector2, ilvl: int) -> void:
	var generator := ItemGen.new(DB, Rng)
	var item := generator.generate(maxi(1, ilvl + player.cultivation.realm), Game.kills + 1000, ground_items.size())
	if not item.is_empty():
		ground_items.append({"x": at.x + 18.0, "y": at.y + 10.0, "item": item})
		Bus.item_dropped.emit(item, at)
	var before := quests.step_index
	quests.track("kill", "beast", 1)
	if quests.step_index != before:
		_toast_new_objective()


# ----------------------------------------------------------- save/load ----

func _save(slot: int) -> void:
	if phase == "realm":
		Bus.toast.emit("You cannot anchor a save inside a hidden realm.")
		return
	var data := {
		"version": "0.2.0",
		"clock": Clock.to_dict(),
		"game": Game.to_dict(),
		"player": player.to_dict(),
		"ground_items": ground_items,
		"quests": quests.to_dict(),
		"used_interactables": used_interactables.duplicate(),
		"chunk_deltas": world_delta.to_dict(),
		"shop": merchant.to_dict(),
		"travel_sites": travel_sites.duplicate(true),
		"waypoint": {"name": waypoint_name, "x": waypoint_position.x, "y": waypoint_position.y},
		"realm_seed": realm_seed,
		"realm_cleared": realm_cleared,
		"inheritance_taken": inheritance_taken,
	}
	if Save.save_game(slot, data):
		Log.info("scene", "saved slot %d" % slot)
		Bus.toast.emit("Saved to slot %d." % slot)
	else:
		Log.error("scene", "save failed for slot %d" % slot)
		Bus.toast.emit("Save failed.")


func _load_game(slot: int) -> void:
	var data: Dictionary = Save.load_game(slot)
	if data.is_empty():
		Bus.toast.emit("No usable save in slot %d." % slot)
		return
	if realm_instance != null:
		realm_instance.cleanup()
		realm_instance.queue_free()
		realm_instance = null
		_set_overworld_active(true)

	Game.from_dict(data.get("game", {}))
	Clock.from_dict(data.get("clock", {}))
	player.from_dict(data.get("player", {}))
	ground_items = data.get("ground_items", []).duplicate(true)
	quests.from_dict(data.get("quests", {}))
	used_interactables = data.get("used_interactables", []).duplicate()
	realm_seed = int(data.get("realm_seed", 0))
	realm_cleared = bool(data.get("realm_cleared", false))
	inheritance_taken = bool(data.get("inheritance_taken", false))
	world_delta = WorldDelta.from_dict(data.get("chunk_deltas", {}))
	chunks.delta = world_delta
	merchant.from_dict(data.get("shop", {}))
	travel_sites = data.get("travel_sites", {}).duplicate(true)
	var waypoint: Dictionary = data.get("waypoint", {})
	waypoint_name = String(waypoint.get("name", ""))
	waypoint_position = Vector2(float(waypoint.get("x", 0.0)), float(waypoint.get("y", 0.0)))
	for node in interactables:
		if used_interactables.has(node.id):
			node.used = true
	# Rebuild the province so loaded deltas decide which resources exist.
	chunks.today = Clock.day
	chunks.resync(player.global_position)
	phase = "play"
	Log.info("scene", "loaded slot %d" % slot)
	Bus.toast.emit("Loaded slot %d." % slot)


func _draw() -> void:
	# The province chunks draw the ground; this only marks the settlement gate
	# so the market is findable from the road.
	if settlement != null:
		draw_string(ThemeDB.fallback_font, settlement.position_for("gate") + Vector2(-70, -34),
			"AZURE CLOUD MARKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c8d4da"))
