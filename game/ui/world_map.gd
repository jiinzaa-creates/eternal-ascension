class_name WorldMap
extends Control
## Continent map, drawn in code like the rest of the interface.
##
## It shows the whole continent coloured by each region's biome, the towns
## the player has discovered, and where the player stands. Regions never
## entered stay dimmed and uncharted. Travel itself lives in the Routes
## panel; this screen is the geography those routes cross.

const PANEL := Color("#0b0f12", 0.93)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const ACCENT := Color("#9fe0c0")
const SEA := Color("#0f1e26")
const EDGE := Color("#2b343a")
const REALM := Color("#d0b0ff")

const TERRAIN_COLORS := {
	"plains": Color("#4f6b3a"),
	"forest": Color("#2f5233"),
	"mountains": Color("#5a5548"),
	"marsh": Color("#3d5245"),
	"desert": Color("#7a6a3f"),
	"coast": Color("#3a5b63"),
}

const GOLD := Color("#d8b25c")
const TOWN_MARK := Color("#ffd98a")

## Region fill by the biome at the region's heart (Biome ids).
const BIOME_COLORS := {
	"biome.verdant": Color("#4f6b3a"),
	"biome.forest": Color("#2f5233"),
	"biome.marsh": Color("#3d5245"),
	"biome.ashen": Color("#6b6259"),
	"biome.frost": Color("#7d8fa0"),
	"biome.snow": Color("#aebfd0"),
	"biome.desert": Color("#b39b57"),
	"biome.valley": Color("#5d8a44"),
	"biome.volcanic": Color("#7a3b2e"),
	"biome.sacred": Color("#8a9a4e"),
	"biome.corrupted": Color("#5d4a6b"),
	"biome.forbidden": Color("#2e2a33"),
}

