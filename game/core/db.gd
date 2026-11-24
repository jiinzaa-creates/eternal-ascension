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
var meridians: Array = []
var tribulations: Array = []
var enlightenments: Array = []
var techniques: Array = []
var bases: Array = []
var prefixes: Array = []
var suffixes: Array = []
var passives: Array = []
var quests: Array = []
var npc_data: Dictionary = {}
var npc_goals: Array = []
var biomes: Array = []
var enemy_archetypes: Array = []
var spirit_beasts: Array = []
var bosses: Array = []
var uniques: Array = []
var loot_tables: Array = []
var origins: Array = []
var physiques: Array = []
var weapon_types: Array = []
var crafting_stations: Array = []
var recipes: Array = []
var crafting_actions: Array = []
var potions: Array = []
var alchemy_station: Dictionary = {}
var professions: Array = []
var bonds: Array = []
var bond_ties: Array = []
var bond_pairs: Array = []
## Captivity rules: keeping terms, loyalty, escape, labour, bounty and the
## legal bands. One file, read by `Captivity` only.
var captivity: Dictionary = {}
## The market's story content: daily beat rules and goal-gated templates.
var stories: Dictionary = {}

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
	meridians = _read("meridians.json").get("meridians", [])
	tribulations = _read("tribulations.json").get("tribulations", [])
	enlightenments = _read("enlightenments.json").get("enlightenments", [])
	techniques = _read("techniques.json").get("techniques", [])
	var items := _read("items.json")
	bases = items.get("bases", [])
	prefixes = items.get("prefixes", [])
	suffixes = items.get("suffixes", [])
	passives = _read("passives.json").get("passives", [])
	quests = _read("quests.json").get("quests", [])
	npc_data = _read("npcs.json")
	npc_goals = npc_data.get("goals", [])
	biomes = _read("biomes.json").get("biomes", [])
	enemy_archetypes = _read("enemy_archetypes.json").get("archetypes", [])
	spirit_beasts = _read("spirit_beasts.json").get("beasts", [])
	bosses = _read("bosses.json").get("bosses", [])
	uniques = _read("uniques.json").get("uniques", [])
	loot_tables = _read("loot_tables.json").get("tables", [])
	origins = _read("origins.json").get("origins", [])
	physiques = _read("physiques.json").get("physiques", [])
	weapon_types = _read("weapons.json").get("weapon_types", [])
	var crafting := _read("crafting.json")
	crafting_stations = crafting.get("stations", [])
	recipes = crafting.get("recipes", [])
	crafting_actions = crafting.get("actions", [])
	var alchemy := _read("alchemy.json")
	potions = alchemy.get("potions", [])
	var station_value: Variant = alchemy.get("station", {})
	alchemy_station = station_value if typeof(station_value) == TYPE_DICTIONARY else {}
	var profession_data := _read("professions.json")
	professions = profession_data.get("professions", [])
	var bond_data := _read("bonds.json")
	bonds = bond_data.get("bands", [])
	bond_ties = bond_data.get("ties", [])
	bond_pairs = bond_data.get("pairs", [])
	captivity = _read("captivity.json")
	stories = _read("stories.json")

	_index("realm", realms)
	_index("root", roots)
	_index("method", methods)
	_index("meridian", meridians)
	_index("tribulation", tribulations)
	_index("enlightenment", enlightenments)
	_index("technique", techniques)
	_index("base", bases)
	_index("prefix", prefixes)
	_index("suffix", suffixes)
	_index("passive", passives)
	_index("quest", quests)
	_index("biome", biomes)
	_index("enemy_archetype", enemy_archetypes)
	_index("spirit_beast", spirit_beasts)
	_index("boss", bosses)
	_index("unique", uniques)
	_index("loot", loot_tables)
	_index("origin", origins)
	_index("npc_goal", npc_goals)
	_index("physique", physiques)
	_index("weapon_type", weapon_types)
	_index("station", crafting_stations)
	_index("recipe", recipes)
	_index("action", crafting_actions)
	_index("potion", potions)
	_index("profession", professions)
	_index("bond", bonds)
	_index("bond_tie", bond_ties)
	_index("story", story_templates())


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


func loot_table(id: String) -> Dictionary:
	return by_id("loot", id)


func station(id: String) -> Dictionary:
	return by_id("station", id)


func recipe(id: String) -> Dictionary:
	return by_id("recipe", id)


func crafting_action(id: String) -> Dictionary:
	return by_id("action", id)


func potion(id: String) -> Dictionary:
	return by_id("potion", id)


func alchemy_brewery() -> Dictionary:
	return alchemy_station


func profession(id: String) -> Dictionary:
	return by_id("profession", id)


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


func meridian(id: String) -> Dictionary:
	return by_id("meridian", id)


func technique(id: String) -> Dictionary:
	return by_id("technique", id)


func tribulation(id: String) -> Dictionary:
	return by_id("tribulation", id)


func enlightenment(id: String) -> Dictionary:
	return by_id("enlightenment", id)


func base_item(id: String) -> Dictionary:
	return by_id("base", id)


func passive(id: String) -> Dictionary:
	return by_id("passive", id)


func quest(id: String) -> Dictionary:
	return by_id("quest", id)


func biome(id: String) -> Dictionary:
	return by_id("biome", id)


## Behaviour archetypes are not NPC archetypes: `archetypes()` reads the
## settlement's npcs.json, while this reads the enemy behaviour table.
func enemy_archetype(id: String) -> Dictionary:
	return by_id("enemy_archetype", id)


func spirit_beast(id: String) -> Dictionary:
	return by_id("spirit_beast", id)


func boss(id: String) -> Dictionary:
	return by_id("boss", id)


func origin(id: String) -> Dictionary:
	return by_id("origin", id)


func physique(id: String) -> Dictionary:
	return by_id("physique", id)


func weapon_type(id: String) -> Dictionary:
	return by_id("weapon_type", id)


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


func npc_goal(id: String) -> Dictionary:
	return by_id("npc_goal", id)


