class_name EnemyAI
extends RefCounted
## The hostile mind: archetypes, perception, leash, group slots and steering.
##
## Every rule here is pure. The body (`Dummy`) owns its timers, its position and
## its facing, and asks these functions what to do with them; nothing touches a
## node or the scene tree, which is what makes a fight testable headlessly.
##
## An archetype is a plain dictionary from `data/enemy_archetypes.json`, passed
## through `profile()` so a missing or malformed field falls back to a sane
## value instead of freezing the body. Four shapes exist:
##
##   brawler     — closes and swings a full circle; the original behaviour
##   skirmisher  — fast, light, retreats after a blow and flees once when hurt
##   sentinel    — slow, heavy, guards a short leash around its home
##   archer      — keeps its distance and fires a telegraphed Qi bolt
##
## A body's states are `idle`, `patrol`, `chase`, `circle`, `windup`, `recover`,
## `retreat`, `return` and `flee`. Staggering is not a state of this layer: poise
## owns it, and the body overrides everything while it is staggered.

const STATES: Array[String] = [
	"idle", "patrol", "chase", "circle", "windup", "recover", "retreat", "return", "flee",
]
const DELIVERIES: Array[String] = ["melee", "bolt"]

const DEFAULTS := {
	"id": "brawler",
	"name": "Brawler",
	"aggro_range": 320.0,
	"vision_degrees": 220.0,
	"leash": 520.0,
	"reach": 48.0,
	"arc": 360.0,
	"keep_range": 0.0,
	"windup": 0.45,
	"cooldown": 1.3,
	"speed_mult": 1.0,
	"hp_mult": 1.0,
	"damage_mult": 1.0,
	"poise_mult": 1.0,
	"memory": 4.0,
	"group_limit": 3,
	"retreat_after": 0,
	"retreat_time": 0.55,
	"flee_below": 0.0,
	"flee_time": 2.5,
	"patrol_radius": 90.0,
	"delivery": "melee",
	"telegraph_color": "#ff9060",
	"projectile": {"speed": 420.0, "range": 380.0, "radius": 7.0, "pierce": 0},
}

## How far a body drifts away from a neighbour that is standing on top of it.
const SEPARATION_RADIUS := 34.0
## How close to its post a body must stand to count as home again. The body uses
## this same distance to arrive and mend, so there is no dead band where a
## returning enemy is "home" but never finishes returning.
const AT_HOME := 6.0


static func defaults() -> Dictionary:
	return (DEFAULTS as Dictionary).duplicate(true)


## A complete, clamped archetype. Unknown keys are ignored and missing keys take
## their defaults, so a body is never left without a usable profile.
static func profile(entry: Dictionary) -> Dictionary:
	var out: Dictionary = (DEFAULTS as Dictionary).duplicate(true)
	for key in out.keys():
		if entry.has(key):
			out[key] = entry[key]
	out["id"] = String(out.get("id", "brawler"))
	out["name"] = String(out.get("name", "Cultivator"))
	out["aggro_range"] = maxf(1.0, float(out.get("aggro_range", 1.0)))
	out["vision_degrees"] = clampf(float(out.get("vision_degrees", 220.0)), 1.0, 360.0)
	out["leash"] = maxf(0.0, float(out.get("leash", 0.0)))
	out["reach"] = maxf(1.0, float(out.get("reach", 1.0)))
	out["arc"] = clampf(float(out.get("arc", 360.0)), 1.0, 360.0)
	out["keep_range"] = maxf(0.0, float(out.get("keep_range", 0.0)))
	out["windup"] = maxf(0.02, float(out.get("windup", 0.02)))
	out["cooldown"] = maxf(0.05, float(out.get("cooldown", 0.05)))
	out["speed_mult"] = clampf(float(out.get("speed_mult", 1.0)), 0.1, 4.0)
	out["hp_mult"] = maxf(0.05, float(out.get("hp_mult", 1.0)))
	out["damage_mult"] = maxf(0.05, float(out.get("damage_mult", 1.0)))
	out["poise_mult"] = maxf(0.05, float(out.get("poise_mult", 1.0)))
	out["memory"] = maxf(0.0, float(out.get("memory", 0.0)))
	out["group_limit"] = maxi(1, int(out.get("group_limit", 1)))
	out["retreat_after"] = maxi(0, int(out.get("retreat_after", 0)))
	out["retreat_time"] = maxf(0.0, float(out.get("retreat_time", 0.0)))
	out["flee_below"] = clampf(float(out.get("flee_below", 0.0)), 0.0, 1.0)
	out["flee_time"] = maxf(0.0, float(out.get("flee_time", 0.0)))
	out["patrol_radius"] = maxf(0.0, float(out.get("patrol_radius", 0.0)))
	var delivery := String(out.get("delivery", "melee"))
	out["delivery"] = delivery if DELIVERIES.has(delivery) else "melee"
	out["projectile"] = _projectile_spec(out.get("projectile", {}))
	return out


