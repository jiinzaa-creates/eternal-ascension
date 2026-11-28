class_name Uniques
extends RefCounted
## Authored relics: hand-written items with fixed rolls, lore, one source and one
## effect. They are never produced by `ItemGen`; an instance exists only because a
## source granted it, and its id is stable so a save can carry it.

const EFFECTS: Array[String] = ["qi_on_kill", "mend_on_kill"]
const ALTAR_SOURCE := "site.inheritance_altar"

var db: Node


func _init(database: Node) -> void:
	db = database


func find(id: String) -> Dictionary:
	if db == null:
		return {}
	var entry: Dictionary = db.by_id("unique", id)
	return entry


func is_unique(item: Dictionary) -> bool:
	return bool(item.get("unique", false)) and not find(String(item.get("id", ""))).is_empty()


## The authored item, canonicalised. Base numbers come from the base; every
## affix and its value comes from the data, so the same relic is always the same
## relic and a save only has to store what it became.
func make(id: String) -> Dictionary:
	var entry := find(id)
	if entry.is_empty():
		return {}
	var base: Dictionary = db.by_id("base", String(entry.get("base", "")))
	if base.is_empty():
		return {}
	var item := {
		"id": String(entry.get("id", "")),
		"seed": 0,
		"base": String(base.get("id", "")),
		"base_name": String(base.get("name", "")),
		"slot": String(base.get("slot", entry.get("slot", ""))),
		"weapon_type": String(base.get("weapon_type", "")),
		"ilvl": maxi(1, int(entry.get("ilvl", 1))),
		"rarity": clampi(int(entry.get("rarity", ItemGen.RARITY_NAMES.size() - 1)), 0, ItemGen.RARITY_NAMES.size() - 1),
		"name": String(entry.get("name", "Relic")),
		"implicit": String(base.get("implicit", "")),
		"base_damage": float(base.get("damage", 0.0)),
		"armor": float(base.get("armor", 0.0)),
		"mods": entry.get("mods", []),
		"value": maxi(0, int(entry.get("value", 0))),
		"unique": true,
		"lore": String(entry.get("lore", "")),
		"set": String(entry.get("set", "")),
		"teaches_passive": String(entry.get("teaches_passive", "")),
	}
	return Items.normalize_item(item)


func for_source(source: String) -> Array:
	var out: Array = []
	for entry in db.uniques:
		if String(entry.get("source", "")) == source:
			out.append(entry)
	return out


## Ids already in hand, worn or bagged. A relic is granted once per save.
static func owned_ids(equipment: Dictionary, inventory: Array) -> Dictionary:
	var out: Dictionary = {}
	for slot in Items.WORN_KEYS:
		var worn: Variant = equipment.get(slot, {})
		if typeof(worn) == TYPE_DICTIONARY:
			var id := String((worn as Dictionary).get("id", ""))
			if id != "":
				out[id] = true
	for entry in inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := String((entry as Dictionary).get("id", ""))
		if id != "":
			out[id] = true
	return out


## Health and Qi worn relics return per kill. A broken relic is a broken relic:
## it contributes nothing, exactly as it contributes no stats.
static func kill_effects(equipment: Dictionary, database: Node) -> Dictionary:
	var out := {"hp": 0.0, "qi": 0.0}
	for slot in Items.WORN_KEYS:
		var worn: Variant = equipment.get(slot, {})
		if typeof(worn) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = worn
		if item.is_empty() or not bool(item.get("unique", false)) or Items.is_broken(item):
			continue
		var entry: Dictionary = database.by_id("unique", String(item.get("id", "")))
		var effect: Variant = entry.get("effect", {})
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var amount := float((effect as Dictionary).get("amount", 0.0))
		match String((effect as Dictionary).get("id", "")):
			"qi_on_kill":
				out["qi"] = float(out["qi"]) + amount
			"mend_on_kill":
				out["hp"] = float(out["hp"]) + amount
	return out


## Pieces of one set currently worn: authored, unbroken, on any
## finger or slot the body offers.
static func set_count(equipment: Dictionary, set_id: String) -> int:
	if set_id == "":
		return 0
	var count := 0
	for slot in Items.WORN_KEYS:
		var worn: Variant = equipment.get(slot, {})
		if typeof(worn) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = worn
		if item.is_empty() or not bool(item.get("unique", false)) or Items.is_broken(item):
			continue
		if String(item.get("set", "")) == set_id:
			count += 1
	return count


## The bonuses every worn set is currently paying, as pipeline
## mods. Each threshold met adds its own mods; thresholds stack.
static func set_mods(equipment: Dictionary, database: Node) -> Array:
	var out: Array = []
	if database == null:
		return out
	for set_entry in database.get("item_sets"):
		var worn_count := set_count(equipment, String(set_entry.get("id", "")))
		if worn_count < 2:
			continue
		for bonus in set_entry.get("bonuses", []):
			if worn_count >= int((bonus as Dictionary).get("count", 0)):
				out.append_array((bonus as Dictionary).get("mods", []))
	return out


## A readable line for a relic's effect, or "" for anything ordinary.
func effect_text(id: String) -> String:
	var effect: Variant = find(id).get("effect", {})
	if typeof(effect) != TYPE_DICTIONARY:
		return ""
	return String((effect as Dictionary).get("text", ""))
