class_name Interactable
extends Node2D
## Anything the player can walk up to and press E on: herbs, shrines, chests,
## realm portals, inheritance altars.

enum Kind { HERB, SHRINE, PORTAL, CHEST, ALTAR }

var kind: int = Kind.HERB
var id: String = ""
var label: String = ""
var used: bool = false
var item_seed: int = 0
var _pulse := 0.0


func setup(kind_value: int, id_value: String, label_value: String) -> void:
	kind = kind_value
	id = id_value
	label = label_value
	add_to_group("interactable")


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _draw() -> void:
	if used and kind != Kind.PORTAL and kind != Kind.SHRINE:
		draw_circle(Vector2.ZERO, 4.0, Color("#3a423c"))
		return

	var pulse := 0.5 + 0.5 * sin(_pulse * 2.0)
	match kind:
		Kind.HERB:
			draw_line(Vector2(0, 4), Vector2(0, -10), Color("#4f8a52"), 2.0)
			draw_circle(Vector2(-5, -10), 4.5, Color("#7fc78a"))
			draw_circle(Vector2(5, -12), 4.0, Color("#9fe0a0"))
			draw_circle(Vector2(0, -16), 3.5, Color("#c0f0b0"))
		Kind.SHRINE:
			draw_rect(Rect2(-16, -10, 32, 22), Color("#4a4540"))
			draw_rect(Rect2(-12, -34, 24, 26), Color("#5c564e"))
			draw_circle(Vector2(0, -38), 7.0, Color("#9fe0c0", 0.65 + pulse * 0.25))
			draw_arc(Vector2(0, -38), 16.0 + pulse * 4.0, 0.0, TAU, 28, Color("#9fe0c0", 0.25), 1.5)
		Kind.PORTAL:
			draw_circle(Vector2.ZERO, 26.0, Color("#1a1230"))
			draw_arc(Vector2.ZERO, 26.0 + pulse * 6.0, 0.0, TAU, 36, Color("#a98fff", 0.75), 2.5)
			draw_arc(Vector2.ZERO, 15.0, _pulse, _pulse + TAU * 0.7, 28, Color("#d0c0ff", 0.8), 2.0)
		Kind.CHEST:
			draw_rect(Rect2(-14, -10, 28, 18), Color("#5a4a32"))
			draw_rect(Rect2(-14, -16, 28, 8), Color("#6a5638"))
			draw_rect(Rect2(-3, -12, 6, 10), Color("#c8a860"))
		Kind.ALTAR:
			draw_rect(Rect2(-22, 6, 44, 10), Color("#3a3548"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -34), Vector2(16, -6), Vector2(0, 10), Vector2(-16, -6),
			]), Color("#b0a0ff", 0.55 + pulse * 0.35))
			draw_arc(Vector2(0, -12), 34.0, 0.0, TAU, 32, Color("#c8b8ff", 0.25), 1.5)


func display_label() -> String:
	if used and kind == Kind.HERB:
		return "Picked clean"
	return label