## Story rules, or an empty dictionary when the data failed to load; the
## validator is what reports that, so readers never have to guess.
func story_rules() -> Dictionary:
	var value: Variant = stories.get("rules", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func story_templates() -> Array:
	var value: Variant = stories.get("templates", [])
	return value if typeof(value) == TYPE_ARRAY else []


func story_template(id: String) -> Dictionary:
	return by_id("story", id)


func bond(id: String) -> Dictionary:
	return by_id("bond", id)


func bond_tie(id: String) -> Dictionary:
	if id == "":
		return {}
	return by_id("bond_tie", id)


## One directed authored pair, or {} when the two people are not formally
## bound. Direction matters: the file may name only one side of a relation.
func bond_pair(from_id: String, to_id: String) -> Dictionary:
	for value in bond_pairs:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pair_entry: Dictionary = value
		if String(pair_entry.get("from", "")) == from_id and String(pair_entry.get("to", "")) == to_id:
			return pair_entry
	return {}


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
	var realm_unlock_ids := {}
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
		if (r.get("unlocks", []) as Array).is_empty():
			problems.append("realm %d has no unlocks" % n)
		for entry in r.get("unlocks", []):
			var unlock_id := ""
			if typeof(entry) == TYPE_DICTIONARY:
				unlock_id = String((entry as Dictionary).get("id", ""))
			elif typeof(entry) == TYPE_STRING:
				unlock_id = String(entry)
			if unlock_id == "":
				problems.append("realm %d has an unlock without an id" % n)
			elif realm_unlock_ids.has(unlock_id):
				problems.append("realm unlock %s is declared twice" % unlock_id)
			realm_unlock_ids[unlock_id] = true
		var ability: Dictionary = r.get("ability", {})
		if ability.is_empty():
			problems.append("realm %d has no realm art" % n)
		else:
			if String(ability.get("id", "")) == "" or String(ability.get("name", "")) == "":
				problems.append("realm %d realm art has no id/name" % n)
			var ability_mods: Array = ability.get("mods", [])
			var ability_flags: Array = ability.get("flags", [])
			if ability_mods.is_empty() and ability_flags.is_empty():
				problems.append("realm %d realm art has no effect" % n)
			for mod in ability_mods:
				if typeof(mod) != TYPE_DICTIONARY:
					problems.append("realm %d realm art has a malformed mod" % n)
					continue
				var ability_stat := String((mod as Dictionary).get("stat", ""))
				if ability_stat == "":
					problems.append("realm %d realm art has a mod without a stat" % n)
				elif not (Attributes.KEYS.has(ability_stat) or StatBlock.PERCENT_STATS.has(ability_stat) or StatBlock.FLAT_STATS.has(ability_stat)):
					problems.append("realm %d realm art uses unknown stat %s" % [n, ability_stat])

	if tribulations.size() < 10:
		problems.append("expected at least 10 tribulation types, found %d" % tribulations.size())
	var tribulation_ids := {}
	for t in tribulations:
		var t_id := String(t.get("id", ""))
		if t_id == "":
			problems.append("tribulation without id")
			continue
		if tribulation_ids.has(t_id):
			problems.append("duplicate tribulation id " + t_id)
		tribulation_ids[t_id] = true
		if String(t.get("name", "")) == "":
			problems.append("tribulation %s has no name" % t_id)
		if int(t.get("waves", 0)) < 1 or int(t.get("bolts", 0)) < 1:
			problems.append("tribulation %s has no waves or bolts" % t_id)
		if float(t.get("interval", 0.0)) <= 0.0 or float(t.get("radius", 0.0)) <= 0.0:
			problems.append("tribulation %s has an invalid schedule" % t_id)
		if float(t.get("damage_mult", 0.0)) <= 0.0:
			problems.append("tribulation %s deals no damage" % t_id)
	for n in range(1, realms.size() + 1):
		var declared := String(realm(n).get("tribulation", ""))
		if not tribulation_ids.has(declared):
			problems.append("realm %d names unknown tribulation %s" % [n, declared])

	if enlightenments.size() < 10:
		problems.append("expected at least 10 enlightenments, found %d" % enlightenments.size())
	var enlightenment_ids := {}
	for e in enlightenments:
		var e_id := String(e.get("id", ""))
		if e_id == "":
			problems.append("enlightenment without id")
			continue
		if enlightenment_ids.has(e_id):
			problems.append("duplicate enlightenment id " + e_id)
		enlightenment_ids[e_id] = true
		if String(e.get("name", "")) == "" or String(e.get("desc", "")) == "":
			problems.append("enlightenment %s has no name or description" % e_id)
		if int(e.get("weight", 0)) < 1:
			problems.append("enlightenment %s has no weight" % e_id)
		var insight_mods: Array = e.get("mods", [])
		if insight_mods.is_empty():
			problems.append("enlightenment %s has no mods" % e_id)
		for mod in insight_mods:
			if typeof(mod) != TYPE_DICTIONARY:
				problems.append("enlightenment %s has a malformed mod" % e_id)
				continue
			var insight_stat := String((mod as Dictionary).get("stat", ""))
			if not (Attributes.KEYS.has(insight_stat) or StatBlock.PERCENT_STATS.has(insight_stat) or StatBlock.FLAT_STATS.has(insight_stat)):
				problems.append("enlightenment %s uses unknown stat %s" % [e_id, insight_stat])
		var req: Dictionary = e.get("requires", {})
		var req_realm := int(req.get("realm", 0))
		if req_realm < 0 or req_realm > 12:
			problems.append("enlightenment %s has an invalid realm" % e_id)
		var req_method := String(req.get("method", ""))
		if req_method != "" and not has("method", req_method):
			problems.append("enlightenment %s requires unknown method %s" % [e_id, req_method])

	if roots.size() != 12:
		problems.append("expected 12 spiritual roots, found %d" % roots.size())
	for i in roots.size():
		if int(roots[i].get("tier", 0)) != i + 1:
			problems.append("root at index %d has wrong tier" % i)

	if methods.is_empty():
		problems.append("no cultivation methods defined")
	if meridians.size() != 12:
		problems.append("expected 12 meridians, found %d" % meridians.size())
	var meridian_ids := {}
	for m in meridians:
		var meridian_id := String(m.get("id", "?"))
		if meridian_ids.has(meridian_id):
			problems.append("duplicate meridian id %s" % meridian_id)
		meridian_ids[meridian_id] = true
		if String(m.get("stat", "")) == "":
			problems.append("meridian %s has no stat" % meridian_id)
		if int(m.get("realm", 0)) < 1 or int(m.get("realm", 0)) > 12:
			problems.append("meridian %s has an invalid realm" % meridian_id)
	for m in methods:
		var method_id := String(m.get("id", "?"))
		if float(m.get("cult_mult", 0.0)) <= 0.0:
			problems.append("method %s has no cultivation multiplier" % method_id)
		if String(m.get("mechanic", "")) == "":
			problems.append("method %s has no mechanic" % method_id)
		var method_attrs: Dictionary = (m.get("requires", {}) as Dictionary).get("attrs", {})
		for key in method_attrs.keys():
			if not Attributes.KEYS.has(String(key)):
				problems.append("method %s requires unknown attribute %s" % [method_id, String(key)])
	if techniques.size() < 6:
		problems.append("expected at least 6 techniques, found %d" % techniques.size())
	for t in techniques:
		var frames: Dictionary = t.get("frames", {})
		for key in ["startup", "active", "recovery"]:
			if not frames.has(key):
				problems.append("technique %s missing frame '%s'" % [t.get("id", "?"), key])
		if String(t.get("id", "")) == "":
			problems.append("technique without id")
		_validate_technique_kind(t, problems)
		_validate_status_payload(t.get("status", {}), "technique %s" % String(t.get("id", "?")), problems)

	if weapon_types.size() < 4:
		problems.append("expected at least 4 weapon categories, found %d" % weapon_types.size())
	var weapon_type_ids: Dictionary = {}
	for w in weapon_types:
		var w_id := String(w.get("id", ""))
		if w_id == "":
			problems.append("weapon category without id")
			continue
		if weapon_type_ids.has(w_id):
			problems.append("duplicate weapon category id " + w_id)
		weapon_type_ids[w_id] = true
		if String(w.get("name", "")) == "":
			problems.append("weapon category %s has no name" % w_id)
		if float(w.get("reach_mult", 0.0)) <= 0.0 or float(w.get("speed_mult", 0.0)) <= 0.0:
			problems.append("weapon category %s has an invalid reach or speed" % w_id)
		var weapon_moves: Array = w.get("moves", [])
		if weapon_moves.is_empty():
			problems.append("weapon category %s has no moves" % w_id)
		for wm in weapon_moves:
			if typeof(wm) != TYPE_DICTIONARY:
				problems.append("weapon category %s has a malformed move" % w_id)
				continue
			var wm_name := String((wm as Dictionary).get("name", "?"))
			var wm_frames: Dictionary = (wm as Dictionary).get("frames", {})
			for frame_key in ["startup", "active", "recovery"]:
				if not wm_frames.has(frame_key) or int(wm_frames[frame_key]) <= 0:
					problems.append("weapon move %s in %s has an invalid '%s' frame" % [wm_name, w_id, frame_key])
			var wm_box: Dictionary = (wm as Dictionary).get("hitbox", {})
			if float(wm_box.get("radius", 0.0)) <= 0.0:
				problems.append("weapon move %s in %s has no reach" % [wm_name, w_id])
			if float(wm_box.get("angle", 0.0)) <= 0.0:
				problems.append("weapon move %s in %s has no arc" % [wm_name, w_id])
			if float((wm as Dictionary).get("damage_mult", 0.0)) <= 0.0:
				problems.append("weapon move %s in %s deals no damage" % [wm_name, w_id])

	if bases.is_empty():
		problems.append("no item bases defined")
	for b in bases:
		if String(b.get("slot", "")) == "":
			problems.append("item base %s has no slot" % b.get("id", "?"))
		if String(b.get("slot", "")) == "weapon" and not weapon_type_ids.has(String(b.get("weapon_type", ""))):
			problems.append("weapon base %s names unknown weapon category '%s'" % [b.get("id", "?"), String(b.get("weapon_type", ""))])
		# Requirements may only name a real attribute or the realm, and must ask
		# for a positive number; a requirement nobody can read is a locked door.
		var requires: Dictionary = b.get("requires", {})
		for key in requires.keys():
			var req_name := String(key)
			if req_name != "realm" and not Attributes.KEYS.has(req_name):
				problems.append("item base %s requires unknown attribute %s" % [b.get("id", "?"), req_name])
			if int(requires[key]) <= 0:
				problems.append("item base %s requires a non-positive %s" % [b.get("id", "?"), req_name])
		for field in ["tags", "conflicts"]:
			var tag_list: Array = b.get(field, [])
			for tag in tag_list:
				if String(tag) == "":
					problems.append("item base %s has an empty %s tag" % [b.get("id", "?"), field])
	# A conflict must name a tag some base actually carries, or the rule can never
	# fire and the data is lying about a restriction.
	var base_tags: Dictionary = {}
	for b in bases:
		for tag in b.get("tags", []):
			base_tags[String(tag)] = true
	for b in bases:
		for tag in b.get("conflicts", []):
			if not base_tags.has(String(tag)):
				problems.append("item base %s conflicts with unused tag %s" % [b.get("id", "?"), String(tag)])
	if prefixes.is_empty() or suffixes.is_empty():
		problems.append("item affix pools are empty")

	# Authored relics: an id a save can reference, a base whose slot agrees, one
	# real acquisition source, one known effect with an amount, and real mods.
	if uniques.is_empty():
		problems.append("no unique items defined")
	for u in uniques:
		var unique_id := String(u.get("id", ""))
		if not Items.is_stable_id(unique_id) or not unique_id.begins_with("item.unique."):
			problems.append("unique %s is not an item.unique.* id" % unique_id)
		if String(u.get("name", "")) == "" or String(u.get("lore", "")) == "":
			problems.append("unique %s has no name or lore" % unique_id)
		var unique_base := by_id("base", String(u.get("base", "")))
		if unique_base.is_empty():
			problems.append("unique %s names unknown base %s" % [unique_id, String(u.get("base", ""))])
		elif String(unique_base.get("slot", "")) != String(u.get("slot", "")):
			problems.append("unique %s slot disagrees with its base" % unique_id)
		var source := String(u.get("source", ""))
		var source_ok := source == Uniques.ALTAR_SOURCE \
			or (source.begins_with("boss.") and not by_id("boss", source).is_empty())
		if not source_ok:
			problems.append("unique %s has unknown source %s" % [unique_id, source])
		var effect: Dictionary = u.get("effect", {})
		if not Uniques.EFFECTS.has(String(effect.get("id", ""))):
			problems.append("unique %s has no known effect" % unique_id)
		elif float(effect.get("amount", 0.0)) <= 0.0:
			problems.append("unique %s effect has no amount" % unique_id)
		var unique_mods: Array = u.get("mods", [])
		if unique_mods.is_empty():
			problems.append("unique %s has no mods" % unique_id)
		for mod in unique_mods:
			if typeof(mod) != TYPE_DICTIONARY:
				problems.append("unique %s has a malformed mod" % unique_id)
				continue
			var mod_stat := String((mod as Dictionary).get("stat", ""))
			if not (Attributes.KEYS.has(mod_stat) or StatBlock.PERCENT_STATS.has(mod_stat) or StatBlock.FLAT_STATS.has(mod_stat)):
				problems.append("unique %s uses unknown stat %s" % [unique_id, mod_stat])
		if int(u.get("value", 0)) <= 0:
			problems.append("unique %s has no value" % unique_id)
	var affix_ids: Dictionary = {}
	for pool in [prefixes, suffixes]:
		for a in pool:
			_validate_affix(a, affix_ids, problems)
	# Every equipment slot must be able to roll both halves, or a treasure item
	# would come up short of the affix count its rarity promises.
	for slot in ["weapon", "armor", "ring", "talisman"]:
		for kind in ["prefix", "suffix"]:
			var usable := false
			for a in (prefixes if kind == "prefix" else suffixes):
				var slots: Array = a.get("slots", [])
				if int(a.get("weight", 10)) <= 0:
					continue
				if slots.is_empty() or slots.has(slot):
					usable = true
			if not usable:
				problems.append("no %s can roll on %s" % [kind, slot])

	if passives.is_empty():
		problems.append("no passives defined")
	for p in passives:
		if String(p.get("id", "")) == "":
			problems.append("passive without id")
		if not p.has("mods"):
			problems.append("passive %s has no mods" % p.get("id", "?"))
		var requirements: Dictionary = p.get("requires", {})
		var min_attr: Dictionary = requirements.get("min_attr", {})
		for key in min_attr.keys():
			if not Attributes.KEYS.has(String(key)):
				problems.append("passive %s requires unknown attribute %s" % [p.get("id", "?"), String(key)])
		for other in p.get("conflicts", []):
			if String(other) == String(p.get("id", "")):
				problems.append("passive %s conflicts with itself" % p.get("id", "?"))
		var synergy: Dictionary = p.get("synergy", {})
		if not synergy.is_empty() and String(synergy.get("with", "")) == "":
			problems.append("passive %s has a synergy without a partner" % p.get("id", "?"))

	if quests.is_empty():
		problems.append("no quests defined")
	for q in quests:
		var steps: Array = q.get("steps", [])
		if steps.is_empty():
			problems.append("quest %s has no steps" % q.get("id", "?"))
		for step in steps:
			if String(step.get("kind", "")) == "" or String(step.get("target", "")) == "":
				problems.append("quest %s has a step without kind/target" % q.get("id", "?"))

	_validate_npc_data(problems)
	# Relationship content: bands must tile the whole score range, ties must
	# name each other, and authored pairs must reference both.
	problems.append_array(Relationships.validate(bonds, bond_ties, bond_pairs))
	# Captivity content: policies must pay, the loyalty ladder must be ordered,
	# the legal bands must tile 0..cap and the binding rules must be usable.
	problems.append_array(Captivity.validate(captivity))
	# Story content: the daily beat rules, template weights, goal and venue
	# references, actor counts and request kinds must all be usable.
	problems.append_array(Stories.validate(stories))

	if enemy_archetypes.size() < 4:
		problems.append("expected at least 4 enemy archetypes, found %d" % enemy_archetypes.size())
	var enemy_archetype_ids := {}
	for a in enemy_archetypes:
		var a_id := String(a.get("id", ""))
		if a_id == "":
			problems.append("enemy archetype without id")
			continue
		if enemy_archetype_ids.has(a_id):
			problems.append("duplicate enemy archetype id " + a_id)
		enemy_archetype_ids[a_id] = true
		var behavior := EnemyAI.profile(a)
		if String(behavior.get("name", "")) == "":
			problems.append("enemy archetype %s has no name" % a_id)
		if float(behavior.get("aggro_range", 0.0)) <= 0.0:
			problems.append("enemy archetype %s has no aggro range" % a_id)
		if float(behavior.get("leash", 0.0)) < float(behavior.get("aggro_range", 0.0)):
			problems.append("enemy archetype %s has a leash shorter than its aggro range" % a_id)
		if float(behavior.get("reach", 0.0)) <= 0.0 or float(behavior.get("arc", 0.0)) <= 0.0:
			problems.append("enemy archetype %s has no strike geometry" % a_id)
		if float(behavior.get("windup", 0.0)) <= 0.0 or float(behavior.get("cooldown", 0.0)) <= 0.0:
			problems.append("enemy archetype %s has an invalid strike clock" % a_id)
		_validate_status_payload(a.get("status", {}), "enemy archetype %s" % a_id, problems)
		if not EnemyAI.DELIVERIES.has(String(a.get("delivery", "melee"))):
			problems.append("enemy archetype %s has unknown delivery '%s'" % [a_id, String(a.get("delivery", "melee"))])
		if EnemyAI.is_ranged(behavior):
			var bolt: Dictionary = behavior.get("projectile", {})
			if float(bolt.get("speed", 0.0)) <= 0.0 or float(bolt.get("range", 0.0)) <= 0.0:
				problems.append("ranged enemy archetype %s has no bolt speed or range" % a_id)
			if float(bolt.get("radius", 0.0)) <= 0.0:
				problems.append("ranged enemy archetype %s has no bolt radius" % a_id)
			if float(behavior.get("keep_range", 0.0)) <= 0.0:
				problems.append("ranged enemy archetype %s wants no distance from its target" % a_id)

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
			var enemy_archetype := String(enemy.get("archetype", ""))
			if enemy_archetype == "":
				problems.append("biome %s enemy %s has no archetype" % [id, String(enemy.get("name", "?"))])
			elif not enemy_archetype_ids.has(enemy_archetype):
				problems.append("biome %s enemy %s names unknown archetype %s" % [id, String(enemy.get("name", "?")), enemy_archetype])

	if physiques.size() < 6:
		problems.append("expected at least 6 physiques, found %d" % physiques.size())
	var physique_ids: Dictionary = {}
	for p in physiques:
		var id := String(p.get("id", ""))
		if id == "":
			problems.append("physique without id")
			continue
		if physique_ids.has(id):
			problems.append("duplicate physique id " + id)
		physique_ids[id] = true
		if String(p.get("name", "")) == "":
			problems.append("physique %s has no name" % id)
		if int(p.get("tier", 0)) < 1 or int(p.get("tier", 0)) > Physiques.MAX_TIER:
			problems.append("physique %s has an out-of-range tier" % id)
		for mod in p.get("mods", []):
			if String(mod.get("stat", "")) == "":
				problems.append("physique %s has a mod without a stat" % id)

	if spirit_beasts.size() < 4:
		problems.append("expected at least 4 spirit beast species, found %d" % spirit_beasts.size())
	var beast_ids: Dictionary = {}
	for entry in spirit_beasts:
		var species := Beasts.profile(entry)
		var species_id := String(species.get("id", ""))
		if species_id == "" or species_id == "beast.unknown":
			problems.append("spirit beast without id")
			continue
		if beast_ids.has(species_id):
			problems.append("duplicate spirit beast id " + species_id)
		beast_ids[species_id] = true
		if String(species.get("name", "")) == "":
			problems.append("spirit beast %s has no name" % species_id)
		if not enemy_archetype_ids.has(String(species.get("archetype", ""))):
			problems.append("spirit beast %s names unknown archetype %s" % [species_id, String(species.get("archetype", ""))])
		var habitats: Dictionary = species.get("biomes", {})
		if habitats.is_empty():
			problems.append("spirit beast %s lives in no biome" % species_id)
		for biome_id in habitats.keys():
			if not has("biome", String(biome_id)):
				problems.append("spirit beast %s names unknown biome %s" % [species_id, String(biome_id)])
		_validate_status_payload(species.get("status", {}), "spirit beast %s" % species_id, problems)
		if String((species.get("core", {}) as Dictionary).get("name", "")) == "":
			problems.append("spirit beast %s leaves no core" % species_id)

	if bosses.is_empty():
		problems.append("expected at least one boss")
	var boss_ids: Dictionary = {}
	for entry in bosses:
		var boss := Boss.profile(entry)
		var boss_id := String(boss.get("id", ""))
		if boss_id == "" or boss_id == "boss.unknown":
			problems.append("boss without id")
			continue
		if boss_ids.has(boss_id):
			problems.append("duplicate boss id " + boss_id)
		boss_ids[boss_id] = true
		if String(boss.get("name", "")) == "":
			problems.append("boss %s has no name" % boss_id)
		if not enemy_archetype_ids.has(String(boss.get("archetype", ""))):
			problems.append("boss %s names unknown archetype %s" % [boss_id, String(boss.get("archetype", ""))])
		var thresholds: Array = boss.get("thresholds", [])
		var phases: Array = boss.get("phases", [])
		if thresholds.is_empty():
			problems.append("boss %s has no health phases" % boss_id)
		if (entry.get("phases", []) as Array).size() < phases.size():
			problems.append("boss %s declares %d phases for %d thresholds" % [boss_id, (entry.get("phases", []) as Array).size(), thresholds.size()])
		for i in phases.size():
			var phase_data: Dictionary = phases[i]
			if String(phase_data.get("name", "")) == "":
				problems.append("boss %s phase %d has no name" % [boss_id, i])
			_validate_status_payload(phase_data.get("status", {}), "boss %s phase %d" % [boss_id, i], problems)
			for add_id in phase_data.get("adds", []):
				if not beast_ids.has(String(add_id)):
					problems.append("boss %s phase %d summons unknown beast %s" % [boss_id, i, String(add_id)])
		if int((boss.get("reward", {}) as Dictionary).get("stones", 0)) < 0:
			problems.append("boss %s pays negative stones" % boss_id)

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

	# Loot tables are the whole drop economy: a bad weight would skew every kill.
	_validate_loot(problems)
	_validate_professions(problems)
	_validate_crafting(problems)
	_validate_alchemy(problems)

	# Duplicate IDs across the whole registry would corrupt save references.
	var seen: Dictionary = {}
	for kind in ["realm", "root", "method", "technique", "base", "prefix", "suffix", "passive", "quest", "weapon_type"]:
		for key in _by_id.keys():
			if String(key).begins_with(kind + ":"):
				var id := String(key).split(":", false, 1)[1]
				var full: String = String(kind) + ":" + id
				if seen.has(full):
					problems.append("duplicate id " + full)
				seen[full] = true

	return problems


## A potion that names a missing base, an unknown effect or a negative cost would
## only fail when a player had already spent herbs on it.
## A profession is only meaningful if it lives at a real station, and a recipe
## gate is only honest if the profession it names exists.
func _validate_professions(problems: Array) -> void:
	if professions.is_empty():
		problems.append("no professions are authored")
	var station_ids: Dictionary = {}
	for entry in crafting_stations:
		if typeof(entry) == TYPE_DICTIONARY:
			station_ids[String((entry as Dictionary).get("id", ""))] = true
	if not alchemy_station.is_empty():
		station_ids[String(alchemy_station.get("id", ""))] = true
	var seen: Dictionary = {}
	for entry in professions:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("profession is not an object")
			continue
		var profession: Dictionary = entry
		var id := String(profession.get("id", ""))
		if id == "":
			problems.append("profession without id")
			continue
		if seen.has(id):
			problems.append("duplicate profession " + id)
		seen[id] = true
		if String(profession.get("name", "")) == "":
			problems.append("profession %s has no name" % id)
		var station := String(profession.get("station", ""))
		if not station_ids.has(station):
			problems.append("profession %s names unknown station %s" % [id, station])
		if float(profession.get("quality_bonus", 0.0)) < 0.0:
			problems.append("profession %s has a negative quality bonus" % id)
		var reduction := float(profession.get("failure_reduction", 0.0))
		if reduction < 0.0 or reduction > 1.0:
			problems.append("profession %s has an invalid failure reduction" % id)


## Every gate must name a real profession and a reachable rank.
func _validate_recipe_gate(data: Dictionary, label: String, problems: Array) -> void:
	var id := String(data.get("profession", ""))
	if id == "":
		problems.append("%s has no profession" % label)
		return
	if not has("profession", id):
		problems.append("%s names unknown profession %s" % [label, id])
	var level := int(data.get("level", 0))
	if level < 0 or level > Professions.MAX_LEVEL:
		problems.append("%s has an out-of-range profession level" % label)


func _validate_alchemy(problems: Array) -> void:
	if alchemy_station.is_empty():
		problems.append("alchemy has no station")
	else:
		if String(alchemy_station.get("id", "")) == "" or String(alchemy_station.get("name", "")) == "":
			problems.append("alchemy station needs an id and a name")
		var location := String(alchemy_station.get("location", ""))
		if not Settlement.LOCATIONS.has(location):
			problems.append("alchemy station names unknown location %s" % location)
	if potions.is_empty():
		problems.append("no potions are authored")
	var seen: Dictionary = {}
	var bases_seen: Dictionary = {}
	for entry in potions:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("potion is not an object")
			continue
		var potion: Dictionary = entry
		var potion_id := String(potion.get("id", ""))
		if potion_id == "":
			problems.append("potion without id")
			continue
		if seen.has(potion_id):
			problems.append("duplicate potion " + potion_id)
		seen[potion_id] = true
		if String(potion.get("name", "")) == "":
			problems.append("potion %s has no name" % potion_id)
		var base_id := String(potion.get("base", ""))
		if base_id == "":
			problems.append("potion %s has no base" % potion_id)
		elif not has("base", base_id):
			problems.append("potion %s names unknown base %s" % [potion_id, base_id])
		elif String(by_id("base", base_id).get("slot", "")) != "consumable":
			problems.append("potion %s does not brew a consumable" % potion_id)
		if bases_seen.has(base_id):
			problems.append("two potions share the base %s" % base_id)
		bases_seen[base_id] = true
		var effect: Variant = potion.get("effect", {})
		if typeof(effect) != TYPE_DICTIONARY:
			problems.append("potion %s has no effect" % potion_id)
		else:
			if not Alchemy.is_effect(String((effect as Dictionary).get("id", ""))):
				problems.append("potion %s has an unknown effect" % potion_id)
			if float((effect as Dictionary).get("amount", 0.0)) <= 0.0:
				problems.append("potion %s has a non-positive effect" % potion_id)
		_validate_craft_cost(potion, "potion " + potion_id, problems, true)
		_validate_recipe_gate(potion, "potion " + potion_id, problems)


func _base_exists_for_slot(slot: String) -> bool:
	for entry in bases:
		if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("slot", "")) == slot:
			return true
	return false


