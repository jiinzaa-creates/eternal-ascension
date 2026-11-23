class_name CameraRig
extends Camera2D
## Follow camera with world bounds and discrete zoom levels.
##
## Bounds are enforced twice on purpose. The camera's own limits stop the view at
## the province or realm edge, and `clamp_center()` is the pure form of the same
## rule so the framing can be tested without a GPU.
##
## Zoom is a fixed ladder rather than a free float: every level is a deliberate
## framing (overview, default, close), and clamping the index means the wheel and
## the keyboard can never reach an unplayable scale.

## Levels are camera zoom factors; 1.0 is the authored field of view.
const ZOOM_LEVELS := [0.75, 1.0, 1.25, 1.5, 2.0]
const MIN_ZOOM := 0.75
const MAX_ZOOM := 2.0
const DEFAULT_ZOOM_INDEX := 1
const SMOOTHING_SPEED := 8.0

var zoom_index := DEFAULT_ZOOM_INDEX
var bounds := Rect2()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = SMOOTHING_SPEED
	limit_smoothed = true
	set_zoom_index(DEFAULT_ZOOM_INDEX)


## Restricts the camera to a world-space rectangle (province or realm).
func set_bounds(area: Rect2) -> void:
	bounds = area
	limit_left = int(round(area.position.x))
	limit_top = int(round(area.position.y))
	limit_right = int(round(area.end.x))
	limit_bottom = int(round(area.end.y))


func set_zoom_index(index: int) -> void:
	zoom_index = clampi(index, 0, ZOOM_LEVELS.size() - 1)
	var factor: float = float(ZOOM_LEVELS[zoom_index])
	zoom = Vector2(factor, factor)


func zoom_in() -> void:
	set_zoom_index(zoom_index + 1)


func zoom_out() -> void:
	set_zoom_index(zoom_index - 1)


func reset_view() -> void:
	set_zoom_index(DEFAULT_ZOOM_INDEX)
	reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				return
	if event.is_action_pressed("zoom_in"):
		zoom_in()
	elif event.is_action_pressed("zoom_out"):
		zoom_out()


## Half of the visible world rectangle at a zoom factor.
static func half_view(viewport_size: Vector2, zoom_factor: float) -> Vector2:
	return viewport_size * 0.5 / maxf(0.01, zoom_factor)


## Clamps a camera centre so the view never shows past `area`.
##
## When the area is smaller than the view on an axis the camera is centred on
## that axis instead of jittering between two impossible clamps.
static func clamp_center(center: Vector2, viewport_size: Vector2, zoom_factor: float, area: Rect2) -> Vector2:
	var half := half_view(viewport_size, zoom_factor)
	var result := center
	if area.size.x <= half.x * 2.0:
		result.x = area.position.x + area.size.x * 0.5
	else:
		result.x = clampf(center.x, area.position.x + half.x, area.end.x - half.x)
	if area.size.y <= half.y * 2.0:
		result.y = area.position.y + area.size.y * 0.5
	else:
		result.y = clampf(center.y, area.position.y + half.y, area.end.y - half.y)
	return result
