class_name Motion
extends RefCounted
## Movement feel: acceleration, braking, sprint and stick shaping.
##
## The player used to snap straight to full speed: releasing a key stopped the
## character on the same frame, and reversing teleported velocity across zero.
## This is the small velocity controller that fixes that, kept as pure static
## functions so the feel maths can be checked headlessly.

const SPRINT_MULTIPLIER := 1.45
const STICK_DEADZONE := 0.2


## Moves `current` toward `desired`, accelerating at `accel` and braking at
## `decel`. `desired` carries both the direction and the target speed.
##
## Pushing against current motion counts as braking rather than acceleration, so
## a reversal plants and turns instead of feeling weightless.
static func approach(current: Vector2, desired: Vector2, accel: float, decel: float, delta: float) -> Vector2:
	var step := maxf(0.0, delta)
	if step <= 0.0:
		return current
	if desired == Vector2.ZERO:
		return current.move_toward(Vector2.ZERO, maxf(0.0, decel) * step)
	var rate := maxf(0.0, accel)
	if current != Vector2.ZERO and current.angle_to(desired) > PI * 0.5:
		rate = maxf(0.0, decel)
	var next := current.move_toward(desired, rate * step)
	if next.length() > desired.length():
		next = next.normalized() * desired.length()
	return next


static func sprint_speed(base: float, sprinting: bool) -> float:
	return base * SPRINT_MULTIPLIER if sprinting else base


## Circular deadzone with rescaling: a stick that just leaves the deadzone
## starts from zero instead of jumping to the threshold.
static func deadzone(raw: Vector2, threshold: float = STICK_DEADZONE) -> Vector2:
	var limit := clampf(threshold, 0.0, 0.99)
	var magnitude := raw.length()
	if magnitude <= limit:
		return Vector2.ZERO
	var scaled := minf(1.0, (magnitude - limit) / (1.0 - limit))
	return raw.normalized() * scaled
