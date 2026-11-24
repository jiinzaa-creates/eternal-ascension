class_name Sects
extends RefCounted
## The twelve sects of the province, as identities rather than simulations.
##
## A sect owns a philosophy, a seat and territory, an economy and a fault line,
## plus one signature method and one signature technique. At this stage they are
## content and a codex: hierarchy, economy and politics arrive in later
## milestones. The validator is what keeps the roster honest — twelve entries,
## no duplicated name or signature, optional links to playable arts that really
## exist, and exactly one sect the player can call their own gate.

const EXPECTED := 12
const TECHNIQUE_KINDS := ["melee", "projectile", "spell", "summon", "buff", "movement"]


# ------------------------------------------------------------------ data ----


static func sects() -> Array:
	return DB.sects()


static func count() -> int:
	return sects().size()


static func sect(id: String) -> Dictionary:
	return DB.sect(id)


## The house whose gate the player stands at. Exactly one is authored local;
## the rest are reached on the continent, not in this market.
static func local_sect() -> Dictionary:
	for value in sects():
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("local", false)):
			return value
	return {}


# --------------------------------------------------------------- reading ----


static func describe(id: String) -> String:
	var entry := sect(id)
	if entry.is_empty():
		return ""
	return "%s — %s" % [String(entry.get("name", id)), String(entry.get("philosophy", ""))]


## "Sword Heart Method · Heaven Splitting Slash"
static func signature_line(id: String) -> String:
	var entry := sect(id)
	if entry.is_empty():
		return ""
	return "%s · %s" % [_art_name(entry.get("method", {})), _art_name(entry.get("technique", {}))]


## "Cliffspire · Cliff spires above the eastern pass · Sword-forging and duels for hire"
static func seat_line(id: String) -> String:
	var entry := sect(id)
	if entry.is_empty():
		return ""
	return "%s · %s · %s" % [
		String(entry.get("seat", "")),
		String(entry.get("territory", "")),
		String(entry.get("economy", "")),
	]


## One row for the codex, with the method and technique flattened so the HUD
## never has to know the data shape.
static func row(id: String) -> Dictionary:
	var entry := sect(id)
	if entry.is_empty():
		return {}
	var method: Dictionary = entry.get("method", {})
	var technique: Dictionary = entry.get("technique", {})
	return {
		"id": id,
		"name": String(entry.get("name", id)),
		"seat": String(entry.get("seat", "")),
		"philosophy": String(entry.get("philosophy", "")),
		"territory": String(entry.get("territory", "")),
		"economy": String(entry.get("economy", "")),
		"fault_line": String(entry.get("fault_line", "")),
		"colour": String(entry.get("colour", "#9aa0a6")),
		"method": String(method.get("name", "")),
		"technique": String(technique.get("name", "")),
		"technique_kind": String(technique.get("kind", "")),
		"local": bool(entry.get("local", false)),
		"faction": String(entry.get("faction", "")),
	}


# ------------------------------------------------------------- validation ----


## Content checks for `data/sects.json`. Every problem is reported, not thrown,
## so one bad entry cannot hide the rest at boot.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no sect data defined")
		return problems
	var list_value: Variant = data.get("sects", null)
	if typeof(list_value) != TYPE_ARRAY:
		problems.append("sect roster is not an array")
		return problems
	var list: Array = list_value
	if list.size() != EXPECTED:
		problems.append("expected %d sects, found %d" % [EXPECTED, list.size()])

	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var seen_methods: Dictionary = {}
	var seen_techniques: Dictionary = {}
	var seen_method_ids: Dictionary = {}
	var seen_technique_ids: Dictionary = {}
	var local_count := 0

	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("sect is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("sect without id")
			continue
		if not id.begins_with("sect."):
			problems.append("sect %s does not use a sect.* id" % id)
		if seen_ids.has(id):
			problems.append("duplicate sect id " + id)
		seen_ids[id] = true

		var name := String(entry.get("name", ""))
		if name == "":
			problems.append("sect %s has no name" % id)
		elif seen_names.has(name):
			problems.append("duplicate sect name " + name)
		seen_names[name] = true

		for field in ["seat", "philosophy", "territory", "economy", "fault_line"]:
			if String(entry.get(field, "")).strip_edges() == "":
				problems.append("sect %s has no %s" % [id, field])

		var colour := String(entry.get("colour", ""))
		if not Color.html_is_valid(colour):
			problems.append("sect %s has an invalid colour" % id)

		# The two signatures are the sect's identity: both must be named, and no
		# two houses may answer with the same art.
		var method_value: Variant = entry.get("method", null)
		if typeof(method_value) != TYPE_DICTIONARY:
			problems.append("sect %s has no signature method" % id)
		else:
			var method: Dictionary = method_value
			var method_name := String(method.get("name", ""))
			if method_name == "":
				problems.append("sect %s signature method has no name" % id)
			elif seen_methods.has(method_name):
				problems.append("signature method %s belongs to two sects" % method_name)
			seen_methods[method_name] = true
			if String(method.get("path", "")).strip_edges() == "":
				problems.append("sect %s signature method has no path" % id)
			var method_id := String(method.get("id", ""))
			if method_id != "":
				if Methods.find(method_id).is_empty():
					problems.append("sect %s names unknown method %s" % [id, method_id])
				if seen_method_ids.has(method_id):
					problems.append("method %s is claimed by two sects" % method_id)
				seen_method_ids[method_id] = true

		var technique_value: Variant = entry.get("technique", null)
		if typeof(technique_value) != TYPE_DICTIONARY:
			problems.append("sect %s has no signature technique" % id)
		else:
			var technique: Dictionary = technique_value
			var technique_name := String(technique.get("name", ""))
			if technique_name == "":
				problems.append("sect %s signature technique has no name" % id)
			elif seen_techniques.has(technique_name):
				problems.append("signature technique %s belongs to two sects" % technique_name)
			seen_techniques[technique_name] = true
			if String(technique.get("path", "")).strip_edges() == "":
				problems.append("sect %s signature technique has no path" % id)
			var kind := String(technique.get("kind", ""))
			if not TECHNIQUE_KINDS.has(kind):
				problems.append("sect %s signature technique has unknown kind %s" % [id, kind])
			var technique_id := String(technique.get("id", ""))
			if technique_id != "":
				var known := DB.technique(technique_id)
				if known.is_empty():
					problems.append("sect %s names unknown technique %s" % [id, technique_id])
				elif String(known.get("kind", "")) != kind:
					problems.append("sect %s signature kind disagrees with %s" % [id, technique_id])
				if seen_technique_ids.has(technique_id):
					problems.append("technique %s is claimed by two sects" % technique_id)
				seen_technique_ids[technique_id] = true

		var local := bool(entry.get("local", false))
		var faction_id := String(entry.get("faction", ""))
		if local:
			local_count += 1
			if faction_id == "":
				problems.append("the local sect %s has no faction" % id)
			elif DB.faction(faction_id).is_empty():
				problems.append("the local sect %s names unknown faction %s" % [id, faction_id])
		elif faction_id != "" and DB.faction(faction_id).is_empty():
			problems.append("sect %s names unknown faction %s" % [id, faction_id])

	if local_count != 1:
		problems.append("expected exactly one local sect, found %d" % local_count)

	return problems


static func _art_name(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	return String((value as Dictionary).get("name", ""))
