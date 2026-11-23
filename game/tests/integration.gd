extends Node
## Integration test: drives the real main scene through the whole milestone.
##
## Creation and allocation, the streamed province, a scheduled settlement,
## combat and loot, the Azure Cloud questline end to end, the hidden realm with
## its inheritance, and a save/load cycle — all in gameplay code.
##
##   godot --headless --path game res://tests/integration.tscn

var _pass := 0
var _fail := 0
var _failures: Array = []
var _toasts: Array = []
var main: Node2D


func _ready() -> void:
	print("=== Eternal Ascension — integration test ===")
	Bus.toast.connect(_record_toast)
	await _run()
	print("-----------------------------------------------")
	print("RESULT: PASS %d / FAIL %d" % [_pass, _fail])
	for failure in _failures:
		print("  FAILED: " + String(failure))
	get_tree().quit(1 if _fail > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
	else:
		_fail += 1
		_failures.append(label)
		push_error("FAIL: " + label)


func _find_interactable(nodes: Array, id: String) -> Interactable:
	for node in nodes:
		if is_instance_valid(node) and node is Interactable and node.id == id:
			return node as Interactable
	return null


func _record_toast(text: String) -> void:
	_toasts.append(text)


func approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	add_child(main)
	await frames(3)
	Clock.paused = true
	Clock.hour = 10.0

	var player: Player = Game.player as Player
	check(player != null, "main scene spawns a player")
	check(main.hud != null, "main scene builds a HUD")
	check(String(main.phase) == "creation", "the run starts at character creation")

	# --- creation and allocation --------------------------------------------
	check(int(main.allocation_remaining()) == int(main.FORMATION_POINTS), "formation points start unspent")
	check(main.allocate_attribute("str"), "a point can be assigned")
	check(player.attrs.get_attr("str") == 11, "assigning a point raises the attribute")
	check(int(main.allocation_remaining()) == int(main.FORMATION_POINTS) - 1, "points decrease on assignment")
	check(main.refund_attribute(), "a point can be refunded")
	check(player.attrs.get_attr("str") == 10, "refunding restores the attribute")
	main.allocate_attribute("wis")
	main.allocate_attribute("int")
	check(int(main.allocation_remaining()) == int(main.FORMATION_POINTS) - 2, "multiple points can be spent")
	check(player.stats.max_qi_mult() > 1.0, "allocated WIS immediately affects derived stats")

	main._begin_run()
	check(String(main.phase) == "play", "accepting creation begins play")
	check(player.hp == player.hp_max, "the run starts at full health")

	# --- province and settlement --------------------------------------------
	check(main.chunks.chunk_count() == 25, "a ring of chunks streams around the player (%d)" % main.chunks.chunk_count())
	check(main.npcs.size() >= 15, "the settlement is populated with 15+ NPCs (%d)" % main.npcs.size())
	check(main.interactables.size() >= 5, "world interactables exist (shrine, herbs, rift)")
	check(not main.elder == null, "the quest giver exists")

	# --- continent geography --------------------------------------------------
	check(not main.continent.is_empty(), "the run has a continent")
	check(Continent.region_for_world_position(player.global_position) == int(main.continent["capital"]), "the playable province is the capital region")
	check(bool(Continent.region_by_index(main.continent, int(main.continent["capital"]))["capital"]), "the capital region is marked on the continent")
	check(main.world_map != null, "the run owns a continent map")
	check(not main.world_map.visible, "the map starts closed")
	main.toggle_map()
	check(main.world_map.visible, "the map opens")
	check(main.world_map.region_count() == (main.continent["regions"] as Array).size(), "the map shows every region")
	check(not player.is_physics_processing(), "the map freezes the player")
	main.toggle_map()
	check(not main.world_map.visible, "the map closes")
	check(player.is_physics_processing() and player.is_processing(), "closing the map restores the player")

	# --- biomes --------------------------------------------------------------
	check(main.chunks.biome_defs.size() == DB.biomes.size(), "the streamer holds a biome snapshot")
	check(main.current_biome_name() != "", "the world reports its biome")
	var home_chunk: Vector2i = main.chunks.world_to_chunk(player.global_position)
	var home_biome: Dictionary = DB.biome(Biome.for_chunk(home_chunk, Game.world_seed))
	check(not home_biome.is_empty(), "the chunk under the player has a biome definition")
	check(String(home_biome["name"]) == main.current_biome_name(), "the HUD biome matches the chunk biome")
	check(Biome.for_chunk(home_chunk, Game.world_seed) == Biome.BANDS[0], "the settlement sits in the starting biome")

	var sample_coords: Array = main.chunks.chunks.keys()
	var sample_chunk = main.chunks.chunks[sample_coords[0]]
	check(String(sample_chunk.biome) != "", "streamed chunks carry their biome")
	check(not (sample_chunk.palette as Array).is_empty(), "streamed chunks carry a biome palette")
	var resolved := 0
	for coord in main.chunks.chunks.keys():
		var chunk = main.chunks.chunks[coord]
		if not DB.biome(String(chunk.biome)).is_empty():
			resolved += 1
	check(resolved == main.chunks.chunk_count(), "every streamed chunk resolves to a real biome (%d)" % resolved)

	var frost_enemy := Biome.pick_enemy(DB.biome("biome.frost"), Rng.stream("biome_probe", 1))
	check(not frost_enemy.is_empty(), "a biome enemy can be drawn")
	var probe := Dummy.new()
	main.world.add_child(probe)
	probe.apply_biome_enemy(frost_enemy, 1)
	check(probe.display_name == String(frost_enemy["name"]), "a biome enemy names its dummy")
	check(probe.ilvl >= 1 and probe.hp_max > 0.0 and probe.damage > 0.0, "a biome enemy scales its stats")
	probe.queue_free()

	# --- settlement services -------------------------------------------------
	var stall: Interactable = null
	var inn: Interactable = null
	for node in main.interactables:
		if not is_instance_valid(node) or not node is Interactable:
			continue
		if node.kind == Interactable.Kind.SHOP:
			stall = node as Interactable
		elif node.kind == Interactable.Kind.INN:
			inn = node as Interactable
	check(stall != null, "the market has a merchant stall")
	check(inn != null, "the tavern has an inn counter")

	Game.spirit_stones = 500
	main._open_shop()
	check(main.shop_open, "the shop opens")
	check(main.shop_panel.visible, "the shop panel is shown")
	check(not player.is_physics_processing(), "the shop freezes the player")
	check(main.merchant.stock.size() > 0, "the merchant has stock")

	var stones_before: int = Game.spirit_stones
	var bag_before: int = player.inventory.size()
	var price: int = Economy.buy_price(main.merchant.stock[0])
	main._buy_index(0)
	check(Game.spirit_stones == stones_before - price, "buying deducts the price")
	check(player.inventory.size() == bag_before + 1, "buying adds the item")
	var stock_after: int = main.merchant.stock.size()
	main._buy_index(0)
	check(main.merchant.stock.size() == stock_after - 1, "each purchase removes one item")

	Game.spirit_stones = 0
	var blocked_before: int = player.inventory.size()
	main._buy_index(0)
	check(player.inventory.size() == blocked_before, "an unaffordable purchase changes nothing")

	main._show_shop("sell")
	check(main.shop_panel.mode == "sell", "the shop switches to selling")
	var sell_stones: int = Game.spirit_stones
	var sell_index: int = player.inventory.size() - 1
	var sell_expected := Economy.sell_price(player.inventory[sell_index])
	main._sell_index(sell_index)
	check(Game.spirit_stones == sell_stones + sell_expected, "selling pays the sell price")
	check(player.inventory.size() == sell_index, "selling removes the item")
	main._close_shop()
	check(not main.shop_open and not main.shop_panel.visible, "the shop closes")
	check(player.is_physics_processing(), "closing the shop restores the player")

	# The inn: pay, heal, lose eight hours.
	Game.spirit_stones = Economy.rest_cost() * 2
	player.hp = 10.0
	var rest_day: int = Clock.day
	var rest_hour: float = Clock.hour
	main._rest_at_inn()
	check(player.hp == player.hp_max, "resting restores health")
	check(Game.spirit_stones == Economy.rest_cost(), "resting costs spirit stones")
	check(Clock.day > rest_day or Clock.hour > rest_hour, "resting advances the clock")
	Clock.day = rest_day
	Clock.hour = rest_hour

	# The purchase record travels with the save.
	Game.spirit_stones = 300
	main._open_shop()
	main._buy_index(0)
	var bought_id := String(player.inventory[player.inventory.size() - 1].get("id", ""))
	main._close_shop()
	main._save(94)
	main._load_game(94)
	await frames(2)
	main._open_shop()
	check(main.merchant.sold.has(bought_id), "bought goods stay sold across a save")
	var still_listed := false
	for item in main.merchant.stock:
		if String(item.get("id", "")) == bought_id:
			still_listed = true
	check(not still_listed, "a reloaded shop does not list what was bought")
	main._close_shop()
	Game.spirit_stones = 500

	var npc: Npc = main.npcs[0]
	check(npc.animator != null, "scheduled NPCs own an animator")
	await frames(3)
	check(npc.current_activity != "idle" or npc.current_location != "", "NPCs resolve a scheduled activity")

	var start_chunk: Vector2i = main.chunks.world_to_chunk(player.global_position)
	player.global_position += Vector2(2400, 0)
	await frames(2)
	main.chunks.settle()
	check(main.chunks.world_to_chunk(player.global_position) != start_chunk, "walking streams a different part of the province")
	check(main.chunks.chunk_count() == 25, "streaming stays bounded while travelling")
	# --- rendering: camera, sorting, occlusion, lighting, scaling ------------
	check(main.world != null and main.world.y_sort_enabled, "the world root Y-sorts its children")
	check(player.get_parent() == main.world, "the player sorts with the world")
	check(main.camera_rig != null, "the player owns a camera rig")
	check(main.camera_rig.limit_right == int(ChunkManager.world_bounds().end.x), "camera bounds cover the whole province")
	check(main.camera_rig.limit_bottom == int(ChunkManager.world_bounds().end.y), "camera bounds cover the province vertically")
	check(main.camera_rig.zoom.x >= CameraRig.MIN_ZOOM and main.camera_rig.zoom.x <= CameraRig.MAX_ZOOM, "camera zoom starts inside its range")
	var zoom_before: float = main.camera_rig.zoom.x
	main.camera_rig.zoom_in()
	check(main.camera_rig.zoom.x > zoom_before, "zooming in changes the camera")
	main.camera_rig.zoom_out()
	check(approx(main.camera_rig.zoom.x, zoom_before), "zooming back out restores the camera")
	check(main.chunks.props.size() == 25 * ChunkManager.ProvinceChunk.FEATURES, "streamed props are live in the world (%d)" % main.chunks.props.size())
	check(main.settlement.buildings.size() == main.settlement.BUILDINGS.size(), "every settlement building is its own node")
	check(main.settlement.buildings[0].get_parent() == main.world, "buildings sort with the player")

	var building: Building = main.settlement.buildings[0]
	var behind := building.world_footprint().get_center()
	player.global_position = behind
	await frames(20)
	check(building.modulate.a < 0.6, "a roof fades while the player stands behind it (a=%.2f)" % building.modulate.a)
	player.global_position = behind + Vector2(0, 900)
	await frames(20)
	check(building.modulate.a > 0.9, "the roof is opaque again when the player leaves")

	check(main.lighting != null, "the world has a lighting rig")
	Clock.hour = 23.0
	await frames(2)
	var night_tint: Color = Climate.lighting_modulate(Clock.ambient_for_hour(23.0), Weather.current)
	check(main.lighting.color == night_tint or (Weather.flash_strength() > 0.0 and main.lighting.color.r >= night_tint.r), "ambient light follows the clock and weather")
	check(main.lighting.color.b > main.lighting.color.r, "night light stays cool")
	check(main.lighting.lights.size() >= 2, "shrine and rift lights exist")
	var dimmest := 1.0
	for light in main.lighting.lights:
		dimmest = minf(dimmest, float(light.energy))
	check(dimmest > 0.5, "point lights are lit at night")
	Clock.hour = 12.0
	await frames(2)
	check(approx(float(main.lighting.lights[0].energy), 0.0), "point lights switch off at noon")
	Clock.hour = 10.0

	check(get_window().content_scale_size == DisplayPolicy.BASE_SIZE, "resolution scaling uses the authored base size")
	check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "resolution scaling stretches canvas items")

	player.global_position = main.settlement.position_for("plaza")

	# --- controller: acceleration curve and sprint ---------------------------
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 220)
	player.velocity = Vector2.ZERO
	check(InputMap.has_action("sprint"), "sprint is a registered action")
	var stick_bound := false
	for ev in InputMap.action_get_events("move_right"):
		if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_LEFT_X:
			stick_bound = true
	check(stick_bound, "the left stick is bound to movement")
	Input.action_press("move_right")
	await frames(2)
	var early_speed: float = player.velocity.length()
	await frames(16)
	var cruise: float = player.velocity.length()
	check(early_speed > 0.0 and early_speed < cruise, "movement accelerates instead of snapping (%.0f -> %.0f)" % [early_speed, cruise])
	check(approx(cruise, player.stats.move_speed(), 1.0), "cruising speed matches the stat block")
	Input.action_press("sprint")
	await frames(20)
	check(player.velocity.length() > cruise * 1.2, "sprinting raises the top speed")
	check(player.is_sprinting(), "the player reports sprinting")
	Input.action_release("sprint")
	Input.action_release("move_right")
	await frames(20)
	check(player.velocity.length() < cruise * 0.2, "releasing input decelerates the player")
	check(not player.is_sprinting(), "sprint clears when input stops")
	player.global_position = main.settlement.position_for("plaza")

	# --- animation -----------------------------------------------------------
	check(player.animator != null, "the player owns an animator")
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 220)
	player.velocity = Vector2.ZERO
	await frames(3)
	check(player.animator.state == "idle", "a standing player animates idle")
	Input.action_press("move_right")
	await frames(10)
	check(player.animator.state == "run" or player.animator.state == "walk", "moving switches the player clip (%s)" % player.animator.state)
	Input.action_press("sprint")
	await frames(10)
	check(player.animator.state == "sprint", "sprinting switches to the sprint clip")
	Input.action_release("sprint")
	Input.action_release("move_right")
	player.velocity = Vector2.ZERO
	await frames(3)
	check(player.animator.state == "idle", "stopping returns the player to idle")
	player.global_position = main.settlement.position_for("plaza")

	# --- combat --------------------------------------------------------------
	var dummy := Dummy.new()
	dummy.ilvl = 1
	dummy.aggressive = false
	main.add_child(dummy)
	dummy.global_position = player.global_position + Vector2(36, 0)
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player._facing = Vector2.RIGHT
	var hp_before := dummy.hp
	check(dummy.animator != null, "enemies own an animator")
	player.try_attack()
	await frames(1)
	check(player.animator.state == "attack", "attacking switches to the attack clip")
	check(player._attack_swing() <= 0.0, "the wind-up pose is drawn back before the strike")
	var aim: Vector2 = player._facing.normalized()
	dummy.global_position = player.global_position + aim * 36.0
	await frames(30)
	check(is_instance_valid(dummy) and dummy.hp < hp_before, "an attack damages an enemy through the frame machine")
	check(player._attack_state == "idle", "the attack state machine returns to idle")
	check(player.animator.state == "idle", "the player returns to an idle clip after the attack")

	# --- questline -----------------------------------------------------------
	player.global_position = main.elder.global_position
	main._try_interact()
	check(main.quests.step_index == 1, "talking to Elder Bai starts the quest")

	player._current_technique = DB.technique("tech.sword.azure_cleave")
	var kills_before := Game.kills
	for n in 3:
		var target := Dummy.new()
		target.ilvl = 1
		target.aggressive = false
		main.add_child(target)
		target.global_position = player.global_position + Vector2(36, 0)
		for hit in 8:
			if is_instance_valid(target):
				target.global_position = player.global_position + Vector2(36, 0)
				player._facing = Vector2.RIGHT
				player._strike()
			await get_tree().physics_frame
	check(Game.kills >= kills_before + 3, "three beasts can be killed in play")
	check(main.quests.step_index == 2, "the kill objective advances the quest")
	check(main.ground_items.size() > 0, "kills drop loot")

	if main.ground_items.size() > 0:
		var entry: Dictionary = main.ground_items[0]
		player.global_position = Vector2(float(entry["x"]), float(entry["y"]))
		var inventory_before := player.inventory.size()
		main._try_pickup()
		check(player.inventory.size() == inventory_before + 1, "dropped loot can be picked up")

	var herbs := 0
	for node in main.interactables:
		if node.kind == Interactable.Kind.HERB and herbs < 2:
			player.global_position = node.global_position
			main._try_interact()
			herbs += 1
			await get_tree().physics_frame
	check(herbs == 2, "two herb nodes exist and can be gathered")
	check(main.quests.step_index == 3, "gathering herbs advances the quest")

	for node in main.interactables:
		if node.kind == Interactable.Kind.SHRINE:
			player.global_position = node.global_position
			main._try_interact()
	check(main.quests.step_index == 4, "attuning at the shrine advances the quest")

	player.global_position = main.elder.global_position
	main._try_interact()
	check(main.quests.completed, "returning to Elder Bai completes the quest")
	check(player.passives.has("passive.heavenly_qi_absorption"), "the quest grants its passive")
	check(player.technique_ids.has("tech.palm.azure_cloud"), "the quest grants its technique")
	check(Game.spirit_stones >= 120, "the quest grants spirit stones")

	# --- hidden realm --------------------------------------------------------
	main._enter_realm()
	await frames(3)
	check(String(main.phase) == "realm", "the rift enters the hidden realm")
	check(main.realm_instance != null, "a hidden realm instance exists")
	check(not main.chunks.visible, "the overworld is hidden inside the realm")
	check(not main.chunks.props[0].visible, "streamed props hide with the overworld")
	check(not main.settlement.buildings[0].visible, "buildings hide inside the realm")
	check(main.camera_rig.limit_right == int(main.realm_instance.world_bounds().end.x), "camera bounds follow the realm")

	var exit_node: Interactable = null
	var altar: Interactable = null
	for node in main.realm_instance.interactables:
		if node.id == "realm.exit":
			exit_node = node
		elif node.id == "realm.altar":
			altar = node
	check(exit_node != null, "the realm has an exit")
	check(altar != null, "the realm has an inheritance altar")
	check(exit_node.get_parent() == main.world, "realm interactables sort with the world")
	check(main.realm_instance.all_rooms_reachable(), "every room of the generated realm is reachable")

	player.global_position = altar.global_position
	main._try_interact()
	check(main.inheritance_taken, "the altar grants an inheritance")
	check(player.passives.has("passive.void_affinity"), "the inheritance grants a passive")
	check(player.technique_ids.has("tech.palm.thousand_petals"), "the inheritance grants a hidden technique")

	player.global_position = exit_node.global_position
	main._try_interact()
	await frames(3)
	check(String(main.phase) == "play", "the exit returns to the overworld")
	check(main.realm_instance == null, "the realm instance is released")
	check(main.chunks.visible, "the overworld is visible again")
	check(main.chunks.props[0].visible, "streamed props return with the overworld")
	check(main.camera_rig.limit_right == int(ChunkManager.world_bounds().end.x), "camera bounds return to the province")

	# --- interaction: doors, containers, manuals, examination ----------------
	var container: Interactable = null
	var manual_node: Interactable = null
	var door: Interactable = null
	var inspectable: Interactable = null
	for node in main.interactables:
		match node.kind:
			Interactable.Kind.CONTAINER:
				if container == null:
					container = node
			Interactable.Kind.MANUAL:
				manual_node = node
			Interactable.Kind.DOOR:
				if door == null:
					door = node
			Interactable.Kind.EXAMINE:
				if inspectable == null:
					inspectable = node
	check(container != null, "the settlement has containers")
	check(manual_node != null, "the settlement has a manual")
	check(door != null, "the settlement has doors")
	check(inspectable != null, "the settlement has examinable objects")
	check(main.interactables.size() >= 16, "the interaction set grew to %d nodes" % main.interactables.size())

	var loot_before: int = main.ground_items.size()
	main._use_interactable(container)
	check(main.ground_items.size() == loot_before + 1, "searching a container drops loot")
	check(container.used and not container.can_interact(), "a searched container is spent")
	main._use_interactable(container)
	check(main.ground_items.size() == loot_before + 1, "a container cannot be looted twice")

	check(not manual_node.used, "the manual starts unread")
	main._use_interactable(manual_node)
	check(player.technique_ids.has("tech.blood.crimson_moon"), "reading a manual teaches its technique")
	check(manual_node.used and not manual_node.can_interact(), "a studied manual is spent")

	check(not door.open, "doors start closed")
	var door_building: Building = door.building
	main._use_interactable(door)
	check(door.open, "a door opens")
	check(door_building.interior_open, "an open door exposes the interior")
	main._use_interactable(door)
	check(not door.open and not door_building.interior_open, "a door closes again")

	var toasts_before: int = _toasts.size()
	main._use_interactable(inspectable)
	check(_toasts.size() > toasts_before, "examining produces a description")
	check(inspectable.can_interact(), "examination is repeatable")

	# --- climate: seasons, weather and their effects --------------------------
	check(Weather.current.has("kind"), "the weather system resolved a sky")
	check(Climate.KINDS.has(Weather.kind()), "the live weather is a known kind")
	check(not Weather.label().is_empty(), "the HUD has a season and weather label")
	check(Weather.label().contains(Weather.season_name()), "the weather label names the season")
	check(approx(player.environment_bonus(), Climate.cultivation_bonus(Weather.current), 0.0001), "cultivation reads the live weather")

	var expected_light: Color = Climate.lighting_modulate(Clock.ambient_for_hour(Clock.hour), Weather.current)
	if Weather.flash_strength() == 0.0:
		check(main.lighting.color.is_equal_approx(expected_light), "the world light carries the weather")
	else:
		check(main.lighting.color.r >= expected_light.r, "a storm flash brightens the weather light")

	var day_before: int = Clock.day
	var hour_before: float = Clock.hour
	Clock.day = 91
	Clock.hour = 3.0
	await frames(2)
	check(Weather.season_name() == "Winter", "reaching day ninety-one brings winter")
	check(int(Weather.current["day"]) == 91, "the weather follows the clock")
	Clock.day = day_before
	Clock.hour = hour_before
	await frames(2)
	check(Weather.season_name() == Climate.season_name(Climate.season_for_day(day_before)), "restoring the clock restores the season")

	# --- streaming: chunk deltas, regrowth and threaded generation -----------
	await frames(2)
	main.chunks.settle()
	check(main.chunks.threaded, "chunk payloads generate on worker threads")
	check(main.world_delta != null, "the run owns a chunk delta store")

	var chunk_herb: Interactable = null
	for node in main.interactables:
		if is_instance_valid(node) and node is Interactable and node.chunk_owned:
			chunk_herb = node as Interactable
			break
	check(chunk_herb != null, "streamed chunks grow herbs (%d resources)" % main.chunks.resource_count())
	check(chunk_herb == null or chunk_herb.id.begins_with("herb.chunk."), "streamed herb ids are namespaced")

	var herb_id: String = chunk_herb.id
	var herb_coord: Vector2i = chunk_herb.chunk_coord
	var home: Vector2 = player.global_position
	player.global_position = chunk_herb.global_position
	main._use_interactable(chunk_herb)
	check(chunk_herb.used, "a streamed herb can be gathered")
	check(main.world_delta.is_spent(herb_coord, herb_id, Clock.day), "gathering records a chunk delta")

	# Leave the ring entirely, then return: the chunk regenerates from the seed.
	player.global_position = Vector2(12200, 12200)
	await frames(2)
	main.chunks.settle()
	check(main.chunks.chunk_count() < 25, "the province edge streams fewer chunks (%d)" % main.chunks.chunk_count())
	player.global_position = home
	await frames(2)
	main.chunks.settle()
	check(_find_interactable(main.interactables, herb_id) == null, "a harvested herb does not stream back in")

	var stale := 0
	for node in main.interactables:
		if not is_instance_valid(node):
			stale += 1
	check(stale == 0, "freed chunk resources leave the interactable list")

	var day_before_chunks: int = Clock.day
	Clock.day = day_before_chunks + WorldDelta.HERB_REGROW_DAYS
	player.global_position = Vector2(12200, 12200)
	await frames(2)
	main.chunks.settle()
	player.global_position = home
	await frames(2)
	main.chunks.settle()
	var regrown: Interactable = _find_interactable(main.interactables, herb_id)
	check(regrown != null, "a harvested herb returns after its regrow window")
	check(regrown == null or regrown.can_interact(), "a regrown herb can be gathered again")
	Clock.day = day_before_chunks

	# Deltas belong to the run, so they travel through a save.
	var kept: Interactable = null
	for node in main.interactables:
		if is_instance_valid(node) and node is Interactable and node.chunk_owned and node.can_interact():
			kept = node as Interactable
			break
	check(kept != null, "another streamed herb is available to keep")
	if kept != null:
		player.global_position = kept.global_position
		var kept_id: String = kept.id
		var kept_coord: Vector2i = kept.chunk_coord
		main._use_interactable(kept)
		main._save(95)
		main._load_game(95)
		await frames(2)
		main.chunks.settle()
		check(main.world_delta.is_spent(kept_coord, kept_id, Clock.day), "chunk deltas survive save and load")
		check(_find_interactable(main.interactables, kept_id) == null, "a harvested herb stays gone after loading")
	player.global_position = home
	await frames(2)
	main.chunks.settle()

	# --- world locations: ruins, mines and deposits --------------------------
	await frames(2)
	main.chunks.settle()
	var poi: Interactable = null
	for node in main.interactables:
		if not is_instance_valid(node) or not node is Interactable:
			continue
		if node.kind in [Interactable.Kind.RUIN, Interactable.Kind.MINE, Interactable.Kind.DEPOSIT]:
			poi = node as Interactable
			break
	check(poi != null, "the overworld contains ruins, mines or deposits")
	var poi_id := ""
	var poi_window := 0
	var poi_coord := Vector2i.ZERO
	if poi != null:
		poi_id = poi.id
		poi_window = poi.regrow_days
		poi_coord = poi.chunk_coord
		var stones_before_site: int = Game.spirit_stones
		player.global_position = poi.global_position
		main._use_interactable(poi)
		check(not poi.can_interact(), "a searched site is spent")
		check(main.world_delta.is_spent(poi_coord, poi_id, Clock.day), "a searched site records a chunk delta")
		check(Game.discovered.has(poi_id), "a first visit is a discovery")
		check(Game.spirit_stones > stones_before_site, "a discovery pays spirit stones")
		var kept_stones: int = Game.spirit_stones
		main._award_discovery(poi, 99)
		check(Game.spirit_stones == kept_stones, "a discovery is rewarded only once")

		main._save(93)
		main._load_game(93)
		await frames(2)
		main.chunks.settle()
		check(Game.discovered.has(poi_id), "discoveries survive save and load")
		check(main.world_delta.is_spent(poi_coord, poi_id, Clock.day), "a searched site stays spent after loading")

		var step: int = mini(poi_window, 5000)
		Clock.day += step
		player.global_position = Vector2(12200, 12200)
		await frames(2)
		main.chunks.settle()
		player.global_position = home
		await frames(2)
		main.chunks.settle()
		var back: Interactable = _find_interactable(main.interactables, poi_id)
		if poi_window == WorldDelta.PERMANENT:
			check(back == null, "a searched ruin never comes back")
		else:
			check(back != null, "a mine or deposit refills after its window")
		Clock.day -= step

	# --- save / load ---------------------------------------------------------
	Save.delete_slot(96)
	player.cultivation.qi = 12.0
	main._save(96)
	check(Save.has_save(96), "quick save writes through the scene")

	var saved_passives := player.passives.size()
	var saved_stones := Game.spirit_stones
	player.passives.clear()
	player.rebuild_stats()
	main.quests.step_index = 0
	main.quests.completed = false
	main.inheritance_taken = false
	Game.spirit_stones = 0
	main._load_game(96)
	check(absf(player.cultivation.qi - 12.0) < 0.01, "quick load restores Qi")
	check(player.passives.size() == saved_passives, "quick load restores passives")
	check(main.quests.completed, "quick load restores quest completion")
	check(main.inheritance_taken, "quick load restores the inheritance")
	check(Game.spirit_stones == saved_stones, "quick load restores spirit stones")
	check(container.used, "a searched container stays spent after loading")
	check(player.technique_ids.has("tech.blood.crimson_moon"), "a manual's technique survives a reload")
	Save.delete_slot(96)

	main.queue_free()
	await get_tree().process_frame
