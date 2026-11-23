class_name Loot
extends RefCounted
## Data-driven loot tables.
##
## A table names one source (`kill.wild`, `kill.elite`, `kill.boss`, the chest
## kinds, the inheritance altar) and owns every decision the call sites used to
## hard-code: how many rolls, whether the roll is empty, the rarity weights, the
## slot weights, an item-level bonus and a purse.
##
## `ItemGen` still decides what the item *is*; `Loot` only decides which roll to
## ask for. One stream per `(source, key, counter)` drives the table, and
## `ItemGen` keeps its own stream per item, so editing a weight cannot reshuffle
## items that were already generated and the same kill always drops the same
## thing.

const DEFAULT_TABLE := "kill.wild"
## A table may ask for at most this many pieces, which bounds one kill's drops.
const MAX_ROLLS := 4
## Sources the game actually calls. A data file missing one would fall back to
## the wild table silently, so validation requires every one of them.
const REQUIRED_SOURCES: Array[String] = [
	"kill.wild", "kill.elite", "kill.boss",
	"chest.common", "chest.sealed", "chest.ruin",
	"inheritance.altar",
]

var db: Node
var rng: Node


func _init(database: Node, rng_node: Node) -> void:
	db = database
	rng = rng_node


## The table for a source, or the wild table for an unknown one. Returning the
## fallback rather than {} keeps a typo from silently deleting a whole source.
func table(source: String) -> Dictionary:
	if db == null:
		return {}
	var entry: Dictionary = db.loot_table(source)
	if not entry.is_empty():
		return entry
	if source == DEFAULT_TABLE:
		return {}
	return db.loot_table(DEFAULT_TABLE)


## Rolls a named source. `key` and `counter` are the same coordinates ItemGen
## takes: the same kill yields the same drops.
func roll(source: String, ilvl: int, key: int = 0, counter: int = 0) -> Dictionary:
	var entry := table(source)
	if entry.is_empty():
		return {"table": source, "items": [], "stones": 0}
	var rolled := roll_with(entry, ilvl, key, counter)
	rolled["table"] = source
	return rolled


## Rolls an explicit table, for tests and for content outside the registry.
func roll_with(entry: Dictionary, ilvl: int, key: int = 0, counter: int = 0) -> Dictionary:
	var out := {"table": String(entry.get("id", DEFAULT_TABLE)), "items": [], "stones": 0}
	if entry.is_empty():
		return out
	var r: RandomNumberGenerator = rng.stream("loot." + String(out["table"]), key, counter)
	if r.randf() < float(entry.get("empty_chance", 0.0)):
		return out
	var generator := ItemGen.new(db, rng)
	var bounds := rolls_of(entry)
	var count := r.randi_range(bounds.x, bounds.y)
	var minimum := int(entry.get("min_rarity", 0))
	var bonus := int(entry.get("ilvl_bonus", 0))
	for i in count:
		var slot := pick_slot(entry, r)
		if slot == "":
			continue
		var rarity := maxi(minimum, pick_rarity(entry, r))
		var item := generator.generate(maxi(1, ilvl + bonus), key, counter + i, rarity, slot)
		if item.is_empty():
			continue
		out["items"].append(item)
	out["stones"] = roll_stones(entry, r)
	return out


# --- table fields -------------------------------------------------------------

static func rolls_of(entry: Dictionary) -> Vector2i:
	var value: Variant = entry.get("rolls", [1, 1])
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 2:
		return Vector2i.ONE
	var low := maxi(1, int((value as Array)[0]))
	var high := clampi(int((value as Array)[1]), low, MAX_ROLLS)
	return Vector2i(low, high)


static func pick_rarity(entry: Dictionary, r: RandomNumberGenerator) -> int:
	var weights: Array = entry.get("rarity_weights", [])
	return maxi(0, Rng.pick_weighted(weights, r))


## "" means the table has no usable slot weights, which the caller treats as
## "this table rolls nothing" rather than guessing a slot.
static func pick_slot(entry: Dictionary, r: RandomNumberGenerator) -> String:
	var value: Variant = entry.get("slot_weights", {})
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	var weights: Dictionary = value
	var slots: Array = []
	var counts: Array = []
	for slot in weights.keys():
		slots.append(String(slot))
		counts.append(int(weights[slot]))
	var index := Rng.pick_weighted(counts, r)
	if index < 0 or index >= slots.size():
		return ""
	return String(slots[index])


static func roll_stones(entry: Dictionary, r: RandomNumberGenerator) -> int:
	var value: Variant = entry.get("stones", [0, 0])
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 2:
		return 0
	var low := maxi(0, int((value as Array)[0]))
	var high := maxi(low, int((value as Array)[1]))
	if high <= 0:
		return 0
	return r.randi_range(low, high)


static func label(source: String) -> String:
	return String(source).replace("kill.", "").replace("chest.", "").capitalize()
