class_name WorldDelta
extends RefCounted
## What the world seed cannot know.
##
## Chunks regenerate identically from the seed, so the only state a chunk needs
## is the difference between what the seed says and what has happened: which
## resources were taken, when, and how long they take to come back.
##
## Regrowth is background simulation without a simulation loop: nothing ticks,
## and a resource is spent only while the clock is still inside its window.
## Herbs return in days; a searched ruin is gone for good.

const HERB_REGROW_DAYS := 3
## Long enough to be permanent in practice, without a second storage kind.
const PERMANENT := 100000

## "cx,cy" -> { resource id: {"day": int, "window": int} }
var spent: Dictionary = {}


static func key_for(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func mark_spent(coord: Vector2i, id: String, day: int, window_days: int = HERB_REGROW_DAYS) -> void:
	var key := key_for(coord)
	if not spent.has(key):
		spent[key] = {}
	(spent[key] as Dictionary)[id] = {
		"day": maxi(1, day),
		"window": maxi(1, window_days),
	}


## Reads an entry, accepting the day-only form written by earlier builds.
func _entry(coord: Vector2i, id: String) -> Dictionary:
	var entries: Variant = spent.get(key_for(coord), {})
	if typeof(entries) != TYPE_DICTIONARY:
		return {}
	var entry: Variant = (entries as Dictionary).get(id, null)
	if typeof(entry) == TYPE_DICTIONARY:
		return entry
	if typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT:
		return {"day": int(entry), "window": HERB_REGROW_DAYS}
	return {}


## Whether the resource is still inside its regrow window. Pure: it never prunes.
func is_spent(coord: Vector2i, id: String, day: int) -> bool:
	var entry := _entry(coord, id)
	if entry.is_empty():
		return false
	return day - int(entry["day"]) < int(entry["window"])


## Drops entries whose regrow window has passed, and chunks that became empty.
## Called when a chunk streams in, so the saved delta cannot grow forever.
func prune(coord: Vector2i, day: int) -> int:
	var key := key_for(coord)
	if not spent.has(key):
		return 0
	var entries: Dictionary = spent[key]
	var removed := 0
	for id in entries.keys():
		var entry := _entry(coord, String(id))
		if entry.is_empty() or day - int(entry["day"]) >= int(entry["window"]):
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
			var raw: Variant = (entries as Dictionary)[id]
			if typeof(raw) == TYPE_DICTIONARY:
				clean[String(id)] = {
					"day": int((raw as Dictionary).get("day", 1)),
					"window": int((raw as Dictionary).get("window", HERB_REGROW_DAYS)),
				}
			else:
				# Earliest format: the value was the day, with the herb window.
				clean[String(id)] = {"day": int(raw), "window": HERB_REGROW_DAYS}
		if not clean.is_empty():
			delta.spent[String(key)] = clean
	return delta
