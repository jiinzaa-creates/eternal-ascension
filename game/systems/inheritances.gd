class_name Inheritances
extends RefCounted
## Inheritances are authored legacies, not a fixed altar script.
##
## Every family owns a small pool. An offer is weighted by rarity, filtered by
## what the claimant's body can actually accept, and then defended by a trial.
## The altar is the only caller; this class is pure and reads no scene state.

const RARITY_NAMES: Array[String] = ["Common", "Resonant", "Transcendent"]
const RARITY_COLORS: Array[String] = ["#b8b0c8", "#8fd8c0", "#e0c060"]
const MAX_TRIAL_SECONDS := 120.0


static func data() -> Dictionary:
	return DB.inheritances_data


static func entries() -> Array:
	var value: Variant = data().get("entries", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func find(id: String) -> Dictionary:
	for value in entries():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("id", "")) == id:
			return entry
	return {}


static func default_id() -> String:
	return String(data().get("default", ""))


static func for_family(family_id: String) -> Array:
	var out: Array = []
	for value in entries():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("family", "")) == family_id:
			out.append(entry)
	return out


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


static func rarity_color(rarity: int) -> String:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


## Compatibility is one pure predicate over the claimant's realm, body tier,
## root affinities and attributes. A refusal always names the first unmet term.
static func check(entry: Dictionary, state: Dictionary) -> Dictionary:
	var requirements_value: Variant = entry.get("requires", {})
	if typeof(requirements_value) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "the altar's terms are unreadable"}
	var requirements: Dictionary = requirements_value
	var realm := int(state.get("realm", 0))
	var min_realm := int(requirements.get("min_realm", 1))
	if realm < min_realm:
		return {"ok": false, "reason": "requires realm %d" % min_realm}
	var physique_tier := int(state.get("physique_tier", 1))
	var min_physique := int(requirements.get("min_physique_tier", 1))
	if physique_tier < min_physique:
		return {"ok": false, "reason": "requires a body of tier %d" % min_physique}
	var affinity_value: Variant = requirements.get("any_affinity", [])
	if typeof(affinity_value) == TYPE_ARRAY and not (affinity_value as Array).is_empty():
		var owned_value: Variant = state.get("affinities", [])
		var owned: Array = owned_value if typeof(owned_value) == TYPE_ARRAY else []
		var found := false
		for affinity in (affinity_value as Array):
			if owned.has(String(affinity)):
				found = true
				break
		if not found:
			var names: Array[String] = []
			for affinity in (affinity_value as Array):
				names.append(String(affinity).capitalize())
			return {"ok": false, "reason": "requires a %s affinity" % ", ".join(names)}
	var min_attrs_value: Variant = requirements.get("min_attrs", {})
	if typeof(min_attrs_value) == TYPE_DICTIONARY:
		var attrs_value: Variant = state.get("attrs", {})
		var attrs: Dictionary = attrs_value if typeof(attrs_value) == TYPE_DICTIONARY else {}
		for key in (min_attrs_value as Dictionary).keys():
			var needed := int((min_attrs_value as Dictionary)[key])
			if int(attrs.get(String(key), 0)) < needed:
				return {"ok": false, "reason": "requires %d %s" % [needed, String(key).to_upper()]}
	return {"ok": true, "reason": ""}


## One deterministic, rarity-weighted offer from the entries this body can accept.
## Incompatible entries are never silently mutated into a fit.
static func offer(family_id: String, seed_value: int, state: Dictionary) -> Dictionary:
	var pool: Array = []
	for value in for_family(family_id):
		var entry: Dictionary = value
		if bool(check(entry, state).get("ok", false)):
			pool.append(entry)
	if pool.is_empty():
		var reason := "no inheritance is compatible with this body"
		var family_entries := for_family(family_id)
		if not family_entries.is_empty():
			var candidate: Dictionary = family_entries[0]
			var refusal := check(candidate, state)
			if not bool(refusal.get("ok", false)):
				reason = String(refusal.get("reason", reason))
		return {"entry": {}, "reason": reason, "eligible": 0}
	var weights: Array = []
	for value in pool:
		weights.append(maxi(1, int((value as Dictionary).get("weight", 1))))
	var rng: RandomNumberGenerator = Rng.stream_from(seed_value, "inheritance_offer", hash(family_id), 0)
	var index: int = int(Rng.pick_weighted(weights, rng))
	if index < 0 or index >= pool.size():
		return {"entry": pool[0], "reason": "", "eligible": pool.size()}
	return {"entry": pool[index], "reason": "", "eligible": pool.size()}


## The trial is data too: how many echoes, how long the claimant has, and
## whether a rival seeker contests the altar.
static func trial_of(entry: Dictionary) -> Dictionary:
	var value: Variant = entry.get("trial", {})
	var trial: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return {
		"guards": clampi(int(trial.get("guards", 2)), 1, 6),
		"seconds": clampf(float(trial.get("seconds", 20.0)), 5.0, MAX_TRIAL_SECONDS),
		"rival": bool(trial.get("rival", false)),
	}


## A rarer legacy is guarded by a stronger echo. The family's own enemy tier is
## the floor, so a late family is never made trivial by a common inheritance.
static func trial_tier(entry: Dictionary, family_tier: int) -> int:
	return clampi(family_tier + int(entry.get("rarity", 0)), 1, 12)


