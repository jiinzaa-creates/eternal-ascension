class_name Professions
extends RefCounted
## Practice made permanent.
##
## A profession is a rank earned by finishing work, not bought: one successful
## forge or brew is one point of practice, and the rank that follows lowers the
## chance of spoiling the next attempt and raises the smith's or alchemist's
## quality. Recipes name the rank they need, so a fresh apprentice sees the
## harder work and cannot yet take it.
##
## The run stores only practice points per profession (`Game.professions`); the
## rank is derived from them, exactly like age is derived from the calendar. An
## old save with no professions is simply an untrained one.

## Practice needed for each rank. Index is the rank; level 0 starts at nothing.
const THRESHOLDS: Array[int] = [0, 4, 10, 20, 34]
const RANKS: Array[String] = ["Apprentice", "Journeyman", "Adept", "Master", "Grandmaster"]
const MAX_LEVEL := 4


static func level_for(xp: int) -> int:
	var level := 0
	for i in range(1, THRESHOLDS.size()):
		if xp >= THRESHOLDS[i]:
			level = i
	return clampi(level, 0, MAX_LEVEL)


static func xp_for_level(level: int) -> int:
	return THRESHOLDS[clampi(level, 0, MAX_LEVEL)]


static func next_threshold(level: int) -> int:
	return THRESHOLDS[mini(MAX_LEVEL, clampi(level, 0, MAX_LEVEL) + 1)]


static func rank_name(level: int) -> String:
	return RANKS[clampi(level, 0, MAX_LEVEL)]


## One profession's stored practice, as `{xp, level}`.
static func entry(data: Dictionary, id: String) -> Dictionary:
	var raw: Variant = data.get(id, {})
	var xp := 0
	if typeof(raw) == TYPE_DICTIONARY:
		xp = maxi(0, int((raw as Dictionary).get("xp", 0)))
	return {"xp": xp, "level": level_for(xp)}


static func xp_of(data: Dictionary, id: String) -> int:
	return int(entry(data, id)["xp"])


static func level_of(data: Dictionary, id: String) -> int:
	return int(entry(data, id)["level"])


## Records practice and reports the resulting rank. Mutates `data` — the run's
## profession dictionary — and is the only way practice is earned.
static func award(data: Dictionary, id: String, amount: int = 1) -> Dictionary:
	var current := entry(data, id)
	if id == "" or amount <= 0:
		return {"xp": int(current["xp"]), "level": int(current["level"]), "leveled": false}
	var xp := int(current["xp"]) + amount
	data[id] = {"xp": xp}
	var level := level_for(xp)
	return {"xp": xp, "level": level, "leveled": level > int(current["level"])}


## Practice read back from a save. Unknown keys, malformed entries and negative
## values are dropped rather than trusted, so a hand-edited save cannot buy a
## rank the run did not earn.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = raw
	for key in source.keys():
		var id := String(key)
		if not id.begins_with("profession."):
			continue
		var value: Variant = source[key]
		var xp := 0
		if typeof(value) == TYPE_DICTIONARY:
			xp = maxi(0, int((value as Dictionary).get("xp", 0)))
		elif typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			xp = maxi(0, int(value))
		if xp > 0:
			out[id] = {"xp": xp}
	return out


## Extra quality above the INT baseline, per rank of this profession.
static func quality_bonus(profession: Dictionary, level: int) -> float:
	return maxf(0.0, float(profession.get("quality_bonus", 0.0)) * float(level))


## Multiplier applied to a recipe's failure chance. Even a grandmaster keeps a
## floor, so no work is ever entirely without risk.
static func failure_mult(profession: Dictionary, level: int) -> float:
	return clampf(1.0 - maxf(0.0, float(profession.get("failure_reduction", 0.0))) * float(level), 0.35, 1.0)


## Whether the run's ranks may take this recipe. A recipe without a profession
## gate is open to anyone.
static func gate(recipe: Dictionary, data: Dictionary, db: Node) -> Dictionary:
	var id := String(recipe.get("profession", ""))
	if id == "":
		return {"ok": true, "level": 0, "need": 0, "reason": ""}
	var need := int(recipe.get("level", 0))
	var level := level_of(data, id)
	if level >= need:
		return {"ok": true, "level": level, "need": need, "reason": ""}
	var name := id
	if db != null and db.has("profession", id):
		name = String(db.profession(id).get("name", id))
	return {"ok": false, "level": level, "need": need, "reason": "%s %d required" % [name, need]}


static func progress_text(data: Dictionary, id: String, db: Node) -> String:
	var profession: Dictionary = db.profession(id) if db != null else {}
	var name := String(profession.get("name", id))
	var xp := xp_of(data, id)
	var level := level_for(xp)
	if level >= MAX_LEVEL:
		return "%s — %s (%d xp)" % [name, rank_name(level), xp]
	return "%s — %s (%d/%d xp)" % [name, rank_name(level), xp, next_threshold(level)]
