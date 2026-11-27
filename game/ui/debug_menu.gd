class_name DebugMenu
extends Control
## The in-game debug menu: the run's verbs, the log tail, and a report.
##
## Drawn in code like the rest of the interface, and deliberately thin: it holds
## a cursor and a status line, and everything it can do lives in `DebugActions`
## (the catalogue) and `DebugReport` (the export). That split is what makes the
## menu testable without a window and keeps a debug tool from growing rules of
## its own.
##
## Keys: up/down move, left/right change group, enter runs, TAB switches to the
## log pane, R writes a report, C copies it, P posts it to `EA_DEBUG_SINK` and
## escape/F11 closes. It consumes every key while open, so nothing leaks into play.

const PANEL := Color("#05080a", 0.94)
const BODY := Color("#0b1014", 0.98)
const BORDER := Color("#2b343a")
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const GOLD := Color("#d8c070")
const BAD := Color("#e08080")
const ROW := Color("#131b21", 0.95)
const ROW_ON := Color("#20303a", 0.98)
const ROWS := 12

var host: Node = null
var actions: Array = []
var group := "clock"
var index := 0
var log_view := false
var status := "Up/Down move · Left/Right group · Enter run · R report · C copy · P post"

var _font: Font
var _redraw := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func open() -> void:
	actions = DebugActions.build(host)
	group = String(DebugActions.GROUPS[0])
	index = 0
	log_view = false
	status = "Up/Down move · Left/Right group · Enter run · R report · C copy · P post"
	visible = true
	size = get_viewport_rect().size
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	var viewport := get_viewport_rect().size
	if size != viewport:
		size = viewport
		queue_redraw()
	# The log moves without a key; redraw at ten hertz rather than every frame.
	_redraw += delta
	if _redraw >= 0.1:
		_redraw = 0.0
		queue_redraw()


## Runs one action by id and returns its status line. Closes first: several
## actions open another screen, and two overlays fighting over the same keys is
## how a debug tool starts lying about the game.
func activate(id: String) -> String:
	var chosen := {}
	for value in actions:
		if String((value as Dictionary).get("id", "")) == id:
			chosen = value
			break
	if chosen.is_empty():
		status = "No action '%s'" % id
		return ""
	if host != null and host.has_method("_close_debug"):
		host.call("_close_debug")
	var result := String((chosen["run"] as Callable).call())
	status = result
	Log.info("debug", "%s: %s" % [id, result])
	return result


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return true
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return true
	match key.keycode:
		KEY_ESCAPE:
			if host != null and host.has_method("_close_debug"):
				host.call("_close_debug")
		KEY_UP, KEY_W:
			_move(-1)
		KEY_DOWN, KEY_S:
			_move(1)
		KEY_LEFT, KEY_A:
			_cycle_group(-1)
		KEY_RIGHT, KEY_D:
			_cycle_group(1)
		KEY_ENTER, KEY_KP_ENTER:
			_run_selected()
		KEY_TAB:
			log_view = not log_view
			queue_redraw()
		KEY_R:
			_write_report()
		KEY_C:
			_copy_report()
		KEY_P:
			_post_report()
	# Everything is consumed while the menu is open; Escape and F11 are the ways out.
	return true


func visible_actions() -> Array:
	var out: Array = []
	for value in actions:
		if String((value as Dictionary).get("group", "")) == group:
			out.append(value)
	return out


func _move(step: int) -> void:
	var list := visible_actions()
	if list.is_empty():
		return
	index = clampi(index + step, 0, list.size() - 1)
	queue_redraw()


func _cycle_group(step: int) -> void:
	var groups := DebugActions.GROUPS
	var current := groups.find(group)
	group = groups[posmod(current + step, groups.size())]
	index = 0
	queue_redraw()


func _run_selected() -> void:
	var list := visible_actions()
	if index < 0 or index >= list.size():
		return
	activate(String((list[index] as Dictionary).get("id", "")))


func _write_report() -> void:
	var path := DebugReport.write(host, "")
	status = "Report written: %s" % path if path != "" else "Report could not be written"
	Log.info("debug", status)
	queue_redraw()