## A recipe that names a missing base, station or material would only fail when a
## player paid for it, so all of it is checked at load.
func _validate_crafting(problems: Array) -> void:
	var station_ids: Dictionary = {}
	for entry in crafting_stations:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("crafting station is not an object")
			continue
		var station_id := String((entry as Dictionary).get("id", ""))
		if station_id == "":
			problems.append("crafting station without id")
			continue
		if station_ids.has(station_id):
			problems.append("duplicate crafting station " + station_id)
		station_ids[station_id] = true
		if String((entry as Dictionary).get("name", "")) == "":
			problems.append("crafting station %s has no name" % station_id)

	var recipe_ids: Dictionary = {}
	var per_station: Dictionary = {}
	for entry in recipes:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("recipe is not an object")
			continue
		var recipe: Dictionary = entry
		var recipe_id := String(recipe.get("id", ""))
		if recipe_id == "":
			problems.append("recipe without id")
			continue
		if recipe_ids.has(recipe_id):
			problems.append("duplicate recipe " + recipe_id)
		recipe_ids[recipe_id] = true
		if String(recipe.get("name", "")) == "":
			problems.append("recipe %s has no name" % recipe_id)
		var station_id := String(recipe.get("station", ""))
		if not station_ids.has(station_id):
			problems.append("recipe %s names unknown station %s" % [recipe_id, station_id])
		else:
			per_station[station_id] = int(per_station.get(station_id, 0)) + 1
		var output: Variant = recipe.get("output", {})
		if typeof(output) != TYPE_DICTIONARY or String((output as Dictionary).get("base", "")) == "":
			problems.append("recipe %s has no output base" % recipe_id)
		else:
			var base_id := String((output as Dictionary).get("base", ""))
			if not has("base", base_id):
				problems.append("recipe %s names unknown base %s" % [recipe_id, base_id])
			elif not Items.is_equipment(String(by_id("base", base_id).get("slot", ""))):
				problems.append("recipe %s makes equipment from a non-equipment base" % recipe_id)
			var rarity := int((output as Dictionary).get("rarity", 1))
			if rarity < 0 or rarity >= ItemGen.RARITY_NAMES.size():
				problems.append("recipe %s has an out-of-range rarity" % recipe_id)
		_validate_craft_cost(recipe, "recipe " + recipe_id, problems, true)
		_validate_recipe_gate(recipe, "recipe " + recipe_id, problems)
	for station_id in station_ids.keys():
		if int(per_station.get(station_id, 0)) == 0:
			problems.append("crafting station %s has no recipes" % station_id)

	var action_ids: Dictionary = {}
	for entry in crafting_actions:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("crafting action is not an object")
			continue
		var action: Dictionary = entry
		var action_id := String(action.get("id", ""))
		if action_id == "":
			problems.append("crafting action without id")
			continue
		if action_ids.has(action_id):
			problems.append("duplicate crafting action " + action_id)
		action_ids[action_id] = true
		_validate_craft_cost(action, "action " + action_id, problems, false)
	for required in ["refine", "disassemble"]:
		if not action_ids.has(required):
			problems.append("missing crafting action " + required)


