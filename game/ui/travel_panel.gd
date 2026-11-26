class_name TravelPanel
extends Control
## Fast-travel and waypoint overlay, drawn in code.
##
## It displays destinations and the time each costs; the host owns availability,
## the clock and the actual move. Selection is a row index so the keyboard and the
## gamepad share one path.

const PANEL := Color("#0b0f12", 0.94)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const ACCENT := Color("#9fe0c0")
const ROW_BG := Color("#141d23", 0.9)

var rows: Array = []
var selected := 0

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func setup(row_data: Array, selected_index: int) -> void:
	rows = row_data
	selected = selected_index
	visible = true
	queue_redraw()


func hide_panel() -> void:
	visible = false


func _text(pos: Vector2, text: String, font_size: int = 13, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	var panel := Rect2(Vector2(150, 110), Vector2(size.x - 300.0, size.y - 220.0))
	UiFrame.panel(self, panel, Color("#0d1418", 0.98))

	var x := panel.position.x + 24.0
	var y := panel.position.y + 34.0
	_text(Vector2(x, y), "Routes", 20)
	y += 22.0
	_text(Vector2(x, y), "Travelling costs time, and time moves the world.", 12, MUTED)
	y += 26.0

	if rows.is_empty():
		_text(Vector2(x, y + 20.0), "No known destinations. Discover a site first.", 13, MUTED)
	else:
		var width := panel.size.x - 48.0
		for i in rows.size():
			var row: Dictionary = rows[i]
			var rect := Rect2(Vector2(x - 8.0, y), Vector2(width, 30.0))
			if i % 2 == 0:
				draw_rect(rect, ROW_BG)
			if i == selected:
				draw_rect(rect, Color(ACCENT, 0.16))
				draw_rect(rect, ACCENT, false, 1.0)
			var color := Color(String(row.get("color", "#e6eef2")))
			_text(Vector2(x, y + 20.0), "%d.  %s" % [i + 1, String(row.get("name", "?"))], 13, color)
			_text(Vector2(panel.end.x - 24.0 - 120.0, y + 20.0), String(row.get("detail", "")), 12, MUTED)
			y += 32.0

	var footer := "1-6 select · ENTER travel · V set waypoint · E close"
	_text(Vector2(x, panel.end.y - 20.0), footer, 11, Color("#6b7b84"))
