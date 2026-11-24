class_name WorldEvents
extends RefCounted
## The province's own calendar of tidings.
##
## A world event is authored content with a duration, a set of multipliers and
## an optional task. Which event is live on a day is derived from
## `(world_seed, cycle)` alone: every cycle is a weighted draw from the authored
## table, a quiet cycle is one of the possible draws, and an event that ends
## early leaves the rest of its cycle quiet. Nothing here reads the scene, and
## the same seed always produces the same calendar.
##
## Progress and the reward flag are the only saved parts; they are sanitised
## against the current cycle so a stale save cannot bring an old tiding back.

const DOMAIN := "world_event"
const GOAL_KINDS: Array[String] = ["kills", "crafts", "trade"]
const MULT_EFFECTS: Array[String] = ["cultivation", "shop_buy", "shop_sell", "contribution", "trial_seconds"]
const INT_EFFECTS: Array[String] = ["enemy_pop", "harvest_extra"]
const GOAL_VERBS := {
	"kills": "foes felled",
	"crafts": "works finished",
	"trade": "purchases made",
}
const DEFAULT_COLOR := "#8fa2ab"


static func data() -> Dictionary:
	return DB.world_events_data


static func events() -> Array:
	var value: Variant = data().get("events", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func find(id: String) -> Dictionary:
	for value in events():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("id", "")) == id:
			return entry
	return {}


static func default_id() -> String:
	return String(data().get("default", ""))


static func interval_days() -> int:
	return clampi(int(data().get("interval_days", 5)), 1, 30)


static func quiet_weight() -> int:
	return maxi(0, int(data().get("quiet_weight", 0)))


## Cycle index for a calendar day. Every `interval_days` days begins a new draw.
static func cycle_for(day: int) -> int:
	return floori(float(maxi(1, day) - 1) / float(interval_days()))


static func cycle_start(cycle: int) -> int:
	return maxi(0, cycle) * interval_days() + 1


## The cycle's authored draw. An empty dictionary is a quiet cycle.
static func roll(cycle: int, world_seed: int) -> Dictionary:
	var table := events()
	var weights: Array = [quiet_weight()]
	for value in table:
		var weight := 0
		if typeof(value) == TYPE_DICTIONARY:
			weight = maxi(0, int((value as Dictionary).get("weight", 0)))
		weights.append(weight)
	var rng: RandomNumberGenerator = Rng.stream_from(world_seed, DOMAIN, cycle, 0)
	var index := Rng.pick_weighted(weights, rng)
	if index <= 0 or index - 1 >= table.size():
		return {}
	var drawn: Variant = table[index - 1]
	return drawn if typeof(drawn) == TYPE_DICTIONARY else {}


## The event live on `day`, with everything the HUD and the herald need. A quiet
## or expired cycle returns the same shape with `active` false and an empty id.
static func active(day: int, world_seed: int) -> Dictionary:
	var current := maxi(1, day)
	var cycle := cycle_for(current)
	var start := cycle_start(cycle)
	var entry := roll(cycle, world_seed)
	if entry.is_empty():
		return quiet_state(cycle)
	var days := clampi(int(entry.get("days", 1)), 1, interval_days())
	var end := start + days - 1
	if current > end:
		return quiet_state(cycle)
	return {
		"active": true,
		"cycle": cycle,
		"id": String(entry.get("id", "")),
		"name": String(entry.get("name", "")),
		"description": String(entry.get("description", "")),
		"color": String(entry.get("color", DEFAULT_COLOR)),
		"start_day": start,
		"end_day": end,
		"days": days,
		"day_index": current - start + 1,
		"effects": effects_of(entry),
		"goal": goal_of(entry),
		"reward": reward_of(entry),
	}


static func quiet_state(cycle: int) -> Dictionary:
	return {
		"active": false,
		"cycle": maxi(0, cycle),
		"id": "",
		"name": "",
		"description": "",
		"color": DEFAULT_COLOR,
		"start_day": cycle_start(cycle),
		"end_day": -1,
		"days": 0,
		"day_index": 0,
		"effects": {},
		"goal": {},
		"reward": {},
	}


static func effects_of(entry: Dictionary) -> Dictionary:
	var value: Variant = entry.get("effects", {})
	return (value as Dictionary).duplicate() if typeof(value) == TYPE_DICTIONARY else {}