func _copy_report() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		status = "No clipboard on this platform — press R to write a file"
		queue_redraw()
		return
	var body := DebugReport.text(host, "")
	DisplayServer.clipboard_set(body)
	status = "Report copied to the clipboard (%d bytes)" % body.length()
	Log.info("debug", status)
	queue_redraw()


func _post_report() -> void:
	var url := DebugReport.sink_url()
	if url.is_empty():
		status = "No sink configured: set EA_DEBUG_SINK to a URL, or press R"
		queue_redraw()
		return
	var body := DebugReport.text(host, "")
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_posted.bind(http, body.length()))
	var headers := PackedStringArray(["Content-Type: text/plain; charset=utf-8"])
	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		status = "Report not sent (request error %d)" % error
		http.queue_free()
		Log.warn("debug", status)
	queue_redraw()


func _posted(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray,
		http: HTTPRequest, sent_bytes: int) -> void:
	if http != null and is_instance_valid(http):
		http.queue_free()
	if code >= 200 and code < 300:
		status = "Report posted (%d bytes, HTTP %d)" % [sent_bytes, code]
	else:
		status = "Report rejected (HTTP %d) — press R to keep a file" % code
	Log.info("debug", status + " " + body.get_string_from_utf8().substr(0, 120))
	queue_redraw()


func _text(pos: Vector2, text: String, size_px: int = 13, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	var panel := Rect2(Vector2(40, 28), size - Vector2(80, 56))
	draw_rect(panel, BODY)
	draw_rect(panel, BORDER, false, 1.0)
	var x := panel.position.x + 20.0
	var y := panel.position.y + 30.0

	_text(Vector2(x, y), "DEBUG  ·  %s  ·  F11 closes" % String(host.phase if host != null else ""), 18, GOLD)
	var counts := "log %d · warn %d · err %d" % [
		Log.entries.size(), Log.count(Log.Level.WARN), Log.count(Log.Level.ERROR)]
	_text(Vector2(panel.end.x - 20.0 - 190.0, y), counts, 12, MUTED)
	y += 26.0

	# Group tabs.
	var gx := x
	for name in DebugActions.GROUPS:
		var label := String(name)
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
		var on := label == group
		draw_rect(Rect2(Vector2(gx, y - 12.0), Vector2(width, 18.0)), ROW_ON if on else ROW)
		_text(Vector2(gx + 7.0, y + 1.0), label, 12, GOLD if on else MUTED)
		gx += width + 4.0
	y += 22.0

	# Action rows.
	var list := visible_actions()
	var first := clampi(index - ROWS / 2, 0, maxi(0, list.size() - ROWS))
	for row in ROWS:
		var at := first + row
		if at >= list.size():
			break
		var action: Dictionary = list[at]
		var rect := Rect2(Vector2(x, y - 12.0), Vector2(panel.size.x - 40.0, 18.0))
		if at == index:
			draw_rect(rect, ROW_ON)
		_text(Vector2(x + 8.0, y + 1.0), String(action["label"]), 13, INK if at == index else MUTED)
		_text(Vector2(panel.end.x - 20.0 - 210.0, y + 1.0), String(action["id"]), 11, Color("#5f7580"))
		y += 19.0

	# Log tail, always present: the point of the menu is catching what happened.
	y = panel.end.y - 96.0
	draw_line(Vector2(x, y - 12.0), Vector2(panel.end.x - 20.0, y - 12.0), BORDER, 1.0)
	_text(Vector2(x, y), "LOG (newest last) · TAB %s" % ("actions" if log_view else "log"), 11, MUTED)
	y += 15.0
	var recent: Array = Log.recent(4)
	if recent.is_empty():
		_text(Vector2(x, y), "(empty)", 11, MUTED)
	for value in recent:
		var entry: Dictionary = value
		var color := INK
		if int(entry["level"]) == Log.Level.WARN:
			color = GOLD
		elif int(entry["level"]) == Log.Level.ERROR:
			color = BAD
		_text(Vector2(x, y), "[%s] %s: %s" % [
			Log.LEVEL_NAMES[int(entry["level"])], String(entry["category"]), String(entry["message"])],
			11, color)
		y += 13.0

	_text(Vector2(x, panel.end.y - 16.0), status, 12, GOLD)
	_text(Vector2(x, panel.end.y - 2.0), "reports: %s" % DebugReport.DIR, 10, Color("#5f7580"))
