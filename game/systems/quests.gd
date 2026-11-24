class_name QuestLog
extends RefCounted
## Quest state for the authored quest graph.
##
## Every quest in res://data/quests.json owns one state entry. Steps are ordered;
## each step holds one or more objectives (a legacy step is a single objective).
## A step in `all` mode needs every objective, while `any` mode completes on the
## first one — that is how a chain branches without a dialogue tree. Quests may
## require other quests, a realm or sect contribution, and a giver that accepts
## them in conversation.
##
## The original Azure Cloud initiation keeps its direct fields (`step_index`,
## `completed`, `rewarded`, `counters`) as property views over its own state, so
## old call sites and pre-M67 saves keep working unchanged.

const PRIMARY_ID := "quest.azure_cloud.initiation"
const SAVE_VERSION := 2
## Every gameplay event a step may listen for. Adding a kind here is the one
## place that decides what content may ask the scene to report.
const KINDS: Array[String] = ["talk", "return", "kill", "collect", "channel", "craft", "trade", "realm", "inheritance"]
const MAX_COUNT := 99

## id -> {step_index, counters, completed, rewarded, accepted}
var states: Dictionary = {}


func _init() -> void:
	reset()


## Fresh state for every authored quest. Only an `auto` quest starts accepted;
## a giver quest waits for the conversation that accepts it.
func reset() -> void:
	states.clear()
	for value in DB.quests:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			continue
		var state := _fresh_state()
		if bool(entry.get("auto", false)):
			state["accepted"] = true
		states[id] = state


## The primary initiation quest's definition, kept for old call sites.
var quest: Dictionary:
	get:
		return DB.quest(PRIMARY_ID)


## --- legacy views over the initiation's state ------------------------------

var step_index: int:
	get:
		return int(_state(PRIMARY_ID).get("step_index", 0))
	set(value):
		_state(PRIMARY_ID)["step_index"] = clampi(value, 0, maxi(0, steps_of(PRIMARY_ID).size() - 1))

var completed: bool:
	get:
		return bool(_state(PRIMARY_ID).get("completed", false))
	set(value):
		_state(PRIMARY_ID)["completed"] = value
		if value:
			_state(PRIMARY_ID)["step_index"] = maxi(0, steps_of(PRIMARY_ID).size() - 1)

var rewarded: bool:
	get:
		return bool(_state(PRIMARY_ID).get("rewarded", false))
	set(value):
		_state(PRIMARY_ID)["rewarded"] = value

var counters: Dictionary:
	get:
		var value: Variant = _state(PRIMARY_ID).get("counters", {})
		return value if typeof(value) == TYPE_DICTIONARY else {}
	set(value):
		_state(PRIMARY_ID)["counters"] = value.duplicate()


## --- definitions -----------------------------------------------------------

func definitions() -> Array:
	return DB.quests


func definition(id: String) -> Dictionary:
	return DB.quest(id)


func is_valid() -> bool:
	return not definition(PRIMARY_ID).is_empty()


func title_of(id: String) -> String:
	return String(definition(id).get("title", "Unknown Quest"))


func steps_of(id: String) -> Array:
	var value: Variant = definition(id).get("steps", [])
	return value if typeof(value) == TYPE_ARRAY else []


func step_of(id: String) -> Dictionary:
	var all := steps_of(id)
	var index := int(_state(id).get("step_index", 0))
	if index < 0 or index >= all.size():
		return {}
	return all[index] if typeof(all[index]) == TYPE_DICTIONARY else {}


func current_kind(id: String = PRIMARY_ID) -> String:
	var step := step_of(id)
	var kind := String(step.get("kind", ""))
	if kind != "":
		return kind
	var objectives := objectives_of(step)
	return String((objectives[0] as Dictionary).get("kind", "")) if not objectives.is_empty() else ""


func current_target(id: String = PRIMARY_ID) -> String:
	var step := step_of(id)
	var target := String(step.get("target", ""))
	if target != "":
		return target
	var objectives := objectives_of(step)
	return String((objectives[0] as Dictionary).get("target", "")) if not objectives.is_empty() else ""


## The count of the step's first objective. A branch's other objectives carry
## their own counts; this is only the legacy single-objective reading.
func required_count(id: String = PRIMARY_ID) -> int:
	var objectives := objectives_of(step_of(id))
	if objectives.is_empty():
		return 1
	return objective_count(objectives[0])


func state_of(id: String) -> Dictionary:
	return _state(id).duplicate(true)


