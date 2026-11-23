class_name Interactable
extends Node2D
## Anything the player can walk up to and press E on.
##
## Herbs, shrines, chests, realm portals and inheritance altars came first;
## doors, containers, manuals and examinable scenery extend the same node.
##
## `can_interact()` is the single rule shared by the prompt and the handler, so a
## spent node can never show a prompt that does nothing.

enum Kind { HERB, SHRINE, PORTAL, CHEST, ALTAR, DOOR, CONTAINER, MANUAL, EXAMINE }

var kind: int = Kind.HERB
var id: String = ""
var label: String = ""
var used: bool = false
var item_seed: int = 0
## Doors only: whether the door is currently open, and the building it belongs to.
var open := false
var building: Building = null
## Manuals only: the technique the manual teaches.
var manual_technique := ""
## Examination only: what the player reads.
var examine_text := ""
## Streamed resources: which chunk owns this node. Chunk-owned nodes are freed
## with their chunk and persist their spent state through a WorldDelta.
var chunk_owned := false
var chunk_coord := Vector2i.ZERO
var _pulse := 0.0


func setup(kind_value: int, id_value: String, label_value: String) -> void:
	kind = kind_value
	id = id_value
	label = label_value
	add_to_group("interactable")


func setup_door(id_value: String, label_value: String, door_building: Building) -> void:
	setup(Kind.DOOR, id_value, label_value)
	building = door_building


func setup_container(id_value: String, label_value: String, seed_value: int) -> void:
	setup(Kind.CONTAINER, id_value, label_value)
	item_seed = seed_value


func setup_manual(id_value: String, label_value: String, technique_id: String) -> void:
	setup(Kind.MANUAL, id_value, label_value)
	manual_technique = technique_id


func setup_examine(id_value: String, label_value: String, text: String) -> void:
	setup(Kind.EXAMINE, id_value, label_value)
	examine_text = text


func setup_chunk_herb(id_value: String, label_value: String, coord: Vector2i) -> void:
	setup(Kind.HERB, id_value, label_value)
	chunk_owned = true
	chunk_coord = coord


## Whether the prompt should offer this node right now.
func can_interact() -> bool:
	match kind:
		Kind.HERB, Kind.CONTAINER, Kind.MANUAL, Kind.CHEST:
			return not used
		_:
			return true


func display_label() -> String:
	if kind == Kind.HERB and used:
		return "Picked clean"
	if kind == Kind.DOOR:
		return "%s — close" % label if open else "%s — open" % label
	if kind == Kind.CONTAINER and used:
		return "Searched %s" % label
	return label


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _draw() -> void:
	if kind == Kind.HERB and used:
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
		Kind.DOOR:
			# The doorway the building leaves at its base.
			draw_rect(Rect2(-10, -22, 20, 22), Color("#120e0a") if open else Color("#6a5638"))
			draw_rect(Rect2(-10, -22, 20, 22), Color("#8a7350"), false, 1.5)
			if open:
				draw_line(Vector2(-9, -22), Vector2(-13, 0), Color("#8a7350"), 2.0)
		Kind.CONTAINER:
			draw_rect(Rect2(-12, -12, 24, 16), Color("#5a4a32"))
			draw_rect(Rect2(-12, -16, 24, 6), Color("#6a5638"))
			draw_line(Vector2(-12, -6), Vector2(12, -6), Color("#3a3024"), 1.5)
			if used:
				# Lid thrown back and the inside visible.
				draw_rect(Rect2(-12, -20, 24, 5), Color("#3a3024"))
				draw_rect(Rect2(-9, -12, 18, 7), Color("#241d16"))
			else:
				draw_arc(Vector2(0, -2), 3.0, PI, TAU, 8, Color("#c8a860"), 1.5)
		Kind.MANUAL:
			draw_rect(Rect2(-8, -12, 16, 12), Color("#3a2a4a"))
			draw_rect(Rect2(-5, -15, 10, 15), Color("#d8d0c0"))
			draw_line(Vector2(0, -15), Vector2(0, 0), Color("#8a7a5a"), 1.0)
			if not used:
				draw_circle(Vector2(0, -8), 2.0, Color("#c0505a", 0.5 + pulse * 0.5))
		Kind.EXAMINE:
			draw_rect(Rect2(-7, -6, 14, 10), Color("#4a4a44"))
			draw_rect(Rect2(-4, -26, 8, 20), Color("#5c5c54"))
			draw_circle(Vector2(0, -30), 4.0, Color("#c0b090", 0.5 + pulse * 0.4))


func display_label_short() -> String:
	return label
