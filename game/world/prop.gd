class_name Prop
extends Node2D
## A streamed decoration that participates in Y-sorting.
##
## Chunk terrain is flat and draws in one layer, but trees, rocks and bushes have
## height. They are separate nodes positioned at their ground contact point and
## drawn upward, so the world's Y-sort puts the player behind a tree when walking
## above it and in front when walking below it.

var kind := "tuft"
var size_scale := 1.0


func setup(kind_value: String, scale_value: float) -> void:
	kind = kind_value
	size_scale = maxf(0.1, scale_value)
	queue_redraw()


func _draw() -> void:
	var s := size_scale
	match kind:
		"tree":
			# Trunk ends at the node origin: that point is what Y-sorts.
			draw_line(Vector2(0.0, -20.0 * s), Vector2.ZERO, Color("#2a2118"), 4.0)
			draw_circle(Vector2(0.0, -26.0 * s), 16.0 * s, Color("#1d3a26"))
			draw_circle(Vector2(-5.0, -30.0 * s), 9.0 * s, Color("#25492f"))
		"rock":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, 6) * s, Vector2(-4, -8) * s,
				Vector2(9, -5) * s, Vector2(11, 5) * s,
			]), Color("#2c3335"))
		"bush":
			draw_circle(Vector2(0.0, -4.0 * s), 8.0 * s, Color("#20361f"))
		_:
			draw_line(Vector2.ZERO, Vector2(-3, -7) * s, Color("#2b4a2b"), 1.5)
			draw_line(Vector2.ZERO, Vector2(2, -8) * s, Color("#2b4a2b"), 1.5)
