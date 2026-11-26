class_name SkillBarPanel
extends Control
## Drag-and-drop arrangement of the three skill bars.
##
## The panel is the only place a layout is edited: the HUD bar stays a combat
## readout, so a stray click in a fight can never rearrange an art. Opening it
## pauses the run, exactly like the map and the travel overlay.
##
## Drag a slot onto another slot to move or swap it, drag a slot off the panel
## to clear it, drag an unplaced known art from the roster into a slot, and
## right-click a slot to empty it. All the rules live in `SkillBar`; this file
## only turns mouse positions into slot indices.

const PANEL := Color("#0b0f12", 0.95)
const SLOT_BG := Color("#141d23", 0.94)
const SLOT_ACTIVE := Color("#17272e", 0.96)
const SLOT_EMPTY := Color("#0e1418", 0.9)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const ACCENT := Color("#9fe0c0")
const COOL := Color("#070b0d", 0.66)
const COOL_INK := Color("#ffd07f")

const SLOT_GAP := 8.0
const SLOT_HEIGHT := 54.0
const PANEL_MARGIN := 112.0

var player: Player
var _font: Font
## The art being dragged: {tech: String, from: int}. `from` is -1 for a roster art.
var _drag: Dictionary = {}
## A click, not a drag, picked the art up: it stays in hand until the next
## click places it. `_press_pos` tells a click from a drag on release.
var _held_click := false
var _press_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func open(target: Player) -> void:
	player = target
	_drag = {}
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag = {}
	queue_redraw()


func is_dragging() -> bool:
	return not _drag.is_empty()


