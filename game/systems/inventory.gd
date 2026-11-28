class_name Inventory
extends RefCounted
## The satchel as a grid, and the sort orders its cells can use.
##
## The inventory itself is still one flat array of canonical items (`Items`);
## this class never owns state. It gives that array a page-based 6x5 grid, the
## index arithmetic a cursor needs, and a small set of total orders. Every order
## is total: ties break on name, then stable id, then insertion index, so two
## runs that hold the same items always lay them out the same way.
##
## Sorting rewrites the satchel order itself rather than keeping a parallel view
## array, so the HUD, the shop and the grid cannot disagree about what index 4 is.

const COLS := 6
const ROWS := 5
const PAGE_SIZE := COLS * ROWS
const SORTS: Array[String] = ["recent", "slot", "rarity", "value", "name"]
const SORT_LABELS := {
	"recent": "Recent",
	"slot": "Slot",
	"rarity": "Rarity",
	"value": "Value",
	"name": "Name",
}
## Left to right in the grid: what a body can wear first, then what it carries.
const SLOT_ORDER := {
	"weapon": 0, "armor": 1, "ring": 2, "necklace": 3, "talisman": 4, "artifact": 5, "consumable": 6, "material": 7,
}
const SLOT_LABELS := {
	"weapon": "Weapon", "armor": "Armour", "ring": "Ring", "necklace": "Necklace", "talisman": "Talisman", "artifact": "Artifact",
	"material": "Material", "consumable": "Consumable",
}


static func is_sort_mode(mode: String) -> bool:
	return SORTS.has(mode)


## The next order in the cycle, wrapping back to the satchel's own order.
static func next_sort(mode: String) -> String:
	var index := SORTS.find(mode)
	if index < 0:
		return SORTS[0]
	return SORTS[(index + 1) % SORTS.size()]


static func sort_label(mode: String) -> String:
	return String(SORT_LABELS.get(mode, SORT_LABELS["recent"]))


static func slot_rank(item: Dictionary) -> int:
	return int(SLOT_ORDER.get(String(item.get("slot", "")), 99))


static func slot_label(item: Dictionary) -> String:
	return String(SLOT_LABELS.get(String(item.get("slot", "")), "Item"))


## A new array in the requested order. The input and its dictionaries are never
## mutated, so a caller can sort a copy without touching the satchel.
static func sort_entries(entries: Array, mode: String) -> Array:
	if not is_sort_mode(mode) or mode == "recent":
		return entries.duplicate(true)
	var decorated: Array = []
	for i in entries.size():
		if typeof(entries[i]) != TYPE_DICTIONARY:
			continue
		decorated.append({"item": entries[i], "index": i})
	decorated.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(a, b, mode))
	var out: Array = []
	for entry in decorated:
		out.append((entry as Dictionary)["item"])
	return out


## One order's comparison, with a total tie-break so no two entries can compare
## equal. Returns true when `a` comes before `b`.
static func _before(a: Dictionary, b: Dictionary, mode: String) -> bool:
	var left: Dictionary = a["item"]
	var right: Dictionary = b["item"]
	match mode:
		"slot":
			if slot_rank(left) != slot_rank(right):
				return slot_rank(left) < slot_rank(right)
		"rarity":
			pass
		"value":
			pass
		"name":
			var left_name := String(left.get("name", "")).to_lower()
			var right_name := String(right.get("name", "")).to_lower()
			if left_name != right_name:
				return left_name < right_name
		_:
			pass
	# From here the orders share their remaining keys: rarity, level, name, id.
	if int(left.get("rarity", 0)) != int(right.get("rarity", 0)):
		return int(left.get("rarity", 0)) > int(right.get("rarity", 0))
	if int(left.get("ilvl", 1)) != int(right.get("ilvl", 1)):
		return int(left.get("ilvl", 1)) > int(right.get("ilvl", 1))
	if mode != "name":
		var left_name := String(left.get("name", "")).to_lower()
		var right_name := String(right.get("name", "")).to_lower()
		if left_name != right_name:
			return left_name < right_name
	var left_id := String(left.get("id", ""))
	var right_id := String(right.get("id", ""))
	if left_id != right_id:
		return left_id < right_id
	return int(a["index"]) < int(b["index"])


# --- grid --------------------------------------------------------------------

static func page_count(entries: Array) -> int:
	return maxi(1, int(ceil(float(entries.size()) / float(PAGE_SIZE))))


static func page_of(index: int) -> int:
	return maxi(0, index) / PAGE_SIZE


## One page of cells, never more than `PAGE_SIZE` entries.
static func page_slice(entries: Array, page: int) -> Array:
	var last := page_count(entries) - 1
	var wanted := clampi(page, 0, last)
	var start := wanted * PAGE_SIZE
	return entries.slice(start, mini(entries.size(), start + PAGE_SIZE))


static func cell_of(index: int) -> Vector2i:
	var slot := maxi(0, index) % PAGE_SIZE
	return Vector2i(slot % COLS, slot / COLS)


## The cursor's next index for one arrow press, clamped to what exists.
static func move_cursor(index: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(maxi(0, index) + delta, 0, count - 1)


## Index of a cell on a page, or -1 when the grid has no item there.
static func index_at(page: int, cell: Vector2i, count: int) -> int:
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return -1
	var index := maxi(0, page) * PAGE_SIZE + cell.y * COLS + cell.x
	return index if index < count else -1
