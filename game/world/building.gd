class_name Building
extends Node2D
## A settlement building drawn as its own Y-sorted node.
##
## Buildings used to be part of the settlement's single `_draw`, which meant the
## player was always painted over every roof. As separate nodes they sort with
## the player, and they fade according to `Occluder` while the player is behind
## them, so a doorway is never hidden by a roof.

const FADE_SPEED := 12.0

var footprint := Rect2()
var wall_color := Color("#3a4a3e")
var roof_color := Color("#4f6a55")
var location := ""
## Set when a door on this building is open: the interior stays visible.
var interior_open := false
var _alpha := 1.0


func setup(offset: Vector2, size: Vector2, wall: Color, roof: Color, location_id: String = "") -> void:
	position = offset
	footprint = Rect2(-size * 0.5, size)
	wall_color = wall
	roof_color = roof
	location = location_id
	queue_redraw()


func roof_height() -> float:
	return footprint.size.y * 0.45


## The building's footprint in world space, for the occlusion test.
func world_footprint() -> Rect2:
	return Rect2(global_position + footprint.position, footprint.size)


func set_interior_open(value: bool) -> void:
	interior_open = value
	queue_redraw()


func _process(delta: float) -> void:
	var target := occlusion_target_for_player()
	_alpha = lerpf(_alpha, target, clampf(delta * FADE_SPEED, 0.0, 1.0))
	modulate.a = _alpha


## Alpha for an arbitrary position. An open interior never occludes.
func occlusion_target(player_pos: Vector2) -> float:
	if interior_open:
		return Occluder.MIN_ALPHA
	return Occluder.alpha_for(player_pos, world_footprint(), roof_height())


func occlusion_target_for_player() -> float:
	if interior_open:
		return Occluder.MIN_ALPHA
	var player := Game.player as Node2D
	if player == null or not is_instance_valid(player):
		return 1.0
	return occlusion_target(player.global_position)


func _draw() -> void:
	var size := footprint.size
	draw_rect(footprint, wall_color)
	var roof := PackedVector2Array([
		footprint.position + Vector2(-10, 0),
		footprint.position + Vector2(size.x + 10, 0),
		footprint.position + Vector2(size.x * 0.5, -size.y * 0.45),
	])
	draw_colored_polygon(roof, roof_color)
	draw_rect(
		Rect2(footprint.position + Vector2(size.x * 0.45, size.y * 0.5), Vector2(size.x * 0.1, size.y * 0.5)),
		Color("#120e0a") if interior_open else Color("#20261f")
	)
