extends Control
## The title screen: key art, the game's name and three ways into it.
##
## The run is still the main scene; this screen only hands it a slot to continue.
## It owns no game state, so a new life, a continued life and a quit are all one
## scene change or one call. Keyboard is the primary path, but the menu also
## answers mouse motion and clicks so a first-time player is never stuck.

const MAIN_SCENE := "res://scenes/main.tscn"
const ART_PATH := "res://assets/title_key_art.jpg"
const ITEMS: Array[String] = ["Begin a new life", "Continue", "Quit"]
const PANEL := Color(0.02, 0.03, 0.04, 0.72)

var index := 0
var slots: Array = []
var _font: Font
var _art: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# No focused control: arrows and ENTER must reach `_unhandled_input` instead
	# of being eaten by focus navigation. The mouse path uses `_gui_input`.
	focus_mode = Control.FOCUS_NONE
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists(ART_PATH):
		var loaded: Resource = load(ART_PATH)
		if loaded is Texture2D:
			_art = loaded as Texture2D
	slots = Save.list_slots()
	# A returning player should not have to walk past "new life" to continue.
	index = 1 if has_continue() else 0
	Music.refresh()
	queue_redraw()


func has_continue() -> bool:
	return not slots.is_empty()


## The highest populated slot is the one the title offers. Slots are created in
## play order, so this is also the most recent life in normal use.
func continue_slot() -> int:
	return newest_slot_of(slots)


static func newest_slot_of(values: Array) -> int:
	var best := 0
	for value in values:
		best = maxi(best, int(value))
	return best


static func menu_items() -> Array[String]:
	return ITEMS


static func version_string() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "1.0.1"))


func _can_activate(item: int) -> bool:
	if item == 1:
		return has_continue()
	return item >= 0 and item < ITEMS.size()


func _move(step: int) -> void:
	for _i in ITEMS.size():
		index = posmod(index + step, ITEMS.size())
		if _can_activate(index):
			break
	queue_redraw()


func _activate(item: int) -> void:
	if not _can_activate(item):
		return
	match item:
		0:
			Game.pending_load_slot = 0
			get_tree().change_scene_to_file(MAIN_SCENE)
		1:
			Game.pending_load_slot = continue_slot()
			get_tree().change_scene_to_file(MAIN_SCENE)
		_:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_move(1)
		return
	if event.is_action_pressed("ui_up"):
		_move(-1)
		return
	if event.is_action_pressed("accept"):
		_activate(index)
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _item_at((event as InputEventMouseMotion).position)
		if hovered >= 0 and hovered != index:
			index = hovered
			queue_redraw()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var hit := _item_at(click.position)
			if hit >= 0:
				index = hit
				_activate(hit)


func _menu_geometry() -> Dictionary:
	var item_height := 44.0
	var width := 330.0
	return {
		"x": 84.0,
		"y": size.y - 96.0 - item_height * float(ITEMS.size()),
		"w": width,
		"h": item_height,
	}


func _item_at(point: Vector2) -> int:
	var geometry := _menu_geometry()
	for i in ITEMS.size():
		var rect := Rect2(
			Vector2(float(geometry["x"]), float(geometry["y"]) + float(geometry["h"]) * float(i)),
			Vector2(float(geometry["w"]), float(geometry["h"]))
		)
		if rect.has_point(point):
			return i
	return -1


func _draw() -> void:
	var width := maxf(size.x, 320.0)
	var height := maxf(size.y, 240.0)
	if _art != null:
		var art_size := _art.get_size()
		var scale := maxf(width / art_size.x, height / art_size.y)
		var drawn := art_size * scale
		draw_texture_rect(_art, Rect2((Vector2(width, height) - drawn) * 0.5, drawn), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color("#0b1418"))
	# A dark foot and a wash on the left keep the menu legible over any crop.
	draw_rect(Rect2(0.0, height * 0.48, width, height * 0.52), Color(0.02, 0.03, 0.04, 0.42))
	UiFrame.panel(self, Rect2(0.0, height - 440.0, 560.0, 440.0), PANEL)
	var palette := Hud.palette(Options.get_bool("high_contrast"))
	var ink: Color = palette["ink"]
	var muted: Color = palette["muted"]
	var accent: Color = palette["accent"]
	_text(Vector2(84.0, height - 380.0), "ETERNAL", 50, ink)
	_text(Vector2(84.0, height - 328.0), "ASCENSION", 50, accent)
	draw_line(Vector2(84.0, height - 308.0), Vector2(318.0, height - 308.0), accent, 2.0)
	_text(Vector2(84.0, height - 284.0), "A xianxia cultivation sandbox", 13, muted)

	var geometry := _menu_geometry()
	for i in ITEMS.size():
		var y := float(geometry["y"]) + float(geometry["h"]) * float(i)
		var rect := Rect2(Vector2(float(geometry["x"]), y), Vector2(float(geometry["w"]), float(geometry["h"])))
		var enabled := _can_activate(i)
		var selected := i == index
		UiFrame.plaque(self, rect, Color(0.02, 0.03, 0.04, 0.35), UiFrame.BRONZE_DIM)
		if selected:
			draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), accent)
			UiFrame.plaque(self, rect, Color(accent, 0.08), UiFrame.BRONZE)
		var colour := ink if enabled else muted
		if selected and enabled:
			colour = accent
		var label := String(ITEMS[i])
		if i == 1 and not enabled:
			label = "Continue  ·  no save yet"
		_text(Vector2(rect.position.x + 18.0, y + 29.0), label, 17, colour)

	_text(Vector2(84.0, height - 42.0), "UP / DOWN choose   ·   ENTER confirm   ·   ESC quit", 11, muted)
	var version := "v%s   ·   Godot %s" % [version_string(), String(Engine.get_version_info().get("string", ""))]
	_text(Vector2(84.0, height - 20.0), version, 10, muted)
	_text(Vector2(width - 330.0, height - 20.0), "F10 opens settings in game", 10, muted)


func _text(at: Vector2, text: String, font_size: int, colour: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
