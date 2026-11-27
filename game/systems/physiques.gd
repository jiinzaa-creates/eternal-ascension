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
	# Weight 0 marks an earned body — an evolution form. Rolls (creation,
	# inheritance) never deal one; it is reached, not dealt.
	var defs: Array = []
	for entry in DB.physiques:
		if int((entry as Dictionary).get("weight", 1)) > 0:
			defs.append(entry)
	if defs.is_empty():
		return ""
	var weights: Array = []
	for entry in defs:
		weights.append(int((entry as Dictionary).get("weight", 1)))
	var rng: RandomNumberGenerator = Rng.stream("physique", key, 0)
	var index: int = int(Rng.pick_weighted(weights, rng))
	if index < 0 or index >= defs.size():
		return DEFAULT_ID
	return String((defs[index] as Dictionary).get("id", DEFAULT_ID))


## A latent bloodline, drawn from the lesser bodies only: a tribulation can
## wake what sleeps in the blood, but it does not hand out apex physiques.
static func latent_roll(key: int) -> String:
	var defs: Array = []
	var weights: Array = []
	for entry in DB.physiques:
		if int(entry.get("weight", 1)) > 0 and int(entry.get("tier", 0)) <= 3 \
				and String(entry.get("id", "")) != DEFAULT_ID:
			defs.append(entry)
			weights.append(int(entry.get("weight", 1)))
	if defs.is_empty():
		return ""
	var rng: RandomNumberGenerator = Rng.stream("physique_latent", key, 0)
	var index: int = int(Rng.pick_weighted(weights, rng))
	if index < 0 or index >= defs.size():
		return ""
	return String((defs[index] as Dictionary).get("id", ""))


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
static func evolves_to(id: String) -> String:
	return String(find(id).get("evolves_to", ""))


static func evolve_realm(id: String) -> int:
	return int(find(id).get("evolve_realm", 0))


## The passive the body's first awakening grants, or "" for none.
static func passive_of(id: String) -> String:
	return String(find(id).get("passive", ""))


static func weakness_text(id: String) -> String:
	var weakness: Dictionary = find(id).get("weakness", {})
	return String(weakness.get("text", ""))


static func describe(id: String) -> String:
	var physique := find(id)
	if physique.is_empty():
		return "Mortal Frame (tier 1)"
	return "%s (tier %d) — %s" % [String(physique.get("name", "?")), int(physique.get("tier", 1)), String(physique.get("blurb", ""))]


static func stages(id: String) -> Array:
	return find(id).get("stages", [])


static func stage_count(id: String) -> int:
	return stages(id).size()


static func stage_name(id: String, stage: int) -> String:
	var list := stages(id)
	if stage < 0 or stage >= list.size():
		return ""
	return String((list[stage] as Dictionary).get("name", ""))


static func stage_scale(id: String, stage: int) -> float:
	var list := stages(id)
	if stage < 0 or stage >= list.size():
		return 1.0
	return float((list[stage] as Dictionary).get("scale", 1.0))


## Realm required to enter the stage after `stage`, or -1 when there is none.
static func next_stage_realm(id: String, stage: int) -> int:
	var list := stages(id)
	if stage + 1 >= list.size():
		return -1
	return int((list[stage + 1] as Dictionary).get("realm", 0))


## The body's full mod list at a stage: gifts and weakness together, every
## value scaled — the tradeoff deepens exactly as the gift does.
static func mods_for(id: String, stage: int, realm_number: int = 1) -> Array:
	var physique := find(id)
	if physique.is_empty():
		return []
	var scale := stage_scale(id, stage) * Realms.growth_factor(realm_number)
	var out: Array = []
	for mod_value in physique.get("mods", []):
		var mod: Dictionary = (mod_value as Dictionary).duplicate()
		mod["value"] = float(mod.get("value", 0.0)) * scale
		out.append(mod)
	var weakness: Dictionary = physique.get("weakness", {})
	for mod_value in weakness.get("mods", []):
		var mod: Dictionary = (mod_value as Dictionary).duplicate()
		mod["value"] = float(mod.get("value", 0.0)) * scale
		out.append(mod)
	return out


## Higher tier wins; ties keep the current body, so an inheritance can never be a
## downgrade dressed up as a reward.
static func best_of(current_id: String, candidate_id: String) -> String:
	if tier_of(candidate_id) > tier_of(current_id):
		return candidate_id
	return current_id


static func inherited_for(current_id: String, key: int) -> String:
	return best_of(current_id, roll(key))
