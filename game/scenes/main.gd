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
var interactables: Array = []
var ground_items: Array = []
var quests: QuestLog
var realm_instance: HiddenRealm = null
var realm_seed := 0
var realm_cleared := false
var inheritance_taken := false
var portal_position := Vector2.ZERO
var used_interactables: Array = []

var _allocation_spent := 0
var _allocation_history: Array = []
var _root_rng: RandomNumberGenerator
var _name_rng: RandomNumberGenerator
var _used_names: Dictionary = {}
var _spawn_timer := 0.0
var _help_visible := true
var _hazard_accum := 0.0
var _npc_index := 0


func _ready() -> void:
	Game.new_run()
	DisplayPolicy.apply(get_window())
	get_window().size_changed.connect(_on_window_resized)
	_root_rng = Rng.stream("root_roll", 0)
	_name_rng = Rng.stream("npc_names", 0)
	quests = QuestLog.new()
	_build_world()
	_spawn_player()
	_build_hud()
	Bus.enemy_died.connect(_on_enemy_died)
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
	chunks.configure(Game.world_seed)
	chunks.set_prop_parent(world)
	chunks.stream_around(SPAWN)

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


func _spawn_npcs() -> void:
	var schedules: Dictionary = DB.schedules()
	elder = _make_npc("elder_bai", "Elder Bai Qing", "Elder", "sect.azure_cloud",
		4, schedules.get("elder", []), Vector2(-30, 40))

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
	phase = "play"
	player.rebuild_stats()
	player.hp = player.hp_max
	player.spawn_point = settlement.position_for("plaza")
	Bus.toast.emit("Azure Cloud Market. Elder Bai waits by the sect hall.")


# --------------------------------------------------------------- loop ----

func _process(delta: float) -> void:
	if player == null:
		return
	# The province is hidden inside a realm: streaming there would load chunks
	# for tomb coordinates and spawn props under the tomb floor.
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
					player.take_hit(_hazard_accum, player.global_position)
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
	var dummy := Dummy.new()
	dummy.ilvl = maxi(1, player.cultivation.realm)
	dummy.position = settlement.position_for("plaza") + Vector2(cos(angle), sin(angle)) * distance
	world.add_child(dummy)


func _on_window_resized() -> void:
	DisplayPolicy.apply(get_window())


func _unhandled_input(event: InputEvent) -> void:
	if phase == "creation":
		if event.is_action_pressed("accept"):
			_begin_run()
		elif event.is_action_pressed("reroll"):
			player.cultivation.root_tier = _roll_root()
			player.rebuild_stats()
			Bus.cultivation_changed.emit()
			Bus.toast.emit("Your root shifts.")
		elif event.is_action_pressed("undo_point"):
			refund_attribute()
		else:
			for i in Attributes.KEYS.size():
				if event.is_action_pressed("skill_%d" % (i + 1)):
					allocate_attribute(Attributes.KEYS[i])
		return

	if event.is_action_pressed("quick_save"):
		_save(1)
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
		if not is_instance_valid(node) or node.used and node.kind == Interactable.Kind.HERB:
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


func _talk(npc: Npc) -> void:
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
			node.used = true
			if not used_interactables.has(node.id):
				used_interactables.append(node.id)
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
			node.used = true
			if not used_interactables.has(node.id):
				used_interactables.append(node.id)
			var generator := ItemGen.new(DB, Rng)
			var item := generator.generate(6, hash(node.id), ground_items.size(), 2)
			if not item.is_empty():
				ground_items.append({"x": node.global_position.x, "y": node.global_position.y + 30.0, "item": item})
				Bus.item_dropped.emit(item, node.global_position)
				Bus.toast.emit("The chest opens: %s" % String(item.get("name", "?")))
		Interactable.Kind.ALTAR:
			_claim_inheritance()


func cultivation_restore() -> void:
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	Bus.cultivation_changed.emit()


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
	for node in interactables:
		if used_interactables.has(node.id):
			node.used = true
	phase = "play"
	Log.info("scene", "loaded slot %d" % slot)
	Bus.toast.emit("Loaded slot %d." % slot)


func _draw() -> void:
	# The province chunks draw the ground; this only marks the settlement gate
	# so the market is findable from the road.
	if settlement != null:
		draw_string(ThemeDB.fallback_font, settlement.position_for("gate") + Vector2(-70, -34),
			"AZURE CLOUD MARKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c8d4da"))
