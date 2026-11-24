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
var _tribulation_result: Dictionary = {}
## Status ids reported by the damage-over-time path, for the polish checks.
var _status_ticks: Array = []
var main: Node2D


func _ready() -> void:
	print("=== Eternal Ascension — integration test ===")
	Bus.toast.connect(_record_toast)
	Bus.tribulation_finished.connect(_record_tribulation)
	Bus.status_ticked.connect(_record_status_tick)
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


func _record_tribulation(result: Dictionary) -> void:
	_tribulation_result = result.duplicate(true)


func _record_status_tick(_target: Node, id: String, _amount: float) -> void:
	_status_ticks.append(id)


func approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Select a technique by stable id, granting it if the scenario needs it.
func _tech_index(player: Player, id: String) -> int:
	if not player.technique_ids.has(id):
		player.learn_technique(id)
	return player.technique_ids.find(id)


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
	var bag_before: int = Items.total_count(player.inventory)
	var price: int = Economy.buy_price(main.merchant.stock[0])
	main._buy_index(0)
	check(Game.spirit_stones == stones_before - price, "buying deducts the price")
	check(Items.total_count(player.inventory) == bag_before + 1, "buying adds the item")
	var stock_after: int = main.merchant.stock.size()
	main._buy_index(0)
	check(main.merchant.stock.size() == stock_after - 1, "each purchase removes one item")

	Game.spirit_stones = 0
	var blocked_before: int = Items.total_count(player.inventory)
	main._buy_index(0)
	check(Items.total_count(player.inventory) == blocked_before, "an unaffordable purchase changes nothing")

	main._show_shop("sell")
	check(main.shop_panel.mode == "sell", "the shop switches to selling")
	var sell_stones: int = Game.spirit_stones
	var sell_index: int = player.inventory.size() - 1
	var sell_entry: Dictionary = player.inventory[sell_index]
	var sell_expected := Economy.sell_value(sell_entry)
	var sell_count := int(sell_entry.get("count", 1))
	var bag_at_sale: int = Items.total_count(player.inventory)
	main._sell_index(sell_index)
	check(Game.spirit_stones == sell_stones + sell_expected, "selling pays for the whole stack")
	check(Items.total_count(player.inventory) == bag_at_sale - sell_count, "selling removes the stack")
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
	var bought_id := String(main.merchant.stock[0].get("id", ""))
	main._buy_index(0)
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

	player._current_attack = DB.technique("tech.sword.azure_cleave")
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
		var inventory_before := Items.total_count(player.inventory)
		main._try_pickup()
		check(Items.total_count(player.inventory) == inventory_before + 1, "dropped loot can be picked up")

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

	# The altar is gated by the tomb's warden. Claiming must fail while it lives,
	# and the kill must be remembered so a later visit is not gated again.
	check(main.realm_instance.has_warden(), "the tomb posts a warden before the altar")
	var warden: Dummy = main.realm_instance.warden
	check(warden.is_boss and warden.boss_id == "boss.tomb_warden", "the warden is a boss body")
	player.global_position = altar.global_position
	main._try_interact()
	check(not main.inheritance_taken, "the altar refuses while the warden lives")
	Game.hitstop.clear()
	warden.take_hit(1000000.0, Vector2.ZERO, 0.0, 1.0)
	await frames(2)
	check(not main.realm_instance.has_warden(), "the warden falls to a killing blow")
	check(main.bosses_slain.has("boss.tomb_warden"), "the boss kill is remembered by id")

	var physique_at_altar: String = player.physique_id
	player.global_position = altar.global_position
	main._try_interact()
	check(main.inheritance_taken, "the altar grants an inheritance")
	check(Physiques.tier_of(player.physique_id) >= Physiques.tier_of(physique_at_altar), "the inheritance never weakens the body")
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
				# Technique manuals and passive manuals share the kind; pick the one
				# this block is about by id rather than by iteration order.
				if node.id == "manual.crimson_moon":
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
	check(approx(player.environment_bonus(), Climate.cultivation_bonus(Weather.current) * Game.biome_density, 0.0001), "cultivation reads the live weather and the land")

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
		if is_instance_valid(node) and node is Interactable and String(node.id).begins_with("herb.chunk."):
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

		# A ruin never returns, so there is no window to wait out; jumping the
		# clock for its sentinel value would age the run to death mid-suite.
		var step: int = 0 if poi_window == WorldDelta.PERMANENT else mini(poi_window, 5000)
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

	# --- navigation and fast travel ------------------------------------------
	check(main.travel_sites.size() > 0, "discovered sites become travel destinations")
	var destinations: Array = main.travel_destinations()
	check(destinations.size() >= 5, "landmarks and sites make a route list (%d)" % destinations.size())
	check(String(destinations[0]["id"]).begins_with("landmark."), "landmarks lead the travel list")

	main._open_travel()
	check(main.travel_open, "the travel panel opens")
	check(main.travel_panel.visible, "the travel panel is drawn")
	check(not player.is_physics_processing(), "the travel panel freezes the player")
	main._close_travel()
	check(not main.travel_open and not main.travel_panel.visible, "the travel panel closes")
	check(player.is_physics_processing(), "closing travel restores the player")

	var shrine_target: Vector2 = main.settlement.position_for("shrine")
	var time_before: float = float(Clock.day) * 24.0 + Clock.hour
	main._open_travel()
	main._travel_to(1)
	check(not main.travel_open, "travelling closes the panel")
	check(player.global_position.distance_to(shrine_target) < 120.0, "travel moves the player to the destination")
	var time_after: float = float(Clock.day) * 24.0 + Clock.hour
	check(time_after > time_before, "travel costs time")

	main._open_travel()
	main._set_waypoint(2)
	check(main.waypoint_name != "", "a waypoint can be set")
	check(main.waypoint_position != Vector2.ZERO, "a waypoint has a position")
	main._save(92)
	main._load_game(92)
	await frames(2)
	check(main.waypoint_name != "", "the waypoint survives a save")
	player.global_position = main.waypoint_position
	await frames(3)
	check(main.waypoint_position == Vector2.ZERO, "reaching a waypoint clears it")

	# --- off-screen simulation ------------------------------------------------
	var some_npc: Npc = main.npcs[0]
	check(some_npc.simulated, "NPCs are simulated while the player is near")
	player.global_position = Vector2(9000, 9000)
	await frames(3)
	check(not some_npc.simulated, "NPCs sleep when the player is far away")
	check(not some_npc.is_physics_processing(), "sleeping NPCs cost no physics frames")

	player.global_position = main.settlement.position_for("plaza")
	await frames(3)
	check(some_npc.simulated, "NPCs wake when the player returns")
	var expected_activity := String(some_npc.resolve_schedule(int(Clock.hour)).get("activity", ""))
	check(some_npc.current_activity == expected_activity, "a woken NPC is doing what the schedule says now")
	check(some_npc.global_position.distance_to(main.settlement.position_for(some_npc.current_location)) < 40.0,
		"a woken NPC stands where the schedule puts them")

	# Resources regrow while their chunk is unloaded, and the player hears about it.
	var herb: Interactable = null
	for candidate in main.interactables:
		if is_instance_valid(candidate) and String(candidate.id).begins_with("herb.chunk."):
			herb = candidate
			break
	check(herb != null, "a herb is streamed near the settlement")
	if herb != null:
		Clock.advance(24.0 * 5.0)
		var regrow_toasts: int = _toasts.size()
		main.chunks.today = Clock.day
		main.chunks.delta.mark_spent(herb.chunk_coord, herb.id, Clock.day - 5)
		main.chunks.resync(player.global_position)
		await frames(3)
		check(main.chunks.regrown_total > 0, "resources regrow while their chunk is unloaded")
		var reported := false
		for i in range(regrow_toasts, _toasts.size()):
			if String(_toasts[i]).contains("wilds recover"):
				reported = true
		check(reported, "regrowth is reported when the player returns")

	# --- character origin and appearance --------------------------------------
	check(not DB.origin(Game.origin_id).is_empty(), "the run records an origin")
	check(int(main.creation_stage) == 0, "creation starts on the formation screen")

	Game.origin_id = "origin.fallen_clan"
	player.cultivation.method_id = "method.traditional"
	player.passives.clear()
	player.rebuild_stats()
	var origin_stones: int = Game.spirit_stones
	main._apply_origin()
	check(player.cultivation.method_id == "method.sword", "an origin sets the starting method")
	check(player.passives.has("passive.sword_heart"), "an origin can grant a passive")
	check(Game.spirit_stones == origin_stones, "the fallen heir starts with no extra stones")

	Game.origin_id = "origin.merchant_child"
	var merchant_stones: int = Game.spirit_stones
	main._apply_origin()
	check(Game.spirit_stones == merchant_stones + 180, "an origin adds its purse")

	player.appearance.robe = 4
	player.appearance.hair = 2
	player.appearance.skin = 3
	player.appearance.presentation = 2
	main._save(91)
	player.appearance.from_dict({})
	main._load_game(91)
	await frames(2)
	check(player.appearance.robe == 4 and player.appearance.hair == 2, "appearance survives a save")
	check(player.appearance.skin == 3 and player.appearance.pronouns() == Appearance.PRESENTATIONS[2], "skin and presentation survive a save")
	check(Game.origin_id == "origin.merchant_child", "the origin survives a save")

	# --- extreme attribute states ---------------------------------------------
	var previous_weapon: Variant = player.equipment.get("weapon", null)
	player.equipment["weapon"] = {
		"id": "item.test.cursed", "name": "Cursed Test Blade", "slot": "weapon",
		"base_damage": -80.0, "armor": -40.0,
		"mods": [
			{"stat": "move_speed_pct", "value": -500.0},
			{"stat": "attack_speed_pct", "value": -500.0},
		],
	}
	player.rebuild_stats()
	check(player.stats.move_speed() > 0.0, "cursed gear cannot stop the player moving")
	check(player.stats.attack_speed() > 0.0, "cursed gear cannot stop attacks")
	check(player.stats.physical_mult() > 0.0, "cursed gear cannot invert damage")
	check(player.weapon_damage() >= 0.0, "a negative weapon reads as unarmed")
	var cursed_hit := Damage.technique_damage(DB.technique("tech.fist.iron_bone"), player.stats)
	check(cursed_hit > 0.0, "a technique still deals damage under cursed gear")
	if previous_weapon == null:
		player.equipment.erase("weapon")
	else:
		player.equipment["weapon"] = previous_weapon
	player.rebuild_stats()
	check(player.stats.weapon_damage() >= 0.0, "removing the curse restores a sane weapon slot")

	# --- secondary stats ------------------------------------------------------
	check(player.stats.evasion_chance() > 0.0, "the player has an evasion chance")
	check(player.stats.evasion_chance() <= StatBlock.EVASION_CAP, "evasion is capped")
	check(player.stats.penetration_fraction() > 0.0, "the player has penetration")
	check(player.stats.crit_multiplier() >= StatBlock.CRIT_DAMAGE_FLOOR, "crit damage is a real multiplier")
	check(player.stats.lifespan_years() > 0, "a starting cultivator has years left")

	# Out-of-combat regeneration heals slowly and stops mid-attack.
	player.hp = player.hp_max * 0.5
	player._hurt_flash = 0.0
	player._attack_state = "idle"
	var before_regen: float = player.hp
	player.regenerate(1.0)
	check(player.hp > before_regen, "health regenerates out of combat")
	var regen_mid_fight: float = player.hp
	player._attack_state = "active"
	player.regenerate(1.0)
	check(player.hp == regen_mid_fight, "regeneration stops while attacking")
	player._attack_state = "idle"
	player.hp = player.hp_max

	# Armour exists, and penetration means the same blow gets through it.
	var armoured := Dummy.new()
	main.world.add_child(armoured)
	armoured.aggressive = false
	armoured.global_position = player.global_position + Vector2(240, 0)
	var bare := Dummy.new()
	main.world.add_child(bare)
	bare.aggressive = false
	bare.armor_value = 0.0
	bare.global_position = player.global_position + Vector2(300, 0)
	await frames(1)
	var armoured_hp: float = armoured.hp
	armoured.take_hit(40.0, Vector2.ZERO, 0.0, 0.0)
	var armoured_loss: float = armoured_hp - armoured.hp
	var bare_hp: float = bare.hp
	bare.take_hit(40.0, Vector2.ZERO, 0.0, 0.0)
	var bare_loss: float = bare_hp - bare.hp
	check(armoured_loss < bare_loss, "armour reduces an incoming hit")
	var armoured_again: float = armoured.hp
	armoured.take_hit(40.0, Vector2.ZERO, 0.0, 1.0)
	check(armoured_again - armoured.hp > armoured_loss, "penetration beats armour")
	armoured.queue_free()
	bare.queue_free()

	# --- spiritual roots: appraisal, marrow, evolution ------------------------
	check(not player.cultivation.identified, "a new run starts with an unread root")
	check(player.cultivation.purity_bonus >= 0.0, "a hidden purity bonus was rolled")
	var pavilion: Interactable = _find_interactable(main.interactables, "root.pavilion")
	check(pavilion != null, "the root pavilion stands by the shrine")
	Game.spirit_stones = 300
	var purity_before := player.cultivation.effective_purity()
	var qi_before := player.cultivation.qi_max(player.stats)
	main._use_interactable(pavilion)
	check(player.cultivation.identified, "the pavilion reads the root")
	check(Game.spirit_stones == 300 - Roots.IDENTIFY_COST, "appraisal costs its stones")
	check(player.cultivation.effective_purity() >= purity_before, "a read root is never worse")
	check(player.cultivation.qi_max(player.stats) >= qi_before, "a read root raises or keeps Qi capacity")

	var tier_before: int = player.cultivation.root_tier
	player.pick_up(main._make_marrow())
	check(main._marrow_count() >= 1, "marrow is an inventory material")
	if tier_before < Roots.MAX_TIER:
		Game.spirit_stones = Roots.evolve_cost(tier_before)
		var marrow_before: int = main._marrow_count()
		main._use_interactable(pavilion)
		check(Game.spirit_stones == 0, "evolution spends its stones")
		check(player.cultivation.root_tier == tier_before + 1, "marrow and stones evolve the root")
		check(main._marrow_count() == marrow_before - 1, "evolution consumes the marrow")
		check(player.cultivation.root_mult() > 0.0, "the evolved root has a cultivation multiplier")

	# --- physiques -------------------------------------------------------------
	check(not Physiques.find(player.physique_id).is_empty(), "the run records an innate physique")
	var physique_before: String = player.physique_id
	var armour_before: float = player.stats.armor()
	var better := Physiques.tier_of("physique.iron_bone") > Physiques.tier_of(physique_before)
	check(player.inherit_physique("physique.iron_bone") == better, "inheritance accepts only a better body")
	if better:
		check(player.stats.armor() > armour_before, "the inherited body changes the stat pipeline")
	check(not player.inherit_physique("physique.mortal_frame"), "inheritance never downgrades")

	main._save(90)
	var saved_tier: int = player.cultivation.root_tier
	var saved_purity: float = player.cultivation.purity_bonus
	main._load_game(90)
	await frames(2)
	check(player.cultivation.identified, "appraisal survives a save")
	check(player.cultivation.root_tier == saved_tier, "the evolved root survives a save")
	check(absf(player.cultivation.purity_bonus - saved_purity) < 0.0001, "the hidden purity survives a save")

	# --- passives: requirements, conditions, conflicts and synergy ------------
	var jade_manual: Interactable = _find_interactable(main.interactables, "manual.jade_skin")
	check(jade_manual != null, "the jade skin manual stands by the shrine")
	player.global_position = jade_manual.global_position
	main._try_interact()
	check(not player.passives.has("passive.jade_skin"), "a manual refuses an unmet requirement")
	check(not jade_manual.used, "a refused manual is not consumed")
	player.attrs.add("str", 4)
	player.rebuild_stats()
	main._try_interact()
	check(player.passives.has("passive.jade_skin"), "a manual teaches once the requirement is met")
	check(jade_manual.used, "a learned manual is consumed")
	check(player.active_passives().has("passive.jade_skin"), "the learned passive is active")
	var armour_with_jade: float = player.stats.armor()
	check(armour_with_jade > 0.0, "jade skin adds armour")

	var trance_manual: Interactable = _find_interactable(main.interactables, "manual.battle_trance")
	check(trance_manual != null, "the battle trance manual exists")
	player.global_position = trance_manual.global_position
	main._try_interact()
	check(player.passives.has("passive.battle_trance"), "battle trance is learned")
	check(not player.active_passives().has("passive.battle_trance"), "battle trance is dormant at full health")
	var damage_healthy: float = player.stats.physical_mult()
	player.hp = player.hp_max * 0.2
	player._refresh_passive_conditions()
	check(player.active_passives().has("passive.battle_trance"), "battle trance wakes when wounded")
	check(player.stats.physical_mult() > damage_healthy, "the wounded passive changes damage")
	player.hp = player.hp_max
	player._refresh_passive_conditions()

	player.add_passive("passive.iron_bone")
	check(player.active_passives().has("passive.jade_skin"), "the first acquired conflicting passive stays active")
	check(player.dormant_passives().size() >= 1, "the conflicting passive is dormant")

	player.attrs.add("agi", 2)
	player.add_passive("passive.swift_steps")
	player.add_passive("passive.flowing_water")
	player.rebuild_stats()
	check(player.active_passives().has("passive.flowing_water"), "the agility requirement is met for flowing water")
	var attack_with_synergy: float = player.stats.attack_speed()
	player.passives.erase("passive.flowing_water")
	player.rebuild_stats()
	check(player.stats.attack_speed() < attack_with_synergy, "the synergy raises attack speed")

	main._save(89)
	main._load_game(89)
	await frames(2)
	check(player.active_passives().has("passive.jade_skin"), "an active passive survives a save")
	check(player.dormant_passives().size() >= 1, "a dormant passive stays dormant through a save")

	# --- technique mastery: teachers and observation ---------------------------
	var instructor: Npc = null
	for candidate in main.npcs:
		if candidate.npc_id == "instructor_rui":
			instructor = candidate
	check(instructor != null, "the sword instructor stands in the settlement")
	var demonstration: Interactable = _find_interactable(main.interactables, "training.falling_petal")
	check(demonstration != null, "a disciple practises the falling petal cut")

	main._use_interactable(demonstration)
	check(not player.technique_ids.has("tech.sword.falling_petal"), "observation refuses a low realm")
	check(not player.observed.has("tech.sword.falling_petal"), "a refused observation does not count")

	player.attrs.add("dex", 4)
	player.cultivation.realm = 2
	player.rebuild_stats()
	# Rui now keeps the yard's hours: put the clock in the morning training block.
	var m48_teach_day: int = Clock.day
	var m48_teach_hour: float = Clock.hour
	Clock.day = 3
	Clock.hour = 10.0
	instructor.snap_to_schedule()
	var stones_before_teach: int = Game.spirit_stones
	Game.spirit_stones = 100
	main._talk(instructor)
	check(not player.technique_ids.has("tech.sword.falling_petal"), "a teacher refuses an unpaid lesson")
	Game.spirit_stones = 500
	main._talk(instructor)
	check(player.technique_ids.has("tech.sword.falling_petal"), "a qualified student buys the technique")
	check(Game.spirit_stones == 500 - 180, "the lesson costs its price")
	main._talk(instructor)
	check(Game.spirit_stones == 500 - 180, "a known technique is not bought twice")
	Game.spirit_stones = stones_before_teach
	Clock.day = m48_teach_day
	Clock.hour = m48_teach_hour
	instructor.snap_to_schedule()

	main._use_interactable(demonstration)
	check(player.technique_ids.has("tech.sword.falling_petal"), "observing a known technique teaches nothing new")
	check(not player.observed.has("tech.sword.falling_petal"), "a known technique is not observed")

	player.add_technique_xp("tech.sword.falling_petal", 200)
	check(player.mastery_tier("tech.sword.falling_petal") == Mastery.MAX_TIER, "practice raises mastery")
	player.selected_technique = player.technique_ids.find("tech.sword.falling_petal")
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var qi_before_cast: float = player.cultivation.qi
	player.try_attack()
	var expected_cost := 18.0 * Mastery.qi_mult(Mastery.MAX_TIER)
	check(approx(qi_before_cast - player.cultivation.qi, expected_cost, 0.01), "mastery discounts the Qi cost")
	var xp_before_strike: int = player.mastery_xp("tech.sword.falling_petal")
	player._strike()
	check(player.mastery_xp("tech.sword.falling_petal") == xp_before_strike, "maxed mastery gains no further xp")
	var cleave_before: int = player.mastery_xp("tech.sword.azure_cleave")
	player.add_technique_xp("tech.sword.azure_cleave", 3)
	check(player.mastery_xp("tech.sword.azure_cleave") == cleave_before + 3, "xp accumulates per technique")

	player.observed["tech.formation.sealing_array"] = 2
	main._save(88)
	main._load_game(88)
	await frames(2)
	check(player.mastery_tier("tech.sword.falling_petal") == Mastery.MAX_TIER, "mastery survives a save")
	check(int(player.observed.get("tech.formation.sealing_array", 0)) == 2, "observation progress survives a save")
	player.observed.erase("tech.formation.sealing_array")

	# --- cultivation methods ---------------------------------------------------
	var method_stele: Interactable = _find_interactable(main.interactables, "method.stele")
	check(method_stele != null, "the method stele stands by the shrine")
	var stones_for_method: int = Game.spirit_stones
	var previous_method: String = player.cultivation.method_id
	Game.spirit_stones = 0
	main._use_interactable(method_stele)
	check(player.cultivation.method_id == previous_method, "the stele refuses without stones")
	Game.spirit_stones = 500
	main._use_interactable(method_stele)
	check(player.cultivation.method_id != previous_method, "a qualified method can be adopted")
	check(Game.spirit_stones == 500 - Methods.SWITCH_COST, "switching methods costs its stones")

	player.cultivation.method_id = "method.traditional"
	player.cultivation.qi = 0.0
	var insight_before: int = player.cultivation.method_insight_points("method.traditional")
	player.meditate_tick(1.0)
	check(player.cultivation.qi > 0.0, "meditation gains Qi through the method")
	check(player.cultivation.method_insight_points("method.traditional") >= insight_before, "meditation builds method insight")

	player.cultivation.method_id = "method.blood"
	player.cultivation.blood_charge = 0.0
	player.on_kill(3)
	var charge_after_kill: float = player.cultivation.blood_charge
	check(charge_after_kill > 0.0, "kills charge the blood method")
	player.meditate_tick(1.0)
	check(player.cultivation.blood_charge < charge_after_kill, "meditation spends blood essence")
	check(player.cultivation.method_insight_points("method.blood") > 0, "the blood method builds its own insight")
	Game.spirit_stones = stones_for_method

	main._save(87)
	main._load_game(87)
	await frames(2)
	check(player.cultivation.method_id == "method.blood", "the method survives a save")
	check(player.cultivation.blood_charge > 0.0, "blood essence survives a save")
	check(player.cultivation.method_insight_points("method.blood") > 0, "method insight survives a save")

	# --- meridians, contamination and Qi density -------------------------------
	var meridian_hall: Interactable = _find_interactable(main.interactables, "meridian.hall")
	check(meridian_hall != null, "the meridian hall stands by the shrine")
	var stones_for_meridian: int = Game.spirit_stones
	Game.spirit_stones = 0
	main._use_interactable(meridian_hall)
	check(player.cultivation.meridian_count() == 0, "the hall refuses without stones")
	Game.spirit_stones = 500
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var cap_before_meridian: float = player.cultivation.qi_max(player.stats)
	var wis_before: int = player.stats.get_attr("wis")
	var qi_before_meridian: float = player.cultivation.qi
	main._use_interactable(meridian_hall)
	check(player.cultivation.meridian_count() == 1, "a meridian can be opened")
	check(player.cultivation.qi_max(player.stats) > cap_before_meridian, "an open meridian raises Qi capacity")
	check(player.stats.get_attr("wis") > wis_before, "the opened meridian adds its stat")
	check(player.cultivation.qi < qi_before_meridian, "opening a meridian spends Qi")
	check(Game.spirit_stones == 500 - Meridians.stone_cost("meridian.lung"), "opening a meridian costs stones")

	player.cultivation.method_id = "method.blood"
	player.cultivation.blood_charge = 40.0
	player.cultivation.cleanse(Meridians.MAX_CONTAMINATION)
	player.meditate_tick(2.0)
	check(player.cultivation.contamination > 0.0, "the blood method contaminates the channels")
	var contaminated_gain: float = player.cultivation.qi_gain_per_sec(player.stats)
	check(player.cultivation.contamination_mult() < 1.0, "contamination dampens cultivation")
	player.cultivation.cleanse(Meridians.MAX_CONTAMINATION)
	check(player.cultivation.qi_gain_per_sec(player.stats) > contaminated_gain, "cleansing restores Qi gain")

	var shrine_node: Interactable = _find_interactable(main.interactables, "shrine.azure")
	player.cultivation.add_contamination(60.0)
	var stones_before_cleanse: int = Game.spirit_stones
	check(shrine_node != null, "the shrine still stands")
	main._use_interactable(shrine_node)
	check(player.cultivation.contamination == 0.0, "the shrine purges contamination")
	check(Game.spirit_stones == stones_before_cleanse - Meridians.CLEANSE_COST, "purging costs its stones")

	var meridian_biome := Biome.for_chunk(main.chunks.world_to_chunk(player.global_position), Game.world_seed)
	check(approx(Game.biome_density, Biome.qi_density(DB.biome(meridian_biome)), 0.0001), "the world reports its Qi density")

	Game.spirit_stones = stones_for_meridian
	player.cultivation.add_contamination(40.0)
	main._save(86)
	main._load_game(86)
	await frames(2)
	check(player.cultivation.meridian_count() == 1, "meridians survive a save")
	check(is_equal_approx(player.cultivation.contamination, 40.0), "contamination survives a save")
	player.cultivation.cleanse(Meridians.MAX_CONTAMINATION)

	# --- realms, sublevels and realm arts -------------------------------------
	player.cultivation.realm = 1
	player.cultivation.sublevel = 1
	player.rebuild_stats()
	check(player.cultivation.stage_title().contains("Early"), "realm one is named by its sublevel band")
	check(not player.cultivation.has_unlock("dash_cancel"), "realm one has no dash cancel")
	check(approx(player.stats.pct("qi_regen_pct"), 5.0), "the Qi Sense art is in the stat pipeline")

	player._meditating = false
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._dodge_cooldown = 0.0
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.try_attack()
	await frames(1)
	var committed_attack: String = player._attack_state
	check(committed_attack != "idle", "an attack is committed before the realm art exists")
	player.try_dodge(Vector2.RIGHT)
	check(player._attack_state == committed_attack, "realm one cannot abandon a swing")
	check(player._dodge_timer <= 0.0, "the refused dodge never starts")
	await frames(40)
	check(player._attack_state == "idle", "the committed attack finishes on its own")

	player.cultivation.realm = 2
	player.rebuild_stats()
	check(player.cultivation.has_unlock("dash_cancel"), "foundation unlocks dash cancel")
	# Equipment and passives may also carry qi_max_pct, so compare the two realm
	# arts against each other instead of against a bare number.
	var realm_two_qi_pct: float = player.stats.pct("qi_max_pct")
	var realm_one_qi_regen: float = player.stats.pct("qi_regen_pct")
	player.cultivation.realm = 1
	player.rebuild_stats()
	check(realm_two_qi_pct > player.stats.pct("qi_max_pct"), "the Dantian art is in the stat pipeline")
	check(player.stats.pct("qi_regen_pct") >= realm_one_qi_regen, "the Qi Sense art is in the stat pipeline")
	player.cultivation.realm = 2
	player.rebuild_stats()
	check(String(player.cultivation.realm_ability().get("name", "")) == "Dantian", "the current realm art is named")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._dodge_cooldown = 0.0
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.try_attack()
	await frames(1)
	player.try_dodge(Vector2.RIGHT)
	check(player._dodge_timer > 0.0, "foundation can dodge out of an attack")
	check(player._attack_state == "idle", "the abandoned swing returns to idle")
	await frames(40)

	# Technique weaving trims cost and cooldown at Spirit Transformation.
	player.selected_technique = player.technique_ids.find("tech.sword.azure_cleave")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.cultivation.realm = 4
	player.rebuild_stats()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var qi_before_unwoven: float = player.cultivation.qi
	player.try_attack()
	var unbound_cost := qi_before_unwoven - player.cultivation.qi
	check(unbound_cost > 0.0, "a technique spends Qi before weaving")
	await frames(40)

	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.cultivation.realm = 5
	player.rebuild_stats()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var qi_before_woven: float = player.cultivation.qi
	player.try_attack()
	var woven_cost := qi_before_woven - player.cultivation.qi
	check(woven_cost < unbound_cost, "technique weaving discounts Qi")
	check(approx(woven_cost, unbound_cost * Realms.WEAVING_MULT, 0.05), "weaving is a tenth off the cost")
	await frames(40)

	player.cultivation.realm = 12
	player.cultivation.sublevel = 10
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.rebuild_stats()
	var apex_attempt: Dictionary = player.attempt_breakthrough()
	check(String(apex_attempt.get("reason", "")) == "apex", "the scene refuses a breakthrough above the final realm")
	check(player.cultivation.realm == 12, "the apex attempt leaves the realm alone")

	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.rebuild_stats()
	main._save(90)
	main._load_game(90)
	await frames(2)
	check(player.cultivation.realm == 5 and player.cultivation.sublevel == 3, "the realm and sublevel survive a save")
	check(player.cultivation.has_unlock("technique_weaving"), "realm unlocks follow the saved realm")
	check(player.cultivation.stage_title().contains("Early"), "the saved sublevel band is derived again")
	Save.delete_slot(90)

	# --- breakthrough preparation and method mechanics ------------------------
	var tribulation_ground: Interactable = _find_interactable(main.interactables, "tribulation.ground")
	check(tribulation_ground != null, "a tribulation ground stands by the shrine")
	player.cultivation.preparation = 0
	var stones_for_prep: int = Game.spirit_stones
	Game.spirit_stones = 0
	main._use_interactable(tribulation_ground)
	check(player.cultivation.preparation == 0, "preparation is refused without stones")
	Game.spirit_stones = Cultivation.PREP_COST * 5
	main._use_interactable(tribulation_ground)
	main._use_interactable(tribulation_ground)
	main._use_interactable(tribulation_ground)
	check(player.cultivation.preparation == Cultivation.MAX_PREPARATION, "preparations stack to the cap")
	main._use_interactable(tribulation_ground)
	check(player.cultivation.preparation == Cultivation.MAX_PREPARATION, "the ground refuses beyond the cap")
	check(Game.spirit_stones == Cultivation.PREP_COST * 2, "preparation costs its stones and no more")

	player.cultivation.realm = 1
	player.cultivation.sublevel = 10
	player.cultivation.method_id = "method.sword"
	player.rebuild_stats()
	player._combat_timer = 0.0
	var sword_calm: float = player.breakthrough_chance_estimate()
	player._combat_timer = 6.0
	var sword_hot: float = player.breakthrough_chance_estimate()
	check(sword_hot > sword_calm, "sword intent changes the tribulation chance")
	player.cultivation.method_id = "method.traditional"
	player._combat_timer = 0.0

	var prepared_chance: float = player.breakthrough_chance_estimate()
	player.cultivation.preparation = 0
	var bare_chance: float = player.breakthrough_chance_estimate()
	player.cultivation.preparation = Cultivation.MAX_PREPARATION
	check(prepared_chance > bare_chance, "banked preparation raises the predicted chance")

	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player._attack_state = "idle"
	player._meditating = false
	var attempt_result: Dictionary = player.attempt_breakthrough()
	check(int(attempt_result.get("preparation", 0)) == Cultivation.MAX_PREPARATION, "the attempt spends the banked preparation")
	check(player.cultivation.preparation == 0, "the preparation is gone after the attempt")
	check(String(attempt_result.get("method", "")) == "method.traditional", "the attempt reports the practising method")

	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.cultivation.preparation = 2
	player.rebuild_stats()
	main._save(91)
	main._load_game(91)
	await frames(2)
	check(player.cultivation.preparation == 2, "preparation survives a save through the scene")
	check(player.cultivation.realm == 5, "preparing does not change the realm")
	player.cultivation.preparation = 0
	Game.spirit_stones = stones_for_prep
	Save.delete_slot(91)

	# --- playable tribulation --------------------------------------------------
	player.attrs.add("wis", 20)
	player.attrs.add("int", 20)
	player.cultivation.realm = 1
	player.cultivation.sublevel = 10
	player.cultivation.method_id = "method.traditional"
	player.cultivation.preparation = Cultivation.MAX_PREPARATION
	player.rebuild_stats()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.hp = player.hp_max
	# Probe a breakthrough index whose roll succeeds, so the outcome of the
	# encounter test does not depend on a coin flip.
	var lucky_index := 0
	for i in 400:
		if float(Rng.stream("breakthrough", 1, i).randf()) < 0.97:
			lucky_index = i
			break
	player.cultivation.breakthrough_attempts = lucky_index
	_tribulation_result = {}
	main._face_tribulation()
	check(main.tribulation_arena != null, "G at the peak starts a playable tribulation")
	check(main.tribulation_arena.tribulation != null, "the arena owns a trial")
	check(main.tribulation_arena.tribulation.type_id == "meridian", "realm one faces the meridian trial")
	check(main.tribulation_arena.tribulation.waves_total == 3, "the trial uses its data-driven wave count")

	var arena: TribulationArena = main.tribulation_arena
	var trial_guard := 0
	while main.tribulation_arena != null and trial_guard < 4000:
		player.global_position = arena.global_position + Vector2(900, 900)
		arena._process(0.05)
		trial_guard += 1
	check(main.tribulation_arena == null, "a finished tribulation removes its arena")
	check(String(_tribulation_result.get("outcome", "")) == "survived", "dodging every wave survives the trial")
	check(int(_tribulation_result.get("perfect_waves", 0)) == int(_tribulation_result.get("waves_total", 0)), "the run was perfect")
	check(float(_tribulation_result.get("composure", 0.0)) > 0.0, "a perfect run earns composure")
	check(player.cultivation.realm == 2, "surviving the trial lets the breakthrough land")

	player.cultivation.realm = 1
	player.cultivation.sublevel = 10
	player.cultivation.preparation = 0
	player.rebuild_stats()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.hp = 1.0
	_tribulation_result = {}
	main._face_tribulation()
	check(main.tribulation_arena != null, "a second tribulation can be started")
	var broken_arena: TribulationArena = main.tribulation_arena
	trial_guard = 0
	while main.tribulation_arena != null and trial_guard < 4000:
		player.global_position = broken_arena.global_position
		player.hp = minf(player.hp, 1.0)
		broken_arena._process(0.05)
		trial_guard += 1
	check(String(_tribulation_result.get("outcome", "")) == "broken", "standing in the fire breaks the cultivator")
	check(player.cultivation.realm == 1, "a broken tribulation does not advance the realm")
	check(player.cultivation.contamination > 0.0, "a broken tribulation corrupts the channels")
	check(player.cultivation.qi == 0.0, "a broken tribulation empties Qi")
	check(main.tribulation_arena == null, "a broken tribulation removes its arena")

	# Leave the run in the state the rest of the suite expects.
	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.cultivation.preparation = 0
	player.cultivation.contamination = 0.0
	player.hp = player.hp_max
	player.rebuild_stats()

	# --- enlightenment --------------------------------------------------------
	player.enlightenments.clear()
	player.cultivation.enlightenment_meter = 0.0
	player.cultivation.enlightenment_attempts = 0
	player.cultivation.realm = 1
	player.cultivation.method_id = "method.traditional"
	player.rebuild_stats()
	check(player.enlightenments.is_empty(), "a run starts with no insights")
	player.meditate_tick(1.0)
	check(player.cultivation.enlightenment_meter > 0.0, "meditation builds understanding")
	var understanding_after_meditation: float = player.cultivation.enlightenment_meter
	player.on_kill(1)
	check(player.cultivation.enlightenment_meter > understanding_after_meditation, "kills build understanding")
	var learned := player.gain_comprehension(Cultivation.ENLIGHTENMENT_GOAL)
	check(learned and player.enlightenments.size() == 1, "a full meter yields an insight")
	check(player.cultivation.enlightenment_meter == 0.0, "the insight spends the meter")
	if not player.enlightenments.is_empty():
		var gained_id := String(player.enlightenments[0])
		check(not Enlightenments.find(gained_id).is_empty(), "the learned insight exists in data")
		check(bool(Enlightenments.eligible(gained_id, player.enlightenment_state())["ok"]), "the insight was eligible when learned")
		check(not player.add_enlightenment(gained_id), "an insight is learned once")
		main._save(92)
		main._load_game(92)
		await frames(2)
		check(player.enlightenments.has(gained_id), "insights survive a save")
		Save.delete_slot(92)
	check(not player.add_enlightenment("enl.none"), "unknown insights are refused")

	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.rebuild_stats()

	# --- aging and lifespan ---------------------------------------------------
	var born_before := Game.born_day
	Clock.day = Game.born_day + int(Aging.DAYS_PER_YEAR)
	check(approx(Game.age_years(), float(Aging.START_AGE + 1)), "world days age the body")
	Clock.day = Game.born_day
	check(approx(Game.age_years(), float(Aging.START_AGE)), "returning the calendar returns the age")

	player.cultivation.realm = 1
	player.rebuild_stats()
	var young_str := player.stats.get_attr("str")
	var mortal_lifespan := player.stats.lifespan_years()
	check(mortal_lifespan > 0, "a realm-one body has a measured lifespan")
	Clock.day = Game.born_day + int(float(mortal_lifespan - Aging.START_AGE) * Aging.DAYS_PER_YEAR) - 100
	player.rebuild_stats()
	check(player.stats.get_attr("str") < young_str, "old age weakens the body")
	check(player.stats.get_attr("wis") > 0, "old age leaves wisdom intact")
	Clock.day = Game.born_day

	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.hp = player.hp_max
	player.rebuild_stats()
	Save.delete_slot(93)
	main._save(93)
	var born_saved := Game.born_day
	var day_saved := Clock.day
	Clock.day = Game.born_day + 240
	main._load_game(93)
	await frames(2)
	check(Game.born_day == born_saved and Clock.day == day_saved, "loading restores the calendar and birth day")
	Save.delete_slot(93)

	# Death ends the run, stops the body and refuses further saves.
	Game.age_warning_stage = 0
	player.cultivation.realm = 1
	player.rebuild_stats()
	var death_lifespan: int = player.stats.lifespan_years()
	Clock.day = Game.born_day + int(float(death_lifespan - Aging.START_AGE + 1) * Aging.DAYS_PER_YEAR)
	main._check_aging()
	check(String(main.phase) == "ended", "outliving the lifespan ends the run")
	check(Game.dead, "the run is marked dead")
	check(not player.is_physics_processing(), "an ended run stops the body")
	main._save(93)
	check(Save.load_game(93).is_empty(), "an ended run cannot be saved")

	# Restore a living run for the rest of the suite.
	Game.dead = false
	Game.running = true
	Game.born_day = born_before
	Game.age_warning_stage = 0
	main._run_ended = false
	main.phase = "play"
	Clock.day = day_saved
	player.set_physics_process(true)
	player.set_process(true)
	player.cultivation.realm = 5
	player.cultivation.sublevel = 3
	player.cultivation.qi = 8.0
	player.hp = player.hp_max
	player.rebuild_stats()

	# --- combat architecture ---------------------------------------------------
	player.poise.reset()
	check(player.poise.maximum > 40.0, "a player body has a poise capacity from realm and strength")
	check(not player.poise.is_staggered(), "a fresh guard is intact")
	player.hp = player.hp_max
	player._attack_state = "startup"
	player._attack_timer = 0.5
	player._attack_phase_total = 0.5
	player.take_hit(1.0, player.global_position + Vector2(20, 0), false, 9999.0, 120.0)
	check(player.poise.is_staggered(), "a breaking blow staggers the player")
	check(player._attack_state == "idle", "a stagger interrupts an attack in startup")
	check(player._knock.length() > 0.0, "a staggering blow throws the body")
	player.poise.tick(2.0)
	check(not player.poise.is_staggered(), "stagger wears off")
	player._knock = Vector2.ZERO
	player._iframes = 0.0
	player.hp = player.hp_max
	player.poise.reset()

	var brawler := Dummy.new()
	brawler.ilvl = 2
	brawler.aggressive = false
	main.add_child(brawler)
	brawler.global_position = player.global_position + Vector2(30, 0)
	# Remove evasion from the calculation so the blow is deterministic.
	var dex_before := player.attrs.get_attr("dex")
	player.attrs.add("dex", -dex_before)
	player.rebuild_stats()
	# Gear can carry evasion of its own, and a slip would decide this check.
	player.stats.add_pct["evasion"] = 0.0
	player.stats.flat_attrs["agi"] = 0.0
	var hp_before_blow := player.hp
	brawler._release_attack(player)
	check(player.hp < hp_before_blow, "an enemy blow still damages the player")
	check(player.poise.current < player.poise.maximum, "an enemy blow carries poise damage")
	player.attrs.add("dex", dex_before)
	player.rebuild_stats()
	brawler.queue_free()
	player.hp = player.hp_max
	player.poise.reset()

	# --- defense: guard, parry and guard break ---------------------------------
	player._iframes = 0.0
	player._dodge_timer = 0.0
	player._attack_state = "idle"
	player._attack_timer = 0.0
	player._guard_broken = 0.0
	player._guard_held = false
	player._guard_time = 0.0
	player._knock = Vector2.ZERO
	player.poise.reset()
	player.hp = player.hp_max
	player._facing = Vector2.RIGHT
	# No evasion: a guard test must not be decided by a fortunate slip.
	var guard_dex := player.attrs.get_attr("dex")
	player.attrs.add("dex", -guard_dex)
	player.rebuild_stats()
	# Gear from an earlier reward can add evasion, which would turn this parry
	# into a slip. Zero both sources so the stance is what is being tested.
	player.stats.add_pct["evasion"] = 0.0
	player.stats.flat_attrs["agi"] = 0.0
	player.cultivation.qi = player.cultivation.qi_max(player.stats)

	check(player.guard_state() == "none", "a lowered guard is no stance")
	check(player.set_guard(true), "a guard can be raised out of combat")
	check(player.guard_state() == "parry", "a fresh guard opens the parry window")
	check(player.is_guarding(), "a held guard guards")

	var guard_dummy := Dummy.new()
	guard_dummy.ilvl = 1
	guard_dummy.aggressive = false
	main.add_child(guard_dummy)
	guard_dummy.global_position = player.global_position + Vector2(30, 0)
	var parry_hp := player.hp
	var parry_qi := player.cultivation.qi
	var parry_poise: float = guard_dummy.poise.current
	guard_dummy._release_attack(player)
	check(approx(player.hp, parry_hp), "a parry turns the blow aside")
	check(approx(player.cultivation.qi, parry_qi), "a parry costs no Qi")
	check(guard_dummy.poise.current < parry_poise or guard_dummy.poise.is_staggered(), "a parry throws the force back")
	check(guard_dummy._windup <= 0.0, "a parry spoils the attacker's wind-up")

	player._guard_held = true
	player._guard_time = Defense.PARRY_WINDOW + 0.1
	player.hp = player.hp_max
	player.poise.reset()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var block_qi := player.cultivation.qi
	var block_hp := player.hp
	player.take_hit(40.0, player.global_position + Vector2(30, 0), false, 12.0, 120.0)
	var blocked_loss: float = block_hp - player.hp
	check(blocked_loss > 0.0 and blocked_loss < 40.0, "a blocked blow hurts far less")
	check(player.cultivation.qi < block_qi, "a block spends Qi")
	check(approx(player.poise.current, player.poise.maximum), "a block spends Qi instead of poise")

	player.poise.reset()
	player._guard_held = true
	player._guard_time = Defense.PARRY_WINDOW + 0.1
	player.hp = player.hp_max
	var open_hp := player.hp
	player.take_hit(40.0, player.global_position + Vector2(-30, 0), false, 12.0, 120.0)
	check(open_hp - player.hp > blocked_loss, "a blow from behind ignores the guard")

	player.poise.reset()
	player.cultivation.qi = 0.0
	player._guard_broken = 0.0
	check(player.set_guard(true), "a guard can be raised again after a block")
	player._guard_time = Defense.PARRY_WINDOW + 0.1
	player.hp = player.hp_max
	var break_hp := player.hp
	player.take_hit(40.0, player.global_position + Vector2(30, 0), false, 12.0, 120.0)
	check(player.is_guard_broken(), "an unpaid block breaks the guard")
	check(player.guard_state() == "broken", "the broken stance is reported")
	check(player.poise.is_staggered(), "a guard break staggers the body")
	check(break_hp - player.hp > blocked_loss, "a broken guard takes more than a held one")
	check(approx(player.cultivation.qi, 0.0), "the failed ward drains the reserve")
	check(not player.set_guard(true), "a broken guard cannot be raised")

	player.poise.tick(3.0)
	player._guard_broken = 0.0
	player._guard_held = false
	player._guard_time = 0.0
	player._knock = Vector2.ZERO
	player.attrs.add("dex", guard_dex)
	player.rebuild_stats()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.hp = player.hp_max
	player.poise.reset()
	guard_dummy.queue_free()

	# --- weapon framework ------------------------------------------------------
	player.equipment["weapon"] = {
		"id": "item.test.jian", "base": "base.sword.iron_jian", "weapon_type": "sword",
		"name": "Test Iron Jian", "slot": "weapon", "ilvl": 1, "rarity": 1,
		"base_damage": 8.0, "armor": 0.0, "mods": [],
	}
	player.rebuild_stats()
	check(player.weapon_type_id() == "sword", "an equipped jian selects the sword moveset")
	check(player.weapon_type_name() == "Sword", "the weapon category is named")
	check(player.next_move_name() != "", "a weapon offers a first strike")

	player._facing = Vector2.RIGHT
	var strike_dir: Vector2 = player._aim_dir()
	var sparring := Dummy.new()
	sparring.ilvl = 1
	sparring.aggressive = false
	main.add_child(sparring)
	# The player is mid-realm here; a normal dummy would die to three strikes.
	sparring.hp_max = 5000.0
	sparring.hp = 5000.0
	sparring.global_position = player.global_position + strike_dir * 42.0
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._combo_index = -1
	player._combo_elapsed = 100.0
	var qi_before_strike := player.cultivation.qi
	var dummy_hp_before := sparring.hp
	check(player.try_light_attack(), "a light strike starts")
	check(approx(player.cultivation.qi, qi_before_strike), "a weapon strike spends no Qi")
	await frames(20)
	check(sparring.hp < dummy_hp_before, "the weapon strike lands on a dummy in reach")
	check(player._combo_index == 0, "the first strike marks the chain's first step")

	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._combo_elapsed = 0.05
	var second_move := String((Weapons.moves("sword") as Array)[1].get("name", ""))
	check(player.next_move_name() == second_move, "an in-time press previews the second strike")
	player.try_light_attack()
	check(player._combo_index == 1, "the chain advances on the second strike")
	await frames(20)
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._combo_elapsed = 100.0
	player.try_light_attack()
	check(player._combo_index == 0, "a late press restarts the chain")
	await frames(20)

	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.equipment["weapon"] = {
		"id": "item.test.rod", "base": "base.staff.azure_rod", "weapon_type": "staff",
		"name": "Test Azure Rod", "slot": "weapon", "ilvl": 3, "rarity": 2,
		"base_damage": 6.0, "armor": 0.0, "mods": [],
	}
	player.rebuild_stats()
	check(player.weapon_type_id() == "staff", "swapping to a rod selects the staff moveset")
	var staff_reach := float((Weapons.attack_payload(Weapons.find("staff"), 0).get("hitbox", {}) as Dictionary).get("radius", 0.0))
	var sword_reach := float((Weapons.attack_payload(Weapons.find("sword"), 0).get("hitbox", {}) as Dictionary).get("radius", 0.0))
	check(staff_reach > sword_reach, "the staff moveset reaches further")
	sparring.global_position = player.global_position + strike_dir * 110.0
	var far_hp := sparring.hp
	player._combo_index = -1
	player._combo_elapsed = 100.0
	player.try_light_attack()
	await frames(20)
	check(sparring.hp < far_hp, "the staff reaches a dummy a sword could not")
	if is_instance_valid(sparring):
		sparring.queue_free()

	player.equipment.erase("weapon")
	player.rebuild_stats()
	check(player.weapon_type_id() == Weapons.DEFAULT_TYPE, "an empty weapon slot is unarmed")
	check(Weapons.moves(player.weapon_type_id()).size() >= 2, "bare hands have a real chain")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._combo_index = -1
	player._combo_elapsed = 100.0
	player.hp = player.hp_max
	player.poise.reset()

	# --- technique kinds: projectile, spell, summon, buff and movement ---------
	# One shared frame machine and one damage path; only the delivery changes.
	player._attack_state = "idle"
	player._attack_timer = 0.0
	player._attack_phase_total = 0.0
	player._current_attack = {}
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._dodge_cooldown = 0.0
	player._dodge_timer = 0.0
	player._iframes = 0.0
	player._knock = Vector2.ZERO
	player._guard_held = false
	player._guard_time = 0.0
	player._guard_broken = 0.0
	player.hp = player.hp_max
	player.poise.reset()
	player._facing = strike_dir
	player.cultivation.qi = 500.0
	player.active_buffs.clear()
	player.rebuild_stats()
	# The camera keeps easing, so the mouse's world point (and therefore the aim)
	# drifts between scenarios. Read the aim fresh before each cast and lay the
	# target along the direction the blow will actually take.
	var aim_now: Vector2 = player._aim_dir()

	var bolt_mark := Dummy.new()
	bolt_mark.ilvl = 1
	bolt_mark.aggressive = false
	main.add_child(bolt_mark)
	bolt_mark.hp_max = 60000.0
	bolt_mark.hp = 60000.0
	bolt_mark.global_position = player.global_position + aim_now * 220.0
	var far_mark := Dummy.new()
	far_mark.ilvl = 1
	far_mark.aggressive = false
	main.add_child(far_mark)
	far_mark.hp_max = 60000.0
	far_mark.hp = 60000.0
	far_mark.global_position = player.global_position + aim_now * 760.0

	player.selected_technique = _tech_index(player, "tech.sword.piercing_thrust")
	check(player.current_technique_kind() == "projectile", "the selected art is a projectile")
	var bolt_hp_before: float = bolt_mark.hp
	var far_hp_before: float = far_mark.hp
	var bolt_qi_before: float = player.cultivation.qi
	player.try_attack()
	check(player._attack_state == "startup", "a projectile art winds up on the shared frame machine")
	check(player.cultivation.qi < bolt_qi_before, "a ranged art spends Qi on cast")
	await frames(60)
	check(bolt_mark.hp < bolt_hp_before, "a projectile art strikes a body downrange")
	check(approx(far_mark.hp, far_hp_before), "a projectile does not reach past its range")
	check(get_tree().get_nodes_in_group("projectile").is_empty(), "a bolt dies at its range")

	var array_id := "tech.formation.sealing_array"
	player.selected_technique = _tech_index(player, array_id)
	aim_now = player._aim_dir()
	var array_spec := TechniqueCombat.spell_of(DB.technique(array_id))
	var array_point := TechniqueCombat.spell_center(player.global_position, aim_now, array_spec)
	var array_mark := Dummy.new()
	array_mark.ilvl = 1
	array_mark.aggressive = false
	main.add_child(array_mark)
	array_mark.hp_max = 60000.0
	array_mark.hp = 60000.0
	array_mark.global_position = array_point + Vector2(0, 24)
	var outside_mark := Dummy.new()
	outside_mark.ilvl = 1
	outside_mark.aggressive = false
	main.add_child(outside_mark)
	outside_mark.hp_max = 60000.0
	outside_mark.hp = 60000.0
	outside_mark.global_position = player.global_position - aim_now * 260.0
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	var array_hp_before: float = array_mark.hp
	var outside_hp_before: float = outside_mark.hp
	player.try_attack()
	await frames(80)
	check(player.current_technique_kind() == "spell", "the selected art is a spell")
	check(array_mark.hp < array_hp_before, "a spell blooms where it was cast")
	check(approx(outside_mark.hp, outside_hp_before), "a spell only strikes its own area")

	var pack_id := "tech.beast.nine_stampede"
	player.selected_technique = _tech_index(player, pack_id)
	var pack_mark := Dummy.new()
	pack_mark.ilvl = 1
	pack_mark.aggressive = false
	main.add_child(pack_mark)
	pack_mark.hp_max = 60000.0
	pack_mark.hp = 60000.0
	pack_mark.global_position = player.global_position + aim_now * 110.0
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.try_attack()
	await frames(35)
	check(player.current_technique_kind() == "summon", "the selected art is a summon")
	check(get_tree().get_nodes_in_group("summon").size() >= 3, "a summon art calls its pack")
	var pack_hp_before: float = pack_mark.hp
	await frames(70)
	check(pack_mark.hp < pack_hp_before, "a summoned beast strikes an enemy")
	# A summon's clock stops during an impact freeze, and its own last blows can
	# start one; allow a frame or two past the hitstop cap for it to fade.
	Game.hitstop.clear()
	for beast in get_tree().get_nodes_in_group("summon"):
		beast.lifetime = 0.001
	await frames(10)
	check(get_tree().get_nodes_in_group("summon").is_empty(), "a summon fades when its time ends")

	player.selected_technique = _tech_index(player, "tech.body.golden_bell")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.active_buffs.clear()
	player.rebuild_stats()
	var armour_without: float = player.stats.armor()
	player.try_attack()
	await frames(30)
	check(player.current_technique_kind() == "buff", "the selected art is a body art")
	check(player.active_buffs.size() == 1, "a body art is applied")
	check(player.stats.armor() > armour_without, "a body art raises the stat it declares")
	player.active_buffs[0]["remaining"] = 0.02
	await frames(4)
	check(player.active_buffs.is_empty(), "a body art expires")
	check(approx(player.stats.armor(), armour_without), "its stat leaves with it")

	player.selected_technique = _tech_index(player, "tech.step.cloud_step")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player._iframes = 0.0
	player._knock = Vector2.ZERO
	var step_from: Vector2 = player.global_position
	player.try_attack()
	await frames(6)
	check(player.current_technique_kind() == "movement", "the selected art is a movement art")
	check(player.global_position.distance_to(step_from) > 100.0, "a movement art carries the body along the aim")
	check(player._iframes > 0.0, "a movement art carries its own i-frames")

	player.selected_technique = _tech_index(player, "tech.sword.azure_cleave")
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	var melee_mark := Dummy.new()
	melee_mark.ilvl = 1
	melee_mark.aggressive = false
	main.add_child(melee_mark)
	melee_mark.hp_max = 60000.0
	melee_mark.hp = 60000.0
	melee_mark.global_position = player.global_position + player._aim_dir() * 40.0
	var melee_hp_before: float = melee_mark.hp
	player.try_attack()
	await frames(30)
	check(melee_mark.hp < melee_hp_before, "a melee art still resolves its own hitbox")

	player.selected_technique = 0
	var cycled_name := player.cycle_technique()
	check(player.selected_technique == 1 and cycled_name != "", "Q brings the next known art to hand")
	player.selected_technique = player.technique_ids.size() - 1
	player.cycle_technique()
	check(player.selected_technique == 0, "cycling wraps back to the first art")

	# --- skill bars ----------------------------------------------------------
	check(main.skill_bar_panel != null, "the scene owns a bar arrangement panel")
	check(not main.skill_bar_panel.visible, "the arrangement panel starts closed")
	main.toggle_bars()
	check(main.bars_open and main.skill_bar_panel.visible, "B opens the bar arrangement panel")
	check(not player.is_physics_processing(), "the arrangement panel freezes the player")
	main.toggle_bars()
	check(not main.bars_open and player.is_physics_processing(), "closing the panel restores the player")

	check(player.bars.size() == SkillBar.SLOT_COUNT, "the player carries eighteen bar slots")
	check(String(player.bars[0]) == String(player.technique_ids[0]), "the default layout starts from the known kit")
	player.set_active_bar(0)
	check(player.select_bar_slot(0), "key one selects the first art on the bar")
	check(String(player.current_technique().get("id", "")) == String(player.technique_ids[0]), "the selected art is the slot's art")

	var bar_two_slot := SkillBar.index_of(1, 2)
	var bar_two_art := "tech.step.cloud_step"
	_tech_index(player, bar_two_art)
	check(player.assign_slot(bar_two_slot, bar_two_art), "a known art can be placed on the second bar")
	check(player.slot_for(bar_two_art) == bar_two_slot, "the bar reports the art's slot")
	check(not player.assign_slot(3, "tech.bogus"), "an unknown art cannot be placed on a bar")
	check(main._switch_bar(1) == 1 and player.active_bar == 1, "the bar switches forward")
	check(player.select_bar_slot(2), "the placed art is selectable from its bar")
	check(String(player.current_technique().get("id", "")) == bar_two_art, "the second bar hands over its own art")
	check(not player.select_bar_slot(5), "an empty slot refuses selection")
	check(main._switch_bar(-1) == 0, "the bar switches backward and wraps")

	check(player.assign_slot(0, bar_two_art), "an art can be moved between bars")
	check(player.slot_for(bar_two_art) == 0, "moving an art clears its old slot")
	check(String(player.bars[bar_two_slot]) == "", "the vacated slot is empty")
	check(player.move_slot(0, 5), "drag and drop swaps two slots")
	check(String(player.bars[5]) == bar_two_art, "the dragged art lands where it was dropped")
	check(not player.move_slot(5, 99), "dropping on a slot outside the layout does nothing")
	check(player.clear_slot(5), "right-click clears a slot")
	check(String(player.bars[5]) == "", "the cleared slot is empty")
	check(not player.clear_slot(5), "clearing an empty slot does nothing")
	player.bars[17] = "tech.bogus"
	player.reconcile_bars()
	check(not player.bars.has("tech.bogus"), "a corrupted layout is pruned to known arts")
	check(player.bars.size() == SkillBar.SLOT_COUNT, "reconciling keeps eighteen slots")

	# --- per-art cooldowns ---------------------------------------------------
	player.assign_slot(0, "tech.step.cloud_step")
	player.assign_slot(1, "tech.sword.azure_cleave")
	var cd_art := "tech.sword.azure_cleave"
	var other_art := "tech.sword.piercing_thrust"
	player.selected_technique = _tech_index(player, cd_art)
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	check(player.cooldown_left(cd_art) == 0.0, "a fresh art has no cooldown")
	player.try_attack()
	# Read the timer on the frame it starts: a headless run simulates frames
	# faster than the art's own cooldown would last a fixed number of waits.
	var cooldown_seen := 0.0
	for i in 60:
		await get_tree().physics_frame
		cooldown_seen = player.cooldown_left(cd_art)
		if cooldown_seen > 0.0:
			break
	check(cooldown_seen > 0.0, "finishing an art starts its own cooldown")
	check(player.slot_cooldown_ratio(player.slot_for(cd_art)) > 0.0, "the slot reports its cooldown for the HUD")
	check(player.cooldown_left(cd_art) <= player.technique_cooldown(cd_art) + 0.001, "the running timer never exceeds its full length")
	player.selected_technique = _tech_index(player, other_art)
	player._attack_state = "idle"
	player._cooldown = 0.0
	check(player.cooldown_left(other_art) == 0.0, "one art's cooldown leaves the others ready")
	check(player.cooldown_left(cd_art) > 0.0, "the first art is still gathering")
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.try_attack()
	check(player._attack_state != "idle", "a ready art can follow a cooling one")
	await frames(40)
	# The same art, still cooling, must refuse the press and spend nothing.
	player._attack_state = "idle"
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.tech_cooldowns[cd_art] = 5.0
	player.selected_technique = _tech_index(player, cd_art)
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	var qi_before_gate: float = player.cultivation.qi
	player.try_attack()
	check(player._attack_state == "idle", "an art that is still gathering refuses the press")
	check(approx(player.cultivation.qi, qi_before_gate), "a refused press spends no Qi")
	player.tech_cooldowns.clear()
	check(player.technique_cooldown(cd_art) > 0.0, "the cooldown length is derived from mastery, gear and realm")

	# --- the layout survives a save, and a pre-M34 save derives one ----------
	player.set_active_bar(2)
	player.assign_slot(SkillBar.index_of(2, 0), "tech.sword.azure_cleave")
	var legacy_state: Dictionary = player.to_dict()
	legacy_state.erase("bars")
	legacy_state.erase("active_bar")
	player.from_dict(legacy_state)
	check(player.bars.size() == SkillBar.SLOT_COUNT and String(player.bars[0]) != "", "a pre-M34 save derives a bar layout")
	check(player.active_bar == 0, "a pre-M34 save starts on the first bar")

	player.set_active_bar(2)
	player.assign_slot(SkillBar.index_of(2, 0), "tech.sword.azure_cleave")
	Save.delete_slot(97)
	main._save(97)
	player.set_active_bar(0)
	player.bars = SkillBar.default_layout(player.technique_ids)
	main._load_game(97)
	await frames(2)
	check(player.active_bar == 2, "the active bar survives a save")
	check(String(player.bars[SkillBar.index_of(2, 0)]) == "tech.sword.azure_cleave", "the bar layout survives a save")
	check(player.cooldown_left("tech.sword.azure_cleave") == 0.0, "cooldowns are transient and never saved")
	Save.delete_slot(97)

	for mark in [bolt_mark, far_mark, array_mark, outside_mark, pack_mark, melee_mark]:
		if is_instance_valid(mark):
			mark.queue_free()
	await frames(2)
	player._attack_state = "idle"
	player._attack_timer = 0.0
	player._cooldown = 0.0
	player.tech_cooldowns.clear()
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	player.hp = player.hp_max
	player.poise.reset()

	# --- enemy AI -------------------------------------------------------------
	# A clear patch far from the settlement, so a wandering spawn cannot land a
	# blow in the middle of a scenario. Evasion is removed so a blow either lands
	# or misses for a reason the check names.
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 1600)
	player.velocity = Vector2.ZERO
	player.hp = player.hp_max
	player.poise.reset()
	player._knock = Vector2.ZERO
	player._iframes = 0.0
	var ai_dex := player.attrs.get_attr("dex")
	var ai_agi := player.attrs.get_attr("agi")
	player.attrs.add("dex", -ai_dex)
	player.attrs.add("agi", -ai_agi)
	player.rebuild_stats()
	# Gear and passives also feed the evasion percent. Zero the rebuilt value
	# instead of stripping the kit, so armour and damage stay realistic.
	player.stats.add_pct["evasion"] = 0.0
	player.stats.flat_attrs["agi"] = 0
	check(approx(player.stats.evasion_chance(), 0.0), "the AI scenario strips evasion so a blow is deterministic")
	await frames(2)

	var ai_far := Dummy.new()
	ai_far.ilvl = 2
	ai_far.global_position = player.global_position + Vector2(700, 0)
	main.add_child(ai_far)
	ai_far.set_archetype("brawler")
	ai_far.home = ai_far.global_position
	await frames(20)
	check(ai_far.memory == 0.0, "an enemy out of range has not seen the player")
	check(ai_far.state == "patrol" or ai_far.state == "idle", "an unaware enemy patrols its home")

	# Nudge the facing each frame so the cone cannot be what this check measures.
	player.global_position = ai_far.global_position + Vector2(140, 0)
	for i in 8:
		ai_far._facing = Vector2.RIGHT
		await get_tree().physics_frame
	check(ai_far.memory > 0.0, "an enemy that sees the player remembers him")
	check(ai_far.state in ["chase", "circle", "windup", "recover"], "a sighted enemy pursues")

	ai_far.home = ai_far.global_position + Vector2(900, 0)
	await frames(3)
	check(ai_far.state == "return", "a body past its leash breaks off the fight")
	await frames(10)
	check(ai_far.state == "return", "a returning body keeps walking home")
	ai_far.queue_free()

	var ai_return := Dummy.new()
	ai_return.ilvl = 1
	ai_return.global_position = player.global_position + Vector2(500, 0)
	main.add_child(ai_return)
	ai_return.set_archetype("sentinel")
	ai_return.home = ai_return.global_position + Vector2(20, 0)
	ai_return.hp = 4.0
	ai_return.memory = 0.0
	await frames(110)
	check(ai_return.hp == ai_return.hp_max, "a body that walks home mends its wounds")
	check(ai_return.state == "patrol" or ai_return.state == "idle", "a body back at its post loses interest")
	ai_return.queue_free()
	await frames(2)

	var ai_striker := Dummy.new()
	ai_striker.ilvl = 1
	ai_striker.global_position = player.global_position + Vector2(40, 0)
	main.add_child(ai_striker)
	ai_striker.set_archetype("brawler")
	ai_striker._facing = Vector2.LEFT
	ai_striker._cooldown = 0.0
	ai_striker.memory = 5.0
	ai_striker._last_seen = player.global_position
	await frames(2)
	check(ai_striker.state == "windup" and ai_striker._windup > 0.0, "an enemy in reach telegraphs its blow")

	var ai_dodged_hp := player.hp
	player.global_position = ai_striker.global_position + Vector2(240, 0)
	await frames(40)
	check(player.hp == ai_dodged_hp, "a telegraphed blow misses a body that steps out of reach")

	player.global_position = ai_striker.global_position + Vector2(-36, 0)
	player._iframes = 0.0
	ai_striker._facing = Vector2.LEFT
	ai_striker._cooldown = 0.0
	ai_striker.memory = 5.0
	ai_striker._provoked = true
	ai_striker._last_seen = player.global_position
	var ai_struck := false
	var ai_hit_hp := player.hp
	for i in 70:
		await get_tree().physics_frame
		if player.hp < ai_hit_hp:
			ai_struck = true
			break
	check(ai_struck, "a wound-up blow lands on a body that stays in reach")

	ai_striker._windup = 0.4
	ai_striker.stagger(999.0)
	check(ai_striker._windup == 0.0, "a stagger cancels a wind-up")
	check(ai_striker.state == "recover", "a staggered body reports recovery")
	ai_striker.queue_free()

	var ai_skirmisher := Dummy.new()
	ai_skirmisher.ilvl = 1
	ai_skirmisher.global_position = player.global_position + Vector2(40, 0)
	main.add_child(ai_skirmisher)
	ai_skirmisher.set_archetype("skirmisher")
	ai_skirmisher._facing = Vector2.LEFT
	ai_skirmisher._cooldown = 0.0
	ai_skirmisher.memory = 5.0
	ai_skirmisher._last_seen = player.global_position
	var ai_retreated := false
	for i in 70:
		await get_tree().physics_frame
		if ai_skirmisher.retreat_left > 0.0:
			ai_retreated = true
			break
	check(ai_retreated, "a skirmisher backs off after its blow")
	ai_skirmisher.queue_free()

	var ai_sentinel := Dummy.new()
	ai_sentinel.ilvl = 1
	ai_sentinel.global_position = player.global_position
	main.add_child(ai_sentinel)
	ai_sentinel.set_archetype("sentinel")
	ai_sentinel.aggressive = false
	ai_sentinel._facing = Vector2.RIGHT
	player.hp = player.hp_max
	player._iframes = 0.0
	player._knock = Vector2.ZERO
	player.global_position = ai_sentinel.global_position + Vector2(-36, 0)
	var ai_behind_hp := player.hp
	ai_sentinel._release_attack(player)
	await frames(1)
	check(approx(player.hp, ai_behind_hp), "a sentinel's frontal arc misses a body behind it")
	player.global_position = ai_sentinel.global_position + Vector2(36, 0)
	player._iframes = 0.0
	ai_sentinel._cooldown = 0.0
	ai_sentinel._release_attack(player)
	await frames(1)
	check(player.hp < ai_behind_hp, "a sentinel's arc lands in front of it")
	ai_sentinel.queue_free()

	var ai_archer := Dummy.new()
	ai_archer.ilvl = 2
	ai_archer.global_position = player.global_position + Vector2(260, 0)
	main.add_child(ai_archer)
	ai_archer.set_archetype("archer")
	ai_archer._facing = Vector2.LEFT
	ai_archer._cooldown = 0.0
	ai_archer.memory = 5.0
	ai_archer._last_seen = player.global_position
	await frames(3)
	check(ai_archer.state == "windup", "an archer winds up a bolt at range")
	player.hp = player.hp_max
	player._iframes = 0.0
	var ai_ranged_hp := player.hp
	var ai_saw_bolt := false
	var ai_kept_distance := true
	var ai_bolt_hit := false
	for i in 150:
		await get_tree().physics_frame
		for ai_bolt_body in get_tree().get_nodes_in_group("projectile"):
			if is_instance_valid(ai_bolt_body) and String(ai_bolt_body.faction) == "enemy":
				ai_saw_bolt = true
		if is_instance_valid(ai_archer) and ai_archer.global_position.distance_to(player.global_position) < 150.0:
			ai_kept_distance = false
		if player.hp < ai_ranged_hp:
			ai_bolt_hit = true
			break
	check(ai_saw_bolt, "an archer fires a Qi bolt instead of closing")
	check(ai_kept_distance, "an archer keeps its distance")
	check(ai_bolt_hit, "an enemy bolt lands through the player's own take_hit")
	ai_archer.queue_free()
	await frames(2)

	var ai_group: Array = []
	for i in 5:
		var ai_body := Dummy.new()
		ai_body.ilvl = 1
		var ai_angle := TAU * float(i) / 5.0
		ai_body.global_position = player.global_position + Vector2(cos(ai_angle), sin(ai_angle)) * 40.0
		main.add_child(ai_body)
		ai_body.set_archetype("brawler")
		ai_body.memory = 5.0
		ai_body._cooldown = 0.0
		ai_body._provoked = true
		ai_group.append(ai_body)
	await frames(6)
	var ai_winding := 0
	for ai_body in ai_group:
		if is_instance_valid(ai_body) and String(ai_body.state) == "windup":
			ai_winding += 1
	check(ai_winding >= 1, "at least one body of a pack commits to a blow")
	check(ai_winding <= 3, "no more than three bodies commit at once (%d)" % ai_winding)
	for ai_body in ai_group:
		if is_instance_valid(ai_body):
			ai_body.queue_free()
	await frames(2)

	var ai_count_before := get_tree().get_nodes_in_group("enemy").size()
	main._spawn_wild_dummy()
	await frames(1)
	var ai_spawned: Array = get_tree().get_nodes_in_group("enemy")
	check(ai_spawned.size() == ai_count_before + 1, "the wilds spawn another enemy")
	var ai_newest := ai_spawned[ai_spawned.size() - 1] as Dummy
	check(ai_newest != null and DB.has("enemy_archetype", String(ai_newest.archetype)), "a wild spawn carries a biome archetype")
	check(ai_newest != null and ai_newest.profile.size() > 0, "a wild spawn has a full behaviour profile")
	if ai_newest != null:
		ai_newest.queue_free()
	await frames(2)

	player.attrs.add("dex", ai_dex)
	player.attrs.add("agi", ai_agi)
	player.rebuild_stats()
	player.hp = player.hp_max
	player.poise.reset()
	player._knock = Vector2.ZERO
	player._iframes = 0.0
	player.global_position = main.settlement.position_for("plaza")
	await frames(2)

	# --- combat polish ---------------------------------------------------------
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 1600)
	player.hp = player.hp_max
	player.poise.reset()
	player._knock = Vector2.ZERO
	player._iframes = 0.0
	player.statuses.clear()
	Game.hitstop.clear()
	await frames(2)

	check(main.damage_numbers != null and main.combat_audio != null, "the run builds its feedback nodes")
	check(main.combat_audio.streams.size() == Sfx.kinds().size(), "every combat sound is synthesized at startup")
	check(main.combat_audio.play("hit"), "a sound can be dispatched")
	var m37_played: int = main.combat_audio.played
	main.combat_audio.set_muted(true)
	check(not main.combat_audio.play("crit"), "a muted run dispatches no sound")
	check(main.combat_audio.played == m37_played + 1, "a muted dispatch is still counted")
	main.combat_audio.set_muted(false)
	check(not main.combat_audio.is_muted(), "sound can be unmuted")
	main.combat_audio.play("nope")
	check(main.combat_audio.played == m37_played + 1, "an unknown sound is not counted")

	var m37_dummy := Dummy.new()
	m37_dummy.ilvl = 1
	m37_dummy.global_position = player.global_position + Vector2(36, 0)
	main.add_child(m37_dummy)
	m37_dummy.aggressive = false
	m37_dummy.hp_max = 5000.0
	m37_dummy.hp = 5000.0
	main.damage_numbers.entries.clear()
	Game.hitstop.clear()
	player._facing = Vector2.RIGHT
	player._current_attack = DB.technique("tech.sword.azure_cleave")
	player._strike()
	check(main.damage_numbers.entries.size() > 0, "a landed blow spawns a damage number")
	check(Game.hitstop.is_frozen(), "a landed blow freezes the fight for a moment")
	var m37_frozen_at := m37_dummy.global_position
	var m37_frozen_left := Game.hitstop.remaining
	await frames(1)
	check(m37_dummy.global_position == m37_frozen_at, "a frozen enemy does not move")
	check(Game.hitstop.remaining < m37_frozen_left or not Game.hitstop.is_frozen(), "the freeze clock runs in real time")
	Game.hitstop.clear()

	main.damage_numbers.entries.clear()
	player._facing = Vector2.LEFT
	player._strike()
	await frames(1)
	check(main.damage_numbers.entries.is_empty(), "a blow that hits nothing shows no number")
	check(not Game.hitstop.is_frozen(), "a blow that hits nothing does not freeze")

	m37_dummy.statuses.clear()
	var m37_hp_before: float = m37_dummy.hp
	var m37_applied: float = m37_dummy.take_hit(10.0, Vector2.ZERO, 0.0, 0.0,
		{"id": "burn", "duration": 2.0, "magnitude": 4.0})
	check(m37_applied > 0.0 and Status.has(m37_dummy.statuses, "burn"), "a blow can apply a status")
	var m37_ticks_before := _status_ticks.size()
	m37_dummy._tick_statuses(0.5)
	check(m37_dummy.hp < m37_hp_before, "a burning body loses health over time")
	check(_status_ticks.size() == m37_ticks_before + 1 and String(_status_ticks[-1]) == "burn", "a status tick reports itself")
	check(not Status.has(m37_dummy.statuses, "chill"), "an unrelated status is not applied")

	player.statuses.clear()
	var m37_player_hp := player.hp
	player.take_hit(5.0, player.global_position + Vector2(40, 0), false, 0.0, 0.0, null,
		{"id": "chill", "duration": 2.0, "magnitude": 0.4})
	check(Status.has(player.statuses, "chill"), "an enemy blow can chill the player")
	check(approx(Status.speed_multiplier(player.statuses), 0.6), "chill slows the player")
	check(player.hp < m37_player_hp, "the blow that carried the status still hurt")
	player.statuses = Status.apply(player.statuses, {"id": "shock", "duration": 2.0, "magnitude": 0.2})
	check(approx(Status.taken_multiplier(player.statuses), 1.2), "shock raises damage taken on the player")
	player.statuses.clear()

	player.statuses = Status.apply([], {"id": "burn", "duration": 2.0, "magnitude": 6.0})
	var m37_burn_hp := player.hp
	player._tick_statuses(0.5)
	check(player.hp < m37_burn_hp, "a burning player loses health over time")
	check(player.status_labels().size() == 1, "the HUD can list live statuses")
	player.statuses.clear()
	check(player.status_labels().is_empty(), "a clean body has no status labels")
	player.hp = player.hp_max

	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 1600)
	player.velocity = Vector2.ZERO
	Game.hitstop.clear()
	Input.action_press("move_right")
	await frames(20)
	var m37_plain_speed := player.velocity.length()
	player.statuses = Status.apply([], {"id": "chill", "duration": 4.0, "magnitude": 0.5})
	await frames(20)
	var m37_chilled_speed := player.velocity.length()
	Input.action_release("move_right")
	check(m37_chilled_speed < m37_plain_speed * 0.75, "chill slows real movement (%.0f -> %.0f)" % [m37_plain_speed, m37_chilled_speed])
	player.statuses.clear()
	await frames(3)

	var m37_kills_before := Game.kills
	var m37_doomed := Dummy.new()
	m37_doomed.ilvl = 1
	m37_doomed.global_position = player.global_position + Vector2(600, 0)
	main.add_child(m37_doomed)
	m37_doomed.aggressive = false
	m37_doomed.hp = 1.0
	m37_doomed.statuses = Status.apply([], {"id": "bleed", "duration": 2.0, "magnitude": 20.0})
	m37_doomed._tick_statuses(0.5)
	await frames(2)
	check(Game.kills == m37_kills_before + 1, "a status tick can finish an enemy")

	main.damage_numbers.entries.clear()
	main.damage_numbers.add(12.0, player.global_position)
	check(main.damage_numbers.entries.size() == 1, "the number layer accepts an entry")
	main.damage_numbers._process(2.0)
	check(main.damage_numbers.entries.is_empty(), "a damage number expires")

	m37_dummy.queue_free()
	await frames(2)
	player.hp = player.hp_max
	player.poise.reset()
	player._knock = Vector2.ZERO
	player.statuses.clear()
	Game.hitstop.clear()

	# --- spirit beasts ---------------------------------------------------------
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 1700)
	player.hp = player.hp_max
	player.poise.reset()
	player.statuses.clear()
	player._knock = Vector2.ZERO
	Game.hitstop.clear()
	await frames(2)

	var m36_species := Beasts.profile(DB.spirit_beast("beast.stoneback"))
	var m36_beast := Dummy.new()
	m36_beast.ilvl = 1
	m36_beast.global_position = player.global_position + Vector2(-160, 0)
	main.world.add_child(m36_beast)
	m36_beast.become_beast(m36_species, player.cultivation.realm)
	check(m36_beast.is_beast and m36_beast.species_id == "beast.stoneback", "a body can become a species' beast")
	check(m36_beast.display_name == "Stoneback Boar", "the beast wears its species' name")
	check(String(m36_beast.profile.get("id", "")) == "sentinel", "the beast fights with its species' archetype")
	check(m36_beast.hp_max > 0.0, "the beast derives its numbers from the species")
	m36_beast.aggressive = false
	var m36_core_before: int = main.ground_items.size()
	m36_beast.take_hit(1000000.0, Vector2.ZERO, 0.0, 1.0)
	await frames(2)
	var m36_core_found := false
	for entry in main.ground_items:
		var dropped: Dictionary = entry.get("item", {})
		if String(dropped.get("base_name", "")) == "Stoneback Hide":
			m36_core_found = true
	check(main.ground_items.size() >= m36_core_before + 2, "a beast drops its core as well as ordinary loot")
	check(m36_core_found, "the core is the species' own")

	# --- the warden: phases, adds and reward -----------------------------------
	var m36_warden := Dummy.new()
	m36_warden.ilvl = 2
	m36_warden.global_position = player.global_position + Vector2(0, 520)
	main.world.add_child(m36_warden)
	m36_warden.become_boss(DB.boss("boss.tomb_warden"), 2)
	m36_warden.hp_max = 1000.0
	m36_warden.hp = 1000.0
	check(m36_warden.is_boss and m36_warden.boss_id == "boss.tomb_warden", "a body can become the warden")
	check(m36_warden.is_in_group("boss"), "a boss joins the boss group")
	var m36_phases: Array = []
	var m36_recorder := func(_b: Node, index: int, phase_name: String) -> void:
		m36_phases.append([index, phase_name])
	Bus.boss_phase_changed.connect(m36_recorder)
	await frames(2)
	check(m36_warden.boss_phase == 0, "a whole warden starts in its first phase")
	m36_warden.hp = 600.0
	await frames(2)
	check(m36_warden.boss_phase == 1, "losing a third moves the warden to its second phase")
	m36_warden.hp = 200.0
	await frames(2)
	check(m36_warden.boss_phase == 2, "losing another third moves it to its last")
	check(approx(m36_warden._phase_mult("damage_mult"), 1.5), "the last phase scales the warden's blows")
	check(m36_phases.size() == 2, "each phase change is announced once")
	check(String((m36_phases[0] as Array)[1]) == "Moon's Wrath", "the announced phase is named")
	Bus.boss_phase_changed.disconnect(m36_recorder)

	var m36_stones := Game.spirit_stones
	var m36_inventory := Items.total_count(player.inventory)
	m36_warden.take_hit(1000000.0, Vector2.ZERO, 0.0, 1.0)
	await frames(2)
	check(main.bosses_slain.has("boss.tomb_warden"), "the warden's fall is recorded by id")
	check(Game.spirit_stones >= m36_stones + 400, "the warden pays its stones")
	check(Items.total_count(player.inventory) > m36_inventory, "the warden's reward is taken")

	main._save(87)
	var m36_saved := Save.load_game(87)
	var m36_slain: Variant = m36_saved.get("bosses_slain", {})
	check(typeof(m36_slain) == TYPE_DICTIONARY and (m36_slain as Dictionary).has("boss.tomb_warden"), "a save records the fallen warden")

	# --- item architecture: stacks, condition and canonical saves --------------
	player.statuses.clear()
	player.hp = player.hp_max
	player._iframes = 0.0
	player.poise.reset()
	Game.hitstop.clear()
	await frames(2)

	var m38_ore_a := Items.normalize_item({"id": "item.m38.ore.1", "slot": "material", "name": "Spirit Ore", "base": "ore.spirit", "value": 20})
	var m38_ore_b := Items.normalize_item({"id": "item.m38.ore.2", "slot": "material", "name": "Spirit Ore", "base": "ore.spirit", "value": 20})
	var m38_kinds_before: int = player.inventory.size()
	player.pick_up(m38_ore_a)
	player.pick_up(m38_ore_b)
	var m38_ore_count := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("base", "")) == "ore.spirit":
			m38_ore_count = int((entry as Dictionary).get("count", 1))
	check(m38_ore_count == 2, "two identical materials share one stack")
	check(player.inventory.size() <= m38_kinds_before + 1, "the second pickup does not add a second entry")

	var m38_weapon := Items.normalize_item({
		"id": "item.m38.weapon", "slot": "weapon", "name": "Test Jian", "base": "base.sword.iron_jian",
		"base_name": "Iron Jian", "weapon_type": "sword", "base_damage": 8.0, "ilvl": 1, "rarity": 0, "value": 12,
	})
	var m38_armor := Items.normalize_item({
		"id": "item.m38.armor", "slot": "armor", "name": "Test Robe", "base": "base.robe.cloud_silk",
		"base_name": "Cloud Silk Robe", "armor": 5.0, "ilvl": 1, "rarity": 0, "value": 12,
	})
	player.equipment["weapon"] = m38_weapon
	player.equipment["armor"] = m38_armor
	player.inventory = Items.add_to_inventory(player.inventory, m38_weapon)
	player.inventory = Items.add_to_inventory(player.inventory, m38_armor)
	player.rebuild_stats()

	var m38_before_wear := Items.durability_of(m38_weapon)
	player._attack_state = "idle"
	player._cooldown = 0.0
	player._facing = Vector2.RIGHT
	player._current_attack = DB.technique("tech.sword.azure_cleave")
	player._strike()
	var m38_worn_weapon: Dictionary = player.equipment["weapon"]
	check(approx(Items.durability_of(m38_worn_weapon), m38_before_wear - Items.WEAR_PER_STRIKE), "a strike wears the weapon")
	Game.hitstop.clear()

	var m38_before_hit := Items.durability_of(m38_armor)
	var m38_hp_before := player.hp
	player.take_hit(5.0, player.global_position + Vector2(30, 0), false)
	var m38_worn_armor: Dictionary = player.equipment["armor"]
	check(player.hp < m38_hp_before, "the armoured body still takes the blow")
	check(approx(Items.durability_of(m38_worn_armor), m38_before_hit - Items.WEAR_PER_HIT), "taking a blow wears the armour")

	# One point left, then a swing: the last wear breaks it and the pipeline drops
	# its contribution immediately.
	player.equipment["weapon"] = Items.wear(m38_weapon, Items.max_durability("weapon") - 1.0)
	player.rebuild_stats()
	player._attack_state = "idle"
	player._cooldown = 0.0
	player._current_attack = DB.technique("tech.sword.azure_cleave")
	player._strike()
	var m38_broken_weapon: Dictionary = player.equipment["weapon"]
	check(Items.is_broken(m38_broken_weapon), "the last point of wear breaks the weapon")
	check(approx(player.stats.weapon_damage(), 0.0), "a broken weapon contributes no damage")
	check(approx(player.weapon_damage(), 0.0), "the reported weapon damage is zero too")
	Game.hitstop.clear()

	var m38_repair_cost := Items.repair_cost(player.equipment)
	check(m38_repair_cost > 0, "broken gear has a repair price")
	player.repair_gear()
	var m38_repaired_weapon: Dictionary = player.equipment["weapon"]
	check(not Items.is_broken(m38_repaired_weapon), "repair restores the weapon")
	check(player.stats.weapon_damage() > 0.0, "a repaired weapon fights again")

	player.equipment["weapon"] = Items.wear(m38_repaired_weapon, 1.0)
	player.rebuild_stats()
	main._save(89)
	var m38_saved := Save.load_game(89)
	var m38_saved_player: Dictionary = m38_saved.get("player", {})
	var m38_saved_equipment: Dictionary = m38_saved_player.get("equipment", {})
	var m38_saved_weapon: Dictionary = m38_saved_equipment.get("weapon", {})
	check(approx(Items.durability_of(m38_saved_weapon), Items.max_durability("weapon") - 1.0), "a save keeps the weapon's exact condition")
	var m38_saved_inventory: Array = m38_saved_player.get("inventory", [])
	var m38_saved_ore := 0
	for entry in m38_saved_inventory:
		if String((entry as Dictionary).get("base", "")) == "ore.spirit":
			m38_saved_ore = int((entry as Dictionary).get("count", 1))
	check(m38_saved_ore == 2, "a save keeps a stack's count")

	# --- procedural generation: tiers reach real loot --------------------------
	var m39_generator := ItemGen.new(DB, Rng)
	var m39_low := m39_generator.generate(1, 9100, 0, 3, "weapon")
	var m39_high := m39_generator.generate(12, 9100, 0, 3, "weapon")
	var m39_high_tier := 0
	for mod in m39_high.get("mods", []):
		m39_high_tier = maxi(m39_high_tier, int((mod as Dictionary).get("tier", 1)))
	var m39_low_tier := 0
	for mod in m39_low.get("mods", []):
		m39_low_tier = maxi(m39_low_tier, int((mod as Dictionary).get("tier", 1)))
	check(m39_high_tier == 3, "a level twelve treasure rolls the top tier")
	check(m39_low_tier == 1, "level one treasure stays on the first tier")
	check(JSON.stringify(m39_high) == JSON.stringify(m39_generator.generate(12, 9100, 0, 3, "weapon")), "a real loot roll reproduces exactly")
	var m39_saved_mods: Dictionary = Items.to_save(m39_high)
	check(JSON.stringify(Items.to_save(Items.from_save(m39_saved_mods))) == JSON.stringify(m39_saved_mods), "the canonical save keeps rolled tiers")

	# --- equipment: requirements, conflicts and the gear panel -----------------
	var m40_plate := Items.normalize_item({"id": "item.m40.plate", "slot": "armor", "name": "Test Plate", "base": "base.robe.iron_plate", "armor": 14.0, "ilvl": 2, "value": 20})
	var m40_charm := Items.normalize_item({"id": "item.m40.charm", "slot": "talisman", "name": "Test Charm", "base": "base.talisman.wind_charm", "ilvl": 1, "value": 14})
	var m40_prev_armor: Dictionary = player.equipment.get("armor", {})
	var m40_prev_talisman: Dictionary = player.equipment.get("talisman", {})
	var m40_prev_str := player.attrs.get_attr("str")
	player.attrs.values["str"] = 10
	player.equipment["armor"] = {}
	player.equipment["talisman"] = {}
	player.rebuild_stats()
	var m40_refused := player.equip(m40_plate)
	check(not bool(m40_refused.get("ok", true)), "a STR 10 body cannot wear STR 12 plate")
	check(String(m40_refused.get("reason", "")).contains("Requires"), "the refusal names the requirement")
	check(player.equipment.get("armor", {}).is_empty(), "a refused piece is not worn")
	player.attrs.values["str"] = 14
	# The ninth point of STR can wake a passive of its own, so the baseline is
	# taken after the attribute change and before the plate goes on.
	player.rebuild_stats()
	var m40_before_armor := float(player.stats.flat_stats.get("armor", 0.0))
	check(bool(player.equip(m40_plate).get("ok", false)), "a STR 14 body wears the plate")
	var m40_after_armor := float(player.stats.flat_stats.get("armor", 0.0))
	check(approx(m40_after_armor - m40_before_armor, 14.0), "worn plate reaches the stat pipeline")
	check(not bool(player.equip(m40_charm).get("ok", true)), "the wind charm refuses heavy plate")
	check(player.equipment.get("talisman", {}).is_empty(), "the conflicting charm stays bagged")
	player.inventory = Items.add_to_inventory(player.inventory, m40_charm)
	var m40_rows: Array = main.gear_candidates()
	var m40_found := false
	for row in m40_rows:
		if String((row as Dictionary).get("id", "")) == "item.m40.charm":
			m40_found = true
	check(m40_found, "the gear panel lists the bagged charm")
	var m40_cmp: Dictionary = main.gear_compare(m40_charm)
	check(not bool((m40_cmp.get("check", {}) as Dictionary).get("ok", true)), "the panel shows the conflict")
	main.toggle_gear()
	check(main.gear_open, "I opens the gear panel")
	check(not player.is_physics_processing(), "the gear panel freezes play")
	main.close_gear()
	check(not main.gear_open and player.is_physics_processing(), "closing the panel resumes play")
	player.attrs.values["str"] = m40_prev_str
	player.equipment["armor"] = m40_prev_armor
	player.equipment["talisman"] = m40_prev_talisman
	player.rebuild_stats()

	# --- uniques: authored relics, granted once, effective when worn -----------
	var m41_rules := Uniques.new(DB)
	var m41_blade := m41_rules.make("item.unique.hollow_moon_blade")
	var m41_sash := m41_rules.make("item.unique.cloudstep_sash")
	check(not m41_blade.is_empty() and not m41_sash.is_empty(), "both relics are authored")
	var m41_owned := Uniques.owned_ids(player.equipment, player.inventory)
	check(m41_owned.has("item.unique.hollow_moon_blade"), "the warden's fall granted its relic")
	check(m41_owned.has("item.unique.cloudstep_sash"), "the altar granted its relic")

	var m41_count_before := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("id", "")) == "item.unique.hollow_moon_blade":
			m41_count_before += 1
	for slot in Items.EQUIP_SLOTS:
		var m41_worn: Dictionary = player.equipment.get(slot, {})
		if String(m41_worn.get("id", "")) == "item.unique.hollow_moon_blade":
			m41_count_before += 1
	check(m41_count_before == 1, "a relic exists exactly once")
	main._grant_unique("boss.tomb_warden")
	var m41_count_after := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("id", "")) == "item.unique.hollow_moon_blade":
			m41_count_after += 1
	for slot in Items.EQUIP_SLOTS:
		var m41_worn_again: Dictionary = player.equipment.get(slot, {})
		if String(m41_worn_again.get("id", "")) == "item.unique.hollow_moon_blade":
			m41_count_after += 1
	check(m41_count_after == 1, "granting the same relic again does not duplicate it")

	var m41_prev_weapon: Dictionary = player.equipment.get("weapon", {})
	var m41_prev_armor: Dictionary = player.equipment.get("armor", {})
	var m41_prev_hp := player.hp
	var m41_prev_qi := player.cultivation.qi
	player.equipment["weapon"] = m41_blade
	player.rebuild_stats()
	player.hp = 40.0
	player.cultivation.qi = 0.0
	player.on_kill(1)
	check(player.cultivation.qi > 0.0, "the Hollow Moon Blade returns Qi on a kill")
	check(approx(player.hp, 40.0), "and no health")
	player.equipment["armor"] = m41_sash
	player.rebuild_stats()
	player.hp = 40.0
	player.on_kill(1)
	check(player.hp > 40.0, "the Cloudstep Sash returns health on a kill")
	check(bool(Items.to_save(m41_blade).get("unique", false)), "a save carries the relic flag")
	player.equipment["weapon"] = m41_prev_weapon
	player.equipment["armor"] = m41_prev_armor
	player.hp = m41_prev_hp
	player.cultivation.qi = m41_prev_qi
	player.rebuild_stats()

	# --- inventory: the grid, the sort key and the storehouse ------------------
	var m42_store := _find_interactable(main.interactables, "storage.market")
	check(m42_store != null and m42_store.kind == Interactable.Kind.STORAGE, "the market has a storehouse")
	check(main.inventory_rows().size() == player.inventory.size(), "the grid reads the satchel")
	var m42_sort_before: String = player.inventory_sort
	var m42_ids_before: Array = []
	for entry in player.inventory:
		m42_ids_before.append(String((entry as Dictionary).get("id", "")))
	main.toggle_gear()
	check(main.gear_open, "I opens the satchel screen")
	main.cycle_inventory_sort()
	check(player.inventory_sort != m42_sort_before, "R changes the satchel's order")
	var m42_ids_after: Array = []
	for entry in player.inventory:
		m42_ids_after.append(String((entry as Dictionary).get("id", "")))
	var m42_permutation := m42_ids_after.size() == m42_ids_before.size()
	for id_value in m42_ids_before:
		if not m42_ids_after.has(id_value):
			m42_permutation = false
	check(m42_permutation, "sorting only reorders the satchel")
	check(Inventory.page_count(main.inventory_rows()) >= 1, "the grid pages the satchel")
	main.close_gear()
	check(not main.gear_open and player.is_physics_processing(), "closing the satchel resumes play")

	var m42_material := Items.normalize_item({"id": "item.m42.ore", "slot": "material", "name": "Test Ore", "base": "ore.spirit", "value": 9, "count": 3})
	player.inventory = Items.add_to_inventory(player.inventory, m42_material)
	var m42_store_before: int = main.storage.slots_used()
	main._open_storage()
	check(main.storage_open, "the storehouse opens")
	check(not player.is_physics_processing(), "the storehouse freezes play")
	main.storage_side = 0
	var m42_cursor := -1
	for i in main.storage_rows(0).size():
		if String((main.storage_rows(0)[i] as Dictionary).get("id", "")) == "item.m42.ore":
			m42_cursor = i
	main.storage_index = m42_cursor
	main.storage_move()
	check(main.storage.has("item.m42.ore"), "ENTER stores the selected stack")
	check(main.storage.slots_used() == m42_store_before + 1, "the shelf count rises")
	var m42_still_bagged := false
	for entry in player.inventory:
		if String((entry as Dictionary).get("id", "")) == "item.m42.ore":
			m42_still_bagged = true
	check(not m42_still_bagged, "the stored stack leaves the satchel")
	main.storage_side = 1
	main.storage_index = main.storage.index_of("item.m42.ore")
	main.storage_move()
	check(not main.storage.has("item.m42.ore"), "ENTER withdraws the selected stack")
	var m42_returned := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("id", "")) == "item.m42.ore":
			m42_returned += int((entry as Dictionary).get("count", 1))
	check(m42_returned == 3, "the whole stack comes back")
	main.close_storage()
	check(not main.storage_open and player.is_physics_processing(), "closing the storehouse resumes play")

	# --- loot tables: elite rank, own tables, table-driven chests --------------
	check(DB.loot_tables.size() >= Loot.REQUIRED_SOURCES.size(), "loot tables are loaded")
	var m43_rules := Loot.new(DB, Rng)
	check(JSON.stringify(m43_rules.roll("kill.wild", 4, 5150, 0)) == JSON.stringify(m43_rules.roll("kill.wild", 4, 5150, 0)), "a kill's loot is reproducible")
	var m43_elite := Dummy.new()
	m43_elite.ilvl = 3
	main.world.add_child(m43_elite)
	m43_elite.global_position = player.global_position + Vector2(240, 0)
	var m43_base_hp := m43_elite.hp_max
	m43_elite.make_elite()
	check(m43_elite.is_elite and m43_elite.hp_max > m43_base_hp, "an elite is tougher than the same body")
	check(m43_elite.is_in_group("elite"), "an elite is marked for the world")
	var m43_kills := Game.kills
	var m43_items_before: int = main.ground_items.size()
	var m43_stones_before := Game.spirit_stones
	m43_elite.take_hit(99999.0, Vector2.ZERO, 999.0)
	await get_tree().process_frame
	check(Game.kills == m43_kills + 1, "the elite kill counts")
	var m43_dropped: int = main.ground_items.size() - m43_items_before
	check(m43_dropped >= 1 and m43_dropped <= Loot.rolls_of(DB.loot_table("kill.elite")).y, "the elite rolls its own table once")
	check(Game.spirit_stones > m43_stones_before, "an elite carries a purse")
	if m43_dropped >= 1:
		var m43_piece: Dictionary = main.ground_items[m43_items_before]["item"]
		check(int(m43_piece["ilvl"]) >= 5, "the elite table adds its level bonus")

	var m43_chest := Interactable.new()
	m43_chest.setup(Interactable.Kind.CHEST, "chest.m43.test", "Test chest")
	main.world.add_child(m43_chest)
	m43_chest.global_position = player.global_position
	var m43_chest_before: int = main.ground_items.size()
	main._loot(m43_chest, 6, "sealed chest", "chest.sealed")
	check(m43_chest.used, "a table-driven chest is spent")
	check(main.ground_items.size() > m43_chest_before, "a sealed chest drops from its own table")
	var m43_good_gear := true
	for i in range(m43_chest_before, main.ground_items.size()):
		var m43_item: Dictionary = main.ground_items[i]["item"]
		if Items.is_equipment(String(m43_item["slot"])) and int(m43_item["rarity"]) < 1:
			m43_good_gear = false
	check(m43_good_gear, "sealed chest gear is never mortal grade")
	m43_chest.queue_free()

	# --- crafting: forge, refine and disassemble at the anvil ------------------
	var m44_forge := _find_interactable(main.interactables, "forge.azure")
	check(m44_forge != null and m44_forge.kind == Interactable.Kind.FORGE, "the settlement has a forge")
	check(main.settlement.has_location("forge") and main.settlement.building_for("forge") != null, "the forge has a building")
	Game.spirit_stones = maxi(Game.spirit_stones, 500)
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m44.ore", "slot": "material", "name": "Spirit Ore", "material": "ore", "count": 12}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m44.herb", "slot": "material", "name": "Spirit Herb", "material": "herb", "count": 4}))
	check(Items.material_key(Items.normalize_item({"id": "item.ore.m44", "slot": "material", "name": "Ore"})) == "ore", "a legacy ore is a crafting material")

	main._open_forge()
	check(main.forge_open, "the forge opens")
	check(not player.is_physics_processing(), "the forge freezes play")
	main.forge_mode = 0
	var m44_recipe_index := -1
	for i in main.forge_rows().size():
		if String((main.forge_rows()[i] as Dictionary).get("id", "")) == "recipe.forge.iron_jian":
			m44_recipe_index = i
	check(m44_recipe_index >= 0, "the forge lists its recipes")
	main.forge_index = m44_recipe_index
	var m44_swords_before := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("base", "")) == "base.sword.iron_jian":
			m44_swords_before += 1
	for slot in Items.EQUIP_SLOTS:
		if String((player.equipment.get(slot, {}) as Dictionary).get("base", "")) == "base.sword.iron_jian":
			m44_swords_before += 1
	var m44_stones_before := Game.spirit_stones
	var m44_ore_before: int = int(Crafting.material_counts(player.inventory).get("ore", 0))
	main.forge_act()
	var m44_swords_after := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("base", "")) == "base.sword.iron_jian":
			m44_swords_after += 1
	for slot in Items.EQUIP_SLOTS:
		if String((player.equipment.get(slot, {}) as Dictionary).get("base", "")) == "base.sword.iron_jian":
			m44_swords_after += 1
	check(m44_swords_after == m44_swords_before + 1, "the forge puts a real piece in hand")
	check(Game.spirit_stones == m44_stones_before - 60, "forging charges its stones")
	check(int(Crafting.material_counts(player.inventory).get("ore", 0)) == m44_ore_before - 3, "forging spends its ore")
	check(Game.crafts_made > 0, "an attempt is recorded")

	var m44_refine := Items.normalize_item({
		"id": "item.m44.refine", "base": "base.sword.iron_jian", "slot": "weapon",
		"name": "Iron Jian", "ilvl": 3, "rarity": 1, "value": 30})
	player.inventory = Items.add_to_inventory(player.inventory, m44_refine)
	main.forge_mode = 1
	var m44_refine_index := -1
	for i in main.forge_rows().size():
		if String((main.forge_rows()[i] as Dictionary).get("id", "")) == "item.m44.refine":
			m44_refine_index = i
	check(m44_refine_index >= 0, "the forge lists satchel gear for refining")
	main.forge_index = m44_refine_index
	var m44_refine_stones := Game.spirit_stones
	var m44_refine_ore: int = int(Crafting.material_counts(player.inventory).get("ore", 0))
	main.forge_act()
	check(Game.spirit_stones == m44_refine_stones - 40, "refining charges its stones")
	check(int(Crafting.material_counts(player.inventory).get("ore", 0)) == m44_refine_ore - 2, "refining spends its ore")

	var m44_ring := Items.normalize_item({
		"id": "item.m44.ring", "base": "base.ring.jade", "slot": "ring",
		"name": "Jade Ring", "ilvl": 3, "rarity": 2, "value": 40})
	player.inventory = Items.add_to_inventory(player.inventory, m44_ring)
	main.forge_mode = 2
	var m44_ring_index := -1
	for i in main.forge_rows().size():
		if String((main.forge_rows()[i] as Dictionary).get("id", "")) == "item.m44.ring":
			m44_ring_index = i
	check(m44_ring_index >= 0, "the forge lists gear for breaking down")
	main.forge_index = m44_ring_index
	var m44_break_ore: int = int(Crafting.material_counts(player.inventory).get("ore", 0))
	main.forge_act()
	check(int(Crafting.material_counts(player.inventory).get("ore", 0)) == m44_break_ore + Crafting.disassemble_ore(m44_ring), "disassembly returns ore")
	var m44_ring_gone := true
	for entry in player.inventory:
		if String((entry as Dictionary).get("id", "")) == "item.m44.ring":
			m44_ring_gone = false
	check(m44_ring_gone, "the broken piece leaves the satchel")
	main.close_forge()
	check(not main.forge_open and player.is_physics_processing(), "closing the forge resumes play")

	# --- alchemy: brew at the cauldron, then drink what comes out ---------------
	var m45_cauldron := _find_interactable(main.interactables, "alchemy.cauldron")
	check(m45_cauldron != null and m45_cauldron.kind == Interactable.Kind.ALCHEMY, "the settlement has a cauldron")
	Game.spirit_stones = maxi(Game.spirit_stones, 500)
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.herb", "slot": "material", "name": "Spirit Herb", "material": "herb", "count": 8}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.core", "slot": "material", "name": "Beast Core", "material": "core", "count": 3}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.marrow", "slot": "material", "name": "Root Marrow", "material": "marrow", "count": 2}))

	main._open_alchemy()
	check(main.alchemy_open, "the cauldron opens")
	check(not player.is_physics_processing(), "the cauldron freezes play")
	var m45_rows: Array = main.alchemy_rows()
	check(m45_rows.size() == DB.potions.size(), "the cauldron lists every potion")
	var m45_index := -1
	for i in m45_rows.size():
		if String((m45_rows[i] as Dictionary).get("id", "")) == "potion.qi_gathering":
			m45_index = i
	check(m45_index >= 0, "the qi potion is on the list")
	main.alchemy_index = m45_index
	var m45_herbs: int = int(Crafting.material_counts(player.inventory).get("herb", 0))
	var m45_stones := Game.spirit_stones
	var m45_pills_before := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("base", "")) == "base.pill.qi_gathering":
			m45_pills_before += int((entry as Dictionary).get("count", 1))
	main.alchemy_act()
	var m45_pills_after := 0
	for entry in player.inventory:
		if String((entry as Dictionary).get("base", "")) == "base.pill.qi_gathering":
			m45_pills_after += int((entry as Dictionary).get("count", 1))
	check(m45_pills_after == m45_pills_before + 1, "the cauldron produces a pill")
	check(int(Crafting.material_counts(player.inventory).get("herb", 0)) == m45_herbs - 2, "brewing spends its herbs")
	check(Game.spirit_stones == m45_stones - 30, "brewing charges its stones")
	main.close_alchemy()
	check(not main.alchemy_open and player.is_physics_processing(), "closing the cauldron resumes play")

	# A pill at a known strength, drunk from the satchel. Each remedy carries a
	# distinct potency so shop stock of the same base cannot merge with it.
	const M45_QI_POTENCY := 1.13
	const M45_MEND_POTENCY := 1.11
	const M45_CLEANSE_POTENCY := 1.12
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.pill", "base": "base.pill.qi_gathering", "slot": "consumable",
		"name": "Qi Gathering Pill", "ilvl": 1, "potency": M45_QI_POTENCY}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.mend", "base": "base.pill.mending", "slot": "consumable",
		"name": "Mending Pill", "potency": M45_MEND_POTENCY}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m45.cleanse", "base": "base.pill.cleansing", "slot": "consumable",
		"name": "Cleansing Pill", "potency": M45_CLEANSE_POTENCY}))
	player.cultivation.qi = 0.0
	player.hp = 10.0
	player.cultivation.contamination = 60.0
	main.toggle_gear()
	check(main.gear_open, "the satchel opens for the pills")
	var m45_pill_index := -1
	var m45_mend_index := -1
	var m45_cleanse_index := -1
	for i in main.inventory_rows().size():
		var row: Dictionary = main.inventory_rows()[i]
		var row_base := String(row.get("base", ""))
		var row_potency := float(row.get("potency", 1.0))
		if row_base == "base.pill.qi_gathering" and is_equal_approx(row_potency, M45_QI_POTENCY):
			m45_pill_index = i
		if row_base == "base.pill.mending" and is_equal_approx(row_potency, M45_MEND_POTENCY):
			m45_mend_index = i
		if row_base == "base.pill.cleansing" and is_equal_approx(row_potency, M45_CLEANSE_POTENCY):
			m45_cleanse_index = i
	check(m45_pill_index >= 0 and m45_mend_index >= 0 and m45_cleanse_index >= 0, "all three remedies are carried")
	main.gear_index = m45_pill_index
	main.use_selected_item()
	var m45_cap := player.cultivation.qi_max(player.stats)
	check(player.cultivation.qi > 0.0, "a qi pill restores Qi")
	check(is_equal_approx(player.cultivation.qi, minf(m45_cap, 45.0 * M45_QI_POTENCY)), "potency decides how much")
	var m45_pill_left := false
	for entry in player.inventory:
		var remaining_entry: Dictionary = entry
		if String(remaining_entry.get("base", "")) == "base.pill.qi_gathering" \
				and is_equal_approx(float(remaining_entry.get("potency", 1.0)), M45_QI_POTENCY):
			m45_pill_left = true
	check(not m45_pill_left, "a drunk pill leaves the satchel")

	# Drinking removes a stack, so each remedy is found again just before use.
	m45_mend_index = -1
	for i in main.inventory_rows().size():
		var mend_row: Dictionary = main.inventory_rows()[i]
		if String(mend_row.get("base", "")) == "base.pill.mending" \
				and is_equal_approx(float(mend_row.get("potency", 1.0)), M45_MEND_POTENCY):
			m45_mend_index = i
	check(m45_mend_index >= 0, "the mending pill is still carried")
	main.gear_index = m45_mend_index
	main.use_selected_item()
	check(is_equal_approx(player.hp, minf(player.hp_max, 10.0 + 50.0 * M45_MEND_POTENCY)), "a mending pill closes wounds")
	m45_cleanse_index = -1
	for i in main.inventory_rows().size():
		var cleanse_row: Dictionary = main.inventory_rows()[i]
		if String(cleanse_row.get("base", "")) == "base.pill.cleansing" \
				and is_equal_approx(float(cleanse_row.get("potency", 1.0)), M45_CLEANSE_POTENCY):
			m45_cleanse_index = i
	check(m45_cleanse_index >= 0, "the cleansing pill is still carried")
	main.gear_index = m45_cleanse_index
	main.use_selected_item()
	check(is_equal_approx(player.cultivation.contamination, 60.0 - 35.0 * M45_CLEANSE_POTENCY), "a cleansing pill purges contamination")
	main.close_gear()

	# --- professions: practice earns ranks, ranks open recipes ------------------
	Game.professions.clear()
	check(Professions.level_of(Game.professions, "profession.smith") == 0, "a run begins as an apprentice")
	Game.spirit_stones = maxi(Game.spirit_stones, 1000)
	player.cultivation.realm = 3
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m46.ore", "slot": "material", "name": "Spirit Ore", "material": "ore", "count": 8}))
	player.inventory = Items.add_to_inventory(player.inventory, Items.normalize_item({
		"id": "item.m46.core", "slot": "material", "name": "Spirit Core", "material": "core", "count": 4}))

	main._open_forge()
	main.forge_mode = 0
	var m46_ring_index := -1
	for i in main.forge_rows().size():
		if String((main.forge_rows()[i] as Dictionary).get("id", "")) == "recipe.forge.spirit_iron_ring":
			m46_ring_index = i
	check(m46_ring_index >= 0, "the masterwork is listed even when locked")
	main.forge_index = m46_ring_index
	var m46_stones := Game.spirit_stones
	var m46_attempts := Game.crafts_made
	main.forge_act()
	check(Game.spirit_stones == m46_stones, "a locked recipe costs nothing")
	check(Game.crafts_made == m46_attempts, "a locked recipe is not even an attempt")

	var m46_award := Professions.award(Game.professions, "profession.smith", 10)
	check(int(m46_award["level"]) == 2 and bool(m46_award["leveled"]), "practice earns the adept rank")
	check(bool(Professions.gate(DB.recipe("recipe.forge.spirit_iron_ring"), Game.professions, DB).get("ok", false)),
		"the adept may take the masterwork")
	main.forge_act()
	check(Game.crafts_made == m46_attempts + 1, "an unlocked recipe is a real attempt")
	check(Game.spirit_stones == m46_stones - 160, "an unlocked recipe charges its stones")
	main.close_forge()

	# Alchemy gates on its own profession, not the smith's.
	Game.professions["profession.alchemist"] = {"xp": 0}
	main._open_alchemy()
	var m46_potion_index := -1
	for i in main.alchemy_rows().size():
		if String((main.alchemy_rows()[i] as Dictionary).get("id", "")) == "potion.cleansing":
			m46_potion_index = i
	check(m46_potion_index >= 0, "the cleansing pill is listed even when locked")
	main.alchemy_index = m46_potion_index
	var m46_herbs: int = int(Crafting.material_counts(player.inventory).get("herb", 0))
	main.alchemy_act()
	check(int(Crafting.material_counts(player.inventory).get("herb", 0)) == m46_herbs, "a locked pill spends no herbs")
	Professions.award(Game.professions, "profession.alchemist", 4)
	check(bool(Professions.gate(DB.potion("potion.mending"), Game.professions, DB).get("ok", false)),
		"practice opens the mending pill")
	main.close_alchemy()

	# --- NPC database: every body carries a whole record ------------------------
	check(main.npcs.size() >= 18, "the market still holds its population (%d)" % main.npcs.size())
	var m47_sheet_ok := true
	var m47_root_ok := true
	var m47_gear_ok := true
	var m47_arts_ok := true
	var m47_goals_ok := true
	var m47_rules := Equipment.new(DB)
	for m47_value in main.npcs:
		var m47_npc: Npc = m47_value
		if m47_npc.root_id == "" or m47_npc.physique_id == "" or m47_npc.goals.is_empty() or m47_npc.attrs.total() <= 0:
			m47_sheet_ok = false
		var m47_root_entry: Dictionary = DB.by_id("root", m47_npc.root_id)
		if m47_root_entry.is_empty() or int(m47_root_entry.get("tier", 0)) != m47_npc.root_tier:
			m47_root_ok = false
		for m47_slot in m47_npc.gear.keys():
			var m47_piece: Dictionary = m47_npc.gear[m47_slot]
			if not m47_rules.missing_requirements(m47_piece, m47_npc.attrs, m47_npc.realm).is_empty():
				m47_gear_ok = false
		for m47_tech in m47_npc.technique_ids:
			var m47_state: Dictionary = {"realm": m47_npc.realm, "attrs": m47_npc.attrs}
			if not bool(Techniques.can_learn(String(m47_tech), m47_state).get("ok", false)):
				m47_arts_ok = false
		for m47_goal in m47_npc.goals:
			if DB.npc_goal(String(m47_goal)).is_empty():
				m47_goals_ok = false
	check(m47_sheet_ok, "every NPC has attributes, a root, a body and ambitions")
	check(m47_root_ok, "every NPC's root tier matches its root")
	check(m47_gear_ok, "every NPC wears only gear it qualifies for")
	check(m47_arts_ok, "every NPC knows only arts it qualifies for")
	check(m47_goals_ok, "every NPC's goals are authored")
	var m47_elder: Npc = main.elder as Npc
	check(m47_elder.attrs.get_attr("int") > 20, "an elder outclasses a mortal")
	check(m47_elder.technique_ids.size() == 2, "an elder carries two arts")
	check(not m47_elder.gear.is_empty(), "an elder is geared")

	var m47_common: Npc = null
	for m47_person in main.npcs:
		var m47_resident: Npc = m47_person
		if m47_resident.npc_id != "elder_bai" and m47_resident.npc_id != "instructor_rui":
			m47_common = m47_resident
			break
	check(m47_common != null, "a generic resident exists")
	m47_common.global_position = player.global_position + Vector2(20, 0)
	check(main.nearest_npc() == m47_common, "the closest person is offered to the dossier")
	var m47_before := NpcDb.memory_entry(Game.npc_memory, m47_common.npc_id)
	main._talk(m47_common)
	var m47_after := NpcDb.memory_entry(Game.npc_memory, m47_common.npc_id)
	check(bool(m47_after.get("met", false)), "talking introduces the player")
	check(int(m47_after.get("talks", 0)) == int(m47_before.get("talks", 0)) + 1, "talking is counted")
	check(int(m47_after.get("last_day", -1)) == Clock.day, "talking records the day")
	check(int(m47_after.get("regard", 0)) > int(m47_before.get("regard", 0)), "talking warms regard")
	check(m47_common.standing() == m47_common.base_disposition + int(m47_after.get("regard", 0)),
		"standing reads base disposition plus memory")
	var m47_expected: Dictionary = NpcDb.sheet(
		main._archetype(m47_common.archetype_id), m47_common.npc_id, m47_common.realm)
	check(String(m47_expected.get("root_id", "")) == m47_common.root_id, "the carried root is the generated one")
	check(int((m47_expected["attrs"] as Dictionary)["str"]) == m47_common.attrs.get_attr("str"),
		"the carried attributes are the generated ones")

	# Memory is the only part of a person a save has to carry.
	Save.delete_slot(85)
	var m47_talks := int(m47_after.get("talks", 0))
	var m47_regard := int(m47_after.get("regard", 0))
	main._save(85)
	Game.npc_memory.clear()
	main._load_game(85)
	var m47_loaded := NpcDb.memory_entry(Game.npc_memory, m47_common.npc_id)
	check(int(m47_loaded.get("talks", 0)) == m47_talks, "NPC memory survives a save")
	check(int(m47_loaded.get("regard", 0)) == m47_regard, "regard survives a save")
	check(m47_common.standing() == m47_common.base_disposition + m47_regard,
		"a loaded NPC reads the restored memory")
	Save.delete_slot(85)

	# --- schedules: the week changes the routine, and the routine has teeth ----
	var m48_day: int = Clock.day
	var m48_hour: float = Clock.hour
	check(Clock.WEEK_DAYS.size() == 7, "the calendar names a seven-day week")
	check(Schedules.validate(DB.schedules().get("disciple", []), "disciple", Settlement.LOCATIONS.keys()).is_empty(),
		"the shipped routines are complete")

	var m48_disciple: Npc = null
	for m48_person in main.npcs:
		var m48_resident: Npc = m48_person
		if m48_resident.archetype_id == "inner_disciple" or m48_resident.archetype_id == "outer_disciple":
			m48_disciple = m48_resident
			break
	check(m48_disciple != null, "a disciple walks the market")
	Clock.day = 3
	Clock.hour = 10.0
	m48_disciple.snap_to_schedule()
	check(m48_disciple.current_activity == "train" and m48_disciple.current_location == "training",
		"a weekday morning sends a disciple to train")
	check(m48_disciple.is_awake(), "a training disciple can be spoken to")
	var m48_next: Dictionary = Schedules.next_entry(m48_disciple.active_schedule(), 10, Clock.weekday())
	check(int(m48_next.get("from", 0)) == 12, "the routine knows when the training block ends")

	Clock.day = 7
	m48_disciple.snap_to_schedule()
	check(Clock.is_rest_day(), "day seven is the Restday")
	check(m48_disciple.current_location == "market" and m48_disciple.current_activity == "socialize",
		"a Restday morning moves the disciple to the market")

	Clock.day = 3
	Clock.hour = 23.0
	m48_disciple.snap_to_schedule()
	check(m48_disciple.current_activity == "sleep", "the night sends a disciple to bed")
	m48_disciple.global_position = player.global_position + Vector2(12, 0)
	var m48_talks := int(NpcDb.memory_entry(Game.npc_memory, m48_disciple.npc_id).get("talks", 0))
	main._talk(m48_disciple)
	check(int(NpcDb.memory_entry(Game.npc_memory, m48_disciple.npc_id).get("talks", 0)) == m48_talks,
		"a sleeping NPC is not spoken to")
	check(String(main.interaction_prompt()).contains("asleep"), "the prompt warns that the body is asleep")

	Clock.hour = 10.0
	m48_disciple.snap_to_schedule()
	main._talk(m48_disciple)
	check(int(NpcDb.memory_entry(Game.npc_memory, m48_disciple.npc_id).get("talks", 0)) == m48_talks + 1,
		"a wakeful NPC answers")

	Clock.hour = 13.0
	instructor.snap_to_schedule()
	check(not instructor.teaches_here(), "the instructor is off duty after the morning block")
	var m48_stones: int = Game.spirit_stones
	Game.spirit_stones = maxi(Game.spirit_stones, 500)
	var m48_purse: int = Game.spirit_stones
	main._talk(instructor)
	check(Game.spirit_stones == m48_purse, "an off-duty lesson costs nothing")
	Clock.hour = 10.0
	instructor.snap_to_schedule()
	check(instructor.teaches_here(), "the instructor teaches during morning training")

	Clock.day = m48_day
	Clock.hour = m48_hour
	Game.spirit_stones = m48_stones
	for m48_node in main.npcs:
		var m48_restore: Npc = m48_node
		m48_restore.snap_to_schedule()

	# --- NPC intelligence: the market notices trouble and does something -------
	var m49_day: int = Clock.day
	var m49_hour: float = Clock.hour
	# The town is only simulated near the player, so the scenario stands in the
	# market rather than watching a sleeping settlement from across the province.
	var m49_player_home: Vector2 = player.global_position
	Clock.day = 3
	Clock.hour = 10.0
	player.global_position = main.settlement.position_for("plaza")
	await frames(2)

	var m49_guard: Npc = null
	var m49_farmer: Npc = null
	var m49_merchant: Npc = null
	for m49_entry in main.npcs:
		var m49_resident: Npc = m49_entry
		if m49_guard == null and m49_resident.archetype_id == "guard":
			m49_guard = m49_resident
		elif m49_farmer == null and m49_resident.archetype_id == "farmer":
			m49_farmer = m49_resident
		elif m49_merchant == null and m49_resident.archetype_id == "merchant":
			m49_merchant = m49_resident
	check(m49_guard != null and m49_farmer != null and m49_merchant != null,
		"the market keeps a guard, a farmer and a merchant")

	var m49_plaza: Vector2 = main.settlement.position_for("plaza")
	for m49_row in [m49_guard, m49_farmer, m49_merchant]:
		var m49_person: Npc = m49_row
		m49_person.wake()
		m49_person.stand_down()
	check(m49_guard.simulated and m49_farmer.simulated and m49_merchant.simulated,
		"a body in the market is simulated")
	m49_guard.global_position = m49_plaza + Vector2(60, 0)
	m49_farmer.global_position = m49_plaza + Vector2(-40, 40)
	m49_merchant.global_position = m49_plaza + Vector2(0, -300)
	check(not m49_guard.reacting(), "a quiet market is nobody's alarm")

	var m49_threat := Dummy.new()
	m49_threat.aggressive = true
	m49_threat.display_name = "Test Beast"
	main.world.add_child(m49_threat)
	m49_threat.global_position = m49_plaza + Vector2(90, 0)
	# A threat that will not chase: this block is about who notices it, not a fight.
	m49_threat.profile["aggro_range"] = 1.0
	await frames(2)
	main._alert_timer = 0.0
	main._direct_npcs(0.3)

	check(m49_guard.reacting() and m49_guard.reaction == "confront",
		"a guard stands its ground against a body in the market")
	check(m49_farmer.reacting() and m49_farmer.reaction == "flee",
		"a farmer runs from the same body")
	check(m49_merchant.reacting() and m49_merchant.reaction == "shelter",
		"a merchant shuts the stall")
	check(m49_merchant.threat_distance > float(m49_merchant.ai.get("alert_range", 0.0)),
		"the merchant answers a neighbour's shout, not its own sighting")
	check(m49_guard.reaction_line().contains("paces"), "the dossier reads the alarm")
	check(m49_guard.goal_position().distance_to(m49_threat.global_position) < 120.0,
		"a confronting body closes on the threat")
	check(m49_farmer.goal_position().distance_to(main.settlement.position_for("fields")) < 1.0,
		"a fleeing body heads for the fields")
	check(m49_merchant.goal_position().distance_to(main.settlement.position_for("tavern")) < 1.0,
		"a sheltering body heads indoors")

	m49_guard.global_position = player.global_position + Vector2(14, 0)
	var m49_talks := int(NpcDb.memory_entry(Game.npc_memory, m49_guard.npc_id).get("talks", 0))
	main._talk(m49_guard)
	check(int(NpcDb.memory_entry(Game.npc_memory, m49_guard.npc_id).get("talks", 0)) == m49_talks,
		"an alarmed guard answers with the alarm, not the routine")
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("Get behind me"),
		"the guard shouts its warning")

	m49_threat.queue_free()
	await frames(2)
	for m49_sweep in [m49_guard, m49_farmer, m49_merchant]:
		var m49_calm: Npc = m49_sweep
		m49_calm.alarm_left = 0.0
		m49_calm.stand_down()
		check(not m49_calm.reacting() and m49_calm.reaction == "routine",
			"%s returns to the routine" % m49_calm.display_name)
	check(m49_guard.current_activity == "patrol" and m49_guard.current_location == "gate",
		"a stood-down guard walks back to the gate")

	Clock.hour = 23.0
	m49_guard.snap_to_schedule()
	var m49_night := Dummy.new()
	m49_night.aggressive = true
	main.world.add_child(m49_night)
	m49_night.global_position = m49_guard.global_position + Vector2(40, 0)
	m49_night.profile["aggro_range"] = 1.0
	await frames(2)
	main._alert_timer = 0.0
	main._direct_npcs(0.3)
	check(not m49_guard.is_awake(), "the night puts the guard to bed")
	check(not m49_guard.reacting(), "a sleeping body is not alarmed")
	m49_night.queue_free()
	await frames(2)

	Clock.day = m49_day
	Clock.hour = m49_hour
	player.global_position = m49_player_home
	for m49_restore_row in main.npcs:
		var m49_restored: Npc = m49_restore_row
		m49_restored.alarm_left = 0.0
		m49_restored.reaction = "routine"
		m49_restored.snap_to_schedule()

	# --- relationships: a directed graph, authored ties and what they change ---
	var m50_day: int = Clock.day
	var m50_hour: float = Clock.hour
	var m50_home: Vector2 = player.global_position
	Clock.day = 3
	Clock.hour = 10.0
	player.global_position = main.settlement.position_for("plaza")
	Game.npc_memory.clear()
	for m50_node in main.npcs:
		var m50_person: Npc = m50_node
		m50_person.alarm_left = 0.0
		m50_person.reaction = "routine"
		m50_person.snap_to_schedule()
	await frames(2)

	check(not main.npcs.is_empty(), "the settlement is populated")
	var m50_ids: Array = []
	for m50_entry in main.npcs:
		m50_ids.append((m50_entry as Npc).npc_id)
	check(m50_ids.size() == main.npcs.size(), "every resident has a stable id")
	var m50_graph := Relationships.graph(m50_ids)
	check(m50_graph.size() == m50_ids.size(), "the whole settlement is in the graph")
	var m50_edges := 0
	var m50_bands_ok := true
	var m50_asymmetric := false
	for m50_from in m50_graph.keys():
		var m50_row: Dictionary = m50_graph[m50_from]
		m50_edges += m50_row.size()
		for m50_to in m50_row.keys():
			var m50_edge: Dictionary = m50_row[m50_to]
			if DB.bond(String(m50_edge.get("band", ""))).is_empty():
				m50_bands_ok = false
			var m50_back: Dictionary = (m50_graph[m50_to] as Dictionary)[m50_from]
			if int(m50_back.get("score", 0)) != int(m50_edge.get("score", 0)):
				m50_asymmetric = true
	check(m50_edges == m50_ids.size() * (m50_ids.size() - 1),
		"every resident has an edge to every other, one direction each")
	check(m50_bands_ok, "every edge reads through a shipped band")
	check(m50_asymmetric, "the town does not feel one way about itself")

	var m50_elder: Npc = main.elder as Npc
	check(String(Relationships.edge("elder_bai", "instructor_rui").get("tie_label", "")) == "Mentor",
		"the elder mentors the instructor")
	check(main.npc_tie_line(m50_elder).contains("Mentor"), "the dossier names the relation")
	check(main.npc_tie_line(m50_elder).contains("Instructor Rui"),
		"the dossier names the tie through the spawned person")
	check(main.person_name("elder_bai") == "Elder Bai Qing", "a stable id resolves to the displayed name")

	var m50_guard: Npc = null
	var m50_other: Npc = null
	for m50_pick in main.npcs:
		var m50_resident: Npc = m50_pick
		if m50_guard == null and m50_resident.archetype_id == "guard":
			m50_guard = m50_resident
		elif m50_other == null and m50_resident.npc_id != "elder_bai" and m50_resident.npc_id != "instructor_rui":
			m50_other = m50_resident
	check(m50_guard != null and m50_other != null, "a guard and a neighbour stand in the market")
	var m50_quiet := m50_guard.bond_to_player()
	check(String(m50_quiet.get("band", "")) == "bond.stranger", "an unmet guard is a stranger, not a friend")
	check(not Relationships.warns(int(m50_quiet.get("score", 0))), "a stranger keeps quiet")

	# Memory is the only stored half; the band is read through it.
	Game.npc_memory[m50_guard.npc_id] = {"met": true, "talks": 3, "last_day": Clock.day, "regard": 30}
	var m50_warm := m50_guard.bond_to_player()
	check(int(m50_warm.get("score", 0)) == 25, "temperament and memory set the bond")
	check(String(m50_warm.get("band", "")) == "bond.friend", "a guard at the cap is a friend")
	m50_guard.global_position = player.global_position + Vector2(16, 0)
	main._talk(m50_guard)
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("face warms"),
		"a friend greets the player differently")

	var m50_threat := Dummy.new()
	m50_threat.aggressive = true
	main.world.add_child(m50_threat)
	m50_threat.global_position = main.settlement.position_for("plaza") + Vector2(80, 0)
	m50_threat.profile["aggro_range"] = 1.0
	await frames(2)
	main._warn_timer = 0.0
	main._alert_timer = 0.0
	main._direct_npcs(0.3)
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("Stay close"),
		"a friend calls a warning to the player")
	_toasts.clear()
	main._alert_timer = 0.0
	main._direct_npcs(0.3)
	check(_toasts.is_empty(), "one warning is enough for one crisis")

	# The alarm would answer for the guard; this block is about the bond.
	m50_guard.alarm_left = 0.0
	m50_guard.stand_down()
	Game.npc_memory[m50_guard.npc_id] = {"met": true, "talks": 2, "last_day": Clock.day, "regard": -30}
	var m50_cold := m50_guard.bond_to_player()
	check(String(m50_cold.get("band", "")) == "bond.enemy", "a guard pushed to the floor is an enemy")
	var m50_talks := int(NpcDb.memory_entry(Game.npc_memory, m50_guard.npc_id).get("talks", 0))
	main._talk(m50_guard)
	check(int(NpcDb.memory_entry(Game.npc_memory, m50_guard.npc_id).get("talks", 0)) == m50_talks,
		"an enemy is not spoken with")
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("turns away"),
		"an enemy turns away")
	check(not Relationships.warns(int(m50_cold.get("score", 0))), "an enemy does not warn the player")
	check(int(m50_other.bond_to_player().get("score", 0)) == m50_other.base_disposition,
		"a neighbour is unaffected by the guard's fall")

	m50_threat.queue_free()
	await frames(2)
	for m50_restore_row in main.npcs:
		var m50_restored: Npc = m50_restore_row
		m50_restored.alarm_left = 0.0
		m50_restored.reaction = "routine"
		m50_restored.snap_to_schedule()
	Game.npc_memory.clear()
	main._warn_timer = 0.0
	main._alert_timer = 0.0
	Clock.day = m50_day
	Clock.hour = m50_hour
	player.global_position = m50_home

	# --- party: a friend joins, fights with its own build and can fall --------
	var m51_day: int = Clock.day
	var m51_hour: float = Clock.hour
	var m51_home: Vector2 = player.global_position
	Clock.day = 3
	Clock.hour = 10.0
	player.global_position = main.settlement.position_for("plaza")
	Game.party_ids.clear()
	Game.npc_memory.clear()
	for m51_node in main.npcs:
		var m51_person: Npc = m51_node
		m51_person.leave_party()
		m51_person.snap_to_schedule()
	await frames(2)

	var m51_guard: Npc = null
	for m51_pick in main.npcs:
		var m51_resident: Npc = m51_pick
		if m51_guard == null and m51_resident.archetype_id == "guard":
			m51_guard = m51_resident
	check(m51_guard != null, "a guard can be asked")
	m51_guard.global_position = player.global_position + Vector2(20, 0)
	main._toggle_party()
	check(Game.party_ids.is_empty() and not m51_guard.in_party, "a stranger is not recruited")
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("trust"),
		"the refusal explains itself")

	Game.npc_memory[m51_guard.npc_id] = {"met": true, "talks": 4, "last_day": Clock.day, "regard": 30}
	check(String(m51_guard.bond_to_player().get("band", "")) == "bond.friend",
		"the guard is a friend at the cap")
	check(String(main.interaction_prompt()).contains("P recruit"), "a friend offers to join")
	main._toggle_party()
	check(Game.party_ids.has(m51_guard.npc_id) and m51_guard.in_party, "a friend joins the party")
	check(m51_guard.hp_max > 0.0 and m51_guard.hp == m51_guard.hp_max,
		"a companion is ready to fight")
	check(m51_guard.party_damage() > 0.0, "a companion brings its own blow")
	check(String(main.interaction_prompt()).contains("P dismiss"), "a companion can be sent home")
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("joins you"),
		"joining is announced")

	# The follower keeps station behind the player.
	player.global_position = main.settlement.position_for("plaza") + Vector2(0, 260)
	var m51_far := m51_guard.global_position.distance_to(player.global_position)
	await frames(40)
	var m51_near := m51_guard.global_position.distance_to(player.global_position)
	check(m51_near < m51_far, "a companion follows the player")
	await frames(80)
	check(m51_guard.global_position.distance_to(player.global_position) < 180.0,
		"a companion closes to formation")

	# It fights with its real build, and the enemy answers in kind.
	var m51_target := Dummy.new()
	m51_target.ilvl = 2
	m51_target.display_name = "Sparring Beast"
	main.world.add_child(m51_target)
	m51_target.global_position = m51_guard.global_position + Vector2(0, 26)
	m51_target.hp_max = 5000.0
	m51_target.hp = 5000.0
	m51_target.profile["aggro_range"] = 300.0
	# Put the player well out of the way, so "nearest body" has one answer.
	player.global_position = m51_guard.global_position + Vector2(700, 0)
	await frames(2)
	check(m51_target._combat_target() == m51_guard, "the enemy turns on the nearest body, not the player")
	var m51_enemy_hp := m51_target.hp
	await frames(90)
	check(m51_target.hp < m51_enemy_hp, "a companion strikes with its own build")

	m51_target.set_physics_process(false)
	var m51_before_hit := m51_guard.hp
	var m51_landed := false
	# A companion may slip a blow, like anyone else; six committed swings make a
	# clean miss on every one of them vanishingly unlikely.
	for _m51_swing in 6:
		if m51_guard.hp < m51_before_hit:
			m51_landed = true
			break
		m51_target.global_position = m51_guard.global_position + Vector2(0, 24)
		m51_target._facing = m51_target.global_position.direction_to(m51_guard.global_position)
		m51_target._release_attack(m51_guard)
	check(m51_landed, "an enemy blow lands on a companion")

	m51_guard.take_hit(m51_guard.hp_max * 2.0, Vector2.ZERO, false)
	check(not m51_guard.in_party, "a downed companion leaves the party")
	check(not Game.party_ids.has(m51_guard.npc_id), "the roster drops a downed companion")
	check(m51_guard.hp > 0.0, "a downed companion is not dead")

	# Membership is the only party state a save carries.
	var m51_other: Npc = null
	for m51_scan in main.npcs:
		var m51_candidate: Npc = m51_scan
		if m51_other == null and m51_candidate.npc_id != "elder_bai" \
				and m51_candidate.npc_id != "instructor_rui" and m51_candidate != m51_guard:
			m51_other = m51_candidate
	check(m51_other != null, "another resident can be asked")
	m51_guard.global_position = main.settlement.position_for("gate")
	m51_other.global_position = player.global_position + Vector2(20, 0)
	Game.npc_memory[m51_other.npc_id] = {"met": true, "talks": 4, "last_day": Clock.day, "regard": 30}
	main._toggle_party()
	check(Game.party_ids.has(m51_other.npc_id) and m51_other.in_party, "a second friend can join")

	Save.delete_slot(84)
	main._save(84)
	Game.party_ids.clear()
	m51_other.leave_party()
	check(not m51_other.in_party, "the roster can be emptied by hand")
	main._load_game(84)
	check(Game.party_ids.has(m51_other.npc_id), "the party survives a save")
	check(m51_other.in_party, "a loaded companion is back at the player's side")
	main._dismiss_party_member(m51_other)
	check(not m51_other.in_party and not Game.party_ids.has(m51_other.npc_id),
		"a companion can be sent home")
	Save.delete_slot(84)

	m51_target.queue_free()
	await frames(2)
	Game.party_ids.clear()
	Game.npc_memory.clear()
	m51_guard.leave_party()
	m51_other.leave_party()
	main._warn_timer = 0.0
	main._alert_timer = 0.0
	Clock.day = m51_day
	Clock.hour = m51_hour
	player.global_position = m51_home
	for m51_restore_row in main.npcs:
		var m51_restored: Npc = m51_restore_row
		m51_restored.leave_party()
		m51_restored.alarm_left = 0.0
		m51_restored.reaction = "routine"
		m51_restored.snap_to_schedule()

	# --- captivity: beat, bind, keep, hand over, save ------------------------
	var m52_day: int = Clock.day
	var m52_hour: float = Clock.hour
	var m52_home: Vector2 = player.global_position
	var m52_toggle: bool = bool(Settings.content.get("captivity", true))
	Clock.day = 11
	Clock.hour = 10.0
	player.global_position = main.settlement.position_for("plaza")
	Game.captives.clear()
	Game.notoriety = 0
	Game.captive_seq = 0
	Game.captive_policy = Captivity.default_policy_id()
	main._captive_day = Clock.day
	Settings.content["captivity"] = true
	await frames(2)

	var m52_body := Dummy.new()
	m52_body.ilvl = 2
	main.world.add_child(m52_body)
	m52_body.global_position = player.global_position + Vector2(36, 0)
	m52_body.profile["aggro_range"] = 0.0
	var m52_kills: int = Game.kills
	m52_body.hp = m52_body.hp_max * 0.1
	check(m52_body.weakened(), "a weakened enemy can be taken")
	check(String(main.interaction_prompt()).contains("H  Subdue"), "a weakened enemy offers the binding key")
	main._bind_captive()
	check(m52_body.subdued and m52_body.hp > 0.0, "subduing drops a foe without killing them")
	check(Game.kills == m52_kills, "taking a body alive is not a kill")
	check(m52_body.can_be_bound(), "a subdued body can still be bound")
	check(String(main.interaction_prompt()).contains("H  Bind"), "a subdued body offers the binding key")

	# Striking the subdued body is the third option: it finishes the fight.
	var m52_exec := Dummy.new()
	m52_exec.ilvl = 1
	main.world.add_child(m52_exec)
	m52_exec.global_position = player.global_position + Vector2(70, 0)
	m52_exec.hp = m52_exec.hp_max * 0.1
	m52_exec.subdue()
	m52_exec.take_hit(4.0, Vector2.ZERO, 0.0, 1.0)
	check(m52_exec.state == "dead" and Game.kills == m52_kills + 1,
		"striking a subdued body still kills it")
	await frames(2)

	main._bind_captive()
	check(Game.captives.size() == 1, "binding fills the holding yard")
	check(Game.notoriety == Captivity.capture_notoriety(), "taking a person marks your name")
	check(not _toasts.is_empty() and String(_toasts[_toasts.size() - 1]).contains("holding yard"),
		"the binding is announced")
	var m52_record: Dictionary = Game.captives[0]
	check(String(m52_record.get("name", "")) != "", "a captive has a name")
	check(int(m52_record.get("realm", 0)) >= 2, "a captive keeps the realm it was beaten at")
	check(int(m52_record.get("bound_day", 0)) == Clock.day, "a captive remembers the day it was taken")
	await frames(2)

	# The ledger is a frozen screen, and its terms change the whole yard.
	main.toggle_captives()
	check(main.captives_open, "the ledger opens on a full yard")
	var m52_policy_before := Game.captive_policy
	main._cycle_captive_policy()
	check(Game.captive_policy != m52_policy_before, "the ledger changes the terms")
	check(String((Game.captives[0] as Dictionary).get("policy", "")) == Game.captive_policy,
		"the terms apply to everyone held")
	main._cycle_captive_policy()
	Game.captive_policy = Captivity.default_policy_id()
	for m52_value in Game.captives:
		(m52_value as Dictionary)["policy"] = Game.captive_policy
	main.toggle_captives()
	check(not main.captives_open, "the ledger closes again")

	# A day of keeping: the work is paid, loyalty moves and the name grows.
	var m52_stones: int = Game.spirit_stones
	var m52_loyalty: int = int((Game.captives[0] as Dictionary).get("loyalty", 0))
	var m52_notoriety: int = Game.notoriety
	main._captive_day = Clock.day
	Clock.day += 1
	main._check_captivity()
	check(Game.spirit_stones > m52_stones, "a kept person earns stones for the yard")
	check(int((Game.captives[0] as Dictionary).get("loyalty", 0)) > m52_loyalty,
		"fair terms win a little loyalty")
	check(Game.notoriety > m52_notoriety, "holding people hardens your name")

	# Handing the sentence to the watch pays a bounty and buys relief.
	var m52_after_day: int = Game.spirit_stones
	main._hand_over_captive(0)
	check(Game.captives.is_empty(), "a handover empties the row")
	check(Game.spirit_stones > m52_after_day, "the watch pays its bounty")
	check(Game.notoriety < m52_notoriety + 5, "a handover buys the name some relief")

	# Release is the other ending: no coin, less of a name.
	Game.captives.append(Captivity.new_record("captive.test.release", "Wei Shan", 1, 0, Clock.day, Game.captive_policy))
	Game.notoriety = 12
	main._release_captive(0)
	check(Game.captives.is_empty(), "a released captive leaves the yard")
	check(Game.notoriety == 12 - Captivity.release_relief(), "release gives the name relief")

	# The roster and the name are saved; the terms travel with them.
	Game.captives.append(Captivity.new_record("captive.test.save", "Qiu Rou", 3, 0, Clock.day, Captivity.HARD_POLICY))
	Game.captive_policy = Captivity.HARD_POLICY
	Game.notoriety = 17
	Save.delete_slot(99)
	main._save(99)
	Game.captives.clear()
	Game.notoriety = 0
	Game.captive_policy = Captivity.default_policy_id()
	main._load_game(99)
	check(Game.captives.size() == 1 and String((Game.captives[0] as Dictionary).get("id", "")) == "captive.test.save",
		"the holding yard survives a save")
	check(Game.notoriety == 17, "the legal name survives a save")
	check(Game.captive_policy == Captivity.HARD_POLICY, "the terms survive a save")
	Save.delete_slot(99)

	# With the subsystem off, a beaten body dies as it always did.
	Game.captives.clear()
	Game.notoriety = 0
	Settings.content["captivity"] = false
	var m52_off_body := Dummy.new()
	m52_off_body.ilvl = 1
	main.world.add_child(m52_off_body)
	m52_off_body.global_position = player.global_position + Vector2(40, 0)
	m52_off_body.hp = m52_off_body.hp_max * 0.1
	check(not m52_off_body.weakened(), "a switched-off subsystem offers no binding")
	main._bind_captive()
	check(Game.captives.is_empty() and not m52_off_body.subdued, "nothing is taken with captivity off")
	m52_off_body.queue_free()
	await frames(2)
	Settings.content["captivity"] = m52_toggle

	Game.captives.clear()
	Game.captive_policy = Captivity.default_policy_id()
	Game.notoriety = 0
	Game.captive_seq = 0
	main._close_captives()
	main._captive_day = m52_day
	Clock.day = m52_day
	Clock.hour = m52_hour
	player.global_position = m52_home

	# --- npc progression: the town climbs from the seed and the day ----------
	var m53_day: int = Clock.day
	var m53_hour: float = Clock.hour
	var m53_home: Vector2 = player.global_position
	Clock.day = 4
	main._progress_day = Clock.day
	main._refresh_npc_progress_all()
	var m53_elder: Npc = main.elder
	check(m53_elder != null, "the elder exists")
	var m53_base: int = m53_elder.realm
	Clock.day = 600
	main._check_npc_progress()
	check(m53_elder.realm >= m53_base, "an elder never loses a realm to time")
	check(m53_elder.realm > m53_base, "the elder climbs over a year and a half")
	check(String(m53_elder.progress_line()).contains("Cultivation"), "the dossier reports the climb")
	check(String(m53_elder.progress_line()).contains(NpcProgress.stage_label(m53_elder.progress)),
		"the dossier names the stage the person stands on")
	check(m53_elder.attrs.get_attr("wis") >= 24, "the grown elder carries a grown sheet")
	check(int(m53_elder.progress.get("realm", 0)) == m53_elder.realm,
		"the body and its record agree")

	# A companion's build reads the realm it has reached.
	var m53_guard: Npc = null
	for m53_row in main.npcs:
		var m53_person: Npc = m53_row
		if m53_guard == null and m53_person.archetype_id == "guard":
			m53_guard = m53_person
	check(m53_guard != null, "a guard can be found")
	m53_guard.join_party()
	check(m53_guard.party_stats != null and m53_guard.hp_max > 0.0,
		"a grown companion brings a grown build")
	m53_guard.leave_party()

	# Progression is derived: a save carries the day, not the ladder.
	check(not Game.to_dict().has("progress"), "progression adds no save key")
	Save.delete_slot(100)
	main._save(100)
	main._load_game(100)
	var m53_loaded := NpcProgress.state_for(m53_elder.archetype_id, m53_elder.npc_id,
		Clock.day, Game.world_seed)
	check(m53_elder.realm == int(m53_loaded.get("realm", 0)),
		"a loaded town derives the same ladder")
	Save.delete_slot(100)

	Clock.day = m53_day
	Clock.hour = m53_hour
	player.global_position = m53_home
	main._progress_day = m53_day
	main._captive_day = m53_day
	main._refresh_npc_progress_all()

	# --- save / load ---------------------------------------------------------
	Save.delete_slot(96)
	player.cultivation.qi = 12.0
	Game.professions = {"profession.smith": {"xp": 12}}
	main._save(96)
	check(Save.has_save(96), "quick save writes through the scene")

	var saved_passives := player.passives.size()
	var saved_stones := Game.spirit_stones
	var saved_physique: String = player.physique_id
	player.passives.clear()
	player.rebuild_stats()
	main.quests.step_index = 0
	main.quests.completed = false
	main.inheritance_taken = false
	Game.spirit_stones = 0
	Game.professions.clear()
	main._load_game(96)
	check(absf(player.cultivation.qi - 12.0) < 0.01, "quick load restores Qi")
	check(player.passives.size() == saved_passives, "quick load restores passives")
	check(main.quests.completed, "quick load restores quest completion")
	check(main.inheritance_taken, "quick load restores the inheritance")
	check(player.physique_id == saved_physique, "quick load restores the physique")
	check(Game.spirit_stones == saved_stones, "quick load restores spirit stones")
	check(Professions.level_of(Game.professions, "profession.smith") == 2, "practice survives a save")
	check(container.used, "a searched container stays spent after loading")
	check(player.technique_ids.has("tech.blood.crimson_moon"), "a manual's technique survives a reload")
	Save.delete_slot(96)

	# M42: the storehouse and the chosen order are part of the run.
	Save.delete_slot(98)
	main.storage.items = Items.add_to_inventory(main.storage.items, Items.normalize_item({"id": "item.m42.keep", "slot": "material", "name": "Kept Ore", "base": "ore.spirit", "value": 4}))
	player.sort_inventory("value")
	main._save(98)
	main.storage.items.clear()
	main._load_game(98)
	check(main.storage.has("item.m42.keep"), "the storehouse survives a save")
	check(player.inventory_sort == "value", "the satchel order survives a save")
	Save.delete_slot(98)

	main.queue_free()
	await get_tree().process_frame
