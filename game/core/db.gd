extends Node
## Content registry.
##
## All game content lives in res://data/*.json so it can be diffed, reviewed,
## modded and schema-checked. This node loads it once, indexes everything by
## stable string ID (saves reference IDs, never array indices), and reports
## validation problems instead of failing silently.

const DATA_DIR := "res://data/"

var realms: Array = []
var roots: Array = []
var methods: Array = []
var techniques: Array = []
var bases: Array = []
var prefixes: Array = []
var suffixes: Array = []
var passives: Array = []
var quests: Array = []
var npc_data: Dictionary = {}
var biomes: Array = []
var origins: Array = []

var _by_id: Dictionary = {}


func _ready() -> void:
	load_all()
	var problems := validate()
	for problem in problems:
		Log.error("db", problem)


func load_all() -> void:
	_by_id.clear()
	realms = _read("realms.json").get("realms", [])
	roots = _read("roots.json").get("roots", [])
	methods = _read("methods.json").get("methods", [])
	techniques = _read("techniques.json").get("techniques", [])
	var items := _read("items.json")
	bases = items.get("bases", [])
	prefixes = items.get("prefixes", [])
	suffixes = items.get("suffixes", [])
	passives = _read("passives.json").get("passives", [])
	quests = _read("quests.json").get("quests", [])
	npc_data = _read("npcs.json")
	biomes = _read("biomes.json").get("biomes", [])
	origins = _read("origins.json").get("origins", [])

	_index("realm", realms)
	_index("root", roots)
	_index("method", methods)
	_index("technique", techniques)
	_index("base", bases)
	_index("prefix", prefixes)
	_index("suffix", suffixes)
	_index("passive", passives)
	_index("quest", quests)
	_index("biome", biomes)
	_index("origin", origins)


