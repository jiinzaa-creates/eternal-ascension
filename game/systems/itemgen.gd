class_name ItemGen
extends RefCounted
## Deterministic procedural item generation.
##
## An item is a pure function of (world_seed, key, counter): the same seed always
## produces the same item, which is what lets a save store only the seed and the
## item's ID instead of a full copy. Affix rolls use their own derived streams so
## adding a new affix to the pool cannot reshuffle existing items.

const RARITY_NAMES: Array[String] = ["Mortal", "Refined", "Spirit", "Treasure"]
const RARITY_MULT: Array[float] = [1.0, 1.6, 2.6, 4.5]
const RARITY_COLORS: Array[String] = ["#9aa0a6", "#7fc7a3", "#7aa7f0", "#e0b24d"]

var db: Node
var rng: Node


func _init(database: Node, rng_node: Node) -> void:
	db = database
	rng = rng_node


## Non-equipment items never roll affixes: a pill is a payload, not a build.
static func is_equipment_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "armor" or slot == "ring" or slot == "talisman"


## `force_base` pins the authored base a recipe names; loot leaves it empty and
## lets the weighted pool decide.
func generate(ilvl: int = 1, key: int = 0, counter: int = 0, force_rarity: int = -1, force_slot: String = "", force_base: String = "") -> Dictionary:
	var r: RandomNumberGenerator = rng.stream("itemgen", key, counter)
	var base := _pick_base(r, ilvl, force_slot, force_base)
	if base.is_empty():
		return {}

	var rarity := force_rarity
	if rarity < 0:
		rarity = _roll_rarity(r, ilvl)
	rarity = clampi(rarity, 0, RARITY_NAMES.size() - 1)

	var slot := String(base.get("slot", "weapon"))
	if not is_equipment_slot(slot):
		rarity = 0
	var mods: Array = []
	var count: int = [0, 1, 2, 3][rarity]
	mods.append_array(_pick_affixes(r, slot, "prefix", count, ilvl))
	mods.append_array(_pick_affixes(r, slot, "suffix", count, ilvl))

	return {
		"id": "item.%d.%d" % [key, counter],
		"seed": key,
		"base": String(base.get("id", "")),
		"base_name": String(base.get("name", "Unknown")),
		"slot": slot,
		"weapon_type": String(base.get("weapon_type", "")),
		"ilvl": ilvl,
		"rarity": rarity,
		"rarity_name": RARITY_NAMES[rarity],
		"name": _name_for(base, mods, rarity),
		"implicit": String(base.get("implicit", "")),
		"base_damage": float(base.get("damage", 0.0)),
		"armor": float(base.get("armor", 0.0)),
		"mods": mods,
		"value": int(ceil(float(base.get("value", 5)) * RARITY_MULT[rarity] * (1.0 + float(ilvl) * 0.15))),
	}


func _pick_base(r: RandomNumberGenerator, ilvl: int, force_slot: String = "", force_base: String = "") -> Dictionary:
	var eligible: Array = []
	var weights: Array = []
	for base in db.bases:
		if int(base.get("ilvl", 1)) > ilvl + 1:
			continue
		if force_slot != "" and String(base.get("slot", "")) != force_slot:
			continue
		if force_base != "" and String(base.get("id", "")) != force_base:
			continue
		eligible.append(base)
		weights.append(int(base.get("weight", 10)))
	if eligible.is_empty():
		return {}
	var index: int = int(rng.pick_weighted(weights, r))
	if index < 0:
		return {}
	return eligible[index]


func _roll_rarity(r: RandomNumberGenerator, ilvl: int) -> int:
	var weights := [maxi(8, 55 - ilvl), 27, 13, 5 + int(ilvl / 4.0)]
	var index: int = int(rng.pick_weighted(weights, r))
	return maxi(0, index)


## How many tiers an affix defines. Data without tiers has exactly one, which is
## how affixes written before tiers existed keep working.
static func tier_count(affix: Dictionary) -> int:
	var tiers: Array = affix.get("tiers", [])
	return maxi(1, tiers.size())


static func tiers_of(affix: Dictionary) -> Array:
	var tiers: Array = affix.get("tiers", [])
	if not tiers.is_empty():
		return tiers
	return [{
		"ilvl": int(affix.get("ilvl", 1)),
		"min": float(affix.get("min", 1.0)),
		"max": float(affix.get("max", 1.0)),
	}]


