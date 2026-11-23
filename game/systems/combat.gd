class_name Combat
extends RefCounted
## Shared combat architecture: frame phases, hitbox geometry, poise capacity,
## stagger length, knockback impulses and interruption rules.
##
## Both the player and every enemy resolve attacks through these functions, so
## reach, facing and stagger behave the same on either side of a blow. Nothing
## here touches nodes or the scene tree; the entities own the state and pass
## plain values in, which keeps the rules testable headlessly.

const PHASES: Array[String] = ["idle", "startup", "active", "recovery"]
## A blow during these phases can be interrupted before it lands.
const INTERRUPTIBLE: Array[String] = ["startup"]
const ACTIVE_MINIMUM := 0.016


## The phase after this one. Idle stays idle; a finished recovery returns to idle.
static func next_phase(state: String) -> String:
	match state:
		"startup":
			return "active"
		"active":
			return "recovery"
	return "idle"


## Seconds a phase lasts, from 60 Hz frame counts. Attack speed shortens every
## phase; recovery reduction only applies to recovery, and no phase disappears.
static func phase_seconds(frames: Dictionary, phase: String, speed := 1.0,
		recovery_reduction := 0.0) -> float:
	var raw := float(frames.get(phase, 4)) / 60.0 / maxf(0.2, speed)
	if phase == "recovery":
		raw *= clampf(1.0 - recovery_reduction, 0.05, 1.0)
	return maxf(ACTIVE_MINIMUM, raw)


## Whether a point lies inside a hitbox. `arc` honours both reach and the facing
## half-angle; `circle` (or any angle of 360+) ignores facing. `target_radius`
## is added to reach so a body is hit by its edge, not its centre.
static func in_hitbox(origin: Vector2, facing: Vector2, hitbox: Dictionary,
		target: Vector2, target_radius := 0.0) -> bool:
	var reach := maxf(0.0, float(hitbox.get("radius", 70.0))) + maxf(0.0, target_radius)
	var to_target := target - origin
	if to_target.length() > reach:
		return false
	var angle := deg_to_rad(float(hitbox.get("angle", 120.0)))
	if angle >= TAU - 0.001 or angle <= 0.0:
		return true
	if to_target.length_squared() < 0.0001 or facing.length_squared() < 0.0001:
		return true
	return absf(facing.normalized().angle_to(to_target.normalized())) <= angle * 0.5


## Every valid node from `candidates` inside the hitbox, in the order given.
static func targets(origin: Vector2, facing: Vector2, hitbox: Dictionary,
		candidates: Array, target_radius := 14.0) -> Array:
	var result: Array = []
	for candidate in candidates:
		var body := candidate as Node2D
		if body == null or not is_instance_valid(body):
			continue
		if in_hitbox(origin, facing, hitbox, body.global_position, target_radius):
			result.append(body)
	return result


## Poise a body of this realm and strength can take before it staggers. The
## mental attributes never contribute: this is a body's endurance.
static func poise_capacity(realm: int, strength: int) -> float:
	return 40.0 + 6.0 * float(maxi(1, realm)) + Attributes.soft(float(maxi(0, strength)), 20.0)


## Knockback impulse from an attack, scaled by whether the guard broke.
static func knock_impulse(direction: Vector2, force: float, poise_broken := false) -> Vector2:
	if direction.length_squared() < 0.0001:
		return Vector2.ZERO
	var scale := 0.2 if poise_broken else 0.12
	return direction.normalized() * maxf(0.0, force) * scale


## Whether a hit lands early enough to spoil the attack.
static func interrupts(state: String) -> bool:
	return INTERRUPTIBLE.has(state)
