class_name Affixes
extends RefCounted
## Affixes: the character an art or a method takes on as it is lived with.
##
## Directive s.12 asks for meaningful combinations; here they grow on the
## cultivator's own tools. A technique earns an affix slot at mastery tiers
## 3 and 5, filled by a seeded roll from the affixes its kind, school and
## tags allow — the roll is deterministic for a given seed and stored once
## made, so an art's character is stable across saves. A method draws one
## affix per life, gated by its mechanic family. All application is pure:
## `effective` returns the adjusted art the cast path actually uses, and
## `apply_method_profile` reshapes a breakthrough profile in place.

static func technique_affix(id: String) -> Dictionary:
	return DB.by_id("technique_affix", id)


static func method_affix(id: String) -> Dictionary:
	return DB.by_id("method_affix", id)


static func technique_name(id: String) -> String:
	return String(technique_affix(id).get("name", id))


static func method_name(id: String) -> String:
	return String(method_affix(id).get("name", id))


static func _gate_ok(gate: Dictionary, tech: Dictionary) -> bool:
	var kinds: Array = gate.get("kinds", [])
	if not kinds.is_empty() and not kinds.has(TechniqueCombat.kind_of(tech)):
		return false
	var schools: Array = gate.get("schools", [])
	if not schools.is_empty() and not schools.has(String(tech.get("school", ""))):
		return false
	var tags: Array = gate.get("tags", [])
	if not tags.is_empty():
		var tech_tags: Array = tech.get("tags", [])
		var hit := false
		for tag in tags:
			if tech_tags.has(tag):
				hit = true
				break
		if not hit:
			return false
	if bool(gate.get("requires_status", false)):
		var status: Variant = tech.get("status", {})
		if typeof(status) != TYPE_DICTIONARY or (status as Dictionary).is_empty():
			return false
	return true


## Every technique affix whose gate the art satisfies.
static func technique_pool(tech: Dictionary) -> Array:
	var out: Array = []
	for affix in DB.technique_affixes:
		if _gate_ok((affix as Dictionary).get("gate", {}), tech):
			out.append(affix)
	return out


## A deterministic pick from the eligible affixes the art does not already
## carry, or "" when the pool is exhausted.
static func roll_technique(tech: Dictionary, owned: Array, seed_value: int) -> String:
	var pool: Array = []
	for affix in technique_pool(tech):
		var id := String((affix as Dictionary).get("id", ""))
		if id != "" and not owned.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return String(pool[rng.randi_range(0, pool.size() - 1)])


## The art as actually cast: base damage, heal and ward strength, Qi cost,
## cooldown, status bite and primary scaling, adjusted by every affix the
## art carries. Returns the art itself when it carries none.
static func effective(tech: Dictionary, affix_ids: Array) -> Dictionary:
	if affix_ids.is_empty():
		return tech
	var out: Dictionary = tech.duplicate(true)
	var damage_pct := 0.0
	var heal_pct := 0.0
	var qi_pct := 0.0
	var cd_pct := 0.0
	var status_dur_pct := 0.0
	var status_mag_pct := 0.0
	var scaling_primary := 0.0
	for affix_id in affix_ids:
		var effects: Dictionary = technique_affix(String(affix_id)).get("effects", {})
		damage_pct += float(effects.get("damage_pct", 0.0))
		heal_pct += float(effects.get("heal_pct", 0.0))
		qi_pct += float(effects.get("qi_cost_pct", 0.0))
		cd_pct += float(effects.get("cooldown_pct", 0.0))
		status_dur_pct += float(effects.get("status_duration_pct", 0.0))
		status_mag_pct += float(effects.get("status_magnitude_pct", 0.0))
		scaling_primary += float(effects.get("scaling_primary", 0.0))
	if damage_pct != 0.0 and out.has("base_damage"):
		out["base_damage"] = float(out["base_damage"]) * (1.0 + damage_pct / 100.0)
	if heal_pct != 0.0:
		if out.has("heal"):
			var heal_spec: Dictionary = out["heal"]
			heal_spec["amount"] = float(heal_spec.get("amount", 0.0)) * (1.0 + heal_pct / 100.0)
		if out.has("ward"):
			var ward_spec: Dictionary = out["ward"]
			ward_spec["shield"] = float(ward_spec.get("shield", 0.0)) * (1.0 + heal_pct / 100.0)
	if qi_pct != 0.0 and out.has("qi_cost"):
		out["qi_cost"] = maxf(0.0, float(out["qi_cost"]) * (1.0 + qi_pct / 100.0))
	if cd_pct != 0.0 and out.has("cooldown"):
		out["cooldown"] = maxf(0.05, float(out["cooldown"]) * (1.0 + cd_pct / 100.0))
	if (status_dur_pct != 0.0 or status_mag_pct != 0.0) and out.has("status"):
		var status: Dictionary = out["status"]
		status["duration"] = float(status.get("duration", 0.0)) * (1.0 + status_dur_pct / 100.0)
		status["magnitude"] = float(status.get("magnitude", 0.0)) * (1.0 + status_mag_pct / 100.0)
	if scaling_primary != 0.0 and out.has("scaling"):
		var scaling: Dictionary = out["scaling"]
		if not scaling.is_empty():
			var keys := scaling.keys()
			keys.sort()
			var primary := String(keys[0])
			scaling[primary] = float(scaling[primary]) + scaling_primary
	return out


## Every method affix whose mechanic family the method belongs to.
static func method_pool(method: Dictionary) -> Array:
	var out: Array = []
	var mechanic := String(method.get("mechanic", ""))
	for affix in DB.method_affixes:
		var mechanics: Array = ((affix as Dictionary).get("gate", {}) as Dictionary).get("mechanics", [])
		if mechanics.is_empty() or mechanics.has(mechanic):
			out.append(affix)
	return out


static func roll_method(method: Dictionary, seed_value: int) -> String:
	var pool: Array = []
	for affix in method_pool(method):
		var id := String((affix as Dictionary).get("id", ""))
		if id != "":
			pool.append(id)
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return String(pool[rng.randi_range(0, pool.size() - 1)])


## The meditation multiplier a method affix contributes (1.0 when none).
static func method_meditation_factor(affix_id: String) -> float:
	if affix_id == "":
		return 1.0
	var effects: Dictionary = method_affix(affix_id).get("effects", {})
	return 1.0 + float(effects.get("meditation_pct", 0.0)) / 100.0


## A breakthrough profile reshaped by the method's affix: flat chance,
## scaled tribulation and harm, and the affix named in the note the HUD
## shows, so the player can see why Heaven's weight changed.
static func apply_method_profile(profile: Dictionary, affix_id: String) -> Dictionary:
	if affix_id == "":
		return profile
	var effects: Dictionary = method_affix(affix_id).get("effects", {})
	var out: Dictionary = profile.duplicate(true)
	out["chance"] = float(out.get("chance", 0.0)) + float(effects.get("breakthrough_chance", 0.0))
	out["tribulation"] = float(out.get("tribulation", 1.0)) * (1.0 + float(effects.get("tribulation_pct", 0.0)) / 100.0)
	out["harm"] = float(out.get("harm", 1.0)) * (1.0 + float(effects.get("harm_pct", 0.0)) / 100.0)
	var affix_name := method_name(affix_id)
	if affix_name != "":
		out["note"] = "%s · %s" % [String(out.get("note", "")), affix_name]
	return out
