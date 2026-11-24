class_name Party
extends RefCounted
## Who walks with you, and why.
##
## A party is a roster of stable NPC ids, in order. Order is not cosmetic: slot
## zero walks directly behind the player and the flanks follow from there, so
## the same roster always forms the same shape. Everything here is pure — the
## membership rules, the capacity rule and the formation — which is what lets a
## follower be tested without spawning a town.
##
## Capacity is not a constant: the caller passes the player's derived
## `StatBlock.party_slots()` (CHAR grows it), so the rule lives in one place and
## the number comes from the one stat pipeline.

## A hard ceiling on stored ids, so a corrupt save cannot grow the roster
## without bound even before capacity is consulted.
const MAX_SIZE := 8
## How far behind the player a follower walks, and how wide the formation is.
const FOLLOW_GAP := 58.0
## How far a companion will look for something to fight.
const ENGAGE_RANGE := 280.0
## Where a companion stops and strikes.
const STRIKE_REACH := 42.0
## The shove a companion's blow carries.
const STRIKE_KNOCK := 130.0


## A body only follows someone it trusts. This is M50's friend band, reused
## rather than restated: the relationship graph is the one authority on bonds.
static func willing(bond_score: int) -> bool:
	return Relationships.warns(bond_score)


## Whether this person may join. The reason is written for the player, and an
## empty reason means yes.
static func can_recruit(roster: Array, npc_id: String, bond_score: int, slots: int) -> Dictionary:
	if npc_id == "":
		return {"ok": false, "reason": "There is nobody to ask."}
	if has(roster, npc_id):
		return {"ok": false, "reason": "is already with you."}
	if roster.size() >= maxi(0, slots):
		return {"ok": false, "reason": "has no room in the party."}
	if not willing(bond_score):
		return {"ok": false, "reason": "does not trust you that far yet."}
	return {"ok": true, "reason": ""}


static func has(roster: Array, npc_id: String) -> bool:
	return npc_id != "" and roster.has(npc_id)


## Appends a new member. Refuses an empty id, a duplicate or a roster beyond the
## hard ceiling; capacity is a recruitment rule, not a storage rule, so a save
## that already holds a full roster still loads.
static func add(roster: Array, npc_id: String) -> bool:
	if npc_id == "" or roster.has(npc_id) or roster.size() >= MAX_SIZE:
		return false
	roster.append(npc_id)
	return true


static func remove(roster: Array, npc_id: String) -> bool:
	var index := roster.find(npc_id)
	if index < 0:
		return false
	roster.remove_at(index)
	return true


static func index_of(roster: Array, npc_id: String) -> int:
	return roster.find(npc_id)


## Read back a save without trusting it: unknown shapes become an empty roster,
## empty or duplicate ids are dropped, and the ceiling still applies.
static func sanitize(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		# JSON may hand back a number for an id; `str()` accepts either shape.
		var id := str(value)
		if id == "" or out.has(id) or out.size() >= MAX_SIZE:
			continue
		out.append(id)
	return out


## Slot zero is directly behind the player; the next two take the flanks; any
## further members widen the arc. Pure and deterministic, so the shape of a
## party is testable without a scene.
static func follow_offset(index: int, facing: Vector2) -> Vector2:
	var dir := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	var back := -dir
	var side := Vector2(-back.y, back.x)
	var slot := maxi(0, index)
	if slot == 0:
		return back * FOLLOW_GAP
	if slot == 1:
		return back * (FOLLOW_GAP * 0.8) + side * (FOLLOW_GAP * 0.7)
	if slot == 2:
		return back * (FOLLOW_GAP * 0.8) - side * (FOLLOW_GAP * 0.7)
	var lane := 1.0 if slot % 2 == 1 else -1.0
	return back * (FOLLOW_GAP + float(slot - 2) * 20.0) + side * lane * (FOLLOW_GAP * 0.9)


static func slots_label(count: int, slots: int) -> String:
	return "%d/%d" % [count, maxi(0, slots)]
