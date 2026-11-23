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
var main: Node2D


func _ready() -> void:
	print("=== Eternal Ascension — integration test ===")
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

	var npc: Npc = main.npcs[0]
	await frames(3)
	check(npc.current_activity != "idle" or npc.current_location != "", "NPCs resolve a scheduled activity")

	var start_chunk: Vector2i = main.chunks.world_to_chunk(player.global_position)
	player.global_position += Vector2(2400, 0)
	await frames(2)
	check(main.chunks.world_to_chunk(player.global_position) != start_chunk, "walking streams a different part of the province")
	check(main.chunks.chunk_count() == 25, "streaming stays bounded while travelling")
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
	player.try_attack()
	var aim: Vector2 = player._facing.normalized()
	dummy.global_position = player.global_position + aim * 36.0
	await frames(30)
	check(is_instance_valid(dummy) and dummy.hp < hp_before, "an attack damages an enemy through the frame machine")
	check(player._attack_state == "idle", "the attack state machine returns to idle")

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

	var exit_node: Interactable = null
	var altar: Interactable = null
	for node in main.realm_instance.interactables:
		if node.id == "realm.exit":
			exit_node = node
		elif node.id == "realm.altar":
			altar = node
	check(exit_node != null, "the realm has an exit")
	check(altar != null, "the realm has an inheritance altar")
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
	Save.delete_slot(96)

	main.queue_free()
	await get_tree().process_frame
