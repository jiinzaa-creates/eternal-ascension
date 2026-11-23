class_name Origin
extends RefCounted
## Character origins: the circumstances a cultivator starts with.
##
## An origin is content (`res://data/origins.json`); this node only normalises it
## and cycles the choice. Starting circumstances are deliberately small — a purse,
## a starting method and at most one passive — because a background that decides
## the build would make the formation points pointless.

const DEFAULT_METHOD := "method.traditional"
const MAX_STONES := 200


## Normalises one origin entry. Missing fields fall back to harmless defaults so a
## malformed origin starts nobody with negative stones or an empty condition.
static func effects(origin: Dictionary) -> Dictionary:
	return {
		"id": String(origin.get("id", "")),
		"name": String(origin.get("name", "")),
		"blurb": String(origin.get("blurb", "")),
		"condition": String(origin.get("condition", "")),
		"stones": clampi(int(origin.get("stones", 0)), 0, MAX_STONES),
		"method_id": String(origin.get("method_id", DEFAULT_METHOD)),
		"passive": String(origin.get("passive", "")),
	}


static func index_of(origins: Array, id: String) -> int:
	for i in origins.size():
		if String((origins[i] as Dictionary).get("id", "")) == id:
			return i
	return 0


## Next origin id, wrapping. An unknown current id lands on the first origin.
static func next(origins: Array, current_id: String, direction: int = 1) -> String:
	if origins.is_empty():
		return current_id
	var start := index_of(origins, current_id)
	var index := wrapi(start + direction, 0, origins.size())
	return String((origins[index] as Dictionary).get("id", ""))


## One line for the creation screen and the opening toast.
static func summary(origin: Dictionary) -> String:
	var fx := effects(origin)
	var parts: Array[String] = []
	parts.append("%d spirit stones" % int(fx["stones"]))
	if String(fx["passive"]) != "":
		parts.append(String(DB.passive(String(fx["passive"])).get("name", fx["passive"])))
	var method: Dictionary = DB.by_id("method", String(fx["method_id"]))
	parts.append(String(method.get("name", "Traditional Qi Refinement")))
	return "%s — %s" % [String(fx["name"]), ", ".join(parts)]