func _read(file: String) -> Dictionary:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		Log.error("db", "missing data file: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		Log.error("db", "invalid JSON object: " + path)
		return {}
	return parsed


func _index(kind: String, entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := String(entry.get("id", ""))
		if id == "":
			continue
		_by_id[kind + ":" + id] = entry


func by_id(kind: String, id: String) -> Dictionary:
	var entry: Variant = _by_id.get(kind + ":" + id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return entry


func has(kind: String, id: String) -> bool:
	return _by_id.has(kind + ":" + id)


func realm(number: int) -> Dictionary:
	for r in realms:
		if int(r.get("n", 0)) == number:
			return r
	return {}


func get_root(tier: int) -> Dictionary:
	for r in roots:
		if int(r.get("tier", 0)) == tier:
			return r
	return {}


func technique(id: String) -> Dictionary:
	return by_id("technique", id)


func base_item(id: String) -> Dictionary:
	return by_id("base", id)


func passive(id: String) -> Dictionary:
	return by_id("passive", id)


func quest(id: String) -> Dictionary:
	return by_id("quest", id)


func biome(id: String) -> Dictionary:
	return by_id("biome", id)


func origin(id: String) -> Dictionary:
	return by_id("origin", id)


## Snapshot of every biome by id. Passed to worker threads, so it is detached
## from the registry and never mutated afterwards.
func biome_table() -> Dictionary:
	var out: Dictionary = {}
	for b in biomes:
		var id := String(b.get("id", ""))
		if id != "":
			out[id] = b.duplicate(true)
	return out


func schedules() -> Dictionary:
	return npc_data.get("schedules", {})


func archetypes() -> Array:
	return npc_data.get("archetypes", [])


func bases_for(slot: String) -> Array:
	var out: Array = []
	for b in bases:
		if String(b.get("slot", "")) == slot:
			out.append(b)
	return out


func affixes_for(slot: String, kind: String) -> Array:
	var pool: Array = prefixes if kind == "prefix" else suffixes
	var out: Array = []
	for a in pool:
		var slots: Array = a.get("slots", [])
		if slots.is_empty() or slots.has(slot):
			out.append(a)
	return out


## Returns a list of human-readable problems. An empty list means the content is sound.
func validate() -> Array:
	var problems: Array = []

	if realms.size() != 12:
		problems.append("expected 12 realms, found %d" % realms.size())
	for i in realms.size():
		var r: Dictionary = realms[i]
		var n := int(r.get("n", 0))
		if n != i + 1:
			problems.append("realm at index %d has n=%d (expected %d)" % [i, n, i + 1])
		if int(r.get("sublevels", 0)) != 10:
			problems.append("realm %d must declare 10 sublevels" % n)
		if String(r.get("id", "")) == "":
			problems.append("realm %d has no id" % n)
		if float(r.get("qi_mult", 0.0)) <= 0.0:
			problems.append("realm %d has non-positive qi_mult" % n)
		if float(r.get("attr_mult", 0.0)) <= 0.0:
			problems.append("realm %d has non-positive attr_mult" % n)

	if roots.size() != 12:
		problems.append("expected 12 spiritual roots, found %d" % roots.size())
	for i in roots.size():
		if int(roots[i].get("tier", 0)) != i + 1:
			problems.append("root at index %d has wrong tier" % i)

	if methods.is_empty():
		problems.append("no cultivation methods defined")
	if techniques.size() < 6:
		problems.append("expected at least 6 techniques, found %d" % techniques.size())
	for t in techniques:
		var frames: Dictionary = t.get("frames", {})
		for key in ["startup", "active", "recovery"]:
			if not frames.has(key):
				problems.append("technique %s missing frame '%s'" % [t.get("id", "?"), key])
		if String(t.get("id", "")) == "":
			problems.append("technique without id")

	if bases.is_empty():
		problems.append("no item bases defined")
	for b in bases:
		if String(b.get("slot", "")) == "":
			problems.append("item base %s has no slot" % b.get("id", "?"))
	if prefixes.is_empty() or suffixes.is_empty():
		problems.append("item affix pools are empty")

	if passives.is_empty():
		problems.append("no passives defined")
	for p in passives:
		if String(p.get("id", "")) == "":
			problems.append("passive without id")
		if not p.has("mods"):
			problems.append("passive %s has no mods" % p.get("id", "?"))

	if quests.is_empty():
		problems.append("no quests defined")
	for q in quests:
		var steps: Array = q.get("steps", [])
		if steps.is_empty():
			problems.append("quest %s has no steps" % q.get("id", "?"))
		for step in steps:
			if String(step.get("kind", "")) == "" or String(step.get("target", "")) == "":
				problems.append("quest %s has a step without kind/target" % q.get("id", "?"))

	if npc_data.is_empty() or npc_data.get("archetypes", []).is_empty():
		problems.append("npc archetype data is missing")

	if biomes.is_empty():
		problems.append("no biomes defined")
	for b in biomes:
		var id := String(b.get("id", ""))
		if id == "":
			problems.append("biome without id")
		if String(b.get("name", "")) == "":
			problems.append("biome %s has no name" % id)
		if (b.get("palette", []) as Array).is_empty():
			problems.append("biome %s has no palette" % id)
		var features: Dictionary = b.get("features", {})
		var feature_total := 0
		for kind in features.keys():
			feature_total += maxi(0, int(features[kind]))
		if feature_total <= 0:
			problems.append("biome %s has no prop weights" % id)
		if (b.get("resources", []) as Array).is_empty():
			problems.append("biome %s has no resources" % id)
		if (b.get("enemies", []) as Array).is_empty():
			problems.append("biome %s has no enemies" % id)
		for enemy in b.get("enemies", []):
			if String(enemy.get("name", "")) == "":
				problems.append("biome %s has an unnamed enemy" % id)

	if origins.size() < 3:
		problems.append("expected at least 3 character origins, found %d" % origins.size())
	var origin_ids: Dictionary = {}
	for o in origins:
		var id := String(o.get("id", ""))
		if id == "":
			problems.append("origin without id")
			continue
		if origin_ids.has(id):
			problems.append("duplicate origin id " + id)
		origin_ids[id] = true
		if String(o.get("name", "")) == "":
			problems.append("origin %s has no name" % id)
		if int(o.get("stones", 0)) < 0 or int(o.get("stones", 0)) > Origin.MAX_STONES:
			problems.append("origin %s gives %d stones (max %d)" % [id, int(o.get("stones", 0)), Origin.MAX_STONES])
		var method := String(o.get("method_id", ""))
		if method != "" and not has("method", method):
			problems.append("origin %s references unknown method %s" % [id, method])
		var passive := String(o.get("passive", ""))
		if passive != "" and not has("passive", passive):
			problems.append("origin %s references unknown passive %s" % [id, passive])

	# Duplicate IDs across the whole registry would corrupt save references.
	var seen: Dictionary = {}
	for kind in ["realm", "root", "method", "technique", "base", "prefix", "suffix", "passive", "quest"]:
		for key in _by_id.keys():
			if String(key).begins_with(kind + ":"):
				var id := String(key).split(":", false, 1)[1]
				var full: String = String(kind) + ":" + id
				if seen.has(full):
					problems.append("duplicate id " + full)
				seen[full] = true

	return problems


func counts() -> Dictionary:
	return {
		"realms": realms.size(),
		"roots": roots.size(),
		"methods": methods.size(),
		"techniques": techniques.size(),
		"bases": bases.size(),
		"prefixes": prefixes.size(),
		"suffixes": suffixes.size(),
		"passives": passives.size(),
		"quests": quests.size(),
		"archetypes": archetypes().size(),
		"biomes": biomes.size(),
		"origins": origins.size(),
	}