static func goal_of(entry: Dictionary) -> Dictionary:
	var value: Variant = entry.get("goal", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var goal: Dictionary = value
	var kind := String(goal.get("kind", ""))
	var count := int(goal.get("count", 0))
	if not GOAL_KINDS.has(kind) or count <= 0:
		return {}
	return {"kind": kind, "count": clampi(count, 1, 99)}


static func reward_of(entry: Dictionary) -> Dictionary:
	var value: Variant = entry.get("reward", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {"stones": 0, "contribution": 0}
	var reward: Dictionary = value
	return {
		"stones": maxi(0, int(reward.get("stones", 0))),
		"contribution": maxi(0, int(reward.get("contribution", 0))),
	}


## Multiplier for a named effect. An absent or inactive event is neutral, so
## every consumer can call this without first checking whether one is live.
static func mult(event: Dictionary, key: String) -> float:
	var value: Variant = event.get("effects", {})
	if typeof(value) != TYPE_DICTIONARY:
		return 1.0
	return clampf(float((value as Dictionary).get(key, 1.0)), 0.05, 10.0)


static func int_effect(event: Dictionary, key: String) -> int:
	var value: Variant = event.get("effects", {})
	if typeof(value) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((value as Dictionary).get(key, 0)))


static func flag(event: Dictionary, key: String) -> bool:
	var value: Variant = event.get("effects", {})
	if typeof(value) != TYPE_DICTIONARY:
		return false
	return bool((value as Dictionary).get(key, false))


## Adds progress only when the live event's task is the one being advanced.
## Returns the clamped progress, so callers never have to guard the count.
static func advance(event: Dictionary, progress: int, kind: String, amount: int = 1) -> int:
	var goal := goal_of(event)
	if goal.is_empty():
		return 0
	var count := int(goal["count"])
	var current := clampi(progress, 0, count)
	if amount <= 0 or String(goal["kind"]) != kind:
		return current
	return clampi(current + amount, 0, count)


static func complete(event: Dictionary, progress: int) -> bool:
	var goal := goal_of(event)
	if goal.is_empty():
		return false
	return progress >= int(goal["count"])


## Progress and reward are the only saved state. A save from another cycle, or
## one naming a different tiding, is discarded rather than carried forward.
static func sanitize(saved: Variant, day: int, world_seed: int) -> Dictionary:
	var event := active(day, world_seed)
	var out := {
		"cycle": int(event.get("cycle", 0)),
		"id": String(event.get("id", "")),
		"progress": 0,
		"rewarded": false,
	}
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	var value: Dictionary = saved
	if int(value.get("cycle", -1)) != int(out["cycle"]):
		return out
	if String(value.get("id", "")) != String(out["id"]):
		return out
	var goal := goal_of(event)
	if goal.is_empty():
		return out
	var count := int(goal["count"])
	var progress := clampi(int(value.get("progress", 0)), 0, count)
	out["progress"] = progress
	out["rewarded"] = bool(value.get("rewarded", false)) and progress >= count
	return out


static func label(event: Dictionary) -> String:
	if not bool(event.get("active", false)) or String(event.get("id", "")) == "":
		return ""
	return "%s · day %d/%d" % [
		String(event.get("name", "Tiding")),
		int(event.get("day_index", 1)),
		maxi(1, int(event.get("days", 1))),
	]


static func progress_text(event: Dictionary, progress: int) -> String:
	var goal := goal_of(event)
	if goal.is_empty():
		return ""
	var count := int(goal["count"])
	var verb := String(GOAL_VERBS.get(String(goal["kind"]), "done"))
	return "%d/%d %s" % [clampi(progress, 0, count), count, verb]


static func reward_text(event: Dictionary) -> String:
	var reward := reward_of(event)
	var parts: Array[String] = []
	if int(reward["stones"]) > 0:
		parts.append("%d spirit stones" % int(reward["stones"]))
	if int(reward["contribution"]) > 0:
		parts.append("%d contribution" % int(reward["contribution"]))
	if parts.is_empty():
		return ""
	return "Reward: " + ", ".join(parts) + "."


static func _percent(multiplier: float) -> String:
	var delta := roundi((multiplier - 1.0) * 100.0)
	if delta == 0:
		return "unchanged"
	return ("+%d%%" % delta) if delta > 0 else ("-%d%%" % absi(delta))


## A readable line for the herald and the HUD, built from the effects actually
## authored. Unknown keys never reach here because validation rejects them.
static func effect_line(event: Dictionary) -> String:
	var parts: Array[String] = []
	var cultivation := mult(event, "cultivation")
	if not is_equal_approx(cultivation, 1.0):
		parts.append("Qi gain " + _percent(cultivation))
	var purchased := mult(event, "shop_buy")
	if not is_equal_approx(purchased, 1.0):
		parts.append("market prices " + _percent(purchased))
	var sold := mult(event, "shop_sell")
	if not is_equal_approx(sold, 1.0):
		parts.append("sale values " + _percent(sold))
	var service := mult(event, "contribution")
	if not is_equal_approx(service, 1.0):
		parts.append("sect service " + _percent(service))
	var trial := mult(event, "trial_seconds")
	if not is_equal_approx(trial, 1.0):
		parts.append("altar trial time " + _percent(trial))
	var foes := int_effect(event, "enemy_pop")
	if foes > 0:
		parts.append("+%d wild foes" % foes)
	var herbs := int_effect(event, "harvest_extra")
	if herbs > 0:
		parts.append("+%d herb per gathering" % herbs)
	var effects_value: Variant = event.get("effects", {})
	var elites := 0.0
	if typeof(effects_value) == TYPE_DICTIONARY:
		elites = float((effects_value as Dictionary).get("elite_bonus", 0.0))
	if elites > 0.0:
		parts.append("more elites afield")
	if flag(event, "rifts_open"):
		parts.append("every rift held open")
	return " · ".join(parts)


## The herald's whole speech: what the day brings, what it changes, what it asks
## and what it pays. Empty on a quiet day.
static func herald_text(event: Dictionary, progress: int) -> String:
	if not bool(event.get("active", false)) or String(event.get("id", "")) == "":
		return "The herald has no tiding today. The market keeps its usual hours."
	var text := "The herald calls: %s. %s" % [String(event.get("name", "A tiding")), String(event.get("description", ""))]
	var effects := effect_line(event)
	if effects != "":
		text += " " + effects + "."
	var task := progress_text(event, progress)
	if task != "":
		text += " Task: " + task + "."
	var reward := reward_text(event)
	if reward != "":
		text += " " + reward
	return text


static func validate(value: Dictionary) -> Array:
	var problems: Array = []
	if value.is_empty():
		problems.append("no world events defined")
		return problems
	var interval := int(value.get("interval_days", 0))
	if interval < 1 or interval > 30:
		problems.append("world event interval must be 1-30 days")
	var quiet := int(value.get("quiet_weight", -1))
	if quiet < 0:
		problems.append("world event quiet weight must not be negative")
	var list_value: Variant = value.get("events", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("world events are missing")
		return problems
	var list: Array = list_value
	var seen: Dictionary = {}
	var total := maxi(0, quiet)
	for raw in list:
		if typeof(raw) != TYPE_DICTIONARY:
			problems.append("world event is not an object")
			continue
		var entry: Dictionary = raw
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("world event without id")
			continue
		if seen.has(id):
			problems.append("duplicate world event " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("world event %s has no name" % id)
		if String(entry.get("description", "")).strip_edges() == "":
			problems.append("world event %s has no description" % id)
		var color := String(entry.get("color", ""))
		if not color.begins_with("#") or color.length() != 7:
			problems.append("world event %s has no hex colour" % id)
		var weight := int(entry.get("weight", 0))
		if weight <= 0:
			problems.append("world event %s has no weight" % id)
		total += maxi(0, weight)
		var days := int(entry.get("days", 0))
		if days < 1 or days > maxi(1, interval):
			problems.append("world event %s lasts outside its cycle" % id)
		var effects_value: Variant = entry.get("effects", {})
		if typeof(effects_value) != TYPE_DICTIONARY:
			problems.append("world event %s has unreadable effects" % id)
		else:
			var effects: Dictionary = effects_value
			for key in effects.keys():
				var effect := String(key)
				var number := float(effects[key])
				if MULT_EFFECTS.has(effect):
					if number <= 0.05 or number > 10.0:
						problems.append("world event %s has an out-of-range %s" % [id, effect])
				elif INT_EFFECTS.has(effect):
					if number < 0.0 or number > 6.0:
						problems.append("world event %s has an out-of-range %s" % [id, effect])
				elif effect == "elite_bonus":
					if number < 0.0 or number > 0.5:
						problems.append("world event %s has an out-of-range elite bonus" % id)
				elif effect == "rifts_open":
					if typeof(effects[key]) != TYPE_BOOL:
						problems.append("world event %s has a non-boolean rifts flag" % id)
				else:
					problems.append("world event %s has an unknown effect %s" % [id, effect])
		var goal_value: Variant = entry.get("goal", {})
		if typeof(goal_value) != TYPE_DICTIONARY:
			problems.append("world event %s has an unreadable task" % id)
		else:
			var goal: Dictionary = goal_value
			if not goal.is_empty():
				var kind := String(goal.get("kind", ""))
				if not GOAL_KINDS.has(kind):
					problems.append("world event %s has an unknown task %s" % [id, kind])
				var count := int(goal.get("count", 0))
				if count < 1 or count > 99:
					problems.append("world event %s has an impossible task count" % id)
		var reward_value: Variant = entry.get("reward", {})
		if typeof(reward_value) != TYPE_DICTIONARY:
			problems.append("world event %s has an unreadable reward" % id)
		else:
			var reward: Dictionary = reward_value
			for key in reward.keys():
				var name := String(key)
				if name != "stones" and name != "contribution":
					problems.append("world event %s rewards an unknown %s" % [id, name])
					continue
				var amount := int(reward[key])
				var ceiling := 10000 if name == "stones" else 500
				if amount < 0 or amount > ceiling:
					problems.append("world event %s has an impossible %s reward" % [id, name])
		var effects_empty := typeof(effects_value) != TYPE_DICTIONARY or (effects_value as Dictionary).is_empty()
		var goal_empty := typeof(goal_value) != TYPE_DICTIONARY or (goal_value as Dictionary).is_empty()
		if effects_empty and goal_empty:
			problems.append("world event %s changes nothing" % id)
	if total <= 0:
		problems.append("world events have no weight at all")
	var fallback := String(value.get("default", ""))
	if fallback == "" or not seen.has(fallback):
		problems.append("world event default is not an authored event")
	return problems
