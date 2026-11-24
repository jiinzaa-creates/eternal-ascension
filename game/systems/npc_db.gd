class_name NpcDb
extends RefCounted
## The NPC record: identity is one deterministic sheet, memory is what the player
## has done to it.
##
## A sheet is a pure function of the world seed, the person's stable id and the
## archetype's pools, exactly like items and chunks. That is what lets a save
## store nothing but the seed and a few memory marks: the attributes, root, body,
## arts, gear and goals regenerate identically.
##
## Nothing here mutates a body. `sheet()` answers what a person is, `remember()`
## is the only thing that writes, and it writes to the dictionary it is handed.

const SHEET_DOMAIN := "npc_sheet"
const GOAL_COUNT := 2
const REGARD_PER_TALK := 3
const REGARD_MAX := 30
const REGARD_MIN := -30


## The complete record for one person. `realm` overrides the archetype's own
## realm for authored characters who outrank their template.
static func sheet(archetype: Dictionary, npc_id: String, realm: int = 0) -> Dictionary:
	var level: int = int(archetype.get("realm", 1))
	if realm > 0:
		level = realm
	level = clampi(level, 1, maxi(1, Realms.count()))
	var rng: RandomNumberGenerator = Rng.stream(SHEET_DOMAIN, hash(npc_id), 0)
	var attrs: Dictionary = _roll_attrs(archetype, level, rng)
	var root: Dictionary = _roll_root(archetype, rng)
	var physique_id: String = _roll_physique(archetype, rng)
	var techniques: Array = _roll_techniques(archetype, level, attrs, rng)
	var goals: Array = _roll_goals(archetype, rng)
	return {
		"id": npc_id,
		"archetype_id": String(archetype.get("id", "")),
		"realm": level,
		"attrs": attrs,
		"root_id": String(root.get("id", "")),
		"root_tier": int(root.get("tier", 1)),
		"physique_id": physique_id,
		"techniques": techniques,
		"gear": roll_gear(archetype, npc_id, level, attrs),
		"goals": goals,
		"disposition": clampi(int(archetype.get("disposition", 0)), -100, 100),
	}


## Attributes are the archetype's base plus one step per realm above the first.
## A small deterministic jitter keeps two disciples of one rank from being
## literally the same person without ever undercutting the template.
static func _roll_attrs(archetype: Dictionary, realm: int, rng: RandomNumberGenerator) -> Dictionary:
	var base: Variant = archetype.get("attrs", {})
	var template: Dictionary = base if typeof(base) == TYPE_DICTIONARY else {}
	var growth: int = maxi(0, int(archetype.get("attr_growth", 1)))
	var out: Dictionary = {}
	for key in Attributes.KEYS:
		var start: int = maxi(0, int(template.get(key, 10)))
		out[key] = start + maxi(0, realm - 1) * growth + rng.randi_range(0, 1)
	return out


