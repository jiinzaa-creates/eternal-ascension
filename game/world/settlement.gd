class_name Settlement
extends Node2D
## Azure Cloud Market — the first handcrafted settlement.
##
## Buildings and paths are drawn in code; the important part is the named
## location graph, because NPC schedules resolve against it. A NPC that
## "trains" walks to `training`; one that "meditates" walks to `shrine`.

const SETTLEMENT_NAME := "Azure Cloud Market"

const LOCATIONS := {
	"plaza": Vector2(0, 0),
	"market": Vector2(200, -70),
	"tavern": Vector2(-200, 70),
	"training": Vector2(-80, 240),
	"shrine": Vector2(0, -300),
	"sect_hall": Vector2(330, 150),
	"fields": Vector2(-340, -200),
	"gate": Vector2(0, 480),
	"herb_garden": Vector2(440, -270),
	"dorms": Vector2(-400, 160),
}

const BUILDINGS := [
	{"location": "sect_hall", "size": Vector2(190, 130), "wall": "#3a4a3e", "roof": "#4f6a55"},
	{"location": "tavern", "size": Vector2(130, 100), "wall": "#463a30", "roof": "#5a4636"},
	{"location": "market", "size": Vector2(120, 90), "wall": "#3d3a32", "roof": "#665a3f"},
	{"location": "dorms", "size": Vector2(150, 90), "wall": "#3c3f48", "roof": "#4d5560"},
	{"location": "fields", "size": Vector2(170, 110), "wall": "#2f3a28", "roof": "#3f4f33"},
]


func position_for(location: String) -> Vector2:
	var offset: Vector2 = LOCATIONS.get(location, Vector2.ZERO)
	return global_position + offset


func has_location(location: String) -> bool:
	return LOCATIONS.has(location)


func _draw() -> void:
	# Ground apron
	draw_circle(Vector2.ZERO, 560.0, Color("#1d2a20", 0.55))

	# Paths radiate from the plaza to every named location.
	for key in LOCATIONS.keys():
		var offset: Vector2 = LOCATIONS[key]
		if offset == Vector2.ZERO:
			continue
		draw_line(Vector2.ZERO, offset, Color("#3a4536"), 24.0)
	draw_circle(Vector2.ZERO, 150.0, Color("#2b362b"))
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 48, Color("#45543f"), 3.0)
	draw_circle(Vector2.ZERO, 18.0, Color("#4a5c46"))

	for building in BUILDINGS:
		var center: Vector2 = LOCATIONS[String(building["location"])]
		var size: Vector2 = building["size"]
		var rect := Rect2(center - size * 0.5, size)
		draw_rect(rect, Color(String(building["wall"])))
		var roof := PackedVector2Array([
			rect.position + Vector2(-10, 0),
			rect.position + Vector2(size.x + 10, 0),
			rect.position + Vector2(size.x * 0.5, -size.y * 0.45),
		])
		draw_colored_polygon(roof, Color(String(building["roof"])))
		draw_rect(Rect2(rect.position + Vector2(size.x * 0.45, size.y * 0.5), Vector2(size.x * 0.1, size.y * 0.5)), Color("#20261f"))

	# Market stalls
	for i in 4:
		var pos: Vector2 = LOCATIONS["market"] + Vector2(-90 + i * 55, 62)
		draw_rect(Rect2(pos, Vector2(42, 12)), Color("#6a5436"))
		draw_line(pos + Vector2(0, 0), pos + Vector2(0, -26), Color("#4a3a26"), 3.0)
		draw_line(pos + Vector2(42, 0), pos + Vector2(42, -26), Color("#4a3a26"), 3.0)
		draw_rect(Rect2(pos + Vector2(-4, -34), Vector2(50, 10)), Color("#7a5f3d"))

	# Herb garden beds
	for i in 3:
		var pos: Vector2 = LOCATIONS["herb_garden"] + Vector2(-60 + i * 60, 30)
		draw_rect(Rect2(pos, Vector2(46, 30)), Color("#26331f"))
		for j in 4:
			draw_circle(pos + Vector2(8 + j * 10, 10 + (j % 2) * 8), 4.0, Color("#4f8a52"))

	# Gate posts
	var gate: Vector2 = LOCATIONS["gate"]
	draw_rect(Rect2(gate + Vector2(-70, -14), Vector2(18, 46)), Color("#39412f"))
	draw_rect(Rect2(gate + Vector2(52, -14), Vector2(18, 46)), Color("#39412f"))
	draw_line(gate + Vector2(-70, -14), gate + Vector2(70, -14), Color("#39412f"), 8.0)
