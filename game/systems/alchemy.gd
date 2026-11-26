class_name Alchemy
extends RefCounted
## Brewing and drinking.
##
## Potions are data (`data/alchemy.json`): a recipe names a consumable base, its
## herbs and cores, a stone cost, a realm gate, a failure chance and one effect.
## `Alchemy` turns a recipe into a normal canonical consumable and answers what
## that consumable does when used.
##
## A potion's strength is its `potency`, stored on the item so a brew keeps its
## quality through a save. Skill does not lift a pill's rarity (a consumable has
## none); it raises potency, which is why two pills of the same base can differ.

const STATION := "station.alchemy"
const EFFECTS: Array[String] = ["qi", "heal", "cleanse", "lifespan", "resurrect", "vessel"]
const EFFECT_LABELS := {"qi": "Qi", "heal": "health", "cleanse": "contamination",
	"lifespan": "years of life", "resurrect": "a cheated death", "vessel": "a waiting body"}
## Potency gained per point of INT quality above an ordinary smith.
const POTENCY_PER_QUALITY := 0.35
## Extra potency for an exceptional brew (the quality roll).
const EXCEPTIONAL_BONUS := 0.25
const MIN_POTENCY := 0.1
const MAX_POTENCY := 5.0

var db: Node


func _init(database: Node) -> void:
	db = database


func recipes() -> Array:
	return db.potions if db != null else []


func recipe(id: String) -> Dictionary:
	return db.potion(id) if db != null else {}


## The potion a consumable was brewed from, by base. World-dropped pills share
## their base, so a found Qi pill is drinkable exactly like a brewed one.
func recipe_for_item(item: Dictionary) -> Dictionary:
	if db == null or String(item.get("slot", "")) != "consumable":
		return {}
	var base_id := String(item.get("base", ""))
	for entry in db.potions:
		if String((entry as Dictionary).get("base", "")) == base_id:
			return entry
	return {}


func effect_for(item: Dictionary) -> Dictionary:
	var entry := recipe_for_item(item)
	if entry.is_empty():
		return {}
	var effect: Variant = entry.get("effect", {})
	return effect if typeof(effect) == TYPE_DICTIONARY else {}


static func is_effect(id: String) -> bool:
	return EFFECTS.has(id)


static func potency_of(item: Dictionary) -> float:
	return clampf(float(item.get("potency", 1.0)), MIN_POTENCY, MAX_POTENCY)


## What one pill of this item actually restores. Potency is the brew's quality.
static func effect_amount(effect: Dictionary, item: Dictionary) -> float:
	return maxf(0.0, float(effect.get("amount", 0.0))) * potency_of(item)


static func effect_text(recipe: Dictionary) -> String:
	var effect: Dictionary = recipe.get("effect", {})
	var id := String(effect.get("id", ""))
	var amount := float(effect.get("amount", 0.0))
	var label := String(EFFECT_LABELS.get(id, id))
	if id == "cleanse":
		return "Purges %.0f contamination" % amount
	return "Restores %.0f %s" % [amount, label]


## The potency a brew ends with. Quality is continuous (INT) plus a discrete
## exceptional roll, so a skilled alchemist always gets something stronger and
## sometimes gets something much stronger.
static func potency_for(quality_mult: float, exceptional: bool) -> float:
	var base := 1.0 + maxf(0.0, quality_mult - 1.0) * POTENCY_PER_QUALITY
	if exceptional:
		base += EXCEPTIONAL_BONUS
	return clampf(base, MIN_POTENCY, MAX_POTENCY)


## Brews one recipe. Pure in `(recipe, ilvl, key, counter, quality_mult)`; the
## caller advances its attempt counter on every try, failures included.
func brew(recipe: Dictionary, ilvl: int, key: int, counter: int, quality_mult: float = 1.0,
		failure_mult: float = 1.0) -> Dictionary:
	var out := {"ok": false, "failed": false, "quality": false, "item": {}, "reason": ""}
	if recipe.is_empty():
		out["reason"] = "unknown potion"
		return out
	var r: RandomNumberGenerator = Rng.stream("brew." + String(recipe.get("id", "")), key, counter)
	if r.randf() < clampf(float(recipe.get("failure_chance", 0.0)) * clampf(failure_mult, 0.0, 1.0), 0.0, 1.0):
		out["failed"] = true
		out["reason"] = "the brew spoils"
		return out
	var exceptional := r.randf() < Crafting.quality_chance(quality_mult)
	var generator := ItemGen.new(db, Rng)
	var item := generator.generate(
		maxi(1, ilvl), key, counter, 0, "consumable", String(recipe.get("base", "")))
	if item.is_empty():
		out["reason"] = "that base cannot be brewed"
		return out
	item["potency"] = potency_for(quality_mult, exceptional)
	out["ok"] = true
	out["quality"] = exceptional
	out["item"] = item
	return out