## Look an archetype up by id in a content table. An unknown id yields the
## defaults under that name, so a stale biome entry degrades to a brawler.
static func profile_by_id(table: Array, id: String) -> Dictionary:
	for entry in table:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get("id", "")) == id:
			return profile(entry)
	return profile({"id": id, "name": id.capitalize()})


static func _projectile_spec(value: Variant) -> Dictionary:
	var out := {"speed": 420.0, "range": 380.0, "radius": 7.0, "pierce": 0}
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		out["speed"] = maxf(1.0, float(data.get("speed", out["speed"])))
		out["range"] = maxf(1.0, float(data.get("range", out["range"])))
		out["radius"] = maxf(1.0, float(data.get("radius", out["radius"])))
		out["pierce"] = maxi(0, int(data.get("pierce", 0)))
	return out


# --- perception --------------------------------------------------------------

## Whether a target at `distance` in direction `to_target` lies inside the aggro
## range and the vision cone. A cone of 360 sees all around; a body with no
## facing is treated as alert rather than blind.
static func perceives(distance: float, to_target: Vector2, facing: Vector2,
		profile_in: Dictionary) -> bool:
	if distance < 0.0 or distance > float(profile_in.get("aggro_range", 0.0)):
		return false
	var half := deg_to_rad(float(profile_in.get("vision_degrees", 360.0))) * 0.5
	if half >= PI - 0.001:
		return true
	if facing.length_squared() < 0.0001 or to_target.length_squared() < 0.0001:
		return true
	return absf(facing.normalized().angle_to(to_target.normalized())) <= half


## A body dragged past its leash gives up the chase and walks home.
static func leash_broken(home_distance: float, profile_in: Dictionary) -> bool:
	return home_distance > float(profile_in.get("leash", 0.0))


## Whether a wounded body of this archetype wants to run. The body may only take
## this decision once; `facts.flee_used` keeps a fight from becoming a chase.
static func wants_to_flee(hp_ratio: float, profile_in: Dictionary) -> bool:
	var threshold := float(profile_in.get("flee_below", 0.0))
	return threshold > 0.0 and hp_ratio <= threshold


# --- decision ----------------------------------------------------------------

## The next state from plain facts. Keys (all optional):
##   dist, home_dist, memory, hp_ratio, flee_left, retreat_left,
##   seen, at_home, ready, committed, flee_used, in_reach
##
## Order matters: a broken leash beats every other consideration, a running
## clock beats a fresh decision, an unseen body forgets, and only then does the
## archetype's own shape (fleeing, kiting, group slots) apply.
static func think(facts: Dictionary, profile_in: Dictionary) -> String:
	var seen := bool(facts.get("seen", false))
	var memory := float(facts.get("memory", 0.0))
	var home_dist := float(facts.get("home_dist", 0.0))
	var at_home := bool(facts.get("at_home", true))
	var in_reach := bool(facts.get("in_reach", false))
	var ready := bool(facts.get("ready", true))
	var committed := bool(facts.get("committed", true))

	if leash_broken(home_dist, profile_in):
		return "return"
	if float(facts.get("flee_left", 0.0)) > 0.0:
		return "flee"
	if float(facts.get("retreat_left", 0.0)) > 0.0:
		return "retreat"
	if not seen and memory <= 0.0:
		return "patrol" if at_home else "return"
	if wants_to_flee(float(facts.get("hp_ratio", 1.0)), profile_in) \
			and not bool(facts.get("flee_used", false)):
		return "flee"
	if is_ranged(profile_in) and float(facts.get("dist", 0.0)) < keep_away(profile_in):
		return "retreat"
	if in_reach:
		if not committed:
			return "circle"
		return "windup" if ready else "recover"
	if not committed:
		return "circle"
	return "chase"


