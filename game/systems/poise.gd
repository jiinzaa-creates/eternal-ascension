class_name Poise
extends RefCounted
## A stagger meter, shared by every combatant.
##
## Poise absorbs blows until it runs out; the blow that empties it staggers the
## body for a moment and refills the meter. Poise never regenerates slowly, so a
## fight is decided by how much punishment a body can take in a row rather than
## by chip damage over a long time.

var maximum := 40.0
var current := 40.0
var stagger := 0.0
## How many times this body has been staggered, for tests and telemetry.
var breaks := 0


func _init(max_value := 40.0) -> void:
	set_maximum(max_value, true)


func set_maximum(value: float, refill := false) -> void:
	maximum = maxf(1.0, value)
	current = maximum if refill else minf(maxf(0.0, current), maximum)


func reset() -> void:
	current = maximum
	stagger = 0.0


## Applies poise damage. Returns true only on the blow that breaks the guard and
## staggers the body; a body already staggering cannot be staggered again.
func apply(poise_damage: float) -> bool:
	if poise_damage <= 0.0 or stagger > 0.0:
		return false
	current -= poise_damage
	if current > 0.0:
		return false
	breaks += 1
	stagger = stagger_for(poise_damage)
	current = maximum
	return true


## A guard break staggers whatever is left in the meter: the ward failed, so the
## body is carried by the blow even if its poise was nearly full. Returns false
## when the body is already staggering, because a stagger never chains.
func break_guard(poise_damage := 0.0) -> bool:
	if stagger > 0.0:
		return false
	breaks += 1
	stagger = stagger_for(maxf(35.0, poise_damage))
	current = maximum
	return true


## Stagger length grows with the force of the breaking blow, within limits.
static func stagger_for(poise_damage: float) -> float:
	return clampf(0.35 + maxf(0.0, poise_damage) * 0.01, 0.35, 0.9)


func tick(delta: float) -> void:
	stagger = maxf(0.0, stagger - maxf(0.0, delta))


func is_staggered() -> bool:
	return stagger > 0.0


func ratio() -> float:
	return clampf(current / maximum, 0.0, 1.0)