var continent: Dictionary = {}
var current_index := -1
## Discovered hidden realms in this province. Owned by the host, drawn here so
## the map is the one place a known rift has a mark.
var realm_marks: Array = []
## Discovered towns: [{name, position (world)}]. Owned by the host.
var town_marks: Array = []
## Lattice indexes of regions the player has entered.
var visited_regions: Array = []
## Per-region biome: {index: {id, name}}. Owned by the host.
var region_biomes: Dictionary = {}
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sync_view_size()
	get_viewport().size_changed.connect(_sync_view_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false



func _sync_view_size() -> void:
	var view := get_viewport_rect().size
	if size != view:
		size = view
		position = Vector2.ZERO
		queue_redraw()

func setup(data: Dictionary, current: int, marks: Array = [], extras: Dictionary = {}) -> void:
	continent = data
	current_index = current
	realm_marks = marks.duplicate(true)
	town_marks = (extras.get("towns", []) as Array).duplicate(true)
	visited_regions = (extras.get("visited", []) as Array).duplicate()
	region_biomes = (extras.get("biomes", {}) as Dictionary).duplicate(true)
	queue_redraw()


func toggle() -> void:
	visible = not visible
	queue_redraw()


func region_count() -> int:
	return (continent.get("regions", []) as Array).size()


func _text(pos: Vector2, text: String, font_size: int = 13, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if continent.is_empty():
		return
	# Code-created full-rect controls under a CanvasLayer report size (0, 0);
	# the viewport is the truth (the same pattern Hud draws with).
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), PANEL)
	var area := Rect2(Vector2(72, 104), Vector2(view.x - 144.0, view.y - 208.0))
	var capital_index := int(continent.get("capital", -1))
	var capital: Dictionary = Continent.region_by_index(continent, capital_index)
	var current: Dictionary = Continent.region_by_index(continent, current_index)

	_text(Vector2(area.position.x, area.position.y - 52.0), String(continent.get("name", "A continent")), 26)
	_text(Vector2(area.position.x, area.position.y - 28.0),
		"%d regions · you stand in %s · M closes the map" % [region_count(), String(current.get("name", "?"))],
		12, MUTED)

	var by_coord := {}
	for region in continent.get("regions", []):
		by_coord[region["coord"]] = region

	var cells: Array = continent.get("cells", [])
	for cell in cells:
		var rect := Continent.map_rect(cell["coord"], area)
		if bool(cell["land"]):
			var region: Dictionary = by_coord.get(cell["coord"], {})
			var index := int(region.get("index", -1))
			var info: Dictionary = region_biomes.get(index, {})
			var fill: Color = BIOME_COLORS.get(String(info.get("id", "")),
				TERRAIN_COLORS.get(String(cell["terrain"]), Color("#3f5a45")))
			if not visited_regions.is_empty() and not visited_regions.has(index):
				fill = fill.darkened(0.5)
			draw_rect(rect, fill)
		else:
			draw_rect(rect, SEA)
		draw_rect(rect, EDGE, false, 1.0)

	UiFrame.frame(self, area, UiFrame.BRONZE_DIM)

	# Land connections, drawn under the labels.
	for cell in cells:
		if not bool(cell["land"]):
			continue
		var from := Continent.map_rect(cell["coord"], area).get_center()
		for neighbour in cell.get("neighbours", []):
			var other: Dictionary = cells[int(neighbour)]
			var to := Continent.map_rect(other["coord"], area).get_center()
			draw_line(from, to, Color("#a8bfb6", 0.3), 1.0)

	for region in continent.get("regions", []):
		var rect := Continent.map_rect(region["coord"], area)
		var index := int(region["index"])
		if visited_regions.is_empty() or visited_regions.has(index):
			var info: Dictionary = region_biomes.get(index, {})
			_text(Vector2(rect.position.x + 8.0, rect.position.y + 20.0), String(region["name"]))
			_text(Vector2(rect.position.x + 8.0, rect.position.y + 36.0),
				"%s · tier %d" % [String(info.get("name", String(region["terrain"]).capitalize())), int(region["tier"])], 10, MUTED)
		else:
			_text(Vector2(rect.position.x + 8.0, rect.position.y + 20.0), "Uncharted", 11, MUTED)

	for town in town_marks:
		var p := Continent.map_point(town["position"], area)
		draw_circle(p, 3.5, TOWN_MARK)
		draw_arc(p, 6.0, 0.0, TAU, 20, TOWN_MARK, 1.0)
		_text(p + Vector2(9.0, 3.0), String(town["name"]), 9, TOWN_MARK)

	if not capital.is_empty():
		var crect := Continent.map_rect(capital["coord"], area)
		draw_rect(crect, GOLD, false, 1.5)
		_text(Vector2(crect.position.x + 8.0, crect.end.y - 10.0), "Capital", 10, GOLD)

	if not current.is_empty():
		var rect := Continent.map_rect(current["coord"], area)
		draw_rect(rect, ACCENT, false, 2.0)
		_text(Vector2(rect.end.x - 74.0, rect.end.y - 10.0), "you are here", 10, ACCENT)

	# A known rift is marked in the region the player walks, never elsewhere.
	if not current.is_empty() and not realm_marks.is_empty():
		var rect := Continent.map_rect(current["coord"], area)
		var center := rect.position + Vector2(rect.size.x - 18.0, 18.0)
		var color := REALM if bool((realm_marks[0] as Dictionary).get("open", false)) else Color("#8f7aa8")
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -6), center + Vector2(6, 0),
			center + Vector2(0, 6), center + Vector2(-6, 0),
		]), color)

	# Legend: the biomes this continent actually carries, then the sea.
	var legend_y := view.y - 58.0
	var seen := {}
	var entries: Array = []
	for region in continent.get("regions", []):
		var info: Dictionary = region_biomes.get(int(region["index"]), {})
		var biome_id := String(info.get("id", ""))
		if biome_id != "" and not seen.has(biome_id):
			seen[biome_id] = true
			entries.append(info)
	entries.append({"id": "", "name": "Sea"})
	var step: float = minf(118.0, area.size.x / float(maxi(1, entries.size())))
	var x := area.position.x
	for entry in entries:
		var swatch: Color = SEA if String(entry["id"]) == "" else BIOME_COLORS.get(String(entry["id"]), Color("#3f5a45"))
		draw_rect(Rect2(Vector2(x, legend_y), Vector2(12, 12)), swatch)
		_text(Vector2(x + 17.0, legend_y + 11.0), String(entry["name"]), 10, MUTED)
		x += step

	if not realm_marks.is_empty():
		var mark: Dictionary = realm_marks[0]
		_text(Vector2(area.position.x, view.y - 84.0),
			"Hidden realm — %s: %s" % [String(mark.get("name", "?")), String(mark.get("status", ""))],
			11, REALM)
	_text(Vector2(area.position.x, view.y - 26.0),
		"Every land region can be walked. Towns you discover are marked; routes between them run from the Travel panel.",
		11, Color("#6b7b84"))
