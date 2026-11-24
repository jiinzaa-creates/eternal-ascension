class_name Hitstop
extends RefCounted
## Impact freeze: the world holds for a few hundredths of a second when a blow
## lands, so a hit has weight.
##
## This is deliberately *not* `Engine.time_scale` or `get_tree().paused`. A
## global freeze would stop the clock the whole game runs on, stall the HUD and
## make a headless suite wait on frames that never tick. Instead one timer is
## ticked by real `_process` time, and the bodies and effects that fight simply
## stand still while it is frozen. Cooldowns, attack timers, statuses and the AI
## pause with them, which is exactly what a freeze frame is.
##
## Blows do not stack: a second hit during a freeze extends it only if it asks
## for more time than remains, so a storm of hits cannot lock the world.

const MIN := 0.02
const MAX := 0.12
const BASE := 0.028
const PER_DAMAGE := 0.0011
const DAMAGE_CAP := 0.05
const CRIT_BONUS := 0.03
const HEAVY_BONUS := 0.018

## A player option can switch the freeze off without changing any combat rule.
var enabled := true
## Seconds left in the current freeze.
var remaining := 0.0
## How many blows were ever asked to freeze, for tests and telemetry.
var requests := 0


## The freeze a single blow earns. A scratch barely registers, a heavy critical
## blow holds the world at the cap; nothing freezes for zero damage.
static func duration_for(amount: float, critical := false, heavy := false) -> float:
	if amount <= 0.0:
		return 0.0
	var seconds := BASE + clampf(amount * PER_DAMAGE, 0.0, DAMAGE_CAP)
	if critical:
		seconds += CRIT_BONUS
	if heavy:
		seconds += HEAVY_BONUS
	return clampf(seconds, MIN, MAX)


## Requests a freeze; never shortens a longer one already running. A disabled
## freeze accepts the request and does nothing, so every damage site stays
## unaware of the option.
func request(seconds: float) -> float:
	if not enabled or seconds <= 0.0:
		return remaining
	requests += 1
	remaining = maxf(remaining, clampf(seconds, 0.0, MAX))
	return remaining


## Convenience for a damage site: compute and request in one call.
func punch(amount: float, critical := false, heavy := false) -> float:
	return request(duration_for(amount, critical, heavy))


func tick(delta: float) -> float:
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	return remaining


func is_frozen() -> bool:
	return remaining > 0.0


func clear() -> void:
	remaining = 0.0
