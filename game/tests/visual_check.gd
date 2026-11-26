extends SceneTree
## Visual verification harness for the Art Studio texture wiring.
##
##   xvfb-run godot --path game --script res://tests/visual_check.gd
##
## Drives the real game with real input: title screen -> accept (New Game)
## -> settlement spawn -> walk east -> walk north, screenshotting each
## stage into /tmp/ea_shots/. Then builds a small arena from the game's
## own entity classes (a spirit beast, a named biome enemy, a boss, and a
## tiled pond with grass-to-water transitions) and screenshots that too.
## Not part of the unit suite; run it by hand after touching the renderer.

const OUT := "/tmp/ea_shots/"
const WATER := 7

var _t := 0.0
var _stage := 0
var _stage_t := 0.0
var _arena: Array = []


func _initialize() -> void:
	DirAccess.make_dir_absolute(OUT)
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + name)
	print("SHOT ", name, " ", img.get_size())


func _player() -> Node:
	var game := root.get_node_or_null("Game")
	if game == null:
		return null
	return game.get("player")


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _process(delta: float) -> bool:
	_t += delta
	_stage_t += delta
	match _stage:
		0:  # title settles
			if _stage_t > 2.0:
				_shot("title.png")
				_press("accept")
				_stage = 1
				_stage_t = 0.0
		1:  # world generates; wait for the player, then let chunks stream
			if _player() != null and _stage_t > 6.0:
				_shot("world_spawn.png")
				_report("player", _player())
				_visit_npc()
				_stage = 5
				_stage_t = 0.0
			elif _stage_t > 40.0:
				print("TIMEOUT waiting for player")
				return true
		5:  # standing beside a settlement NPC
			if _stage_t > 1.5:
				_shot("npc_closeup.png")
				Input.action_press("move_right")
				_stage = 2
				_stage_t = 0.0
		2:  # walking east
			if _stage_t > 0.9:
				_shot("walk_east.png")
				Input.action_release("move_right")
				Input.action_press("move_up")
				_stage = 3
				_stage_t = 0.0
		3:  # walking north (back view)
			if _stage_t > 0.9:
				_shot("walk_north.png")
				Input.action_release("move_up")
				_build_arena()
				_stage = 4
				_stage_t = 0.0
		4:  # arena settles
			if _stage_t > 2.5:
				for pair in _arena:
					_report(pair[0], pair[1])
				_shot("arena.png")
				print("VISUAL CHECK DONE")
				return true
	return false


func _report(label: String, actor: Node) -> void:
	var spr: Object = actor.get("_sprite")
	if spr == null:
		print("REPORT ", label, ": no sprite node")
		return
	var tex: Texture2D = spr.get("texture")
	print("REPORT ", label, ": active=", spr.call("is_active"),
		" tex=", tex.resource_path if tex != null else "none")


func _visit_npc() -> void:
	var npcs: Array = current_scene.get("npcs")
	if npcs.is_empty():
		print("REPORT npc: none spawned")
		return
	var npc: Node2D = npcs[0]
	print("REPORT npc: role=", npc.get("role"), " archetype=", npc.get("archetype_id"))
	_report("npc", npc)
	_player().set("global_position", npc.global_position + Vector2(46, 6))


func _build_arena() -> void:
	if current_scene != null:
		current_scene.queue_free()
	var world := Node2D.new()
	world.name = "Arena"
	world.y_sort_enabled = true
	root.add_child(world)

	var layer := TileMapLayer.new()
	layer.tile_set = TerrainTiles.tileset_for("biome.verdant")
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = -20
	world.add_child(layer)
	for cx in 24:
		for cy in 14:
			layer.set_cell(Vector2i(cx, cy), (cx * 7 + cy * 3) % 4, Vector2i.ZERO)
	# A pond: water cells with grass-to-water transitions on the rim. The
	# transition name gives the side the water sits on, seen from the grass.
	var pond := Rect2i(15, 4, 4, 3)
	for cx in range(pond.position.x, pond.position.x + pond.size.x):
		for cy in range(pond.position.y, pond.size.y + pond.position.y):
			layer.set_cell(Vector2i(cx, cy), WATER, Vector2i.ZERO)
	var sides := {Vector2i(0, -1): "n", Vector2i(0, 1): "s", Vector2i(-1, 0): "w", Vector2i(1, 0): "e"}
	for cx in range(pond.position.x - 1, pond.position.x + pond.size.x + 1):
		for cy in range(pond.position.y - 1, pond.position.y + pond.size.y + 1):
			var cell := Vector2i(cx, cy)
			if pond.has_point(cell):
				continue
			for d in sides:
				if pond.has_point(cell + d):
					var src := TerrainTiles.NAMES.find("grass_water_" + sides[d])
					if src >= 0:
						layer.set_cell(cell, src, Vector2i.ZERO)

	var cam := Camera2D.new()
	cam.position = Vector2(384, 224)
	world.add_child(cam)
	cam.make_current()

	var player := Player.new()
	player.position = Vector2(150, 300)
	world.add_child(player)

	var db := root.get_node("DB")

	var beast := Dummy.new()
	beast.position = Vector2(300, 270)
	world.add_child(beast)
	beast.become_beast(db.call("spirit_beast", "beast.moonfang"), 1)

	var enemy := Dummy.new()
	enemy.position = Vector2(430, 320)
	world.add_child(enemy)
	for entry in db.call("biome", "biome.verdant").get("enemies", []):
		if String(entry.get("name", "")) == "Ridge Boar":
			enemy.apply_biome_enemy(entry, 1)

	var boss := Dummy.new()
	boss.position = Vector2(580, 250)
	world.add_child(boss)
	boss.become_boss(db.call("boss", "boss.tomb_warden"), 5)

	_arena = [["beast", beast], ["enemy", enemy], ["boss", boss]]