func is_accepted(id: String) -> bool:
	return bool(_state(id).get("accepted", false))


func is_completed(id: String) -> bool:
	return bool(_state(id).get("completed", false))


func progress_of(id: String) -> int:
	return clampi(int(_state(id).get("step_index", 0)), 0, maxi(0, steps_of(id).size() - 1))


## --- objectives ------------------------------------------------------------

## A step may author `objectives` (many paths) or the legacy `kind`/`target`.
static func objectives_of(step: Dictionary) -> Array:
	var value: Variant = step.get("objectives", null)
	if typeof(value) == TYPE_ARRAY and not (value as Array).is_empty():
		var list: Array = []
		for raw in (value as Array):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var objective: Dictionary = raw
			if String(objective.get("kind", "")) != "" and String(objective.get("target", "")) != "":
				list.append(objective)
		return list
	if String(step.get("kind", "")) != "" and String(step.get("target", "")) != "":
		return [step]
	return []


static func step_mode(step: Dictionary) -> String:
	return "any" if String(step.get("mode", "all")) == "any" else "all"


static func objective_key(objective: Dictionary) -> String:
	return "%s:%s" % [String(objective.get("kind", "")), String(objective.get("target", ""))]


static func objective_count(objective: Dictionary) -> int:
	return clampi(int(objective.get("count", 1)), 1, MAX_COUNT)


static func objective_short(objective: Dictionary) -> String:
	var short := String(objective.get("short", ""))
	if short != "":
		return short
	return String(objective.get("target", "objective")).replace("_", " ")


## --- availability and acceptance -------------------------------------------

## Whether the quest's authored requirements are met right now. Completed and
## accepted quests are never offered again.
func is_available(id: String, context: Dictionary = {}) -> bool:
	var entry := definition(id)
	if entry.is_empty():
		return false
	var state := _state(id)
	if bool(state.get("accepted", false)) or bool(state.get("completed", false)):
		return false
	var requirements: Variant = entry.get("requires", {})
	if typeof(requirements) == TYPE_DICTIONARY:
		var requirements_data: Dictionary = requirements
		var required: Variant = requirements_data.get("quests", [])
		if typeof(required) == TYPE_ARRAY:
			for value in (required as Array):
				if not is_completed(String(value)):
					return false
		var any_value: Variant = requirements_data.get("any_quests", [])
		if typeof(any_value) == TYPE_ARRAY and not (any_value as Array).is_empty():
			var met := false
			for value in (any_value as Array):
				if is_completed(String(value)):
					met = true
					break
			if not met:
				return false
		if int(context.get("realm", 0)) < int(requirements_data.get("min_realm", 0)):
			return false
		if int(context.get("contribution", 0)) < int(requirements_data.get("min_contribution", 0)):
			return false
	return true


func available_ids(context: Dictionary = {}) -> Array:
	var out: Array = []
	for value in definitions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and is_available(id, context):
			out.append(id)
	return out


func active_ids() -> Array:
	var out: Array = []
	for value in definitions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id == "":
			continue
		var state := _state(id)
		if bool(state.get("accepted", false)) and not bool(state.get("completed", false)):
			out.append(id)
	return out


func completed_ids() -> Array:
	var out: Array = []
	for value in definitions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and is_completed(id):
			out.append(id)
	return out


func quest_state(id: String, context: Dictionary = {}) -> String:
	if is_completed(id):
		return "completed"
	if is_accepted(id):
		return "active"
	if is_available(id, context):
		return "available"
	return "locked"


## Accepts an available quest. The caller decides which giver was spoken to;
## this only enforces that the requirements are actually met.
func accept(id: String, context: Dictionary = {}) -> bool:
	if not is_available(id, context):
		return false
	_state(id)["accepted"] = true
	return true


func mark_rewarded(id: String) -> bool:
	var state := _state(id)
	if bool(state.get("rewarded", false)):
		return false
	state["rewarded"] = true
	return true


## --- event reporting -------------------------------------------------------

