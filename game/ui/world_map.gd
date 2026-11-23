class_name WorldMap
extends Control
## Continent map, drawn in code like the rest of the interface.
##
## It is a read-only geography screen: it shows land, terrain, connections and
## the province the player stands in. It does not travel anywhere — fast travel
## is a later milestone and will consume `Continent` data rather than replace it.

const PANEL := Color("#0b0f12", 0.93)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const ACCENT := Color("#9fe0c0")
const SEA := Color("#0f1e26")
const EDGE := Color("#2b343a")

const TERRAIN_COLORS := {
	"plains": Color("#4f6b3a"),
	"forest": Color("#2f5233"),
	"mountains": Color("#5a5548"),
	"marsh": Color("#3d5245"),
	"desert": Color("#7a6a3f"),
	"coast": Color("#3a5b63"),
}

var continent: Dictionary = {}
var current_index := -1
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func setup(data: Dictionary, current: int) -> void:
	continent = data
	current_index = current
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
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	var area := Rect2(Vector2(72, 104), Vector2(size.x - 144.0, size.y - 208.0))
	var capital_index := int(continent.get("capital", -1))
	var capital: Dictionary = Continent.region_by_index(continent, capital_index)

	_text(Vector2(area.position.x, area.position.y - 52.0), String(continent.get("name", "A continent")), 26)
	_text(Vector2(area.position.x, area.position.y - 28.0),
		"%d regions · you stand in %s · M closes the map" % [region_count(), String(capital.get("name", "?")), ],
		12, MUTED)

	var cells: Array = continent.get("cells", [])
	for cell in cells:
		var rect := Continent.map_rect(cell["coord"], area)
		if bool(cell["land"]):
			draw_rect(rect, TERRAIN_COLORS.get(String(cell["terrain"]), Color("#3f5a45")))
		else:
			draw_rect(rect, SEA)
		draw_rect(rect, EDGE, false, 1.0)

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
		_text(Vector2(rect.position.x + 8.0, rect.position.y + 20.0), String(region["name"]))
		_text(Vector2(rect.position.x + 8.0, rect.position.y + 36.0),
			"%s · tier %d" % [String(region["terrain"]).capitalize(), int(region["tier"])], 10, MUTED)

	if not capital.is_empty():
		var rect := Continent.map_rect(capital["coord"], area)
		draw_rect(rect, ACCENT, false, 2.0)
		_text(Vector2(rect.position.x + 8.0, rect.end.y - 10.0), "you are here", 10, ACCENT)

	# Legend.
	var legend_y := size.y - 58.0
	var x := area.position.x
	for terrain in ["plains", "forest", "mountains", "marsh", "desert", "coast"]:
		draw_rect(Rect2(Vector2(x, legend_y), Vector2(12, 12)), TERRAIN_COLORS[terrain])
		_text(Vector2(x + 17.0, legend_y + 11.0), String(terrain).capitalize(), 10, MUTED)
		x += 96.0
	draw_rect(Rect2(Vector2(x, legend_y), Vector2(12, 12)), SEA)
	_text(Vector2(x + 17.0, legend_y + 11.0), "Sea", 10, MUTED)
	_text(Vector2(area.position.x, size.y - 26.0),
		"The province you walk is one region of this continent. Distant regions are geography, not yet reachable.",
		11, Color("#6b7b84"))