func _validate_craft_cost(data: Dictionary, label: String, problems: Array, needs_realm: bool) -> void:
	if int(data.get("stones", 0)) < 0:
		problems.append("%s has a negative stone cost" % label)
	if needs_realm and int(data.get("realm", 1)) < 1:
		problems.append("%s needs a realm of at least one" % label)
	var chance := float(data.get("failure_chance", 0.0))
	if chance < 0.0 or chance > 1.0:
		problems.append("%s has an invalid failure chance" % label)
	var materials: Variant = data.get("materials", [])
	if typeof(materials) != TYPE_ARRAY:
		problems.append("%s has malformed materials" % label)
		return
	for entry in (materials as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("%s has a malformed material" % label)
			continue
		var key := String((entry as Dictionary).get("material", ""))
		if not Crafting.is_material_key(key):
			problems.append("%s names unknown material %s" % [label, key])
		if int((entry as Dictionary).get("count", 0)) < 1:
			problems.append("%s needs a positive amount of %s" % [label, key])


## Loot tables are the whole drop economy: a bad weight would skew every kill,
## and a missing source would silently fall back to the wild table.
func _validate_loot(problems: Array) -> void:
	for source in Loot.REQUIRED_SOURCES:
		if not has("loot", String(source)):
			problems.append("missing loot table " + String(source))
	var seen: Dictionary = {}
	var rarity_count := ItemGen.RARITY_NAMES.size()
	for entry in loot_tables:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("loot table is not an object")
			continue
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("loot table without id")
			continue
		if seen.has(id):
			problems.append("duplicate loot table " + id)
		seen[id] = true
		var weights: Variant = entry.get("rarity_weights", [])
		if typeof(weights) != TYPE_ARRAY or (weights as Array).size() != rarity_count:
			problems.append("loot table %s needs %d rarity weights" % [id, rarity_count])
		else:
			var rarity_total := 0
			for value in (weights as Array):
				var weight := int(value)
				if weight < 0:
					problems.append("loot table %s has a negative rarity weight" % id)
				rarity_total += maxi(0, weight)
			if rarity_total <= 0:
				problems.append("loot table %s has no positive rarity weight" % id)
		var minimum := int(entry.get("min_rarity", 0))
		if minimum < 0 or minimum >= rarity_count:
			problems.append("loot table %s has an out-of-range min_rarity" % id)
		var empty_chance := float(entry.get("empty_chance", 0.0))
		if empty_chance < 0.0 or empty_chance > 1.0:
			problems.append("loot table %s has an invalid empty chance" % id)
		if int(entry.get("ilvl_bonus", 0)) < 0:
			problems.append("loot table %s has a negative ilvl bonus" % id)
		var rolls: Variant = entry.get("rolls", [])
		if typeof(rolls) != TYPE_ARRAY or (rolls as Array).size() != 2:
			problems.append("loot table %s needs a two-number roll count" % id)
		else:
			var low := int((rolls as Array)[0])
			var high := int((rolls as Array)[1])
			if low < 1 or high < low or high > Loot.MAX_ROLLS:
				problems.append("loot table %s has an invalid roll count" % id)
		var slots: Variant = entry.get("slot_weights", {})
		if typeof(slots) != TYPE_DICTIONARY:
			problems.append("loot table %s has malformed slot weights" % id)
		else:
			var slot_total := 0
			for slot in (slots as Dictionary).keys():
				var slot_name := String(slot)
				if not Items.is_known_slot(slot_name):
					problems.append("loot table %s names unknown slot %s" % [id, slot_name])
				elif not _base_exists_for_slot(slot_name):
					# A weight on a slot with no base would silently roll nothing.
					problems.append("loot table %s names slot %s with no item base" % [id, slot_name])
				var slot_weight := int((slots as Dictionary)[slot])
				if slot_weight < 0:
					problems.append("loot table %s has a negative slot weight" % id)
				slot_total += maxi(0, slot_weight)
			if slot_total <= 0:
				problems.append("loot table %s has no positive slot weight" % id)
		var stones: Variant = entry.get("stones", [0, 0])
		if typeof(stones) != TYPE_ARRAY or (stones as Array).size() != 2:
			problems.append("loot table %s needs a two-number stone range" % id)
		else:
			var stone_low := int((stones as Array)[0])
			var stone_high := int((stones as Array)[1])
			if stone_low < 0 or stone_high < stone_low:
				problems.append("loot table %s has an invalid stone range" % id)


## A technique's delivery declares its own payload. `melee` is the default, so
## old data validates without change; every other kind must carry the dictionary
## its entities read, or it would silently perform as an empty melee blow.
func _validate_technique_kind(technique: Dictionary, problems: Array) -> void:
	var technique_id := String(technique.get("id", "?"))
	var kind := String(technique.get("kind", TechniqueCombat.DEFAULT_KIND))
	if not TechniqueCombat.is_valid_kind(kind):
		problems.append("technique %s has unknown kind '%s'" % [technique_id, kind])
		return
	if kind == "melee":
		var box: Dictionary = technique.get("hitbox", {})
		if float(box.get("radius", 0.0)) <= 0.0 or float(box.get("angle", 0.0)) <= 0.0:
			problems.append("melee technique %s has no hitbox" % technique_id)
		return
	var payload: Variant = technique.get(kind, {})
	if typeof(payload) != TYPE_DICTIONARY:
		problems.append("technique %s is %s but has no '%s' payload" % [technique_id, kind, kind])
		return
	var data: Dictionary = payload
	match kind:
		"projectile":
			if float(data.get("speed", 0.0)) <= 0.0 or float(data.get("range", 0.0)) <= 0.0:
				problems.append("projectile technique %s has no speed or range" % technique_id)
			if float(data.get("radius", 0.0)) <= 0.0:
				problems.append("projectile technique %s has no radius" % technique_id)
			if int(data.get("pierce", 0)) < 0:
				problems.append("projectile technique %s has negative pierce" % technique_id)
		"spell":
			if float(data.get("radius", 0.0)) <= 0.0 or float(data.get("range", 0.0)) < 0.0:
				problems.append("spell technique %s has no radius or range" % technique_id)
			if float(data.get("delay", 0.0)) < 0.0:
				problems.append("spell technique %s has a negative delay" % technique_id)
		"summon":
			if int(data.get("count", 0)) < 1 or float(data.get("duration", 0.0)) <= 0.0:
				problems.append("summon technique %s has no count or duration" % technique_id)
			if float(data.get("interval", 0.0)) <= 0.0 or float(data.get("damage_mult", 0.0)) <= 0.0:
				problems.append("summon technique %s has an invalid interval or share" % technique_id)
		"buff":
			var buff_mods: Array = data.get("mods", [])
			if float(data.get("duration", 0.0)) <= 0.0 or buff_mods.is_empty():
				problems.append("buff technique %s has no duration or mods" % technique_id)
			for mod in buff_mods:
				if typeof(mod) != TYPE_DICTIONARY:
					problems.append("buff technique %s has a malformed mod" % technique_id)
					continue
				var stat := String((mod as Dictionary).get("stat", ""))
				if not (Attributes.KEYS.has(stat) or StatBlock.PERCENT_STATS.has(stat) or StatBlock.FLAT_STATS.has(stat)):
					problems.append("buff technique %s uses unknown stat %s" % [technique_id, stat])
		"movement":
			if float(data.get("distance", 0.0)) <= 0.0:
				problems.append("movement technique %s does not move" % technique_id)


## A status payload is optional. When present it must name a real status with a
## positive clock and magnitude, or a technique would promise an effect the
## fight never applies.
func _validate_status_payload(payload: Variant, label: String, problems: Array) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		problems.append("%s has a malformed status" % label)
		return
	var data: Dictionary = payload
	if data.is_empty():
		return
	var id := String(data.get("id", ""))
	if not Status.is_valid(id):
		problems.append("%s names unknown status '%s'" % [label, id])
		return
	if float(data.get("duration", 0.0)) <= 0.0:
		problems.append("%s status %s has no duration" % [label, id])
	if float(data.get("magnitude", 0.0)) <= 0.0:
		problems.append("%s status %s has no magnitude" % [label, id])
	var stacks := int(data.get("stacks", 1))
	if stacks < 1 or stacks > Status.MAX_STACKS:
		problems.append("%s status %s has an out-of-range stack count" % [label, id])


## An affix must be selectable (a weight), limited to real slots, and either
## carry a usable flat range or an ordered, non-weakening ladder of tiers whose
## first tier matches the flat range the older code still reads.
func _validate_affix(affix: Dictionary, seen: Dictionary, problems: Array) -> void:
	var affix_id := String(affix.get("id", ""))
	if affix_id == "":
		problems.append("affix without id")
		return
	if seen.has(affix_id):
		problems.append("duplicate affix id " + affix_id)
	seen[affix_id] = true
	var kind := String(affix.get("kind", ""))
	if kind != "prefix" and kind != "suffix":
		problems.append("affix %s has invalid kind '%s'" % [affix_id, kind])
	if String(affix.get("name", "")) == "":
		problems.append("affix %s has no name" % affix_id)
	var stat := String(affix.get("stat", ""))
	if not (Attributes.KEYS.has(stat) or StatBlock.PERCENT_STATS.has(stat) or StatBlock.FLAT_STATS.has(stat)):
		problems.append("affix %s uses unknown stat %s" % [affix_id, stat])
	if int(affix.get("weight", 10)) < 0:
		problems.append("affix %s has a negative weight" % affix_id)
	var slot_weights: Dictionary = affix.get("slot_weights", {})
	for slot_key in slot_weights.keys():
		if not ["weapon", "armor", "ring", "talisman"].has(String(slot_key)):
			problems.append("affix %s weights an unknown slot %s" % [affix_id, String(slot_key)])
		if int(slot_weights[slot_key]) < 0:
			problems.append("affix %s has a negative slot weight" % affix_id)
	var tiers: Array = affix.get("tiers", [])
	if tiers.is_empty():
		if float(affix.get("max", 0.0)) < float(affix.get("min", 0.0)) or float(affix.get("max", 0.0)) <= 0.0:
			problems.append("affix %s has no usable range" % affix_id)
		return
	var last_ilvl := 0
	var last_max := -1.0
	for i in tiers.size():
		if typeof(tiers[i]) != TYPE_DICTIONARY:
			problems.append("affix %s has a malformed tier" % affix_id)
			continue
		var tier: Dictionary = tiers[i]
		var tier_ilvl := int(tier.get("ilvl", 0))
		var lo := float(tier.get("min", 0.0))
		var hi := float(tier.get("max", 0.0))
		if tier_ilvl < 1:
			problems.append("affix %s tier %d has no level" % [affix_id, i + 1])
		if tier_ilvl < last_ilvl:
			problems.append("affix %s tiers are out of order" % affix_id)
		if lo <= 0.0 or hi < lo:
			problems.append("affix %s tier %d has an invalid range" % [affix_id, i + 1])
		if i > 0 and hi < last_max:
			problems.append("affix %s tier %d is weaker than the tier below it" % [affix_id, i + 1])
		last_ilvl = tier_ilvl
		last_max = maxf(last_max, hi)
	var first: Dictionary = tiers[0]
	if not is_equal_approx(float(affix.get("min", 0.0)), float(first.get("min", -1.0))) \
			or not is_equal_approx(float(affix.get("max", 0.0)), float(first.get("max", -1.0))):
		problems.append("affix %s flat range disagrees with its first tier" % affix_id)
	if int(first.get("ilvl", 1)) > int(affix.get("ilvl", 1)):
		problems.append("affix %s unlocks below its first tier" % affix_id)


func counts() -> Dictionary:
	return {
		"realms": realms.size(),
		"npc_goals": npc_goals.size(),
		"roots": roots.size(),
		"methods": methods.size(),
		"meridians": meridians.size(),
		"tribulations": tribulations.size(),
		"enlightenments": enlightenments.size(),
		"techniques": techniques.size(),
		"bases": bases.size(),
		"prefixes": prefixes.size(),
		"suffixes": suffixes.size(),
		"passives": passives.size(),
		"quests": quests.size(),
		"archetypes": archetypes().size(),
		"biomes": biomes.size(),
		"enemy_archetypes": enemy_archetypes.size(),
		"spirit_beasts": spirit_beasts.size(),
		"bosses": bosses.size(),
		"origins": origins.size(),
		"physiques": physiques.size(),
		"weapon_types": weapon_types.size(),
	}


## The NPC record is content too: an archetype naming a root band, a body, an
## art or a piece of gear that does not exist would quietly make a hollow person.
## A sheet can only be built from what this function accepts.
func _validate_npc_data(problems: Array) -> void:
	if npc_data.is_empty() or npc_data.get("archetypes", []).is_empty():
		problems.append("npc archetype data is missing")
		return
	var goal_ids: Dictionary = {}
	for value in npc_goals:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("npc goal is not an object")
			continue
		var goal: Dictionary = value
		var goal_id: String = String(goal.get("id", ""))
		if goal_id == "":
			problems.append("npc goal without id")
			continue
		if goal_ids.has(goal_id):
			problems.append("duplicate npc goal id " + goal_id)
		goal_ids[goal_id] = true
		if String(goal.get("label", "")) == "":
			problems.append("npc goal %s has no label" % goal_id)
		if String(goal.get("blurb", "")) == "":
			problems.append("npc goal %s has no blurb" % goal_id)
	if goal_ids.is_empty():
		problems.append("npc goals are missing")

	var schedules: Dictionary = npc_data.get("schedules", {})
	for schedule_name in schedules.keys():
		var entries: Variant = schedules[schedule_name]
		if typeof(entries) != TYPE_ARRAY:
			problems.append("schedule %s is not an array" % String(schedule_name))
			continue
		problems.append_array(Schedules.validate(
			entries, String(schedule_name), Settlement.LOCATIONS.keys()))
	var seen: Dictionary = {}
	for value in npc_data.get("archetypes", []):
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("npc archetype is not an object")
			continue
		var archetype: Dictionary = value
		var id: String = String(archetype.get("id", ""))
		if id == "":
			problems.append("npc archetype without id")
			continue
		if seen.has(id):
			problems.append("duplicate npc archetype id " + id)
		seen[id] = true
		if String(archetype.get("role", "")) == "":
			problems.append("npc archetype %s has no role" % id)
		var realm: int = int(archetype.get("realm", 0))
		if realm < 1 or realm > 12:
			problems.append("npc archetype %s has realm outside 1..12" % id)
		if not schedules.has(String(archetype.get("schedule", ""))):
			problems.append("npc archetype %s names unknown schedule %s" % [id, String(archetype.get("schedule", ""))])
		var rest_name: String = String(archetype.get("rest_schedule", ""))
		if rest_name != "" and not schedules.has(rest_name):
			problems.append("npc archetype %s names unknown rest schedule %s" % [id, rest_name])
		var disposition: int = int(archetype.get("disposition", 0))
		if disposition < -100 or disposition > 100:
			problems.append("npc archetype %s has disposition outside -100..100" % id)

		# The brain is data too: a response naming a verb nobody implements, or a
		# refuge that is not a real place, would only show up as a frozen crowd.
		var brain_data: Variant = archetype.get("ai", null)
		if typeof(brain_data) != TYPE_DICTIONARY:
			problems.append("npc archetype %s has no ai block" % id)
		else:
			var brain: Dictionary = brain_data
			var nerve: float = float(brain.get("nerve", -1.0))
			if nerve < 0.0 or nerve > 1.0:
				problems.append("npc archetype %s has nerve outside 0..1" % id)
			var alert_range: float = float(brain.get("alert_range", 0.0))
			if alert_range < 40.0 or alert_range > 900.0:
				problems.append("npc archetype %s has an alert range outside 40..900" % id)
			if not NpcAi.RESPONSES.has(String(brain.get("response", ""))):
				problems.append("npc archetype %s has unknown ai response %s" % [id, String(brain.get("response", ""))])
			if not Settlement.LOCATIONS.has(String(brain.get("refuge", ""))):
				problems.append("npc archetype %s has unknown refuge %s" % [id, String(brain.get("refuge", ""))])
			if typeof(brain.get("shout", null)) != TYPE_BOOL:
				problems.append("npc archetype %s has a non-boolean shout flag" % id)

		var attrs: Variant = archetype.get("attrs", null)
		if typeof(attrs) != TYPE_DICTIONARY:
			problems.append("npc archetype %s has no attribute block" % id)
		else:
			for key in Attributes.KEYS:
				if not (attrs as Dictionary).has(key):
					problems.append("npc archetype %s is missing %s" % [id, String(key)])
				elif int((attrs as Dictionary)[key]) < 0:
					problems.append("npc archetype %s has negative %s" % [id, String(key)])
		if int(archetype.get("attr_growth", 0)) < 0:
			problems.append("npc archetype %s has negative attribute growth" % id)

		var span: Variant = archetype.get("root", null)
		if typeof(span) != TYPE_ARRAY or (span as Array).size() != 2:
			problems.append("npc archetype %s has no root tier range" % id)
		else:
			var low: int = int((span as Array)[0])
			var high: int = int((span as Array)[1])
			if low < 1 or high > Roots.MAX_TIER or low > high:
				problems.append("npc archetype %s has a bad root tier range" % id)

		var physique_pool: Variant = archetype.get("physiques", null)
		if typeof(physique_pool) != TYPE_ARRAY or (physique_pool as Array).is_empty():
			problems.append("npc archetype %s has no physique pool" % id)
		else:
			for physique_id in physique_pool:
				if by_id("physique", String(physique_id)).is_empty():
					problems.append("npc archetype %s names unknown physique %s" % [id, String(physique_id)])

		var technique_pool: Variant = archetype.get("techniques", null)
		if typeof(technique_pool) != TYPE_ARRAY or (technique_pool as Array).is_empty():
			problems.append("npc archetype %s has no technique pool" % id)
		else:
			for technique_id in technique_pool:
				if by_id("technique", String(technique_id)).is_empty():
					problems.append("npc archetype %s names unknown technique %s" % [id, String(technique_id)])
		if int(archetype.get("technique_count", 0)) < 0:
			problems.append("npc archetype %s asks for a negative number of techniques" % id)

		var gear_pool: Variant = archetype.get("gear", null)
		if typeof(gear_pool) != TYPE_ARRAY or (gear_pool as Array).is_empty():
			problems.append("npc archetype %s has no gear pool" % id)
		else:
			for base_id in gear_pool:
				var base: Dictionary = by_id("base", String(base_id))
				if base.is_empty():
					problems.append("npc archetype %s names unknown item base %s" % [id, String(base_id)])
				elif not Items.is_equipment(String(base.get("slot", ""))):
					problems.append("npc archetype %s names a non-equipment base %s" % [id, String(base_id)])

		var goal_pool: Variant = archetype.get("goals", null)
		if typeof(goal_pool) != TYPE_ARRAY or (goal_pool as Array).is_empty():
			problems.append("npc archetype %s has no goals" % id)
		else:
			for goal_id in goal_pool:
				if not goal_ids.has(String(goal_id)):
					problems.append("npc archetype %s names unknown goal %s" % [id, String(goal_id)])

	# Progression is content too: a person must be able to grow, and a cap below
	# their own realm would make the simulation start above its ceiling.
	problems.append_array(NpcProgress.validate(npc_data))
