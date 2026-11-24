extends Node
## Persistent interface, audio and accessibility options.
##
## These belong to the person at the keyboard, not to a run: they live in
## `user://options.cfg`, never in a save, so starting a new life keeps the
## reading size, contrast, sound and bindings the player chose. The model is
## plain data with validation at every edge, so a hand-edited config cannot
## produce an impossible volume, an unknown action or a malformed toggle.

const PATH := "user://options.cfg"
const VERSION := 1

## Every value the settings screen may change. A key added here is automatically
## persisted, sanitised and reset by this class.
const DEFAULTS := {
	"high_contrast": false,
	"reduce_motion": false,
	"damage_numbers": true,
	"combat_sound": true,
	"volume": 100,
	"captivity": true,
}

## Actions the controls page may rebind. The list is deliberately finite: these
## are the keys a player reaches for, not every internal action.
const REBINDABLE: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"sprint", "dodge", "block", "meditate", "interact",
	"open_character", "open_inventory", "map",
	"open_narrative", "open_endgame", "quick_save", "quick_load",
	"skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6",
]

const LABELS := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left",
	"move_right": "Move right", "sprint": "Sprint", "dodge": "Dodge", "block": "Guard",
	"meditate": "Meditate", "interact": "Interact", "open_character": "Character sheet",
	"open_inventory": "Satchel", "open_settings": "Settings", "map": "Continent map",
	"open_narrative": "Narrative archive", "open_endgame": "The blank page",
	"quick_save": "Quick save", "quick_load": "Quick load",
	"skill_1": "Technique 1", "skill_2": "Technique 2", "skill_3": "Technique 3",
	"skill_4": "Technique 4", "skill_5": "Technique 5", "skill_6": "Technique 6",
}

var path := PATH
var values: Dictionary = {}
var bindings: Dictionary = {}


func _ready() -> void:
	load_from(path)


func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	bindings.clear()
	for action in REBINDABLE:
		bindings[action] = default_key(action)


func default_key(action: String) -> int:
	var keys_value: Variant = Settings.KEY_BINDINGS.get(action, [])
	if typeof(keys_value) == TYPE_ARRAY and not (keys_value as Array).is_empty():
		return int((keys_value as Array)[0])
	return 0


func get_value(key: String) -> Variant:
	if not DEFAULTS.has(key):
		return null
	return values.get(key, DEFAULTS[key])


func get_bool(key: String) -> bool:
	return bool(get_value(key))


func get_int(key: String) -> int:
	return int(get_value(key))


## Stores one value, sanitised against its default's type and range. Returns the
## value that is actually held.
func set_value(key: String, value: Variant) -> Variant:
	if not DEFAULTS.has(key):
		return null
	var stored: Variant = _sanitize_one(key, value)
	values[key] = stored
	return stored


func toggle(key: String) -> bool:
	var next := not get_bool(key)
	set_value(key, next)
	return bool(values[key])


func adjust_volume(delta: int) -> int:
	var next := clampi(get_int("volume") + delta, 0, 100)
	set_value("volume", next)
	return next


func binding_of(action: String) -> int:
	if not REBINDABLE.has(action):
		return 0
	return int(bindings.get(action, default_key(action)))


func binding_label(action: String) -> String:
	var keycode := binding_of(action)
	if keycode == 0:
		return "unbound"
	return OS.get_keycode_string(keycode)


## Assigns a key and leaves no two actions on the same key. Returns the actions
## that lost the key, so the screen can say what moved rather than silently
## stealing a binding.
func rebind(action: String, keycode: int) -> Array:
	var displaced: Array = []
	if not REBINDABLE.has(action) or keycode == 0:
		return displaced
	for other in REBINDABLE:
		if other == action:
			continue
		if binding_of(other) == keycode:
			bindings[other] = 0
			displaced.append(other)
	bindings[action] = keycode
	apply_bindings()
	return displaced


func unbind(action: String) -> void:
	if not REBINDABLE.has(action):
		return
	bindings[action] = 0
	apply_bindings()


func reset_bindings() -> void:
	for action in REBINDABLE:
		bindings[action] = default_key(action)
	apply_bindings()


## Pushes the held bindings into the engine. Keyboard keys are replaced; gamepad
## and mouse events stay, because a key rebind must not cost a controller button.
func apply_bindings() -> void:
	for action in REBINDABLE:
		var keycode := binding_of(action)
		if keycode == 0:
			Settings.unbind(action)
		else:
			Settings.rebind(action, keycode)


## Pushes every option into the live scene. The nodes are untyped on purpose:
## the model must be testable without a scene, and each target decides how its
## own switch is implemented.
func apply_runtime(hud: Node, audio: Node, freeze: Object, numbers: Object) -> void:
	if hud != null and hud.has_method("apply_palette"):
		hud.apply_palette(get_bool("high_contrast"))
	if audio != null:
		audio.set_muted(not get_bool("combat_sound"))
		audio.set_volume(get_int("volume"))
	if freeze != null:
		freeze.set("enabled", not get_bool("reduce_motion"))
	if numbers != null:
		numbers.set("enabled", get_bool("damage_numbers"))
	Settings.content["captivity"] = get_bool("captivity")


# ------------------------------------------------------------ persistence ----


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"values": values.duplicate(true),
		"bindings": bindings.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	reset_defaults()
	if data.is_empty():
		return
	var values_value: Variant = data.get("values", {})
	if typeof(values_value) == TYPE_DICTIONARY:
		values = _sanitize_values(values_value)
	var bindings_value: Variant = data.get("bindings", {})
	if typeof(bindings_value) == TYPE_DICTIONARY:
		for action in REBINDABLE:
			var keycode := int((bindings_value as Dictionary).get(action, default_key(action)))
			bindings[action] = keycode if keycode >= 0 else default_key(action)
	apply_bindings()


func load_from(path_value: String) -> void:
	path = path_value
	reset_defaults()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		apply_bindings()
		return
	var raw: Dictionary = {}
	for key in DEFAULTS.keys():
		raw[key] = config.get_value("options", key, DEFAULTS[key])
	values = _sanitize_values(raw)
	for action in REBINDABLE:
		var keycode := int(config.get_value("bindings", action, default_key(action)))
		bindings[action] = keycode if keycode >= 0 else default_key(action)
	apply_bindings()


func save() -> void:
	save_to(path)


func save_to(path_value: String) -> bool:
	path = path_value
	var config := ConfigFile.new()
	for key in DEFAULTS.keys():
		config.set_value("options", key, values.get(key, DEFAULTS[key]))
	for action in REBINDABLE:
		config.set_value("bindings", action, binding_of(action))
	var err := config.save(path)
	if err != OK:
		Log.error("options", "could not save %s (%d)" % [path, err])
		return false
	return true


func _sanitize_values(source: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	for key in DEFAULTS.keys():
		if source.has(key):
			out[key] = _sanitize_one(key, source[key])
	return out


func _sanitize_one(key: String, value: Variant) -> Variant:
	match key:
		"volume":
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return clampi(int(value), 0, 100)
			return int(DEFAULTS["volume"])
		_:
			if typeof(value) == TYPE_BOOL:
				return bool(value)
			return bool(DEFAULTS[key])
