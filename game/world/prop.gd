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
var biome := ""
var _sprite: Sprite2D = null


func setup(kind_value: String, scale_value: float, biome_id: String = "") -> void:
	kind = kind_value
	size_scale = maxf(0.1, scale_value)
	biome = biome_id
	_attach_sprite()
	queue_redraw()


## Gives the prop its Art Studio texture (biome-graded when one is
## filed) with the art's bottom on the ground contact point. Without
## a texture the primitive drawing below stays.
func _attach_sprite() -> void:
	if not ActorSprite.sprites_enabled():
		return
	var folder := "res://assets/art-studio/assets/environments/props/"
	if biome != "" and biome != "biome.verdant":
		var sub := biome.trim_prefix("biome.")
		if ResourceLoader.exists(folder + "biome_" + sub + "/prop_" + kind + ".png"):
			folder += "biome_" + sub + "/"
	var path := folder + "prop_" + kind + ".png"
	if not ResourceLoader.exists(path):
		return
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := load(path) as Texture2D
	_sprite.texture = tex
	_sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	_sprite.scale = Vector2.ONE * size_scale
	add_child(_sprite)


func _draw() -> void:
	if _sprite != null:
		return
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
