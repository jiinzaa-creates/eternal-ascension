class_name GroundLoot
extends Node2D

## Draws what lies on the ground. Kills, chests and altars have always
## rolled loot into the host's ground_items - but nothing ever drew it,
## so drops were invisible and pickup was blind luck within reach.
## This view is the missing half: a rarity-coloured marker per item,
## its name when the player is close, redrawn every frame for the pulse.

var host: Node = null
var _pulse := 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if host == null:
		return
	var items: Array = host.get("ground_items")
	if items == null or items.is_empty():
		return
	var player: Node2D = host.get("player")
	var font := ThemeDB.fallback_font
	for entry_value in items:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var item: Dictionary = entry.get("item", {})
		if item.is_empty():
			continue
		var pos := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		var rarity := clampi(int(item.get("rarity", 0)), 0, ItemGen.RARITY_COLORS.size() - 1)
		var color := Color(ItemGen.RARITY_COLORS[rarity])
		var bob := sin(_pulse * 3.0 + pos.x * 0.05) * 2.0
		# Ground shadow, then the marker diamond and its breathing ring.
		draw_circle(pos + Vector2(0, 5), 9.0, Color(0, 0, 0, 0.30))
		draw_arc(pos, 13.0 + sin(_pulse * 2.4) * 2.0, 0.0, TAU, 24, Color(color, 0.45), 1.5)
		var c := pos + Vector2(0, bob - 4.0)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0),
		]), color)
		draw_circle(c, 2.0, Color(1, 1, 1, 0.85))
		if player != null and pos.distance_to(player.global_position) <= 170.0:
			var label := String(item.get("name", "item"))
			var count := int(item.get("count", 1))
			if count > 1:
				label += " x%d" % count
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, pos + Vector2(-width * 0.5, -18.0 + bob), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8e2d0"))