## Reports a gameplay event to every accepted quest. Returns one entry per quest
## that advanced: {quest_id, title, step_index, completed}. The scene turns those
## into toasts and rewards; this class never touches the world.
func report(kind: String, target: String, amount: int = 1) -> Array:
	var out: Array = []
	if amount <= 0:
		return out
	for id_value in states.keys():
		var id := String(id_value)
		var state: Dictionary = states[id]
		if not bool(state.get("accepted", false)) or bool(state.get("completed", false)):
			continue
		var step := step_of(id)
		if step.is_empty():
			continue
		var objectives := objectives_of(step)
		var matched := false
		for value in objectives:
			var objective: Dictionary = value
			if String(objective.get("kind", "")) != kind or String(objective.get("target", "")) != target:
				continue
			matched = true
			var key := objective_key(objective)
			var counters_value: Variant = state.get("counters", {})
			var step_counters: Dictionary = counters_value if typeof(counters_value) == TYPE_DICTIONARY else {}
			step_counters[key] = int(step_counters.get(key, 0)) + amount
			state["counters"] = step_counters
		if not matched or not _step_complete(id, step):
			continue
		var next_index := int(state.get("step_index", 0)) + 1
		var all_steps := steps_of(id)
		var finished := next_index >= all_steps.size()
		state["step_index"] = mini(next_index, maxi(0, all_steps.size() - 1))
		if finished:
			state["completed"] = true
		out.append({
			"quest_id": id,
			"title": title_of(id),
			"step_index": int(state["step_index"]),
			"completed": finished,
		})
	return out


## Legacy single-line entry point: true when the initiation quest itself moved.
func track(kind: String, target: String, amount: int = 1) -> bool:
	var before_step := step_index
	var before_done := completed
	report(kind, target, amount)
	return step_index != before_step or completed != before_done


func _step_complete(id: String, step: Dictionary) -> bool:
	var objectives := objectives_of(step)
	if objectives.is_empty():
		return false
	var state := _state(id)
	var value: Variant = state.get("counters", {})
	var counters_data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var done := 0
	for objective_value in objectives:
		var objective: Dictionary = objective_value
		if int(counters_data.get(objective_key(objective), 0)) >= objective_count(objective):
			done += 1
	if step_mode(step) == "any":
		return done > 0
	return done >= objectives.size()


## --- text -----------------------------------------------------------------

func objective_text(id: String = PRIMARY_ID) -> String:
	var entry := definition(id)
	if entry.is_empty():
		return ""
	if is_completed(id):
		var closing := String(entry.get("completion", ""))
		return closing if closing != "" else "%s is complete." % title_of(id)
	var step := step_of(id)
	if step.is_empty():
		return ""
	var text := String(step.get("text", ""))
	if text == "":
		text = "Continue %s" % title_of(id)
	var value: Variant = _state(id).get("counters", {})
	var counters_data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var objectives := objectives_of(step)
	var parts: Array[String] = []
	for objective_value in objectives:
		var objective: Dictionary = objective_value
		var need := objective_count(objective)
		var have := mini(int(counters_data.get(objective_key(objective), 0)), need)
		parts.append("%d/%d %s" % [have, need, objective_short(objective)])
	if parts.is_empty():
		return text
	if objectives.size() == 1:
		return "%s  (%s)" % [text, parts[0]]
	return "%s  (%s)" % [text, " · ".join(parts)]


func tracker_text() -> String:
	if not is_valid():
		return ""
	return "%s\n  %s" % [title_of(PRIMARY_ID), objective_text()]


## Flat HUD lines: a heading and one objective line per active quest. Capped so
## the tracker can never grow into the party panel below it.
func tracker_lines(max_quests: int = 2) -> Array:
	var out: Array = []
	for id_value in active_ids():
		if out.size() >= max_quests * 2:
			break
		var id := String(id_value)
		out.append("QUEST — " + title_of(id))
		out.append(objective_text(id))
	return out