## The highest tier the item's level has unlocked, 0-based. A level below the
## first tier still reads the first: the affix itself is already level-gated.
static func tier_for(affix: Dictionary, ilvl: int) -> int:
	var tiers := tiers_of(affix)
	var out := 0
	for i in tiers.size():
		if ilvl >= int((tiers[i] as Dictionary).get("ilvl", 1)):
			out = i
	return out


static func tier_data(affix: Dictionary, index: int) -> Dictionary:
	var tiers := tiers_of(affix)
	return tiers[clampi(index, 0, tiers.size() - 1)]


## Base selection weight, or the slot's override when the data names one. A
## weight of zero removes the affix from that pool entirely.
static func affix_weight(affix: Dictionary, slot: String) -> int:
	var slot_weights: Dictionary = affix.get("slot_weights", {})
	if slot_weights.has(slot):
		return maxi(0, int(slot_weights[slot]))
	return maxi(0, int(affix.get("weight", 10)))


## Weighted and without replacement, drawn only from the item's own stream.
## `Array.shuffle()` would have consumed the engine-global RNG here, which is
## exactly the order-dependence the generator exists to avoid.
func _pick_affixes(r: RandomNumberGenerator, slot: String, kind: String, count: int, ilvl: int) -> Array:
	if count <= 0:
		return []
	var pool: Array = []
	var weights: Array = []
	for affix in db.affixes_for(slot, kind):
		if int(affix.get("ilvl", 1)) > ilvl + 2:
			continue
		var weight := affix_weight(affix, slot)
		if weight <= 0:
			continue
		pool.append(affix)
		weights.append(weight)
	var out: Array = []
	for _i in mini(count, pool.size()):
		var index: int = Rng.pick_weighted(weights, r)
		if index < 0 or index >= pool.size():
			break
		var affix: Dictionary = pool[index]
		var tier_index := tier_for(affix, ilvl)
		var tier := tier_data(affix, tier_index)
		var lo := float(tier.get("min", affix.get("min", 1.0)))
		var hi := float(tier.get("max", lo))
		var value := lo + (hi - lo) * r.randf()
		if value >= 10.0:
			value = round(value)
		else:
			value = snappedf(value, 0.1)
		out.append({
			"id": String(affix.get("id", "")),
			"stat": String(affix.get("stat", "")),
			"value": value,
			"tier": tier_index + 1,
			"text": _affix_text(affix, value),
		})
		pool.remove_at(index)
		weights.remove_at(index)
	return out


func _affix_text(affix: Dictionary, value: float) -> String:
	var unit := String(affix.get("unit", ""))
	var label := String(affix.get("stat_label", String(affix.get("stat", ""))))
	if value < 10.0:
		return "+%.1f%s %s" % [value, unit, label]
	return "+%d%s %s" % [int(value), unit, label]


func _name_for(base: Dictionary, mods: Array, rarity: int) -> String:
	var base_name := String(base.get("name", "Item"))
	if rarity >= 3:
		# Treasure-grade items get a unique epithet rather than a prefix stack.
		return _epithet(mods) + " " + base_name
	var prefix := ""
	var suffix := ""
	for mod in mods:
		var affix: Dictionary = db.by_id("prefix", String(mod.get("id", "")))
		if not affix.is_empty() and prefix == "":
			prefix = String(affix.get("name", ""))
		var s: Dictionary = db.by_id("suffix", String(mod.get("id", "")))
		if not s.is_empty() and suffix == "":
			suffix = String(s.get("name", ""))
	var out := base_name
	if prefix != "":
		out = prefix + " " + out
	if suffix != "":
		out = out + " " + suffix
	return out


func _epithet(mods: Array) -> String:
	if mods.is_empty():
		return "Ancient"
	return String(mods[0].get("stat", "Ancient")).capitalize()


func describe(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("%s  [%s]" % [item.get("name", "?"), item.get("rarity_name", "?")])
	lines.append("%s  ilvl %d" % [String(item.get("slot", "")).capitalize(), int(item.get("ilvl", 1))])
	if float(item.get("base_damage", 0.0)) > 0.0:
		lines.append("%d damage" % int(item.get("base_damage", 0.0)))
	if float(item.get("armor", 0.0)) > 0.0:
		lines.append("%d armor" % int(item.get("armor", 0.0)))
	if String(item.get("implicit", "")) != "":
		lines.append(String(item.get("implicit", "")))
	for mod in item.get("mods", []):
		var line := String(mod.get("text", ""))
		var tier := int(mod.get("tier", 1))
		if tier > 1:
			line += "  (T%d)" % tier
		lines.append(line)
	lines.append("Value: %d spirit stones" % int(item.get("value", 0)))
	return "\n".join(lines)
