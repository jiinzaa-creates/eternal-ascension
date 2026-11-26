class_name Crafting
extends RefCounted
## Forge rules.
##
## Recipes, costs and failure chances are data (`data/crafting.json`); this class
## only answers "may it be made", "what does it cost" and "what comes out". The
## output is a normal canonical item from `ItemGen`, so a forged piece stacks,
## wears, saves and sells exactly like loot.
##
## Three verbs are implemented here, not eleven: **forge** makes an authored base,
## **refine** rerolls a piece's affixes while keeping its base, level and rarity,
## and **disassemble** breaks a piece back into spirit ore. Failure is real: a
## failed forge loses its materials, a failed refine keeps the item but loses the
## ore and stones. Quality is the smith's INT: a high `crafting_quality_mult()`
## gives a chance to lift the result one rarity step.

const MATERIALS: Array[String] = ["ore", "herb", "core", "marrow"]
const MATERIAL_LABELS := {
	"ore": "Spirit Ore",
	"herb": "Spirit Herb",
	"core": "Spirit Core",
	"marrow": "Spirit Root Marrow",
}
## Chance to lift a result by one rarity per point of quality above 1.0.
const QUALITY_CHANCE_SCALE := 0.5
const MAX_QUALITY_CHANCE := 0.45
const ORE_BASE := 1
const ORE_PER_RARITY := 2

var db: Node


func _init(database: Node) -> void:
	db = database


func recipe(id: String) -> Dictionary:
	return db.recipe(id) if db != null else {}


func action(id: String) -> Dictionary:
	return db.crafting_action(id) if db != null else {}


func recipes_for(station_id: String) -> Array:
	var out: Array = []
	if db == null:
		return out
	for entry in db.recipes:
		if String((entry as Dictionary).get("station", "")) == station_id:
			out.append(entry)
	return out


static func is_material_key(key: String) -> bool:
	return MATERIALS.has(key)


static func material_label(key: String) -> String:
	return String(MATERIAL_LABELS.get(key, key.capitalize()))


