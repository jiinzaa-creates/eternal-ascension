class_name Boss
extends RefCounted
## Boss rules: phases, their multipliers, their adds and the reward.
##
## A boss is an ordinary enemy body with a longer health bar, a set of phases
## keyed to health thresholds and a reward paid once. Everything here is pure
## data handling: the body asks which phase it is in and what that phase
## multiplies, and the scene root pays the reward when the death signal fires.
##
## Thresholds are fractions of maximum health, read from the top down: with
## thresholds `[0.66, 0.33]` a body above 66% is in phase 0, between 66% and 33%
## in phase 1, and at or below 33% in the last phase. The last phase is never
## entered by falling through a threshold, so there is always one more phase
## than there are thresholds.

const DEFAULTS := {
	"id": "boss.unknown",
	"name": "Nameless Warden",
	"archetype": "sentinel",
	"color": "#b08ae0",
	"hp_mult": 6.0,
	"damage_mult": 1.4,
	"poise_mult": 1.8,
	"ilvl_bonus": 2,
	"thresholds": [0.5],
	"phases": [],
	"reward": {"stones": 100, "rarity": 2, "title": ""},
	"telegraph_color": "#c090ff",
	"intro": "",
}

const MAX_THRESHOLDS := 3
const PHASE_KEYS: Array[String] = ["damage_mult", "speed_mult", "cooldown_mult"]


static func defaults() -> Dictionary:
	return (DEFAULTS as Dictionary).duplicate(true)


## A complete boss definition. Thresholds are clamped, sorted and de-duplicated;
## phases are padded or trimmed to match, so `phase_index()` can never point
## past the end of the phase table.
static func profile(entry: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	for key in out.keys():
		if entry.has(key):
			out[key] = entry[key]
	out["id"] = String(out.get("id", "boss.unknown"))
	out["name"] = String(out.get("name", "Nameless Warden"))
	var archetype := String(out.get("archetype", "sentinel"))
	out["archetype"] = archetype if Beasts.ARCHETYPES.has(archetype) else "sentinel"
	out["color"] = String(out.get("color", "#b08ae0"))
	out["hp_mult"] = clampf(float(out.get("hp_mult", 6.0)), 0.5, 60.0)
	out["damage_mult"] = clampf(float(out.get("damage_mult", 1.4)), 0.2, 6.0)
	out["poise_mult"] = clampf(float(out.get("poise_mult", 1.8)), 0.2, 8.0)
	out["ilvl_bonus"] = clampi(int(out.get("ilvl_bonus", 2)), 0, 12)
	out["thresholds"] = _thresholds(out.get("thresholds", []))
	out["phases"] = _phases(out.get("phases", []), (out["thresholds"] as Array).size() + 1)
	out["reward"] = _reward(out.get("reward", {}))
	out["telegraph_color"] = String(out.get("telegraph_color", "#c090ff"))
	out["intro"] = String(out.get("intro", ""))
	return out


static func _thresholds(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in (value as Array):
		var fraction := clampf(float(item), 0.02, 0.98)
		if not out.has(fraction):
			out.append(fraction)
	out.sort()
	out.reverse()
	if out.size() > MAX_THRESHOLDS:
		out = out.slice(0, MAX_THRESHOLDS)
	return out


static func _phases(value: Variant, count: int) -> Array:
	var given: Array = value if typeof(value) == TYPE_ARRAY else []
	var out: Array = []
	for i in count:
		var source: Dictionary = {}
		if i < given.size() and typeof(given[i]) == TYPE_DICTIONARY:
			source = given[i]
		out.append({
			"name": String(source.get("name", "Phase %d" % (i + 1))),
			"damage_mult": clampf(float(source.get("damage_mult", 1.0)), 0.1, 6.0),
			"speed_mult": clampf(float(source.get("speed_mult", 1.0)), 0.1, 4.0),
			"cooldown_mult": clampf(float(source.get("cooldown_mult", 1.0)), 0.2, 4.0),
			"status": source.get("status", {}) if typeof(source.get("status", {})) == TYPE_DICTIONARY else {},
			"adds": _ids(source.get("adds", [])),
		})
	return out


static func _ids(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in (value as Array):
		var id := String(item)
		if id != "" and not out.has(id):
			out.append(id)
	return out


static func _reward(value: Variant) -> Dictionary:
	var out := {"stones": 100, "rarity": 2, "title": ""}
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		out["stones"] = maxi(0, int(data.get("stones", out["stones"])))
		out["rarity"] = clampi(int(data.get("rarity", out["rarity"])), 0, ItemGen.RARITY_NAMES.size() - 1)
		out["title"] = String(data.get("title", ""))
	return out


# --- questions ---------------------------------------------------------------

## Which phase a body at `ratio` of its maximum health is in. At or below a
## threshold the next phase begins; at or below the last one, the last phase.
static func phase_index(ratio: float, profile_in: Dictionary) -> int:
	var thresholds: Array = profile_in.get("thresholds", [])
	var out := 0
	for i in thresholds.size():
		if ratio <= float(thresholds[i]):
			out = i + 1
	return clampi(out, 0, maxi(0, phase_count(profile_in) - 1))


static func phase_count(profile_in: Dictionary) -> int:
	return (profile_in.get("phases", []) as Array).size()


static func phase(profile_in: Dictionary, index: int) -> Dictionary:
	var phases: Array = profile_in.get("phases", [])
	if phases.is_empty():
		return {}
	return phases[clampi(index, 0, phases.size() - 1)]


static func phase_name(profile_in: Dictionary, index: int) -> String:
	return String(phase(profile_in, index).get("name", "Phase %d" % (index + 1)))


## A phase multiplier, 1.0 when the definition does not say otherwise. The body
## reads these directly instead of mutating its base numbers, so a phase change
## can never compound on itself.
static func phase_mult(profile_in: Dictionary, index: int, key: String) -> float:
	return float(phase(profile_in, index).get(key, 1.0))


static func phase_status(profile_in: Dictionary, index: int) -> Dictionary:
	return phase(profile_in, index).get("status", {})


static func adds(profile_in: Dictionary, index: int) -> Array:
	return phase(profile_in, index).get("adds", [])


static func thresholds(profile_in: Dictionary) -> Array:
	return profile_in.get("thresholds", [])


static func reward(profile_in: Dictionary) -> Dictionary:
	return profile_in.get("reward", {})


static func bar_color(profile_in: Dictionary) -> Color:
	return Color(String(profile_in.get("color", "#b08ae0")))


static func telegraph_color(profile_in: Dictionary) -> Color:
	return Color(String(profile_in.get("telegraph_color", "#c090ff")))


static func label(profile_in: Dictionary, index: int) -> String:
	return "%s — %s" % [String(profile_in.get("name", "Warden")), phase_name(profile_in, index)]
