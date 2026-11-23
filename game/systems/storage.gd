class_name Storage
extends RefCounted
## The settlement storehouse.
##
## Storage is a second container with a hard limit, so hoarding has a cost and a
## full satchel is not the only consequence of greed. A move always transfers a
## whole stack: partial deposits would leave two half-stacks and a worse grid.
##
## The container is state, not a rule: `Items` still decides what an item may be,
## and every entry is re-normalised on load so a hand-edited save cannot smuggle
## a malformed item into the storehouse.

## Kinds (entries), not units: a stack of twenty ore is one shelf.
const CAPACITY := 60

var items: Array = []


## Re-normalises the shelves in place. Returns the number of entries dropped.
func sanitize() -> int:
	var before := items.size()
	items = Items.normalize_inventory(items)
	return before - items.size()


func slots_used() -> int:
	return items.size()


func is_full() -> bool:
	return items.size() >= CAPACITY


func has(item_id: String) -> bool:
	return index_of(item_id) >= 0


func index_of(item_id: String) -> int:
	for i in items.size():
		if String((items[i] as Dictionary).get("id", "")) == item_id:
			return i
	return -1


func item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	return items[index] as Dictionary


## Moves a whole satchel stack into the storehouse. Returns the satchel that
## results, so the caller never has to mutate the player's array by hand.
func deposit(inventory: Array, item_id: String) -> Dictionary:
	var bag := Items.normalize_inventory(inventory)
	var index := -1
	for i in bag.size():
		if String((bag[i] as Dictionary).get("id", "")) == item_id:
			index = i
			break
	if index < 0:
		return {"ok": false, "reason": "nothing of that kind in the satchel", "inventory": bag}
	var item: Dictionary = bag[index]
	var merged := Items.add_to_inventory(items, item)
	if merged.size() > CAPACITY:
		return {"ok": false, "reason": "the storehouse is full", "inventory": bag}
	items = merged
	bag.remove_at(index)
	return {"ok": true, "reason": "", "inventory": bag, "item": item}


## Moves a whole stored stack back into the satchel. The satchel has no hard
## limit, so a withdrawal can only fail when the shelf is empty.
func withdraw(inventory: Array, item_id: String) -> Dictionary:
	var bag := Items.normalize_inventory(inventory)
	var index := index_of(item_id)
	if index < 0:
		return {"ok": false, "reason": "nothing of that kind is stored", "inventory": bag}
	var item: Dictionary = items[index]
	items.remove_at(index)
	bag = Items.add_to_inventory(bag, item)
	return {"ok": true, "reason": "", "inventory": bag, "item": item}


func to_dict() -> Dictionary:
	return {"items": Items.inventory_to_save(items)}


func from_dict(data: Dictionary) -> void:
	items = Items.normalize_inventory(data.get("items", []))
