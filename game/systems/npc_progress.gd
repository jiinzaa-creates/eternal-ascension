class_name NpcProgress
extends RefCounted
## The town climbs without the player.
##
## Every resident's cultivation is a pure function of
## `(world_seed, archetype, npc_id, day)`: a day-by-day simulation of insight,
## sublevels and realm breakthroughs, driven by the archetype's own discipline
## and a seeded jitter. Nothing here is saved, because nothing here is chosen —
## the same world seed and the same day always produce the same elder, the same
## prodigy and the same farmer who never gets past Qi Condensation.
##
## Why a simulation rather than a formula: a breakthrough is a *roll with
## consequences*. A failure resets the peak's insight, injures the body for a
## fortnight and can cost a sublevel, so two people with the same discipline
## diverge by luck. A closed-form curve could not express that, and saving it
## would make a save file responsible for a fact the seed already decides.
##
## The cache is an optimisation only: it holds each person's state at the last
## day asked for, so a daily tick costs one step instead of replaying a life.
## Asking for an earlier day rebuilds from the beginning, which is what makes a
## loaded save rewind exactly rather than remembering a future it lost.

const INSIGHT_DOMAIN := "npc_insight"
const BREAKTHROUGH_DOMAIN := "npc_breakthrough"
const REGRESSION_DOMAIN := "npc_regression"
const CACHE_LIMIT := 512

static var _cache: Dictionary = {}


## The trade's knobs, from `npcs.json` with code defaults so a missing block
## degrades to a slow, sane town instead of a crash.
static func rules() -> Dictionary:
	var out := {
		"sublevel_cost": 36.0,
		"max_sim_days": 1200,
		"injury_days": 14,
		"regression_chance": 0.15,
		"base_chance": 0.62,
		"realm_penalty": 0.055,
		"min_chance": 0.06,
		"max_chance": 0.92,
		"jitter_min": 0.7,
		"jitter_max": 1.3,
		"realm_drag": 0.05,
		"drag_floor": 0.5,
	}
	var source: Variant = DB.npc_data.get("progression", {})
	if typeof(source) == TYPE_DICTIONARY:
		var table: Dictionary = source
		for key in table.keys():
			out[key] = table[key]
	return out


## The archetype record, or {} for an unknown id.
static func archetype(id: String) -> Dictionary:
	var list: Variant = DB.npc_data.get("archetypes", [])
	if typeof(list) != TYPE_ARRAY:
		return {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("id", "")) == id:
			return entry
	return {}