# --- steering ----------------------------------------------------------------

## A unit direction for the state. `to_home` is only read by `return`; `strafe`
## (±1) decides which way a circling body orbits.
static func move_intent(state: String, to_target: Vector2, dist: float,
		profile_in: Dictionary, strafe := 1.0, to_home := Vector2.ZERO) -> Vector2:
	var dir := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	match state:
		"chase":
			return dir
		"return":
			return to_home.normalized() if to_home.length_squared() > 0.0001 else Vector2.ZERO
		"retreat", "flee":
			return -dir
		"circle":
			var ring := ring_distance(profile_in)
			var tangent := Vector2(-dir.y, dir.x) * clampf(strafe, -1.0, 1.0)
			var radial := clampf((dist - ring) / maxf(ring, 1.0), -1.0, 1.0) * dir
			var out := tangent + radial
			return out.normalized() if out.length_squared() > 0.0001 else tangent
	return Vector2.ZERO


## The ring a circling body keeps: its own reach, or an archer's firing band.
static func ring_distance(profile_in: Dictionary) -> float:
	if is_ranged(profile_in):
		return maxf(keep_away(profile_in), 1.0)
	return maxf(reach(profile_in) * 1.15, 1.0)


## A push away from every neighbour inside the radius, one unit per overlapping
## body. Stacked bodies get a deterministic shove so a crowd cannot freeze.
static func separation(position: Vector2, others: Array, radius: float) -> Vector2:
	var push := Vector2.ZERO
	var limit := maxf(1.0, radius)
	for other in others:
		if typeof(other) != TYPE_VECTOR2:
			continue
		var offset: Vector2 = position - (other as Vector2)
		var distance := offset.length()
		if distance < 0.0001:
			push += Vector2.RIGHT * 0.5
		elif distance < limit:
			push += offset / distance * (1.0 - distance / limit)
	return push


## Group coordination: only so many bodies commit to a blow at once, the rest
## orbit. `committed` counts allies already winding up nearby.
static func may_commit(committed: int, profile_in: Dictionary) -> bool:
	return maxi(0, committed) < int(profile_in.get("group_limit", 1))


# --- numbers -----------------------------------------------------------------

static func is_ranged(profile_in: Dictionary) -> bool:
	return String(profile_in.get("delivery", "melee")) == "bolt"


static func reach(profile_in: Dictionary) -> float:
	return maxf(0.0, float(profile_in.get("reach", 0.0)))


## The distance an archer tries to hold. A melee body has no preferred band and
## returns zero, which is why kiting rules only ever apply to a `bolt` delivery.
static func keep_away(profile_in: Dictionary) -> float:
	if not is_ranged(profile_in):
		return 0.0
	return maxf(reach(profile_in) * 0.35, float(profile_in.get("keep_range", 0.0)))


static func strike_hitbox(profile_in: Dictionary) -> Dictionary:
	return {
		"shape": "circle",
		"radius": reach(profile_in),
		"angle": float(profile_in.get("arc", 360.0)),
	}


static func windup_time(profile_in: Dictionary) -> float:
	return maxf(0.02, float(profile_in.get("windup", 0.02)))


static func cooldown_time(profile_in: Dictionary) -> float:
	return maxf(0.05, float(profile_in.get("cooldown", 0.05)))


static func telegraph_color(profile_in: Dictionary) -> Color:
	return Color(String(profile_in.get("telegraph_color", "#ff9060")))


static func label(state: String) -> String:
	match state:
		"idle":
			return "Idle"
		"patrol":
			return "Patrolling"
		"chase":
			return "Chasing"
		"circle":
			return "Circling"
		"windup":
			return "Winding up"
		"recover":
			return "Recovering"
		"retreat":
			return "Retreating"
		"return":
			return "Returning home"
		"flee":
			return "Fleeing"
	return "Unknown"
