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
	"forge": Vector2(180, 210),
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
	{"location": "forge", "size": Vector2(120, 90), "wall": "#3a2e28", "roof": "#5a3a2a"},
]


var buildings: Array = []


func position_for(location: String) -> Vector2:
	var offset: Vector2 = LOCATIONS.get(location, Vector2.ZERO)
	return global_position + offset


func has_location(location: String) -> bool:
	return LOCATIONS.has(location)


## Every path in the market radiates from the plaza, so a body walking from one
## named place to another goes through it rather than through a wall. Pure: it
## reads the location graph and returns location ids, never positions.
func route_from(from_location: String, to_location: String) -> Array:
	var out: Array = []
	if to_location == "":
		return out
	if from_location == "" or from_location == to_location or from_location == "plaza" \
			or to_location == "plaza" or not LOCATIONS.has(from_location) or not LOCATIONS.has(to_location):
		out.append(to_location)
		return out
	out.append("plaza")
	out.append(to_location)
	return out


## Buildings become their own nodes in the Y-sorted world layer, so they can
## sort against the player and fade when he walks behind a roof. Call after the
## settlement is in the tree (it needs its world position).
func build_buildings(parent: Node) -> void:
	for spec in BUILDINGS:
		var building := Building.new()
		building.setup(
			global_position + (LOCATIONS[String(spec["location"])] as Vector2),
			spec["size"] as Vector2,
			Color(String(spec["wall"])),
			Color(String(spec["roof"])),
			String(spec["location"])
		)
		parent.add_child(building)
		buildings.append(building)


func set_buildings_visible(value: bool) -> void:
	for building in buildings:
		if is_instance_valid(building):
			building.visible = value
			building.set_process(value)


func building_for(location_id: String) -> Building:
	for building in buildings:
		if is_instance_valid(building) and building.location == location_id:
			return building
	return null


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

	# Buildings are drawn by Building nodes in the Y-sorted layer, not here.

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