## Picks a root whose tier sits inside the archetype's range. The root carries
## its own purity and affinity, so the sheet needs only the id and its tier.
static func _roll_root(archetype: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var span: Variant = archetype.get("root", [1, 3])
	var low := 1
	var high := 3
	if typeof(span) == TYPE_ARRAY and (span as Array).size() >= 2:
		low = clampi(int((span as Array)[0]), 1, Roots.MAX_TIER)
		high = clampi(int((span as Array)[1]), low, Roots.MAX_TIER)
	var pool: Array = []
	for value in DB.roots:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var root: Dictionary = value
		var tier: int = int(root.get("tier", 0))
		if tier >= low and tier <= high:
			pool.append(root)
	if pool.is_empty():
		return {"id": "", "tier": low}
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return {"id": String(chosen.get("id", "")), "tier": int(chosen.get("tier", low))}


static func _roll_physique(archetype: Dictionary, rng: RandomNumberGenerator) -> String:
	var pool: Variant = archetype.get("physiques", [])
	if typeof(pool) != TYPE_ARRAY or (pool as Array).is_empty():
		return Physiques.DEFAULT_ID
	var ids: Array = pool
	var picked: String = String(ids[rng.randi_range(0, ids.size() - 1)])
	if DB.physique(picked).is_empty():
		return Physiques.DEFAULT_ID
	return picked


## Only arts the body genuinely qualifies for. A guard with a cracked root does
## not get to carry a formation array the sheet cannot justify.
static func _roll_techniques(archetype: Dictionary, realm: int, attrs: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var pool: Variant = archetype.get("techniques", [])
	if typeof(pool) != TYPE_ARRAY:
		return []
	var body := _attributes_from(attrs)
	var state: Dictionary = {"realm": realm, "attrs": body}
	var legal: Array = []
	for value in pool:
		var id: String = String(value)
		if Techniques.find(id).is_empty():
			continue
		if bool(Techniques.can_learn(id, state).get("ok", false)):
			legal.append(id)
	var count: int = clampi(int(archetype.get("technique_count", 2)), 0, legal.size())
	var out: Array = []
	for _i in count:
		var index: int = rng.randi_range(0, legal.size() - 1)
		out.append(String(legal[index]))
		legal.remove_at(index)
	return out


## Gear is generated exactly like loot, through ItemGen's own stream, then put
## through the same equip gate the player uses. An illegal piece is dropped, not
## worn: the record can never claim a body is wearing what it could not wear.
static func roll_gear(archetype: Dictionary, npc_id: String, realm: int, attrs: Dictionary,
		counter_base: int = 0) -> Dictionary:
	var out: Dictionary = {}
	var pool: Variant = archetype.get("gear", [])
	if typeof(pool) != TYPE_ARRAY or (pool as Array).is_empty():
		return out
	var rules := Equipment.new(DB)
	var body := _attributes_from(attrs)
	var generator := ItemGen.new(DB, Rng)
	var bases: Array = pool
	for i in bases.size():
		var base_id: String = String(bases[i])
		if DB.base_item(base_id).is_empty():
			continue
		var item: Dictionary = generator.generate(
			maxi(1, realm + 1), hash(npc_id), counter_base + i, -1, "", base_id)
		if item.is_empty():
			continue
		var slot: String = String(item.get("slot", ""))
		if slot == "" or out.has(slot):
			continue
		if not bool(rules.can_equip(item, out, body, realm).get("ok", false)):
			continue
		item["id"] = "item.npc.%s.%d" % [npc_id, counter_base + i]
		out[slot] = item
	return out


static func _roll_goals(archetype: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Variant = archetype.get("goals", [])
	if typeof(pool) != TYPE_ARRAY or (pool as Array).is_empty():
		return []
	var remaining: Array = (pool as Array).duplicate()
	var count: int = clampi(int(archetype.get("goal_count", GOAL_COUNT)), 0, remaining.size())
	var out: Array = []
	for _i in count:
		var index: int = rng.randi_range(0, remaining.size() - 1)
		out.append(String(remaining[index]))
		remaining.remove_at(index)
	return out


static func _attributes_from(values: Dictionary) -> Attributes:
	var body := Attributes.new()
	body.from_dict(values)
	return body


# ---------------------------------------------------------------- memory ----


## What a person remembers about the player, independent of their sheet. Memory
## is keyed by stable NPC id, so it survives a regenerated world.
static func memory_entry(memory: Dictionary, npc_id: String) -> Dictionary:
	var value: Variant = memory.get(npc_id, {})
	if typeof(value) != TYPE_DICTIONARY:
		return _blank_memory()
	return _clean_memory(value)


## The only write. Talking is what turns an unknown face into a known one; the
## regard cap means patience can warm even a guard, but only so far.
static func remember(memory: Dictionary, npc_id: String, day: int) -> Dictionary:
	if npc_id == "":
		return _blank_memory()
	var record: Dictionary = memory_entry(memory, npc_id)
	record["met"] = true
	record["talks"] = int(record.get("talks", 0)) + 1
	record["last_day"] = maxi(0, day)
	record["regard"] = mini(REGARD_MAX, int(record.get("regard", 0)) + REGARD_PER_TALK)
	memory[npc_id] = record
	return record


## Read back a save without trusting it: unknown shapes are dropped and every
## number is clamped to what the simulation can produce.
static func sanitize_memory(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var records: Dictionary = raw
	for key in records.keys():
		var id: String = String(key)
		if id == "":
			continue
		var value: Variant = records[key]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		out[id] = _clean_memory(value)
	return out


static func _blank_memory() -> Dictionary:
	return {"met": false, "talks": 0, "last_day": 0, "regard": 0}


static func _clean_memory(value: Dictionary) -> Dictionary:
	return {
		"met": bool(value.get("met", false)),
		"talks": maxi(0, int(value.get("talks", 0))),
		"last_day": maxi(0, int(value.get("last_day", 0))),
		"regard": clampi(int(value.get("regard", 0)), REGARD_MIN, REGARD_MAX),
	}


## Base disposition plus what the player has earned. A guard starts wary and
## can end merely neutral; an elder starts warm and becomes friendlier still.
static func standing_label(value: int) -> String:
	if value <= -20:
		return "hostile"
	if value <= -5:
		return "wary"
	if value < 10:
		return "neutral"
	if value < 25:
		return "friendly"
	return "warm"


static func goal_label(id: String) -> String:
	return String(DB.npc_goal(id).get("label", id))


static func goal_blurb(id: String) -> String:
	return String(DB.npc_goal(id).get("blurb", ""))
