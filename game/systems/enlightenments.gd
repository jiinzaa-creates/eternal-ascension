class_name Enlightenments
extends RefCounted
## Sudden comprehension, made concrete.
##
## Insight is not bought and not trained: it arrives when enough understanding
## has accumulated and the character qualifies for one of the insights still
## unlearned. The roll is deterministic (`Rng` stream keyed by realm and the
## attempt counter), so two identical runs see the same epiphany at the same
## moment.
##
## An enlightenment is permanent and cumulative: every learned insight adds its
## mods to the one stat pipeline. There is no activation state, because an
## insight cannot be forgotten.

static func all() -> Array:
	return DB.enlightenments


static func find(id: String) -> Dictionary:
	return DB.enlightenment(id)


## Requirement check, returning a reason fit for a tooltip:
## {"ok": bool, "reason": "realm 4"}.
static func eligible(id: String, state: Dictionary) -> Dictionary:
	var entry := find(id)
	if entry.is_empty():
		return {"ok": false, "reason": "unknown insight"}
	var req: Dictionary = entry.get("requires", {})
	var min_realm := int(req.get("realm", 0))
	if int(state.get("realm", 0)) < min_realm:
		return {"ok": false, "reason": "realm %d" % min_realm}
	var method := String(req.get("method", ""))
	if method != "" and String(state.get("method", "")) != method:
		return {"ok": false, "reason": "%s path" % method}
	var dao_req := String(req.get("dao", ""))
	if dao_req != "":
		var dao_stages: Dictionary = state.get("dao_stages", {})
		if int(dao_stages.get(dao_req, 0)) < int(req.get("stage", 1)):
			return {"ok": false, "reason": "%s stage %d" % [dao_req, int(req.get("stage", 1))]}
	var min_int := int(req.get("min_int", 0))
	if min_int > 0:
		var attrs: Variant = state.get("attrs", null)
		var have := 0
		if attrs != null:
			have = (attrs as Attributes).get_attr("int")
		if have < min_int:
			return {"ok": false, "reason": "INT %d" % min_int}
	return {"ok": true, "reason": ""}


## Every insight currently within reach and not yet learned.
static func available(state: Dictionary, owned: Array = []) -> Array:
	var out: Array = []
	for entry in all():
		var id := String(entry.get("id", ""))
		if id == "" or owned.has(id):
			continue
		if bool(eligible(id, state)["ok"]):
			out.append(id)
	return out


## Weighted pick among eligible, unlearned insights. Returns "" when nothing is
## in reach; the caller keeps the comprehension rather than wasting it.
static func pick(generator: RandomNumberGenerator, state: Dictionary, owned: Array = []) -> String:
	var options: Array = []
	var weights: Array = []
	for id_value in available(state, owned):
		var id := String(id_value)
		options.append(id)
		weights.append(maxi(1, int(find(id).get("weight", 1))))
	if options.is_empty():
		return ""
	var index := int(Rng.pick_weighted(weights, generator))
	if index < 0 or index >= options.size():
		return ""
	return String(options[index])


## Combined mods of every learned insight, for StatBlock.
static func mods(owned: Array) -> Array:
	var out: Array = []
	for id_value in owned:
		var entry := find(String(id_value))
		for mod in entry.get("mods", []):
			out.append(mod)
	return out


## Learning is idempotent and rejects unknown ids, so a corrupt save cannot add
## a phantom insight.
static func learn(owned: Array, id: String) -> bool:
	if id == "" or find(id).is_empty() or owned.has(id):
		return false
	owned.append(id)
	return true


static func count_total() -> int:
	return all().size()


static func known_names(owned: Array) -> Array:
	var out: Array = []
	for id_value in owned:
		var entry := find(String(id_value))
		if not entry.is_empty():
			out.append(String(entry.get("name", id_value)))
	return out
