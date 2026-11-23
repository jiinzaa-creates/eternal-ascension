class_name Animator
extends RefCounted
## Procedural animation for code-drawn actors.
##
## The project ships no sprite sheets: every character is shapes. Animation is
## therefore a pose, not a texture swap — a clip is chosen from what the actor is
## doing, and the clip is a small set of offsets, a lean and a limb swing applied
## while drawing.
##
## Two rules keep it honest:
##  * combat animation reads the same frame data as combat (`attack_swing` takes
##    the technique's startup/active/recovery phase), so the visual strike can
##    never drift away from the frame that deals damage;
##  * every value is a pure function, so poses are asserted headlessly instead of
##    being eyeballed.

const STATES := ["idle", "walk", "run", "sprint", "attack", "dodge", "hurt", "meditate", "dead"]
const WALK_RATIO := 0.05
const RUN_RATIO := 0.6
const MAX_BOB := 4.0
const MAX_SWING := 1.0

var state := "idle"
var previous := "idle"
var time := 0.0
var state_changed := false


## Advances the clock and re-selects the clip. Returns the active clip name.
func update(delta: float, speed_ratio: float, sprinting: bool, attacking: bool,
		dodging: bool, hurt: bool, meditating: bool, dead: bool) -> String:
	var next := state_for(speed_ratio, sprinting, attacking, dodging, hurt, meditating, dead)
	state_changed = next != state
	if state_changed:
		previous = state
		state = next
		time = 0.0
	else:
		time += maxf(0.0, delta)
	return state


## Clip priority: terminal and interrupt states win over locomotion.
##
## Death > hurt > dodge > attack > meditation > sprint > run > walk > idle.
## Sprint still requires movement, so holding the key while standing cannot put
## the character into a running pose.
static func state_for(speed_ratio: float, sprinting: bool, attacking: bool, dodging: bool,
		hurt: bool, meditating: bool, dead: bool) -> String:
	if dead:
		return "dead"
	if hurt:
		return "hurt"
	if dodging:
		return "dodge"
	if attacking:
		return "attack"
	if meditating:
		return "meditate"
	if sprinting and speed_ratio > WALK_RATIO:
		return "sprint"
	if speed_ratio >= RUN_RATIO:
		return "run"
	if speed_ratio > WALK_RATIO:
		return "walk"
	return "idle"


## Pose for a clip at time `t`: body bob, squash/stretch, limb swing and lean.
static func pose(state_name: String, t: float, _speed_ratio: float = 0.0) -> Dictionary:
	var result := {
		"bob": Vector2.ZERO,
		"squash": Vector2.ONE,
		"swing": 0.0,
		"lean": 0.0,
	}
	match state_name:
		"walk":
			var walk_rate := 7.0
			result["bob"] = Vector2(0.0, -absf(sin(t * walk_rate)) * 2.0)
			result["swing"] = sin(t * walk_rate) * 0.45
			result["lean"] = 0.03
		"run":
			var run_rate := 10.0
			result["bob"] = Vector2(0.0, -absf(sin(t * run_rate)) * 3.0)
			result["swing"] = sin(t * run_rate) * 0.7
			result["lean"] = 0.07
		"sprint":
			var sprint_rate := 13.0
			result["bob"] = Vector2(0.0, -absf(sin(t * sprint_rate)) * MAX_BOB)
			result["swing"] = sin(t * sprint_rate) * 0.95
			result["lean"] = 0.13
		"dodge":
			result["bob"] = Vector2(0.0, 2.0)
			result["squash"] = Vector2(1.25, 0.78)
			result["lean"] = 0.2
		"hurt":
			result["bob"] = Vector2(-2.0, 1.0)
			result["squash"] = Vector2(1.08, 0.92)
		"meditate":
			result["bob"] = Vector2(0.0, sin(t * 1.4) * 0.8)
		"dead":
			result["bob"] = Vector2(0.0, 4.0)
			result["squash"] = Vector2(1.35, 0.5)
		_:
			# idle and attack breathe gently; the attack arm is added by swing.
			result["bob"] = Vector2(0.0, sin(t * 2.0) * 0.7)
	return result


## Limb swing for an attack, driven by the combat frame phase.
##
## Startup draws the arm back (negative), the active frames snap it forward, and
## recovery eases it home. `ratio` is progress through that phase, 0..1.
static func attack_swing(phase: String, ratio: float) -> float:
	var r := clampf(ratio, 0.0, 1.0)
	match phase:
		"startup":
			return lerpf(0.0, -MAX_SWING, r)
		"active":
			return lerpf(0.85, MAX_SWING, r)
		"recovery":
			return lerpf(MAX_SWING, 0.0, r)
	return 0.0
