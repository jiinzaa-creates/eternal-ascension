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
	"sprint": [KEY_SHIFT],
	"attack": [],
	"dodge": [KEY_SPACE],
	"block": [KEY_CTRL],
	"meditate": [KEY_F],
	"interact": [KEY_E],
	"party_toggle": [KEY_P],
	"breakthrough": [KEY_G],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"skill_5": [KEY_5],
	"skill_6": [KEY_6],
	"cycle_bar": [KEY_Q],
	"bar_prev": [KEY_BRACKETLEFT],
	"bar_next": [KEY_BRACKETRIGHT],
	"open_bars": [KEY_B],
	"open_inventory": [KEY_I],
	"sort_inventory": [KEY_R],
	"use_item": [KEY_U],
	"open_character": [KEY_C],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"toggle_help": [KEY_F1],
	"mute_audio": [KEY_F2],
	"map": [KEY_M],
	"shop_mode": [KEY_TAB],
	"open_travel": [KEY_T],
	"travel_waypoint": [KEY_V],
	"zoom_in": [KEY_EQUAL],
	"zoom_out": [KEY_MINUS],
	"accept": [KEY_ENTER],
	"reroll": [KEY_R],
	"undo_point": [KEY_BACKSPACE],
	"creation_origin": [KEY_TAB],
	"creation_robe": [KEY_Z],
	"creation_hair": [KEY_X],
	"creation_skin": [KEY_C],
	"creation_presentation": [KEY_N],
	"creation_physique": [KEY_P],
}

const MOUSE_BINDINGS := {
	"attack": [MOUSE_BUTTON_LEFT],
	"light_attack": [MOUSE_BUTTON_RIGHT],
	"block": [MOUSE_BUTTON_MIDDLE],
}

## Gamepad axes. Each entry is [axis, direction]; `Input.get_vector` combines the
## two halves of an axis into a stick direction.
const JOY_AXIS_BINDINGS := {
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"aim_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	"aim_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	"aim_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	"aim_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
}

const JOY_BUTTON_BINDINGS := {
	"attack": [JOY_BUTTON_X],
	"dodge": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_B],
	"party_toggle": [JOY_BUTTON_RIGHT_STICK],
	"meditate": [JOY_BUTTON_Y],
	"sprint": [JOY_BUTTON_RIGHT_SHOULDER],
	"breakthrough": [JOY_BUTTON_DPAD_UP],
	"map": [JOY_BUTTON_BACK],
	"shop_mode": [JOY_BUTTON_LEFT_SHOULDER],
	"open_travel": [JOY_BUTTON_DPAD_DOWN],
	"travel_waypoint": [JOY_BUTTON_DPAD_LEFT],
	"creation_origin": [JOY_BUTTON_RIGHT_SHOULDER],
	"light_attack": [JOY_BUTTON_DPAD_RIGHT],
	"block": [JOY_BUTTON_LEFT_STICK],
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
	for action in JOY_AXIS_BINDINGS.keys():
		_ensure_action(action)
		for entry in JOY_AXIS_BINDINGS[action]:
			_add_joy_axis(action, int(entry[0]), float(entry[1]))
	for action in JOY_BUTTON_BINDINGS.keys():
		_ensure_action(action)
		for button in JOY_BUTTON_BINDINGS[action]:
			_add_joy_button(action, int(button))


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


func _add_joy_axis(action: String, axis: int, direction: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
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
