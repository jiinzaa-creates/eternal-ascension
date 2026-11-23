class_name DamageNumbers
extends Node2D
## Floating damage numbers drawn in world space, above the bodies that took the
## blow.
##
## It listens to `Bus.hit_landed`, so every damage path (melee, projectile,
## spell, summon, status tick) shows a number without knowing this node exists.
## The text itself is pure (`CombatText`); this node only holds the font, the
## world position and the draw call.

const MAX_ENTRIES := 48

var entries: Array = []
var _font: Font
var _spawned := 0


func _ready() -> void:
	z_index = 500
	_font = ThemeDB.fallback_font
	Bus.hit_landed.connect(_on_hit_landed)
	Bus.status_ticked.connect(_on_status_ticked)


func _process(delta: float) -> void:
	if entries.is_empty():
		return
	entries = CombatText.advance(entries, delta)
	queue_redraw()


## Spawns one number. `at` is a world position; the drift counter fans numbers
## out so two blows on the same spot stay readable.
func add(amount: float, at: Vector2, critical := false, tint := "") -> Dictionary:
	var drift := float((_spawned % 5) - 2) * 7.0
	var entry_data := CombatText.entry(amount, critical, tint, drift)
	if entry_data.is_empty():
		return {}
	entry_data["at"] = at
	entries.append(entry_data)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	_spawned += 1
	queue_redraw()
	return entry_data


func _on_hit_landed(target: Node, amount: float, critical: bool, tint: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	var body := target as Node2D
	if body == null:
		return
	add(amount, body.global_position + Vector2(0, -26), critical, tint)


## A damage-over-time tick shows its own tinted number, so a burning body reads
## as burning rather than as taking another hit.
func _on_status_ticked(target: Node, id: String, amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var body := target as Node2D
	if body == null:
		return
	add(amount, body.global_position + Vector2(0, -26), false, id)


func _draw() -> void:
	if _font == null:
		return
	for entry in entries:
		var pos: Vector2 = (entry["at"] as Vector2) + CombatText.offset(entry)
		var color := CombatText.color(entry)
		color.a = CombatText.alpha(entry)
		draw_string(_font, pos + Vector2(-30, 0), CombatText.text(entry),
			HORIZONTAL_ALIGNMENT_CENTER, 60.0, CombatText.font_size(entry), color)