## --- persistence -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		# Legacy mirrors of the initiation quest, so a pre-M67 reader still finds
		# the fields it knows in the place it expects them.
		"quest_id": PRIMARY_ID,
		"step_index": step_index,
		"counters": counters.duplicate(),
		"completed": completed,
		"rewarded": rewarded,
		"states": _states_copy(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	var saved: Variant = data.get("states", null)
	if typeof(saved) == TYPE_DICTIONARY and not (saved as Dictionary).is_empty():
		for key in (saved as Dictionary).keys():
			var id := String(key)
			if not states.has(id):
				continue
			_apply_state(id, (saved as Dictionary)[key])
	else:
		_apply_state(PRIMARY_ID, data)
	_accept_auto()
	# A legacy save with progress, completion or a reward proves the line was
	# already taken up even if it never carried an explicit flag.
	var primary := _state(PRIMARY_ID)
	if int(primary.get("step_index", 0)) > 0 or bool(primary.get("completed", false)) \
			or bool(primary.get("rewarded", false)):
		primary["accepted"] = true


func _apply_state(id: String, value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = value
	var state := _state(id)
	var all_steps := steps_of(id)
	state["step_index"] = clampi(int(raw.get("step_index", 0)), 0, maxi(0, all_steps.size() - 1))
	state["counters"] = _sanitize_counters(raw.get("counters", {}))
	state["completed"] = bool(raw.get("completed", false))
	if bool(state["completed"]):
		state["step_index"] = maxi(0, all_steps.size() - 1)
	state["rewarded"] = bool(raw.get("rewarded", false))
	var auto := bool(definition(id).get("auto", false))
	state["accepted"] = bool(raw.get("accepted", auto)) or auto or bool(state["completed"])


func _accept_auto() -> void:
	for value in definitions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id != "" and states.has(id) and bool(entry.get("auto", false)):
			var state: Dictionary = states[id]
			state["accepted"] = true


func _sanitize_counters(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = {}
	for key in (value as Dictionary).keys():
		var name := String(key)
		if not name.contains(":"):
			continue
		out[name] = clampi(int((value as Dictionary)[key]), 0, 9999)
	return out


func _states_copy() -> Dictionary:
	var out: Dictionary = {}
	for id in states.keys():
		out[String(id)] = (states[id] as Dictionary).duplicate(true)
	return out


func _fresh_state() -> Dictionary:
	return {
		"step_index": 0,
		"counters": {},
		"completed": false,
		"rewarded": false,
		"accepted": false,
	}


func _state(id: String) -> Dictionary:
	if not states.has(id):
		# An unknown id gets a transient state, never a new save entry.
		if definition(id).is_empty():
			return _fresh_state()
		states[id] = _fresh_state()
	return states[id]


# ------------------------------------------------------------ validation ----

## Boot safety for the quest graph: ordered steps, real objectives, reachable
## prerequisites without cycles, authored rewards that resolve, and one primary
## line that starts itself.
static func validate(list: Array) -> Array:
	var problems: Array = []
	if list.is_empty():
		problems.append("no quests defined")
		return problems
	var seen: Dictionary = {}
	var by_id: Dictionary = {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("a quest is not an object")
			continue
		var quest_data: Dictionary = value
		var id := String(quest_data.get("id", ""))
		if id == "":
			problems.append("a quest has no id")
			continue
		if seen.has(id):
			problems.append("duplicate quest " + id)
		seen[id] = true
		by_id[id] = quest_data
		if String(quest_data.get("title", "")).strip_edges() == "":
			problems.append("quest %s has no title" % id)
		if String(quest_data.get("summary", "")).strip_edges() == "":
			problems.append("quest %s has no summary" % id)
		var auto := bool(quest_data.get("auto", false))
		if String(quest_data.get("giver", "")).strip_edges() == "" and not auto:
			problems.append("quest %s has no giver and does not start itself" % id)
		var sect_id := String(quest_data.get("sect", ""))
		if sect_id != "" and DB.sect(sect_id).is_empty():
			problems.append("quest %s names an unknown sect" % id)
		var steps_value: Variant = quest_data.get("steps", [])
		if typeof(steps_value) != TYPE_ARRAY or (steps_value as Array).is_empty():
			problems.append("quest %s has no steps" % id)
		else:
			for step_value in (steps_value as Array):
				if typeof(step_value) != TYPE_DICTIONARY:
					problems.append("quest %s has a step that is not an object" % id)
					continue
				var step: Dictionary = step_value
				if String(step.get("text", "")).strip_edges() == "":
					problems.append("quest %s has a step without text" % id)
				var objectives := objectives_of(step)
				if objectives.is_empty():
					problems.append("quest %s has a step without kind/target" % id)
				var mode := String(step.get("mode", "all"))
				if mode != "all" and mode != "any":
					problems.append("quest %s has an unknown step mode" % id)
				for objective_value in objectives:
					var objective: Dictionary = objective_value
					var kind := String(objective.get("kind", ""))
					if not KINDS.has(kind):
						problems.append("quest %s asks for an unknown kind %s" % [id, kind])
					if String(objective.get("target", "")).strip_edges() == "":
						problems.append("quest %s has an objective without target" % id)
					var count := int(objective.get("count", 1))
					if count < 1 or count > MAX_COUNT:
						problems.append("quest %s has an impossible objective count" % id)
		var requirements_value: Variant = quest_data.get("requires", {})
		if typeof(requirements_value) != TYPE_DICTIONARY:
			problems.append("quest %s has unreadable requirements" % id)
		else:
			var requirements: Dictionary = requirements_value
			for key_name in ["quests", "any_quests"]:
				var required_value: Variant = requirements.get(key_name, [])
				if typeof(required_value) != TYPE_ARRAY:
					problems.append("quest %s has malformed %s" % [id, key_name])
					continue
				for required in (required_value as Array):
					var required_id := String(required)
					if required_id == id:
						problems.append("quest %s requires itself" % id)
			var realm := int(requirements.get("min_realm", 0))
			if realm < 0 or realm > 12:
				problems.append("quest %s has an impossible realm gate" % id)
			var contribution := int(requirements.get("min_contribution", 0))
			if contribution < 0 or contribution > 100000:
				problems.append("quest %s has an impossible contribution gate" % id)
		var reward_value: Variant = quest_data.get("reward", {})
		if typeof(reward_value) != TYPE_DICTIONARY:
			problems.append("quest %s has an unreadable reward" % id)
		else:
			var reward: Dictionary = reward_value
			var pays := false
			for key in reward.keys():
				var name := String(key)
				if name == "technique":
					var technique_id := String(reward[key])
					if technique_id != "":
						pays = true
						if DB.technique(technique_id).is_empty():
							problems.append("quest %s rewards an unknown technique" % id)
				elif name == "passive":
					var passive_id := String(reward[key])
					if passive_id != "":
						pays = true
						if DB.passive(passive_id).is_empty():
							problems.append("quest %s rewards an unknown passive" % id)
				elif name == "spirit_stones":
					var stones := int(reward[key])
					if stones < 0 or stones > 100000:
						problems.append("quest %s has an impossible stone reward" % id)
					pays = pays or stones > 0
				elif name == "contribution":
					var contribution := int(reward[key])
					if contribution < 0 or contribution > 1000:
						problems.append("quest %s has an impossible contribution reward" % id)
					pays = pays or contribution > 0
				else:
					problems.append("quest %s rewards an unknown %s" % [id, name])
			if not pays:
				problems.append("quest %s pays nothing" % id)
	# Prerequisites must resolve to authored quests, and must not form a cycle.
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var quest_data: Dictionary = value
		var id := String(quest_data.get("id", ""))
		var requirements_value: Variant = quest_data.get("requires", {})
		if typeof(requirements_value) != TYPE_DICTIONARY:
			continue
		var requirements: Dictionary = requirements_value
		for key_name in ["quests", "any_quests"]:
			var required_value: Variant = requirements.get(key_name, [])
			if typeof(required_value) != TYPE_ARRAY:
				continue
			for required in (required_value as Array):
				var required_id := String(required)
				if required_id != "" and not seen.has(required_id):
					problems.append("quest %s requires unknown quest %s" % [id, required_id])
	if problems.is_empty() and _has_cycle(list):
		problems.append("quest prerequisites form a cycle")
	if not seen.has(PRIMARY_ID):
		problems.append("the primary quest is missing")
	else:
		var primary: Dictionary = by_id.get(PRIMARY_ID, {})
		if not bool(primary.get("auto", false)):
			problems.append("the primary quest does not start itself")
	return problems


static func _has_cycle(list: Array) -> bool:
	var table: Dictionary = {}
	for value in list:
		if typeof(value) == TYPE_DICTIONARY:
			table[String((value as Dictionary).get("id", ""))] = value
	var visiting: Dictionary = {}
	var finished: Dictionary = {}
	for id in table.keys():
		if _cycle_visit(String(id), table, visiting, finished):
			return true
	return false


static func _cycle_visit(id: String, table: Dictionary, visiting: Dictionary, finished: Dictionary) -> bool:
	if finished.has(id):
		return false
	if visiting.has(id):
		return true
	visiting[id] = true
	var entry: Dictionary = table.get(id, {})
	var requirements_value: Variant = entry.get("requires", {})
	if typeof(requirements_value) == TYPE_DICTIONARY:
		var requirements: Dictionary = requirements_value
		for key_name in ["quests", "any_quests"]:
			var required_value: Variant = requirements.get(key_name, [])
			if typeof(required_value) != TYPE_ARRAY:
				continue
			for required in (required_value as Array):
				var required_id := String(required)
				if table.has(required_id) and _cycle_visit(required_id, table, visiting, finished):
					return true
	visiting.erase(id)
	finished[id] = true
	return false