func _text(pos: Vector2, text: String, font_size: int = 13, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _fit(text: String, font_size: int, max_width: float) -> String:
	if _text_width(text, font_size) <= max_width:
		return text
	var cut := text
	while cut.length() > 1 and _text_width(cut + "..", font_size) > max_width:
		cut = cut.substr(0, cut.length() - 1)
	return cut + ".."


func _panel_rect() -> Rect2:
	var view := get_viewport_rect().size
	var w := clampf(view.x - 80.0, 760.0, 1180.0)
	var h := minf(486.0, maxf(320.0, view.y - 40.0))
	return Rect2(Vector2((view.x - w) * 0.5, (view.y - h) * 0.5), Vector2(w, h))


func _slot_size() -> Vector2:
	var panel := _panel_rect()
	var gaps := SLOT_GAP * float(SkillBar.SLOTS_PER_BAR - 1)
	var width := (panel.size.x - PANEL_MARGIN - gaps) / float(SkillBar.SLOTS_PER_BAR)
	return Vector2(maxf(84.0, width), SLOT_HEIGHT)


func _slot_rect(bar: int, slot: int) -> Rect2:
	var panel := _panel_rect()
	var cell := _slot_size()
	return Rect2(
		Vector2(panel.position.x + 84.0 + float(slot) * (cell.x + SLOT_GAP),
			panel.position.y + 102.0 + float(bar) * (SLOT_HEIGHT + SLOT_GAP)),
		cell
	)


func _roster_rect(index: int) -> Rect2:
	var panel := _panel_rect()
	var cell := _slot_size()
	var column := index % SkillBar.SLOTS_PER_BAR
	var row := index / SkillBar.SLOTS_PER_BAR
	return Rect2(
		Vector2(panel.position.x + 84.0 + float(column) * (cell.x + SLOT_GAP),
			panel.position.y + 356.0 + float(row) * 26.0),
		Vector2(cell.x, 22.0)
	)


func _roster_top() -> float:
	return _panel_rect().position.y + 356.0


## Global slot index under `pos`, or -1.
func _slot_at(pos: Vector2) -> int:
	for bar in SkillBar.BAR_COUNT:
		for slot in SkillBar.SLOTS_PER_BAR:
			if _slot_rect(bar, slot).has_point(pos):
				return SkillBar.index_of(bar, slot)
	return -1


## Technique id of the unplaced roster row under `pos`, or "".
func _roster_at(pos: Vector2) -> String:
	if player == null:
		return ""
	var off_bar: Array = player.known_off_bar()
	for i in off_bar.size():
		if _roster_rect(i).has_point(pos):
			return String(off_bar[i])
	return ""


func _gui_input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _held_click:
				_place_held(event.position)
			else:
				_press_pos = event.position
				_begin_drag(event.position)
		else:
			if _held_click:
				pass  # placement happens on the next press, not this release
			elif not _drag.is_empty() and int(_drag.get("from", -1)) == -1 \
					and event.position.distance_to(_press_pos) < 6.0 \
					and _roster_at(event.position) == String(_drag.get("tech", "")):
				# A click on a roster art picks it up instead of dragging.
				_held_click = true
				queue_redraw()
			else:
				_finish_drag(event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _held_click:
			_drag = {}
			_held_click = false
			queue_redraw()
			accept_event()
			return
		var slot := _slot_at(event.position)
		if slot >= 0:
			var slotted := player.bar_slot(slot)
			if slotted != "" and player.can_evolve(slotted):
				player.evolve_technique(slotted)
				queue_redraw()
				accept_event()
				return
			if player.clear_slot(slot):
				queue_redraw()
			accept_event()
			return
		var roster := _roster_at(event.position)
		if roster != "" and player.can_evolve(roster):
			player.evolve_technique(roster)
			queue_redraw()
			accept_event()
			return
	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		# Scrolling a slot walks the unplaced arts into it, one per notch.
		var slot := _slot_at(event.position)
		if slot >= 0:
			var off_bar: Array = player.known_off_bar()
			if not off_bar.is_empty():
				var pick := String(off_bar[0]) if event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
					else String(off_bar[off_bar.size() - 1])
				player.assign_slot(slot, pick)
				queue_redraw()
		accept_event()
		return
	if event is InputEventMouseMotion and not _drag.is_empty():
		queue_redraw()


## Put down an art that a click picked up: onto a slot, or nowhere (the
## click missed every slot and the hand simply empties).
func _place_held(pos: Vector2) -> void:
	var target := _slot_at(pos)
	var from := int(_drag.get("from", -1))
	var tech_id := String(_drag.get("tech", ""))
	if target >= 0:
		if from >= 0 and from != target:
			player.move_slot(from, target)
		elif from >= 0:
			if player.select_slot(target):
				player.set_active_bar(SkillBar.bar_of(target))
		else:
			player.assign_slot(target, tech_id)
	_drag = {}
	_held_click = false
	queue_redraw()


func _begin_drag(pos: Vector2) -> void:
	var slot := _slot_at(pos)
	if slot >= 0 and player.bar_slot(slot) != "":
		_drag = {"tech": player.bar_slot(slot), "from": slot}
		return
	var roster := _roster_at(pos)
	if roster != "":
		_drag = {"tech": roster, "from": -1}
		return
	_drag = {}


func _finish_drag(pos: Vector2) -> void:
	if _drag.is_empty():
		var clicked := _slot_at(pos)
		if clicked >= 0 and player.select_slot(clicked):
			player.set_active_bar(SkillBar.bar_of(clicked))
			queue_redraw()
		return
	var target := _slot_at(pos)
	var from := int(_drag.get("from", -1))
	var tech_id := String(_drag.get("tech", ""))
	if target >= 0:
		if from >= 0 and from != target:
			player.move_slot(from, target)
		elif from >= 0:
			if player.select_slot(target):
				player.set_active_bar(SkillBar.bar_of(target))
		else:
			player.assign_slot(target, tech_id)
	elif from >= 0:
		# Dropped outside the grid: taken off the bar, still known.
		player.clear_slot(from)
	_drag = {}
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05080a", 0.72))
	var panel := _panel_rect()
	UiFrame.panel(self, panel, PANEL)

	var x := panel.position.x + 24.0
	var y := panel.position.y + 30.0
	_text(Vector2(x, y), "SKILL BARS", 20, INK)
	_text(Vector2(x + 150.0, y), "drag, or click an art then a slot · scroll a slot to swap its art · right-click clears", 12, MUTED)

	for bar in SkillBar.BAR_COUNT:
		var row := _slot_rect(bar, 0)
		var label_color := ACCENT if bar == player.active_bar else MUTED
		_text(Vector2(x, row.position.y + 18.0), SkillBar.bar_label(bar), 16, label_color)
		_text(Vector2(x, row.position.y + 34.0), "%d/%d" % [SkillBar.bar_filled(player.bars, bar), SkillBar.SLOTS_PER_BAR], 10, MUTED)
		if bar == player.active_bar:
			var first := row.position
			var last := _slot_rect(bar, SkillBar.SLOTS_PER_BAR - 1)
			draw_rect(Rect2(first + Vector2(-6.0, -4.0),
				Vector2(last.end.x - first.x + 12.0, SLOT_HEIGHT + 8.0)), Color(ACCENT, 0.07))

		for slot in SkillBar.SLOTS_PER_BAR:
			var rect := _slot_rect(bar, slot)
			var index := SkillBar.index_of(bar, slot)
			var tech_id := player.bar_slot(index)
			var selected := tech_id != "" and tech_id == String(player.current_technique().get("id", ""))
			draw_rect(rect, SLOT_ACTIVE if selected else (SLOT_BG if tech_id != "" else SLOT_EMPTY))
			draw_rect(rect, Color("#7fd3e0") if selected else UiFrame.BRONZE_DIM, false, 2.0 if selected else 1.0)
			_text(rect.position + Vector2(8.0, 15.0), "%d" % (slot + 1), 10, MUTED)
			if tech_id == "":
				_text(rect.position + Vector2(26.0, 16.0), "empty", 11, Color("#42515a"))
				continue
			var tech: Dictionary = DB.technique(tech_id)
			_text(rect.position + Vector2(26.0, 16.0), _fit(String(tech.get("name", "?")), 11, rect.size.x - 34.0), 11, INK)
			if player.can_evolve(tech_id):
				_text(rect.position + Vector2(8.0, 32.0), "PERFECTED — RIGHT-CLICK EVOLVES", 9, ACCENT)
			else:
				_text(rect.position + Vector2(8.0, 32.0), player.mastery_label(tech_id), 9, MUTED)
			var kind := TechniqueCombat.kind_label(TechniqueCombat.kind_of(tech))
			_text(rect.position + Vector2(8.0, 46.0), kind, 9, Color("#7fa8b8"))
			var left := player.slot_cooldown_left(index)
			if left > 0.0:
				var ratio := player.slot_cooldown_ratio(index)
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), COOL)
				_text(rect.position + Vector2(rect.size.x - 36.0, 46.0), SkillBar.cooldown_text(left), 10, COOL_INK)

	var off_bar: Array = player.known_off_bar()
	_text(Vector2(x, _roster_top() - 14.0), "KNOWN, NOT ON A BAR — drag into a slot", 12, MUTED)
	if off_bar.is_empty():
		_text(Vector2(x, _roster_top() + 12.0), "Every known art has a slot.", 11, Color("#5d6d76"))
	for i in off_bar.size():
		var rect := _roster_rect(i)
		UiFrame.card(self, rect, Color("#101a1f", 0.9), Color("#243038"))
		var tech: Dictionary = DB.technique(String(off_bar[i]))
		_text(rect.position + Vector2(8.0, 15.0), _fit(String(tech.get("name", "?")), 10, rect.size.x - 14.0), 10, Color("#cfdae0"))

	_text(Vector2(x, panel.end.y - 18.0),
		"B / E close · click a roster art, then a slot, to place it · right-click clears a slot, or evolves a Perfected art",
		11, Color("#6b7b84"))

	if not _drag.is_empty():
		var ghost := String(DB.technique(String(_drag.get("tech", ""))).get("name", "?"))
		var at := get_local_mouse_position() + Vector2(14.0, -8.0)
		var width := _text_width(ghost, 12) + 18.0
		UiFrame.plaque(self, Rect2(at - Vector2(6.0, 14.0), Vector2(width, 22.0)), Color("#0d1b21", 0.95), ACCENT)
		_text(at, ghost, 12, INK)
