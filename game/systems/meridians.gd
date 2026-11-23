class_name Meridians
extends RefCounted
## The twelve primary meridians: body content that Qi flows through.
##
## A meridian is opened at the hall by paying Qi (a fraction of capacity) and
## spirit stones. Opening is permanent, raises Qi capacity by a flat percentage
## and adds one mod through the same stat pipeline as everything else. The model
## is deliberately ordered: you open the low-realm channels before the high ones,
## so progression is legible rather than a shopping list.

const OPEN_QI_PCT := 0.35
const CAPACITY_PER_MERIDIAN := 0.04
const MAX_CONTAMINATION := 100.0
const CLEANSE_COST := 30
const BLOOD_CONTAMINATION_PER_SECOND := 0.8
const DEVIATION_CONTAMINATION := 12.0


static func all() -> Array:
	return DB.meridians


static func find(id: String) -> Dictionary:
	return DB.meridian(id)


static func count(ids: Array) -> int:
	var unique := {}
	for id in ids:
		if not find(String(id)).is_empty():
			unique[String(id)] = true
	return unique.size()


## Qi capacity is 1.0 with no meridians and +4% each, in the same multiplicative
## pipeline as the rest of the character.
static func capacity_mult(ids: Array) -> float:
	return 1.0 + CAPACITY_PER_MERIDIAN * float(count(ids))


## Flat mods for every opened meridian, aggregated for StatBlock.
static func bonus_mods(ids: Array) -> Array:
	var mods: Array = []
	for id in ids:
		var meridian := find(String(id))
		if meridian.is_empty():
			continue
		mods.append({"stat": String(meridian.get("stat", "")), "value": float(meridian.get("value", 0.0))})
	return mods


static func can_open(id: String, opened: Array, realm: int) -> Dictionary:
	var meridian := find(id)
	if meridian.is_empty():
		return {"ok": false, "reason": "unknown meridian"}
	if opened.has(id):
		return {"ok": false, "reason": "already open"}
	var need_realm := int(meridian.get("realm", 1))
	if realm < need_realm:
		return {"ok": false, "reason": "realm %d" % need_realm}
	return {"ok": true, "reason": ""}


## The next meridian in data order that the character is allowed to open.
static func next_available(opened: Array, realm: int) -> Dictionary:
	for meridian in all():
		var id := String(meridian.get("id", ""))
		if bool(can_open(id, opened, realm)["ok"]):
			return meridian
	return {}


static func stone_cost(id: String) -> int:
	return int(find(id).get("stones", 0))


static func qi_cost(id: String, qi_cap: float) -> float:
	if find(id).is_empty():
		return 0.0
	return maxf(0.0, qi_cap) * OPEN_QI_PCT
