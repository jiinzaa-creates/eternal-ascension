class_name SkillBar
extends RefCounted
## Three quick-access bars of six slots each.
##
## A bar is a layout, never a curriculum: it may only hold techniques the body
## actually knows, so a slot can never promise an art the character cannot cast.
## Every function here is pure and works on a plain 18-entry array, which keeps
## assignment, swapping, pruning and cooldown display testable without a scene.
##
## The layout is saved as technique ids. Unknown or duplicated ids are dropped by
## `reconcile()`, so an old or corrupted save degrades to a valid bar instead of
## producing phantom slots.

const BAR_COUNT := 3
const SLOTS_PER_BAR := 6
const SLOT_COUNT := 18
## The short pause every technique leaves behind once its swing resolves. Each
## art's own cooldown runs beside it, so two different arts may follow one another
## while the first is still gathering.
const SWING_PAUSE := 0.1

const BAR_LABELS := ["I", "II", "III"]


static func empty_layout() -> Array:
	var layout: Array = []
	for i in SLOT_COUNT:
		layout.append("")
	return layout


## A copy padded or truncated to exactly 18 string slots.
static func copy_layout(layout: Array) -> Array:
	var next := empty_layout()
	for i in mini(layout.size(), SLOT_COUNT):
		next[i] = str(layout[i])
	return next


static func index_of(bar: int, slot: int) -> int:
	return clampi(bar, 0, BAR_COUNT - 1) * SLOTS_PER_BAR + clampi(slot, 0, SLOTS_PER_BAR - 1)


static func bar_of(index: int) -> int:
	return clampi(index, 0, SLOT_COUNT - 1) / SLOTS_PER_BAR


static func slot_of(index: int) -> int:
	return clampi(index, 0, SLOT_COUNT - 1) % SLOTS_PER_BAR


## The starting arrangement: known arts in learned order, six to a bar. Anything
## past eighteen slots stays known but off the bars, and Q still reaches it.
static func default_layout(known: Array) -> Array:
	var layout := empty_layout()
	var placed := 0
	for value in known:
		if placed >= SLOT_COUNT:
			break
		var tech_id := str(value)
		if tech_id == "" or layout.has(tech_id):
			continue
		layout[placed] = tech_id
		placed += 1
	return layout


## Keep only known, unique arts in the slots they already occupy. Gaps are kept,
## because an empty slot is a deliberate arrangement, not something to refill.
static func reconcile(layout: Array, known: Array) -> Array:
	var clean := empty_layout()
	var seen: Dictionary = {}
	for i in mini(layout.size(), SLOT_COUNT):
		var tech_id := str(layout[i])
		if tech_id == "" or seen.has(tech_id) or not known.has(tech_id):
			continue
		clean[i] = tech_id
		seen[tech_id] = true
	return clean


static func slot_tech(layout: Array, index: int) -> String:
	if index < 0 or index >= SLOT_COUNT or index >= layout.size():
		return ""
	return str(layout[index])


## Place an art, moving it out of any slot it already held: one art, one slot.
## An empty id clears the slot. Out-of-range indices change nothing.
static func assign(layout: Array, index: int, tech_id: String) -> Array:
	var next := copy_layout(layout)
	if index < 0 or index >= SLOT_COUNT:
		return next
	if tech_id != "":
		for i in SLOT_COUNT:
			if next[i] == tech_id:
				next[i] = ""
	next[index] = tech_id
	return next


## Drag and drop between two slots. Dropping onto an occupied slot swaps them.
static func swap(layout: Array, a: int, b: int) -> Array:
	var next := copy_layout(layout)
	if a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT or a == b:
		return next
	var hold: Variant = next[a]
	next[a] = next[b]
	next[b] = hold
	return next


static func find_slot(layout: Array, tech_id: String) -> int:
	if tech_id == "":
		return -1
	for i in mini(layout.size(), SLOT_COUNT):
		if str(layout[i]) == tech_id:
			return i
	return -1


static func bar_filled(layout: Array, bar: int) -> int:
	var count := 0
	for slot in SLOTS_PER_BAR:
		if slot_tech(layout, index_of(bar, slot)) != "":
			count += 1
	return count


## First filled slot within a bar, or -1 when the bar is empty.
static func first_filled(layout: Array, bar: int) -> int:
	for slot in SLOTS_PER_BAR:
		if slot_tech(layout, index_of(bar, slot)) != "":
			return slot
	return -1


## Known arts that are not on any bar, in learned order.
static func unplaced(known: Array, layout: Array) -> Array:
	var out: Array = []
	for value in known:
		var tech_id := str(value)
		if tech_id == "" or out.has(tech_id):
			continue
		if find_slot(layout, tech_id) >= 0:
			continue
		out.append(tech_id)
	return out


static func wrap_bar(bar: int, step: int) -> int:
	var current := clampi(bar, 0, BAR_COUNT - 1)
	return posmod(current + step, BAR_COUNT)


static func bar_label(bar: int) -> String:
	return String(BAR_LABELS[clampi(bar, 0, BAR_COUNT - 1)])


## How much of the cooldown is still left, 0.0–1.0, for the slot's sweep.
static func cooldown_ratio(left: float, total: float) -> float:
	if total <= 0.0:
		return 0.0
	return clampf(left / total, 0.0, 1.0)


## A tenth-second readout, empty once the art is ready (or nearly so).
static func cooldown_text(left: float) -> String:
	if left <= 0.05:
		return ""
	return "%.1fs" % left
