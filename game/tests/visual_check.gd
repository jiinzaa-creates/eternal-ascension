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
var _acted := false
var _arena: Array = []
var _props: Array = []
var _herbs: Array = []
var _buildings: Array = []


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


func _click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	Input.parse_input_event(up)


func _wheel(pos: Vector2, down_dir: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down_dir else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = pos
	Input.parse_input_event(ev)


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
				_scan_world()
				_stage = 6
				_stage_t = 0.0
		6:  # beside a textured prop
			if _stage_t > 1.2:
				_shot("props.png")
				if _goto_herb():
					_stage = 7
				elif _goto_building():
					_stage = 8
				else:
					_start_walk_east()
				_stage_t = 0.0
		7:  # beside a textured herb
			if _stage_t > 1.2:
				_shot("herbs.png")
				if _goto_building():
					_stage = 8
				else:
					_start_walk_east()
				_stage_t = 0.0
		8:  # in front of a textured building
			if _stage_t > 1.2:
				_shot("settlement.png")
				_stage = 9
				_stage_t = 0.0
		9:  # Esc opens the menu hub
			if _stage_t > 0.4 and not _acted:
				_acted = true
				_press("ui_cancel")
			elif _stage_t > 1.2:
				_shot("menu.png")
				_wheel(Vector2(640, 300), true)
				_wheel(Vector2(640, 300), true)
				_stage = 10
				_stage_t = 0.0
				_acted = false
		10:  # the wheel walked the menu cursor to Gear; a click opens it
			if _stage_t > 1.2:
				_shot("menu_wheel.png")
				_click(Vector2(640, 202))
				_stage = 11
				_stage_t = 0.0
				_acted = false
		11:  # the satchel, opened by mouse alone
			if _stage_t > 1.2:
				_shot("menu_gear.png")
				_press("ui_cancel")
				_stage = 12
				_stage_t = 0.0
				_acted = false
		12:  # the MENU plaque beside the minimap opens the hub on a click
			if _stage_t > 0.4 and not _acted:
				_acted = true
				_click(Vector2(1051, 689))
			elif _stage_t > 1.2:
				_shot("menu_button.png")
				_press("ui_cancel")
				_stage = 13
				_stage_t = 0.0
				_acted = false
		13:  # character sheet still draws over the lean HUD
			if _stage_t > 0.4 and not _acted:
				_acted = true
				current_scene.set("character_open", true)
			elif _stage_t > 1.2:
				_shot("sheet.png")
				current_scene.set("character_open", false)
				current_scene.set("settings_open", true)
				_stage = 14
				_stage_t = 0.0
				_acted = false
		14:  # settings page (UI frame check)
			if _stage_t > 1.2:
				_shot("settings.png")
				_press("shop_mode")
				_stage = 15
				_stage_t = 0.0
				_acted = false
		15:  # the KEYBINDS tab of settings
			if _stage_t > 1.2:
				_shot("keybinds.png")
				current_scene.set("settings_open", false)
				_start_walk_east()
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
	for layer_name in ["_skin_sprite", "_hair_sprite"]:
		var layer: Object = spr.get(layer_name)
		if layer != null and layer.get("texture") != null:
			print("REPORT ", label, " ", layer_name, "=",
				(layer.get("texture") as Texture2D).resource_path)


func _visit_npc() -> void:
	var npcs: Array = current_scene.get("npcs")
	if npcs.is_empty():
		print("REPORT npc: none spawned")
		return
	var npc: Node2D = npcs[0]
	print("REPORT npc: role=", npc.get("role"), " archetype=", npc.get("archetype_id"))
	_report("npc", npc)
	_player().set("global_position", npc.global_position + Vector2(46, 6))


func _start_walk_east() -> void:
	Input.action_press("move_right")
	_stage = 2


## Finds the textured props, herbs and buildings in the live world
## and walks the player to a tree prop for its screenshot.
func _scan_world() -> void:
	_props.clear()
	_herbs.clear()
	_buildings.clear()
	var stack: Array = [current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is Prop and n.get("_sprite") != null:
			_props.append(n)
		elif n is Interactable and n.get("_sprite") != null:
			_herbs.append(n)
		elif n is Building and n.get("_sprite") != null:
			_buildings.append(n)
	print("SCAN textured props=", _props.size(), " herbs=", _herbs.size(),
		" buildings=", _buildings.size())
	for b in _buildings:
		var t: Texture2D = (b.get("_sprite") as Sprite2D).texture
		print("BUILDING ", b.get("location"), " tex=",
			t.get_size() if t != null else Vector2i.ZERO)
	var target: Node2D = null
	for p in _props:
		if String(p.get("kind")) == "tree":
			target = p
			break
	if target == null and not _props.is_empty():
		target = _props[0]
	if target != null:
		print("PROP VISIT kind=", target.get("kind"), " biome=", target.get("biome"))
		_player().set("global_position", target.global_position + Vector2(52, 30))


func _goto_herb() -> bool:
	if _herbs.is_empty():
		return false
	var h: Node2D = _herbs[0]
	print("HERB VISIT label=", h.get("label"))
	_player().set("global_position", h.global_position + Vector2(34, 22))
	return true


func _goto_building() -> bool:
	if _buildings.is_empty():
		return false
	var target: Node2D = _buildings[0]
	for b in _buildings:
		if String(b.get("location")) == "sect_hall":
			target = b
			break
	print("BUILDING VISIT location=", target.get("location"))
	_player().set("global_position", target.global_position + Vector2(0, 110))
	return true


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
	# Non-default appearance: red hair + deep skin over the robe, to
	# prove the overlay layers engage in the live renderer.
	var app: Object = player.get("appearance")
	app.set("hair", 4)
	app.set("skin", 3)

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
