class_name Items
extends RefCounted
## The item schema: one canonical shape, stable ids, durability, stacks and a
## save form that is guaranteed to round-trip.
##
## `ItemGen` decides what an item *is*; this class decides what an item *is
## allowed to be*. Every item that enters the inventory, gets equipped, is sold,
## or is written to a save passes through `normalize_item()`, so a hand-edited
## save, an old save and a freshly rolled drop all become the same dictionary
## with the same key order and the same value types.
##
## Durability is simple on purpose: only weapons and armour wear, a worn piece
## still works, and a **broken** piece still occupies its slot but contributes
## nothing to the stat pipeline. Repairing it restores it to full.
##
## Stacking is by `(slot, base, name)` and only for materials and consumables.
## Equipment never stacks: two swords are two swords even with the same name.

const SLOTS: Array[String] = ["weapon", "armor", "ring", "talisman", "material", "consumable"]
const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "ring", "talisman"]
const DURABLE_SLOTS: Array[String] = ["weapon", "armor"]
const MAX_DURABILITY := {"weapon": 300.0, "armor": 400.0}
const STACK_LIMITS := {"material": 20, "consumable": 10}
## Points lost per swing with a weapon and per blow that damages an armoured body.
const WEAR_PER_STRIKE := 1.0
const WEAR_PER_HIT := 1.0
## A broken piece contributes nothing rather than a fraction: a broken sword is
## not a worse sword, it is a handle.
const BROKEN_MULT := 0.0
## Stones charged per point of missing durability, before rarity.
const REPAIR_RATE := 0.18
## Keys a saved item may carry, in the order they are written. Anything else is
## dropped, which is what makes a save canonical.
const FIELDS: Array[String] = [
	"id", "seed", "base", "base_name", "slot", "weapon_type", "ilvl", "rarity",
	"rarity_name", "name", "implicit", "base_damage", "armor", "mods", "value",
	"count", "durability",
]


static func is_known_slot(slot: String) -> bool:
	return SLOTS.has(slot)


static func is_equipment(slot: String) -> bool:
	return EQUIP_SLOTS.has(slot)


static func has_durability(item: Dictionary) -> bool:
	return DURABLE_SLOTS.has(String(item.get("slot", "")))


static func max_durability(slot: String) -> float:
	return float(MAX_DURABILITY.get(slot, 0.0))


## Current durability, or the slot's maximum when the field is missing (legacy
## items and freshly generated ones both read as undamaged).
static func durability_of(item: Dictionary) -> float:
	if not has_durability(item):
		return 0.0
	var maximum := max_durability(String(item.get("slot", "")))
	return clampf(float(item.get("durability", maximum)), 0.0, maximum)


static func durability_ratio(item: Dictionary) -> float:
	var maximum := max_durability(String(item.get("slot", "")))
	if maximum <= 0.0:
		return 1.0
	return clampf(durability_of(item) / maximum, 0.0, 1.0)


static func is_broken(item: Dictionary) -> bool:
	return has_durability(item) and durability_of(item) <= 0.0


## What a broken piece multiplies its contribution by. Everything else is 1.0.
static func condition_mult(item: Dictionary) -> float:
	return BROKEN_MULT if is_broken(item) else 1.0


## A worn copy with `amount` fewer points. Never below zero, never above max.
static func wear(item: Dictionary, amount: float) -> Dictionary:
	var out := normalize_item(item)
	if out.is_empty() or not has_durability(out) or amount <= 0.0:
		return out
	out["durability"] = maxf(0.0, durability_of(out) - amount)
	return out


static func repair(item: Dictionary) -> Dictionary:
	var out := normalize_item(item)
	if out.is_empty() or not has_durability(out):
		return out
	out["durability"] = max_durability(String(out["slot"]))
	return out


## Stones to mend every worn piece currently equipped. Worn rarity costs more,
## because a treasure blade deserves a better smith.
static func repair_cost(equipment: Dictionary) -> int:
	var total := 0
	for slot in DURABLE_SLOTS:
		var value: Variant = equipment.get(slot, {})
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item := normalize_item(value)
		if item.is_empty() or not has_durability(item):
			continue
		var missing := max_durability(slot) - durability_of(item)
		if missing <= 0.01:
			continue
		var cost: float = ceil(missing * REPAIR_RATE * (1.0 + 0.2 * int(item["rarity"])))
		total += maxi(1, int(cost))
	return total


## How many of this item fit in one slot. Equipment is always one.
static func stack_limit(item: Dictionary) -> int:
	return int(STACK_LIMITS.get(String(item.get("slot", "")), 1))


## Two items share a stack only when they are the same kind of thing: same slot,
## same base and same display name. Two rolls of the same ore merge; two swords
## never do.
static func stack_key(item: Dictionary) -> String:
	if stack_limit(item) <= 1:
		return ""
	return "%s|%s|%s" % [String(item.get("slot", "")), String(item.get("base", "")), String(item.get("name", ""))]


static func can_stack(a: Dictionary, b: Dictionary) -> bool:
	var key := stack_key(a)
	return key != "" and key == stack_key(b)


# --- canonical form ----------------------------------------------------------

