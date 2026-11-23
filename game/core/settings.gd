extends Node
## Input bindings and content toggles.
##
## Actions are registered in code rather than baked into project.godot: it keeps
## the project file small, makes rebinding trivial, and lets headless test runs
## register the same actions as the game.

const KEY_BINDINGS := {
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"attack": [],
	"dodge": [KEY_SPACE],
	"meditate": [KEY_F],
	"interact": [KEY_E],
	"breakthrough": [KEY_G],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"skill_5": [KEY_5],
	"skill_6": [KEY_6],
	"cycle_bar": [KEY_Q],
	"open_inventory": [KEY_I],
	"open_character": [KEY_C],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"toggle_help": [KEY_F1],
	"zoom_in": [KEY_EQUAL],
	"zoom_out": [KEY_MINUS],
	"accept": [KEY_ENTER],
	"reroll": [KEY_R],
	"undo_point": [KEY_BACKSPACE],
}

const MOUSE_BINDINGS := {
	"attack": [MOUSE_BUTTON_LEFT],
}

## Content toggles. Captivity is a moral/legal simulation, not an inventory system,
## and must be safe to disable on an existing save.
var content := {
	"captivity": true,
	"gore": false,
}

var bindings: Dictionary = {}


func _enter_tree() -> void:
	register_defaults()


func register_defaults() -> void:
	for action in KEY_BINDINGS.keys():
		_ensure_action(action)
		for keycode in KEY_BINDINGS[action]:
			_add_key(action, keycode)
	for action in MOUSE_BINDINGS.keys():
		_ensure_action(action)
		for button in MOUSE_BINDINGS[action]:
			_add_mouse(action, button)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _add_key(action: String, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)
	bindings[action] = keycode


func _add_mouse(action: String, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _has_event(action: String, probe: InputEvent) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev.is_match(probe, true):
			return true
	return false


## Rebinds a keyboard action at runtime and returns the new keycode.
func rebind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	_add_key(action, keycode)


func action_keycode(action: String) -> String:
	if not bindings.has(action):
		return "unbound"
	return OS.get_keycode_string(int(bindings[action]))