static func profile(id: String) -> Dictionary:
	var entry := archetype(id)
	var raw: Variant = entry.get("progression", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func realm_cap(id: String) -> int:
	var entry := archetype(id)
	var block := profile(id)
	var base := maxi(1, int(entry.get("realm", 1)))
	return clampi(int(block.get("cap", base)), 1, maxi(1, Realms.count()))


## The realm a person is born into. The simulation starts here, never below.
static func base_realm(id: String) -> int:
	return maxi(1, int(archetype(id).get("realm", 1)))


# ------------------------------------------------------------------ state ----


static func initial(entry: Dictionary) -> Dictionary:
	return {
		"realm": maxi(1, int(entry.get("realm", 1))),
		"sublevel": 1,
		"insight": 0.0,
		"attempts": 0,
		"failures": 0,
		"injured_until": 0,
		"last_event": "",
		"last_event_day": 0,
	}


## The person's whole cultivation record on `day`. Pure in its arguments: the
## world seed is passed rather than read, so tests and worker code can ask the
## same question without touching autoload state.
static func state_for(archetype_id: String, npc_id: String, day: int, world_seed: int) -> Dictionary:
	var entry := archetype(archetype_id)
	if entry.is_empty() or npc_id == "":
		return {}
	var table := rules()
	var horizon := clampi(int(table.get("max_sim_days", 1200)), 1, 4000)
	var target := clampi(day, 1, horizon)
	var key := "%d|%s" % [world_seed, npc_id]
	var state: Dictionary
	var from := 1
	if _cache.has(key):
		var cached: Variant = _cache[key]
		if typeof(cached) == TYPE_DICTIONARY:
			var record: Dictionary = cached
			state = (record.get("state", {}) as Dictionary).duplicate(true)
			from = int(record.get("day", 0)) + 1
			if from > target:
				# Time went backwards (a load). Rebuild the past instead of
				# handing back a record from a day that no longer happened.
				state = initial(entry)
				from = 1
		else:
			state = initial(entry)
	else:
		state = initial(entry)
	var block := profile(archetype_id)
	var cap := realm_cap(archetype_id)
	for cursor in range(from, target + 1):
		_step(state, block, cap, npc_id, cursor, world_seed, table)
	_cache[key] = {"day": target, "state": state.duplicate(true)}
	if _cache.size() > CACHE_LIMIT:
		_cache.clear()
		_cache[key] = {"day": target, "state": state.duplicate(true)}
	return state


## One day for one person. Mutates the state it is handed; `state_for` owns the
## copy, so callers never share a record with the cache.
static func _step(state: Dictionary, block: Dictionary, cap: int, npc_id: String, day: int,
		world_seed: int, table: Dictionary) -> void:
	var realm := clampi(int(state.get("realm", 1)), 1, cap)
	var sublevel := clampi(int(state.get("sublevel", 1)), 1, Realms.SUBLEVELS)
	state["realm"] = realm
	state["sublevel"] = sublevel
	# An injured body does not cultivate. This is a failed breakthrough's real
	# cost: days of progress lost, not a number on a screen.
	if day <= int(state.get("injured_until", 0)):
		return
	if realm >= cap and sublevel >= Realms.SUBLEVELS:
		return
	var cost := maxf(1.0, float(table.get("sublevel_cost", 36.0)))
	state["insight"] = float(state.get("insight", 0.0)) + _daily_insight(block, realm, day, npc_id, world_seed, table)
	if float(state["insight"]) < cost:
		return
	if sublevel < Realms.SUBLEVELS:
		state["sublevel"] = sublevel + 1
		state["insight"] = float(state["insight"]) - cost
		state["last_event"] = "advance"
		state["last_event_day"] = day
		return
	# At the peak: one roll decides whether a realm is won today.
	var attempt := int(state.get("attempts", 0)) + 1
	state["attempts"] = attempt
	var chance := breakthrough_chance(realm, float(block.get("talent", 0.0)), table)
	var roll := _roll(BREAKTHROUGH_DOMAIN, world_seed, npc_id, day * 131 + attempt)
	if roll < chance:
		state["realm"] = mini(realm + 1, cap)
		state["sublevel"] = 1
		state["insight"] = 0.0
		state["last_event"] = "breakthrough"
		state["last_event_day"] = day
		return
	state["failures"] = int(state.get("failures", 0)) + 1
	state["insight"] = 0.0
	state["injured_until"] = day + maxi(0, int(table.get("injury_days", 14)))
	state["last_event"] = "deviation"
	state["last_event_day"] = day
	var regression := _roll(REGRESSION_DOMAIN, world_seed, npc_id, day)
	if regression < clampf(float(table.get("regression_chance", 0.15)), 0.0, 1.0) and sublevel > 1:
		state["sublevel"] = sublevel - 1


## Insight gathered in a day: archetype discipline, dragged down by realm and
## jittered per person per day. The jitter is what makes two outer disciples
## diverge without either being scripted.
static func _daily_insight(block: Dictionary, realm: int, day: int, npc_id: String,
		world_seed: int, table: Dictionary) -> float:
	var base := maxf(0.0, float(block.get("rate", 1.0)))
	var drag := maxf(float(table.get("drag_floor", 0.5)),
		1.0 - maxf(0.0, float(table.get("realm_drag", 0.05))) * float(maxi(0, realm - 1)))
	var low := maxf(0.0, float(table.get("jitter_min", 0.7)))
	var high := maxf(low, float(table.get("jitter_max", 1.3)))
	var jitter := low + (high - low) * _roll(INSIGHT_DOMAIN, world_seed, npc_id, day)
	return base * drag * jitter


## Breakthrough odds: the realm's weight, the person's talent and a floor so no
## one is ever doomed and a ceiling so no one is ever guaranteed.
static func breakthrough_chance(realm: int, talent: float, table: Dictionary = {}) -> float:
	var rules_table := table if not table.is_empty() else rules()
	var base := float(rules_table.get("base_chance", 0.62))
	var penalty := maxf(0.0, float(rules_table.get("realm_penalty", 0.055))) * float(maxi(0, realm - 1))
	var low := clampf(float(rules_table.get("min_chance", 0.06)), 0.0, 1.0)
	var high := clampf(float(rules_table.get("max_chance", 0.92)), low, 1.0)
	return clampf(base - penalty + talent, low, high)


## A seeded draw from the explicit world seed. Worker-safe and independent of
## whichever seed the autoload happens to hold.
static func _roll(domain: String, world_seed: int, npc_id: String, counter: int) -> float:
	return Rng.stream_from(world_seed, domain, hash(npc_id), counter).randf()


# ------------------------------------------------------------------ reads ----


## Progress towards the next step, 0..100. At a capped peak the number stays
## at 100 rather than pretending more is coming.
static func insight_percent(state: Dictionary) -> int:
	var cost := maxf(1.0, float(rules().get("sublevel_cost", 36.0)))
	return clampi(roundi(float(state.get("insight", 0.0)) / cost * 100.0), 0, 100)


static func at_peak(archetype_id: String, state: Dictionary) -> bool:
	return int(state.get("realm", 1)) >= realm_cap(archetype_id) \
		and int(state.get("sublevel", 1)) >= Realms.SUBLEVELS


## "Foundation Establishment 3" — the stage without the progress number.
static func stage_label(state: Dictionary) -> String:
	return "%s %d" % [Realms.name_of(int(state.get("realm", 1))),
		clampi(int(state.get("sublevel", 1)), 1, Realms.SUBLEVELS)]


static func describe(archetype_id: String, state: Dictionary) -> String:
	if state.is_empty():
		return ""
	if at_peak(archetype_id, state):
		return "%s · the peak of their path" % stage_label(state)
	return "%s · %d%% to the next step" % [stage_label(state), insight_percent(state)]


static func reset_cache() -> void:
	_cache.clear()


# ------------------------------------------------------------- validation ----


## Content checks for the progression blocks. A cap below the archetype's own
## realm, a rate of zero or a jitter range that is inside out would make a
## person who can never grow, or grows at a negative speed.
static func validate(npc_data: Dictionary) -> Array:
	var problems: Array = []
	var raw: Variant = npc_data.get("progression", null)
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("npc progression rules are missing")
		return problems
	var table: Dictionary = raw
	if float(table.get("sublevel_cost", 0.0)) <= 0.0:
		problems.append("npc progression has no sublevel cost")
	if int(table.get("max_sim_days", 0)) < 30:
		problems.append("npc progression simulates too few days")
	if int(table.get("injury_days", -1)) < 0:
		problems.append("npc progression has negative injury days")
	if float(table.get("regression_chance", -1.0)) < 0.0 or float(table.get("regression_chance", 2.0)) > 1.0:
		problems.append("npc progression regression is not a chance")
	if float(table.get("base_chance", -1.0)) < 0.0 or float(table.get("base_chance", 2.0)) > 1.0:
		problems.append("npc progression base chance is not a chance")
	var low := float(table.get("min_chance", -1.0))
	var high := float(table.get("max_chance", 2.0))
	if low < 0.0 or high > 1.0 or low > high:
		problems.append("npc progression chance bounds are invalid")
	if float(table.get("realm_penalty", -1.0)) < 0.0:
		problems.append("npc progression rewards higher realms")
	if float(table.get("jitter_min", 0.0)) <= 0.0 or float(table.get("jitter_max", 0.0)) < float(table.get("jitter_min", 0.0)):
		problems.append("npc progression jitter range is invalid")
	if float(table.get("realm_drag", -1.0)) < 0.0 or float(table.get("realm_drag", 1.0)) > 0.5:
		problems.append("npc progression realm drag is out of range")
	if float(table.get("drag_floor", 0.0)) <= 0.0 or float(table.get("drag_floor", 2.0)) > 1.0:
		problems.append("npc progression drag floor is out of range")

	var list: Variant = npc_data.get("archetypes", [])
	if typeof(list) != TYPE_ARRAY:
		return problems
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var block_value: Variant = entry.get("progression", null)
		if typeof(block_value) != TYPE_DICTIONARY:
			problems.append("npc archetype %s has no progression block" % id)
			continue
		var block: Dictionary = block_value
		if float(block.get("rate", 0.0)) <= 0.0:
			problems.append("npc archetype %s learns nothing" % id)
		var base_realm := maxi(1, int(entry.get("realm", 1)))
		var cap := int(block.get("cap", 0))
		if cap < base_realm or cap > maxi(1, Realms.count()):
			problems.append("npc archetype %s has a realm cap outside its ladder" % id)
		var talent := float(block.get("talent", 0.0))
		if talent < -0.5 or talent > 0.5:
			problems.append("npc archetype %s has talent outside -0.5..0.5" % id)
	return problems