## The one shape every item is stored and compared in. Missing fields take safe
## defaults, values out of range are clamped, unknown fields are dropped and the
## key order is fixed.
static func normalize_item(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = value
	var out: Dictionary = {}
	out["id"] = String(data.get("id", ""))
	out["seed"] = int(data.get("seed", 0))
	out["base"] = String(data.get("base", ""))
	out["base_name"] = String(data.get("base_name", data.get("name", "")))
	out["slot"] = String(data.get("slot", ""))
	out["weapon_type"] = String(data.get("weapon_type", ""))
	out["ilvl"] = maxi(1, int(data.get("ilvl", 1)))
	out["rarity"] = clampi(int(data.get("rarity", 0)), 0, ItemGen.RARITY_NAMES.size() - 1)
	out["rarity_name"] = ItemGen.RARITY_NAMES[int(out["rarity"])]
	out["name"] = String(data.get("name", out["base_name"]))
	out["implicit"] = String(data.get("implicit", ""))
	out["base_damage"] = maxf(0.0, float(data.get("base_damage", 0.0)))
	out["armor"] = maxf(0.0, float(data.get("armor", 0.0)))
	out["mods"] = _normalize_mods(data.get("mods", []))
	out["value"] = maxi(0, int(data.get("value", 0)))
	out["count"] = clampi(int(data.get("count", 1)), 1, 999)
	if DURABLE_SLOTS.has(String(out["slot"])):
		var maximum := max_durability(String(out["slot"]))
		out["durability"] = clampf(float(data.get("durability", maximum)), 0.0, maximum)
	return out


static func _normalize_mods(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for mod in (value as Array):
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = mod
		out.append({
			"id": String(data.get("id", "")),
			"stat": String(data.get("stat", "")),
			"value": float(data.get("value", 0.0)),
			"text": String(data.get("text", "")),
		})
	return out


## Whether an item may exist in a player's possession at all. An item without a
## stable id cannot be referenced by a save, so it is not an item.
static func is_valid_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if not is_stable_id(String(item.get("id", ""))):
		return false
	if not is_known_slot(String(item.get("slot", ""))):
		return false
	if String(item.get("name", "")) == "":
		return false
	return int(item.get("count", 1)) >= 1


## A save references an item by id, so an id must be an "item." name with at
## least one non-empty segment after the prefix.
static func is_stable_id(id: String) -> bool:
	var parts := id.split(".", false)
	if parts.size() < 3 or String(parts[0]) != "item":
		return false
	for i in range(1, parts.size()):
		if String(parts[i]) == "":
			return false
	return true


# --- containers --------------------------------------------------------------

## Adds an item to an inventory, filling existing stacks first and starting new
## ones when a stack is full. Returns a new array; the input is untouched.
static func add_to_inventory(inventory: Array, item: Variant) -> Array:
	var out: Array = inventory.duplicate(true)
	var incoming := normalize_item(item)
	if not is_valid_item(incoming):
		return out
	var limit := stack_limit(incoming)
	if limit <= 1:
		out.append(incoming)
		return out
	var key := stack_key(incoming)
	var left := int(incoming["count"])
	for i in out.size():
		if left <= 0:
			break
		var entry := normalize_item(out[i])
		if entry.is_empty() or stack_key(entry) != key:
			continue
		var room := limit - int(entry["count"])
		if room <= 0:
			continue
		var moved := mini(room, left)
		entry["count"] = int(entry["count"]) + moved
		out[i] = entry
		left -= moved
	while left > 0:
		var chunk := incoming.duplicate(true)
		chunk["count"] = mini(limit, left)
		out.append(chunk)
		left -= int(chunk["count"])
	return out


## Sanitises a whole inventory: drops malformed entries, normalises the rest and
## merges everything that should have been one stack.
static func normalize_inventory(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in (value as Array):
		var item := normalize_item(entry)
		if not is_valid_item(item):
			continue
		out = add_to_inventory(out, item)
	return out


## Sanitises an equipment map. A piece whose slot does not match its key, or
## which cannot be represented, is dropped rather than trusted.
static func normalize_equipment(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	var data: Dictionary = value
	for slot in EQUIP_SLOTS:
		var item_value: Variant = data.get(slot, {})
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item := normalize_item(item_value)
		if not is_valid_item(item) or String(item["slot"]) != slot:
			continue
		out[slot] = item
	return out


static func inventory_to_save(value: Variant) -> Array:
	return normalize_inventory(value)


static func equipment_to_save(value: Variant) -> Dictionary:
	return normalize_equipment(value)


# --- reading -----------------------------------------------------------------

## The save form of one item, and the only entry point a save should use.
static func to_save(item: Dictionary) -> Dictionary:
	return normalize_item(item)


## A stored item, normalised and validated. Returns {} for anything that is not
## an item a save may contain.
static func from_save(value: Variant) -> Dictionary:
	var item := normalize_item(value)
	return item if is_valid_item(item) else {}


static func total_count(inventory: Array) -> int:
	var total := 0
	for entry in inventory:
		var item := normalize_item(entry)
		if not is_valid_item(item):
			continue
		total += maxi(0, int(item.get("count", 0)))
	return total


## "Spirit Herb x3" for a stack, the plain name for a single item.
static func label(item: Dictionary) -> String:
	var name := String(item.get("name", "?"))
	var count := int(item.get("count", 1))
	return name if count <= 1 else "%s x%d" % [name, count]
