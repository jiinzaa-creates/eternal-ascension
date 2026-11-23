class_name Techniques
extends RefCounted
## Who may learn a technique, and how observation turns into knowledge.
##
## Grants (starting kit, manuals, inheritance, quest rewards) deliberately bypass
## requirements, exactly like passives: a reward must never be lost because the
## character was not ready for it. Teachers and observation are voluntary and do
## enforce the data's requirements.
##
## `requirements.physique` in technique data is a legacy bloodline marker, not a
## physique id, so it is not checked here.

const OBSERVE_REQUIRED := 3


static func find(id: String) -> Dictionary:
	return DB.technique(id)


static func can_learn(id: String, state: Dictionary) -> Dictionary:
	var tech := find(id)
	if tech.is_empty():
		return {"ok": false, "reason": "unknown technique"}
	var req: Dictionary = tech.get("requirements", {})
	var min_realm := int(req.get("realm", 0))
	if int(state.get("realm", 0)) < min_realm:
		return {"ok": false, "reason": "realm %d" % min_realm}
	var attrs: Variant = state.get("attrs", null)
	for key in Attributes.KEYS:
		if not req.has(key):
			continue
		var have := 0
		if attrs != null:
			have = (attrs as Attributes).get_attr(String(key))
		var need := int(req[key])
		if have < need:
			return {"ok": false, "reason": "%s %d" % [String(key).to_upper(), need]}
	return {"ok": true, "reason": ""}


## Fraction of the way to learning by observation, 0.0–1.0.
static func observation_progress(count: int) -> float:
	return clampf(float(count) / float(OBSERVE_REQUIRED), 0.0, 1.0)