## Total units of every material kind in a satchel. Stacks count by unit, not by
## entry, so three ore split over two stacks read as three.
static func material_counts(inventory: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in Items.normalize_inventory(inventory):
		var item: Dictionary = entry
		var key := Items.material_key(item)
		if key == "":
			continue
		out[key] = int(out.get(key, 0)) + maxi(0, int(item.get("count", 1)))
	return out


## "3 Spirit Ore, 60 spirit stones" — the cost line every panel shows.
static func requirement_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for entry in (recipe.get("materials", []) as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		parts.append("%d %s" % [int((entry as Dictionary).get("count", 0)),
			material_label(String((entry as Dictionary).get("material", "")))])
	var stones := int(recipe.get("stones", 0))
	if stones > 0:
		parts.append("%d spirit stones" % stones)
	return ", ".join(parts)


## Whether a recipe can be paid for right now. The reason names everything that
## is missing, not just the first thing checked.
static func check(recipe: Dictionary, inventory: Array, stones: int, realm: int) -> Dictionary:
	if recipe.is_empty():
		return {"ok": false, "reason": "unknown recipe", "missing": []}
	var missing: Array[String] = []
	var counts := material_counts(inventory)
	for entry in (recipe.get("materials", []) as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var key := String((entry as Dictionary).get("material", ""))
		var need := maxi(0, int((entry as Dictionary).get("count", 0)))
		var held := int(counts.get(key, 0))
		if held < need:
			missing.append("%d %s" % [need - held, material_label(key)])
	var cost := maxi(0, int(recipe.get("stones", 0)))
	if stones < cost:
		missing.append("%d spirit stones" % (cost - stones))
	var needed_realm := maxi(1, int(recipe.get("realm", 1)))
	if realm < needed_realm:
		missing.append("realm %d" % needed_realm)
	var ok := missing.is_empty()
	return {
		"ok": ok,
		"reason": "" if ok else "needs " + ", ".join(missing),
		"missing": missing,
	}


## Removes a recipe's materials from the satchel and returns the new satchel. An
## unaffordable cost changes nothing, so a caller can check first and consume
## after without ever half-paying.
static func consume(inventory: Array, materials: Array) -> Dictionary:
	var bag := Items.normalize_inventory(inventory)
	var wanted: Dictionary = {}
	for entry in materials:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var key := String((entry as Dictionary).get("material", ""))
		if not is_material_key(key):
			continue
		wanted[key] = int(wanted.get(key, 0)) + maxi(0, int((entry as Dictionary).get("count", 0)))
	var counts := material_counts(bag)
	for key in wanted.keys():
		if int(counts.get(key, 0)) < int(wanted[key]):
			return {"ok": false, "reason": "not enough " + material_label(String(key)), "inventory": bag}
	for key in wanted.keys():
		var left := int(wanted[key])
		var kept: Array = []
		for item in bag:
			var data: Dictionary = item
			if left > 0 and Items.material_key(data) == String(key):
				var take := mini(left, int(data.get("count", 1)))
				data["count"] = int(data.get("count", 1)) - take
				left -= take
			if int(data.get("count", 1)) > 0:
				kept.append(data)
		bag = kept
	return {"ok": true, "reason": "", "inventory": Items.normalize_inventory(bag)}


static func quality_chance(quality_mult: float) -> float:
	return clampf((maxf(1.0, quality_mult) - 1.0) * QUALITY_CHANCE_SCALE, 0.0, MAX_QUALITY_CHANCE)


## Forges one recipe. `key`/`counter` are the item's stream coordinates, so the
## same attempt always produces the same piece; every attempt should advance the
## caller's attempt counter, failures included, or a failed roll would repeat.
func craft(recipe: Dictionary, ilvl: int, key: int, counter: int, quality_mult: float = 1.0,
		failure_mult: float = 1.0) -> Dictionary:
	var out := {"ok": false, "failed": false, "quality": false, "item": {}, "reason": ""}
	if recipe.is_empty():
		out["reason"] = "unknown recipe"
		return out
	var r: RandomNumberGenerator = Rng.stream("craft." + String(recipe.get("id", "")), key, counter)
	if r.randf() < clampf(float(recipe.get("failure_chance", 0.0)) * clampf(failure_mult, 0.0, 1.0), 0.0, 1.0):
		out["failed"] = true
		out["reason"] = "the work fails"
		return out
	var quality := r.randf() < quality_chance(quality_mult)
	var output: Dictionary = recipe.get("output", {})
	var rarity := int(output.get("rarity", 1))
	if quality:
		rarity = mini(ItemGen.RARITY_NAMES.size() - 1, rarity + 1)
	var generator := ItemGen.new(db, Rng)
	var item := generator.generate(maxi(1, ilvl), key, counter, rarity, "", String(output.get("base", "")))
	if item.is_empty():
		out["reason"] = "that base cannot be forged"
		return out
	out["ok"] = true
	out["quality"] = quality
	out["item"] = item
	return out


## Rerolls a piece's affixes. The base, level, rarity and wear are kept — a
## refiner improves a sword, it does not smith a different one.
func refine(item: Dictionary, key: int, counter: int, quality_mult: float = 1.0,
		failure_mult: float = 1.0) -> Dictionary:
	var out := {"ok": false, "failed": false, "quality": false, "item": item, "reason": ""}
	if not Items.is_equipment(String(item.get("slot", ""))):
		out["reason"] = "only gear can be refined"
		return out
	if bool(item.get("unique", false)):
		out["reason"] = "an authored relic refuses a smith"
		return out
	var rules := action("refine")
	if rules.is_empty():
		out["reason"] = "refining is not offered"
		return out
	var r: RandomNumberGenerator = Rng.stream("craft.refine", key, counter)
	if r.randf() < clampf(float(rules.get("failure_chance", 0.0)) * clampf(failure_mult, 0.0, 1.0), 0.0, 1.0):
		out["failed"] = true
		out["reason"] = "the work fails; the piece survives unchanged"
		return out
	var quality := r.randf() < quality_chance(quality_mult)
	var rarity := int(item.get("rarity", 0))
	if quality:
		rarity = mini(ItemGen.RARITY_NAMES.size() - 1, rarity + 1)
	var generator := ItemGen.new(db, Rng)
	var refined := generator.generate(
		int(item.get("ilvl", 1)), key, counter, rarity,
		String(item.get("slot", "")), String(item.get("base", "")))
	if refined.is_empty():
		out["reason"] = "the piece cannot be reforged"
		return out
	refined["durability"] = Items.durability_of(item)
	out["ok"] = true
	out["quality"] = quality
	out["item"] = refined
	return out


## What raising a piece one item level costs, and how likely the work is
## to fail. There is no level cap: the price and the risk are the ceiling,
## and both climb with every level already gained.
static func upgrade_cost(item: Dictionary) -> Dictionary:
	var ilvl := int(item.get("ilvl", 1))
	var rarity := int(item.get("rarity", 0))
	return {
		"stones": 25 * (ilvl + 1) + 10 * rarity,
		"materials": [{"material": "ore", "count": 2 + ilvl / 3}],
		"failure_chance": clampf(0.05 + 0.03 * float(ilvl + 1), 0.0, 0.60),
		"realm": 1,
	}


## Raises a piece one item level. The affixes it already carries stay —
## each value is re-rolled inside its affix's tier at the new level, so
## an upgrade can roll low as well as high. Failure keeps the piece but
## strains it: a quarter of its durability is spent in the attempt.
func upgrade(item: Dictionary, key: int, counter: int, failure_mult: float = 1.0) -> Dictionary:
	var out := {"ok": false, "failed": false, "item": item, "reason": ""}
	if not Items.is_equipment(String(item.get("slot", ""))):
		out["reason"] = "only gear can be upgraded"
		return out
	if bool(item.get("unique", false)):
		out["reason"] = "an authored relic refuses a smith"
		return out
	var cost := upgrade_cost(item)
	var r: RandomNumberGenerator = Rng.stream("craft.upgrade", key, counter)
	if r.randf() < clampf(float(cost["failure_chance"]) * clampf(failure_mult, 0.0, 1.0), 0.0, 1.0):
		var strained: Dictionary = item.duplicate(true)
		var maximum := Items.max_durability(String(item.get("slot", "")))
		strained["durability"] = maxf(0.0, Items.durability_of(item) - maximum * 0.25)
		out["failed"] = true
		out["item"] = strained
		out["reason"] = "the work fails; the piece is strained"
		return out
	var upgraded: Dictionary = item.duplicate(true)
	var new_ilvl := int(item.get("ilvl", 1)) + 1
	upgraded["ilvl"] = new_ilvl
	var mods: Array = []
	for mod_value in item.get("mods", []):
		var mod: Dictionary = (mod_value as Dictionary).duplicate()
		if not bool(mod.get("enchant", false)):
			var affix: Dictionary = db.by_id("prefix", String(mod.get("id", "")))
			if affix.is_empty():
				affix = db.by_id("suffix", String(mod.get("id", "")))
			if not affix.is_empty():
				var tier_index := ItemGen.tier_for(affix, new_ilvl)
				var tier := ItemGen.tier_data(affix, tier_index)
				var lo := float(tier.get("min", affix.get("min", 1.0)))
				var hi := float(tier.get("max", lo))
				var value := lo + (hi - lo) * r.randf()
				if value >= 10.0:
					value = round(value)
				else:
					value = snappedf(value, 0.1)
				mod["value"] = value
				mod["tier"] = tier_index + 1
				mod["text"] = ItemGen.affix_text(affix, value)
		mods.append(mod)
	upgraded["mods"] = mods
	var base: Dictionary = db.base_item(String(item.get("base", "")))
	upgraded["value"] = int(ceil(float(base.get("value", 5))
		* ItemGen.RARITY_MULT[int(item.get("rarity", 0))] * (1.0 + float(new_ilvl) * 0.15)))
	out["ok"] = true
	out["item"] = upgraded
	return out


## Ore returned for breaking a piece down. Rarer and higher pieces give more; a
## relic or a non-gear item gives none.
static func disassemble_ore(item: Dictionary) -> int:
	if not Items.is_equipment(String(item.get("slot", ""))):
		return 0
	if bool(item.get("unique", false)):
		return 0
	return maxi(1, ORE_BASE + int(item.get("rarity", 0)) * ORE_PER_RARITY + int(item.get("ilvl", 1)) / 2)
