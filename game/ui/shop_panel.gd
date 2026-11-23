class_name ShopPanel
extends Control
## Merchant overlay: what is for sale, or what the satchel will fetch.
##
## Like the rest of the interface it is drawn in code. It holds no economy rules:
## the host decides prices, affordability and what a purchase does, and only hands
## the panel rows to display.

const PANEL := Color("#0b0f12", 0.94)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const GOLD := Color("#d8c070")
const ROW_BG := Color("#141d23", 0.9)

var mode := "buy"
var title := ""
var rows: Array = []
var stones := 0

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func setup(mode_value: String, title_value: String, row_data: Array, stones_value: int) -> void:
	mode = mode_value
	title = title_value
	rows = row_data
	stones = stones_value
	visible = true
	queue_redraw()


func hide_panel() -> void:
	visible = false


func _text(pos: Vector2, text: String, font_size: int = 13, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	var panel := Rect2(Vector2(120, 90), Vector2(size.x - 240.0, size.y - 180.0))
	draw_rect(panel, Color("#0d1418", 0.98))
	draw_rect(panel, Color("#2b343a"), false, 1.0)

	var x := panel.position.x + 24.0
	var y := panel.position.y + 34.0
	_text(Vector2(x, y), title, 20)
	y += 22.0
	var subtitle := "Buying" if mode == "buy" else "Selling"
	_text(Vector2(x, y), "%s · 1-6 choose · TAB switch · E close" % subtitle, 12, MUTED)
	y += 12.0
	_text(Vector2(panel.end.x - 24.0 - 150.0, panel.position.y + 34.0), "Spirit stones: %d" % stones, 14, GOLD)
	y += 22.0

	if rows.is_empty():
		_text(Vector2(x, y + 20.0), "Nothing to trade today.", 13, MUTED)
	else:
		var row_width := panel.size.x - 48.0
		for i in rows.size():
			var row: Dictionary = rows[i]
			var rect := Rect2(Vector2(x - 8.0, y), Vector2(row_width, 30.0))
			if i % 2 == 0:
				draw_rect(rect, ROW_BG)
			var color := Color(String(row.get("color", "#e6eef2")))
			_text(Vector2(x, y + 20.0), "%d.  %s" % [i + 1, String(row.get("name", "?"))], 13, color)
			var price_text := "%d stones" % int(row.get("price", 0))
			_text(Vector2(panel.end.x - 24.0 - 110.0, y + 20.0), price_text, 13, GOLD)
			y += 32.0

	var footer := "Enter an inn to rest, or sell spoils here."
	if mode == "buy":
		footer = "Merchant stock refreshes every day."
	else:
		footer = "Selling pays 40% of an item's value."
	_text(Vector2(x, panel.end.y - 20.0), footer, 11, Color("#6b7b84"))
