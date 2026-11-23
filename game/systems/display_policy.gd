class_name DisplayPolicy
extends RefCounted
## Resolution scaling policy.
##
## The game is authored at 1280x720 and stretches with `canvas_items`. A window
## that is an exact multiple of the base size uses integer stretching, so pixel
## edges stay sharp; every other size uses fractional stretching with EXPAND, so
## a wider or taller window shows more of the world instead of black bars.
##
## The arithmetic is static and pure: the window is the only thing it touches.

const BASE_SIZE := Vector2i(1280, 720)
const MIN_SCALE := 0.75


## Largest whole number of times the base size fits in the window (at least 1).
static func integer_scale(window_size: Vector2i, base: Vector2i = BASE_SIZE) -> int:
	if base.x <= 0 or base.y <= 0:
		return 1
	var sx := float(window_size.x) / float(base.x)
	var sy := float(window_size.y) / float(base.y)
	return maxi(1, int(floor(minf(sx, sy))))


## True only for exact 2x, 3x, ... windows, where integer stretching is sharp.
static func uses_integer_stretch(window_size: Vector2i, base: Vector2i = BASE_SIZE) -> bool:
	if base.x <= 0 or base.y <= 0:
		return false
	if window_size.x % base.x != 0 or window_size.y % base.y != 0:
		return false
	return integer_scale(window_size, base) >= 2


static func stretch_for(window_size: Vector2i, base: Vector2i = BASE_SIZE) -> int:
	if uses_integer_stretch(window_size, base):
		return Window.CONTENT_SCALE_STRETCH_INTEGER
	return Window.CONTENT_SCALE_STRETCH_FRACTIONAL


static func min_window_size(base: Vector2i = BASE_SIZE) -> Vector2i:
	return Vector2i(
		maxi(1, int(round(float(base.x) * MIN_SCALE))),
		maxi(1, int(round(float(base.y) * MIN_SCALE)))
	)


## Applies the policy to a window. Safe to call again on every resize.
static func apply(window: Window, base: Vector2i = BASE_SIZE) -> void:
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = base
	window.content_scale_stretch = stretch_for(window.size, base)
	window.min_size = min_window_size(base)