static func trial_label(entry: Dictionary) -> String:
	var trial := trial_of(entry)
	var rival := " and a rival seeker" if bool(trial["rival"]) else ""
	return "%d echoes%s · %ds" % [int(trial["guards"]), rival, int(trial["seconds"])]


static func validate(content: Dictionary) -> Array:
	var problems: Array = []
	var list_value: Variant = content.get("entries", null)
	if typeof(list_value) != TYPE_ARRAY:
		problems.append("inheritances are missing")
		return problems
	var list: Array = list_value
	if list.is_empty():
		problems.append("expected at least one inheritance")
	var seen: Dictionary = {}
	var by_family: Dictionary = {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("an inheritance is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if not id.begins_with("inherit."):
			problems.append("inheritance without an inherit id")
			continue
		if seen.has(id):
			problems.append("duplicate inheritance " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("inheritance %s has no name" % id)
		if String(entry.get("blurb", "")).strip_edges() == "":
			problems.append("inheritance %s has no blurb" % id)
		var family_id := String(entry.get("family", ""))
		if HiddenRealms.family(family_id).is_empty():
			problems.append("inheritance %s names unknown family %s" % [id, family_id])
		else:
			by_family[family_id] = int(by_family.get(family_id, 0)) + 1
		if int(entry.get("rarity", -1)) < 0 or int(entry.get("rarity", -1)) >= RARITY_NAMES.size():
			problems.append("inheritance %s has an invalid rarity" % id)
		if int(entry.get("weight", 0)) < 1:
			problems.append("inheritance %s has no weight" % id)
		var requirements_value: Variant = entry.get("requires", {})
		if typeof(requirements_value) != TYPE_DICTIONARY:
			problems.append("inheritance %s has no requirements object" % id)
		else:
			var requirements: Dictionary = requirements_value
			if int(requirements.get("min_realm", 0)) < 1 or int(requirements.get("min_realm", 0)) > 12:
				problems.append("inheritance %s has an invalid realm gate" % id)
			if int(requirements.get("min_physique_tier", 0)) < 1 or int(requirements.get("min_physique_tier", 0)) > Physiques.MAX_TIER:
				problems.append("inheritance %s has an invalid body gate" % id)
			var affinity_value: Variant = requirements.get("any_affinity", [])
			if typeof(affinity_value) != TYPE_ARRAY:
				problems.append("inheritance %s has malformed affinities" % id)
			else:
				for affinity in (affinity_value as Array):
					if not DB.root_affinities.has(String(affinity)):
						problems.append("inheritance %s names unknown affinity %s" % [id, String(affinity)])
			var min_attrs_value: Variant = requirements.get("min_attrs", {})
			if typeof(min_attrs_value) != TYPE_DICTIONARY:
				problems.append("inheritance %s has malformed attribute gates" % id)
			else:
				for key in (min_attrs_value as Dictionary).keys():
					if not Attributes.KEYS.has(String(key)):
						problems.append("inheritance %s requires unknown attribute %s" % [id, String(key)])
					elif int((min_attrs_value as Dictionary)[key]) < 0:
						problems.append("inheritance %s requires a negative attribute" % id)
		var grants_value: Variant = entry.get("grants", {})
		if typeof(grants_value) != TYPE_DICTIONARY:
			problems.append("inheritance %s has no grants object" % id)
		else:
			var grants: Dictionary = grants_value
			var grants_anything := false
			var technique := String(grants.get("technique", ""))
			if technique != "":
				grants_anything = true
				if DB.technique(technique).is_empty():
					problems.append("inheritance %s grants unknown technique %s" % [id, technique])
			var passive := String(grants.get("passive", ""))
			if passive != "":
				grants_anything = true
				if DB.passive(passive).is_empty():
					problems.append("inheritance %s grants unknown passive %s" % [id, passive])
			var physique := String(grants.get("physique", ""))
			if physique != "":
				grants_anything = true
				if DB.physique(physique).is_empty():
					problems.append("inheritance %s grants unknown physique %s" % [id, physique])
			if not grants_anything:
				problems.append("inheritance %s grants nothing" % id)
		var relic := String(entry.get("relic", ""))
		if relic != "" and DB.by_id("unique", relic).is_empty():
			problems.append("inheritance %s grants unknown relic %s" % [id, relic])
		var trial_value: Variant = entry.get("trial", {})
		if typeof(trial_value) != TYPE_DICTIONARY:
			problems.append("inheritance %s has no trial object" % id)
		else:
			var trial: Dictionary = trial_value
			if int(trial.get("guards", 0)) < 1 or int(trial.get("guards", 0)) > 6:
				problems.append("inheritance %s has an invalid echo count" % id)
			if float(trial.get("seconds", 0.0)) < 5.0 or float(trial.get("seconds", 0.0)) > MAX_TRIAL_SECONDS:
				problems.append("inheritance %s has an invalid trial time" % id)
			if typeof(trial.get("rival", false)) != TYPE_BOOL:
				problems.append("inheritance %s has a malformed rival flag" % id)
	var default_value := String(content.get("default", ""))
	if default_value == "" or not seen.has(default_value):
		problems.append("the default inheritance is missing or unknown")
	elif String(find(default_value).get("family", "")) != "family.ancient_tomb":
		problems.append("the default inheritance must belong to the tomb")
	for family in HiddenRealms.families():
		if typeof(family) != TYPE_DICTIONARY:
			continue
		var family_id := String((family as Dictionary).get("id", ""))
		if int(by_family.get(family_id, 0)) < 1:
			problems.append("family %s has no inheritance" % family_id)
	return problems
