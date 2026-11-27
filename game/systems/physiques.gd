class_name Physiques
extends RefCounted
## Innate bodies: rolled at creation, applied through the stat pipeline, and
## replaceable only by a better one.
##
## A physique is content plus mods, never code: the same `StatBlock.apply_mods`
## path that equipment and passives use, so a physique can never invent a stat
## rule of its own.

const MAX_TIER := 5
## Fallback used by saves written before physiques existed.
const DEFAULT_ID := "physique.mortal_frame"


static func all() -> Array:
	return DB.physiques


## Weighted roll. `key` is the roll counter, and `Rng` mixes the world seed, so
## two runs with different seeds roll differently but a given run is repeatable.
static func roll(key: int) -> String:
	var defs: Array = DB.physiques
	if defs.is_empty():
		return ""
	var weights: Array = []
	for entry in defs:
		weights.append(maxi(1, int((entry as Dictionary).get("weight", 1))))
	var rng: RandomNumberGenerator = Rng.stream("physique", key, 0)
	var index: int = int(Rng.pick_weighted(weights, rng))
	if index < 0 or index >= defs.size():
		return DEFAULT_ID
	return String((defs[index] as Dictionary).get("id", DEFAULT_ID))


static func find(id: String) -> Dictionary:
	return DB.physique(id)


static func tier_of(id: String) -> int:
	return int(find(id).get("tier", 0))


static func name_of(id: String) -> String:
	var physique := find(id)
	if physique.is_empty():
		return "Mortal Frame"
	return String(physique.get("name", DEFAULT_ID))


## The tradeoff's own words, or "" for a body that carries none.
static func weakness_text(id: String) -> String:
	var weakness: Dictionary = find(id).get("weakness", {})
	return String(weakness.get("text", ""))


static func describe(id: String) -> String:
	var physique := find(id)
	if physique.is_empty():
		return "Mortal Frame (tier 1)"
	return "%s (tier %d) — %s" % [String(physique.get("name", "?")), int(physique.get("tier", 1)), String(physique.get("blurb", ""))]


## Higher tier wins; ties keep the current body, so an inheritance can never be a
## downgrade dressed up as a reward.
static func best_of(current_id: String, candidate_id: String) -> String:
	if tier_of(candidate_id) > tier_of(current_id):
		return candidate_id
	return current_id


static func inherited_for(current_id: String, key: int) -> String:
	return best_of(current_id, roll(key))
