class_name Passives
extends RefCounted
## Passive rules: who may learn one, when it counts, and how they interact.
##
## Ownership and activation are separate on purpose. A quest or an inheritance can
## hand you a passive your body cannot use yet; it is owned, dormant, and wakes by
## itself when you qualify. That keeps fixed rewards from being lost to a
## requirement they were never meant to gate.
##
## Conflicts resolve **first acquired wins**: the earlier passive in the owned
## list stays active and the later one is dormant. Order is stable because it is
## the order the save already stores.

const WOUNDED_RATIO := 0.35


static func all() -> Array:
	return DB.passives


static func find(id: String) -> Dictionary:
	return DB.passive(id)


## Requirement check, returning a reason fit for a toast:
## {"ok": bool, "reason": "STR 14"}.
static func meets_requirements(passive: Dictionary, state: Dictionary) -> Dictionary:
	var req: Dictionary = passive.get("requires", {})
	if req.is_empty():
		return {"ok": true, "reason": ""}
	var min_realm := int(req.get("min_realm", 0))
	if min_realm > 0 and int(state.get("realm", 0)) < min_realm:
		return {"ok": false, "reason": "realm %d" % min_realm}
	var min_tier := int(req.get("min_physique_tier", 0))
	if min_tier > 0 and int(state.get("physique_tier", 0)) < min_tier:
		return {"ok": false, "reason": "physique tier %d" % min_tier}
	var affinity := String(req.get("affinity", ""))
	if affinity != "":
		var affinities: Array = state.get("affinities", [])
		if not affinities.has(affinity):
			return {"ok": false, "reason": "%s affinity" % affinity}
	var min_attr: Dictionary = req.get("min_attr", {})
	var attrs: Variant = state.get("attrs", null)
	for key in min_attr.keys():
		var have := 0
		if attrs != null:
			have = (attrs as Attributes).get_attr(String(key))
		var need := int(min_attr[key])
		if have < need:
			return {"ok": false, "reason": "%s %d" % [String(key).to_upper(), need]}
	return {"ok": true, "reason": ""}


## Situational conditions. These are recomputed on state change, not per frame.
static func condition_met(passive: Dictionary, state: Dictionary) -> Dictionary:
	var cond: Dictionary = passive.get("condition", {})
	if cond.is_empty():
		return {"ok": true, "reason": ""}
	if bool(cond.get("wounded", false)) and float(state.get("hp_ratio", 1.0)) >= WOUNDED_RATIO:
		return {"ok": false, "reason": "wounded"}
	if cond.has("karma_above") and int(state.get("karma", 0)) < int(cond["karma_above"]):
		return {"ok": false, "reason": "karma above %d" % int(cond["karma_above"])}
	if cond.has("karma_below") and int(state.get("karma", 0)) > int(cond["karma_below"]):
		return {"ok": false, "reason": "karma below %d" % int(cond["karma_below"])}
	return {"ok": true, "reason": ""}


## The passives that actually apply right now, in owned order.
static func resolve(owned: Array, state: Dictionary) -> Array:
	var active: Array = []
	for id in issues(owned, state, true):
		active.append(String(id))
	return active


## Owned passives that are not applying, with the reason. `only_active` lets
## resolve() share the same walk without allocating the reason dictionaries.
static func issues(owned: Array, state: Dictionary, only_active: bool = false) -> Array:
	var active: Array = []
	var dormant: Array = []
	for id_value in owned:
		var id := String(id_value)
		var passive := find(id)
		if passive.is_empty():
			continue
		var req := meets_requirements(passive, state)
		if not bool(req["ok"]):
			if not only_active:
				dormant.append({"id": id, "reason": String(req["reason"])})
			continue
		var cond := condition_met(passive, state)
		if not bool(cond["ok"]):
			if not only_active:
				dormant.append({"id": id, "reason": String(cond["reason"])})
			continue
		# Conflicts are declared on either side: content authors only need one
		# direction, and the earlier acquisition still wins.
		var blocked := ""
		for other in active:
			var other_id := String(other)
			var other_passive := find(other_id)
			if passive.get("conflicts", []).has(other_id) or other_passive.get("conflicts", []).has(id):
				blocked = other_id
				break
		if blocked != "":
			if not only_active:
				var other_name := String(find(blocked).get("name", blocked))
				dormant.append({"id": id, "reason": "conflicts with %s" % other_name})
			continue
		active.append(id)
	return active if only_active else dormant


## Bonus mods granted by pairs of active passives. Additive like every other
## source, so a synergy cannot break the pipeline's floors or caps.
static func synergy_mods(active: Array) -> Array:
	var out: Array = []
	for id_value in active:
		var passive := find(String(id_value))
		var synergy: Dictionary = passive.get("synergy", {})
		if synergy.is_empty():
			continue
		if active.has(String(synergy.get("with", ""))):
			for mod in synergy.get("mods", []):
				out.append(mod)
	return out
