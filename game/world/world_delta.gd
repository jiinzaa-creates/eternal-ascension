class_name WorldDelta
extends RefCounted
## What the world seed cannot know.
##
## Chunks regenerate identically from the seed, so the only state a chunk needs
## is the difference between what the seed says and what has happened: which
## resources were harvested, and on which day. That is a chunk delta.
##
## Regrowth is background simulation without a simulation loop: nothing ticks,
## and a resource is spent only while the clock is still inside its regrow
## window. Walking away from a harvested herb and back cannot resurrect it; four
## days later it is simply back.

const HERB_REGROW_DAYS := 3

## "cx,cy" -> { resource id: day it was spent }
var spent: Dictionary = {}


static func key_for(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func mark_spent(coord: Vector2i, id: String, day: int) -> void:
	var key := key_for(coord)
	if not spent.has(key):
		spent[key] = {}
	(spent[key] as Dictionary)[id] = maxi(1, day)


## Whether the resource is still inside its regrow window. Pure: it never prunes.
func is_spent(coord: Vector2i, id: String, day: int) -> bool:
	var entries: Variant = spent.get(key_for(coord), {})
	if typeof(entries) != TYPE_DICTIONARY:
		return false
	if not (entries as Dictionary).has(id):
		return false
	return day - int((entries as Dictionary)[id]) < HERB_REGROW_DAYS


## Drops entries whose regrow window has passed, and chunks that became empty.
## Called when a chunk streams in, so the saved delta cannot grow forever.
func prune(coord: Vector2i, day: int) -> int:
	var key := key_for(coord)
	if not spent.has(key):
		return 0
	var entries: Dictionary = spent[key]
	var removed := 0
	for id in entries.keys():
		if day - int(entries[id]) >= HERB_REGROW_DAYS:
			entries.erase(id)
			removed += 1
	if entries.is_empty():
		spent.erase(key)
	return removed


func chunk_count() -> int:
	return spent.size()


func total_entries() -> int:
	var total := 0
	for key in spent.keys():
		total += (spent[key] as Dictionary).size()
	return total


func to_dict() -> Dictionary:
	return spent.duplicate(true)


static func from_dict(data: Dictionary) -> WorldDelta:
	var delta := WorldDelta.new()
	for key in data.keys():
		var entries: Variant = data[key]
		if typeof(entries) != TYPE_DICTIONARY:
			continue
		var clean: Dictionary = {}
		for id in (entries as Dictionary).keys():
			clean[String(id)] = int((entries as Dictionary)[id])
		if not clean.is_empty():
			delta.spent[String(key)] = clean
	return delta
