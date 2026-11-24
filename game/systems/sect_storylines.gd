class_name SectStorylines
extends RefCounted
## The twelve houses' own stories.
##
## Every sect owns one authored arc of three chapters. A chapter is a real
## gameplay test (the same events the quest log hears) followed by a choice
## between two stances. The choice moves that house's regard, pays the effects it
## names and decides which ending the arc reaches.
##
## The structure of stakes is shared — welcome, fault line, reckoning — but the
## work is not: a sword house asks for duels and forge-work, a medicine valley for
## herbs and brews, an archive for a copied page. The class is pure; the scene
## owns the purse, the standing and the satchel.
##
## The Azure Cloud's arc begins in conversation with Elder Bai. The other eleven
## houses write to the market board; only one such correspondence may be open at
## a time, and two houses refuse each other outright.

const SAVE_VERSION := 1
## Every gameplay event a chapter may listen for. The quest log exposes the same
## set, because both systems are fed by the scene's one reporting call.
const KINDS: Array[String] = ["talk", "return", "kill", "collect", "channel", "craft", "trade", "realm", "inheritance"]
const MAX_COUNT := 99
const MAX_REGARD := 100
const CHAPTERS_PER_STORYLINE := 3
const CHOICES_PER_CHAPTER := 2

## storyline id -> {accepted, chapter, counters, awaiting_choice, completed,
##                  choices, regard}
var states: Dictionary = {}


func _init() -> void:
	reset()


# ------------------------------------------------------------------ data ----


func data() -> Dictionary:
	return DB.sect_storylines_data


func start_regard() -> int:
	return clampi(int(data().get("start_regard", 10)), 0, MAX_REGARD)


func stakes() -> Array:
	var value: Variant = data().get("stakes", [])
	return value if typeof(value) == TYPE_ARRAY else []


func stake(id: String) -> Dictionary:
	for value in stakes():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


func storylines() -> Array:
	var value: Variant = data().get("storylines", [])
	return value if typeof(value) == TYPE_ARRAY else []


func storyline(id: String) -> Dictionary:
	for value in storylines():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


## The one arc whose house the player stands in. Exactly one sect is authored
## local, so this resolves without a scene lookup.
func local_id() -> String:
	for value in storylines():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var sect := Sects.sect(String(entry.get("sect", "")))
		if bool(sect.get("local", false)):
			return String(entry.get("id", ""))
	return ""


func is_local(id: String) -> bool:
	var sect := Sects.sect(String(storyline(id).get("sect", "")))
	return bool(sect.get("local", false))


func chapters_of(id: String) -> Array:
	var value: Variant = storyline(id).get("chapters", [])
	return value if typeof(value) == TYPE_ARRAY else []


func chapter_at(id: String, index: int) -> Dictionary:
	var list := chapters_of(id)
	if index < 0 or index >= list.size():
		return {}
	var value: Variant = list[index]
	return value if typeof(value) == TYPE_DICTIONARY else {}


func chapter_of(id: String) -> Dictionary:
	return chapter_at(id, progress_of(id))


func title_of(id: String) -> String:
	return String(storyline(id).get("title", "Unknown Storyline"))


func sect_of(id: String) -> Dictionary:
	return Sects.sect(String(storyline(id).get("sect", "")))


# ----------------------------------------------------------------- state ----


func reset() -> void:
	states.clear()
	for value in storylines():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "":
			states[id] = _fresh_state()


func _fresh_state() -> Dictionary:
	return {
		"accepted": false,
		"chapter": 0,
		"counters": {},
		"awaiting_choice": false,
		"completed": false,
		"choices": {},
		"regard": start_regard(),
	}


func state_of(id: String) -> Dictionary:
	return _state(id).duplicate(true)


func is_accepted(id: String) -> bool:
	return bool(_state(id).get("accepted", false))


func is_completed(id: String) -> bool:
	return bool(_state(id).get("completed", false))


func is_awaiting_choice(id: String) -> bool:
	return bool(_state(id).get("awaiting_choice", false))


func progress_of(id: String) -> int:
	return clampi(int(_state(id).get("chapter", 0)), 0, maxi(0, chapters_of(id).size() - 1))


func regard_of(id: String) -> int:
	return clampi(int(_state(id).get("regard", start_regard())), 0, MAX_REGARD)


## chapter id -> chosen option id, for the ledger and the codex.
func choices_made(id: String) -> Dictionary:
	var value: Variant = _state(id).get("choices", {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func accepted_ids() -> Array:
	var out: Array = []
	for value in storylines():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and is_accepted(id) and not is_completed(id):
			out.append(id)
	return out


func completed_ids() -> Array:
	var out: Array = []
	for value in storylines():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and is_completed(id):
			out.append(id)
	return out


# ------------------------------------------------------------ availability ----


## Whether a house's letter can be taken up now. The gates are the authored
## realm and contribution, the completed arcs it names, the houses it refuses and
## the one-correspondence rule for everything outside the player's own gate.
func is_available(id: String, context: Dictionary = {}) -> bool:
	var entry := storyline(id)
	if entry.is_empty():
		return false
	var state := _state(id)
	if bool(state.get("accepted", false)) or bool(state.get("completed", false)):
		return false
	var unlock_value: Variant = entry.get("unlock", {})
	if typeof(unlock_value) == TYPE_DICTIONARY:
		var unlock: Dictionary = unlock_value
		if int(context.get("realm", 0)) < int(unlock.get("min_realm", 0)):
			return false
		if int(context.get("contribution", 0)) < int(unlock.get("min_contribution", 0)):
			return false
	var required: Variant = entry.get("requires_storylines", [])
	if typeof(required) == TYPE_ARRAY:
		for value in (required as Array):
			if not is_completed(String(value)):
				return false
	var exclusions: Variant = entry.get("excludes", [])
	if typeof(exclusions) == TYPE_ARRAY:
		for value in (exclusions as Array):
			var other := String(value)
			if other != "" and is_accepted(other) and not is_completed(other):
				return false
	if not is_local(id) and foreign_active_id() != "":
		return false
	return true


func available_ids(context: Dictionary = {}) -> Array:
	var out: Array = []
	for value in storylines():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and is_available(id, context):
			out.append(id)
	return out


## The one open correspondence outside the player's gate, or "" when there is
## none. A completed foreign arc no longer occupies the slot.
func foreign_active_id() -> String:
	for value in accepted_ids():
		var id := String(value)
		if not is_local(id):
			return id
	return ""


func status(id: String, context: Dictionary = {}) -> String:
	if is_completed(id):
		return "completed"
	if is_accepted(id):
		return "decision" if is_awaiting_choice(id) else "active"
	if is_available(id, context):
		return "available"
	return "locked"


func accept(id: String, context: Dictionary = {}) -> bool:
	if not is_available(id, context):
		return false
	_state(id)["accepted"] = true
	return true


# --------------------------------------------------------------- progress ----


## The current chapter's test, exactly as authored.
func test_of(id: String) -> Dictionary:
	var value: Variant = chapter_of(id).get("test", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


## Reports an event to every open arc. A test only advances while its chapter is
## unpaid and undecided; once the choice is pending, further events are ignored
## so the decision cannot be farmed.
func report(kind: String, target: String, amount: int = 1) -> Array:
	var out: Array = []
	if amount <= 0:
		return out
	for id_value in states.keys():
		var id := String(id_value)
		var state: Dictionary = states[id]
		if not bool(state.get("accepted", false)) or bool(state.get("completed", false)):
			continue
		if bool(state.get("awaiting_choice", false)):
			continue
		var chapter := chapter_of(id)
		if chapter.is_empty():
			continue
		var test_value: Variant = chapter.get("test", {})
		if typeof(test_value) != TYPE_DICTIONARY:
			continue
		var test: Dictionary = test_value
		if String(test.get("kind", "")) != kind or String(test.get("target", "")) != target:
			continue
		var key := _test_key(test)
		var need := clampi(int(test.get("count", 1)), 1, MAX_COUNT)
		var counters_value: Variant = state.get("counters", {})
		var counters: Dictionary = counters_value if typeof(counters_value) == TYPE_DICTIONARY else {}
		counters[key] = mini(int(counters.get(key, 0)) + amount, need)
		state["counters"] = counters
		if int(counters[key]) < need:
			continue
		state["awaiting_choice"] = true
		out.append({
			"storyline_id": id,
			"title": title_of(id),
			"chapter_id": String(chapter.get("id", "")),
			"chapter_title": String(chapter.get("title", "")),
			"completed": false,
		})
	return out


## The two authored stances for the current chapter, or [] until its test is
## paid. The screen draws them; nothing here touches the world.
func choices_of(id: String) -> Array:
	if not is_accepted(id) or is_completed(id) or not is_awaiting_choice(id):
		return []
	var value: Variant = chapter_of(id).get("choices", [])
	return value if typeof(value) == TYPE_ARRAY else []


func choice_by_id(id: String, choice_id: String) -> Dictionary:
	for value in choices_of(id):
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == choice_id:
			return value
	return {}


## Takes one stance. Regard is applied here because it is the story's own number;
## every other effect is returned for the scene, which owns the purse and the
## satchel. A chapter can be decided once.
func choose(id: String, choice_id: String) -> Dictionary:
	var out := {
		"ok": false,
		"reason": "",
		"storyline_id": id,
		"chapter_id": "",
		"choice_id": choice_id,
		"effects": {},
		"completed": false,
		"ending": {},
		"next_chapter": {},
	}
	var entry := storyline(id)
	if entry.is_empty():
		out["reason"] = "unknown storyline"
		return out
	var state := _state(id)
	if not bool(state.get("accepted", false)):
		out["reason"] = "the house has not opened its doors"
		return out
	if bool(state.get("completed", false)):
		out["reason"] = "this story is already told"
		return out
	if not bool(state.get("awaiting_choice", false)):
		out["reason"] = "the chapter is not finished"
		return out
	var chapter := chapter_of(id)
	if chapter.is_empty():
		out["reason"] = "the chapter is missing"
		return out
	var choice := choice_by_id(id, choice_id)
	if choice.is_empty():
		out["reason"] = "unknown stance"
		return out
	var effects_value: Variant = choice.get("effects", {})
	var effects: Dictionary = effects_value if typeof(effects_value) == TYPE_DICTIONARY else {}
	var regard := clampi(regard_of(id) + int(effects.get("regard", 0)), 0, MAX_REGARD)
	var choices_value: Variant = state.get("choices", {})
	var ledger: Dictionary = choices_value if typeof(choices_value) == TYPE_DICTIONARY else {}
	ledger[String(chapter.get("id", ""))] = choice_id
	state["choices"] = ledger
	state["regard"] = regard
	state["awaiting_choice"] = false
	var next := int(state.get("chapter", 0)) + 1
	var finished := next >= chapters_of(id).size()
	state["chapter"] = mini(next, maxi(0, chapters_of(id).size() - 1))
	state["completed"] = finished
	state["counters"] = {}
	out["ok"] = true
	out["chapter_id"] = String(chapter.get("id", ""))
	out["effects"] = effects.duplicate(true)
	out["completed"] = finished
	if finished:
		out["ending"] = ending_for(id)
	else:
		out["next_chapter"] = chapter_of(id)
	return out


## The first authored ending whose regard floor is met. Data is ordered from the
## highest floor down, with a zero floor last, so this always resolves.
func ending_for(id: String) -> Dictionary:
	var value: Variant = storyline(id).get("endings", [])
	if typeof(value) != TYPE_ARRAY:
		return {}
	var regard := regard_of(id)
	for entry in (value as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		if regard >= int(row.get("min_regard", 0)):
			return row
	return {}


## The live chapter's one line, with its own counter. A pending decision says so
## instead of the test, so the screen never asks for work already done.
func progress_text(id: String) -> String:
	if is_completed(id):
		var ending := ending_for(id)
		return String(ending.get("title", "The story is told."))
	if not is_accepted(id):
		return "The house has not written to you."
	if is_awaiting_choice(id):
		return "Decision — %s" % String(chapter_of(id).get("title", "the chapter"))
	var test := test_of(id)
	if test.is_empty():
		return String(chapter_of(id).get("title", ""))
	var need := clampi(int(test.get("count", 1)), 1, MAX_COUNT)
	var have := mini(int(_counters(id).get(_test_key(test), 0)), need)
	return "%s  (%d/%d)" % [String(test.get("text", "Continue the chapter")), have, need]


## Two flat lines per open arc, for the HUD tracker under the quest lines.
func tracker_lines(max_storylines: int = 1) -> Array:
	var out: Array = []
	for value in accepted_ids():
		if out.size() >= max_storylines * 2:
			break
		var id := String(value)
		out.append("STORY — " + title_of(id))
		out.append(progress_text(id))
	return out


# ------------------------------------------------------------ persistence ----


func to_dict() -> Dictionary:
	var copy: Dictionary = {}
	for id in states.keys():
		copy[String(id)] = (states[id] as Dictionary).duplicate(true)
	return {"version": SAVE_VERSION, "states": copy}


## A save carries only decisions. Unknown arcs vanish, an oversized chapter is
## clamped, a decision that no longer has a paid test is reopened, counters are
## kept only for the live chapter, picked stances must belong to their chapter,
## and regard is bounded.
func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	var saved: Variant = data.get("states", null)
	if typeof(saved) != TYPE_DICTIONARY:
		return
	var table: Dictionary = saved
	for key in table.keys():
		var id := String(key)
		if not states.has(id) or not table.has(id):
			continue
		var raw_value: Variant = table[id]
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue
		_apply_state(id, raw_value)


func _apply_state(id: String, value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = value
	var state := _state(id)
	var chapters := chapters_of(id)
	var chapter := clampi(int(raw.get("chapter", 0)), 0, maxi(0, chapters.size() - 1))
	state["chapter"] = chapter
	state["regard"] = clampi(int(raw.get("regard", start_regard())), 0, MAX_REGARD)
	var decisions_value: Variant = raw.get("choices", {})
	var decisions: Dictionary = decisions_value if typeof(decisions_value) == TYPE_DICTIONARY else {}
	var clean: Dictionary = {}
	for index in chapters.size():
		var entry := chapter_at(id, index)
		var chapter_id := String(entry.get("id", ""))
		if chapter_id == "" or not decisions.has(chapter_id):
			continue
		var picked := String(decisions[chapter_id])
		if _choice_exists(entry, picked):
			clean[chapter_id] = picked
	state["choices"] = clean
	var completed := bool(raw.get("completed", false))
	state["completed"] = completed
	state["accepted"] = bool(raw.get("accepted", false)) or completed or chapter > 0 or not clean.is_empty()
	state["awaiting_choice"] = false
	state["counters"] = {}
	if completed:
		state["chapter"] = maxi(0, chapters.size() - 1)
		state["accepted"] = true
		return
	# The live chapter is the first one without a recorded stance. A save cannot
	# point back at a chapter it already decided, so no stance pays twice.
	var first_open := chapters.size()
	for index in chapters.size():
		var open_entry := chapter_at(id, index)
		if not clean.has(String(open_entry.get("id", ""))):
			first_open = index
			break
	if first_open >= chapters.size():
		state["completed"] = true
		state["accepted"] = true
		state["chapter"] = maxi(0, chapters.size() - 1)
		return
	chapter = mini(chapter, first_open)
	state["chapter"] = chapter
	# A live test's counters are restored only when they belong to this chapter.
	var live := chapter_at(id, chapter)
	var test_value: Variant = live.get("test", {})
	if typeof(test_value) == TYPE_DICTIONARY:
		var test: Dictionary = test_value
		var key := _test_key(test)
		var need := clampi(int(test.get("count", 1)), 1, MAX_COUNT)
		var counters_value: Variant = raw.get("counters", {})
		var counters: Dictionary = counters_value if typeof(counters_value) == TYPE_DICTIONARY else {}
		if key != "" and counters.has(key):
			var have := clampi(int(counters[key]), 0, need)
			if have > 0:
				state["counters"] = {key: have}
				if have >= need:
					state["awaiting_choice"] = true


func _counters(id: String) -> Dictionary:
	var value: Variant = _state(id).get("counters", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _state(id: String) -> Dictionary:
	if not states.has(id):
		if storyline(id).is_empty():
			return _fresh_state()
		states[id] = _fresh_state()
	return states[id]


static func _test_key(test: Dictionary) -> String:
	return "%s:%s" % [String(test.get("kind", "")), String(test.get("target", ""))]


static func _choice_exists(chapter: Dictionary, choice_id: String) -> bool:
	var value: Variant = chapter.get("choices", [])
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in (value as Array):
		if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) == choice_id:
			return true
	return false


# ------------------------------------------------------------- validation ----


## Boot safety for `data/sect_storylines.json`: one arc per house, three shared
## stakes used once each, resolvable gates, symmetric refusals, real tests,
## exactly two stances with real effects, and endings that always resolve.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no sect storyline data defined")
		return problems
	var start := int(data.get("start_regard", -1))
	if start < 0 or start > MAX_REGARD:
		problems.append("sect storyline start regard is outside 0..%d" % MAX_REGARD)

	var stake_rows: Variant = data.get("stakes", null)
	var stake_ids: Dictionary = {}
	if typeof(stake_rows) != TYPE_ARRAY or (stake_rows as Array).is_empty():
		problems.append("sect storyline stakes are missing")
	else:
		for value in (stake_rows as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("a sect storyline stake is not an object")
				continue
			var stake: Dictionary = value
			var id := String(stake.get("id", ""))
			if id == "":
				problems.append("a sect storyline stake has no id")
				continue
			if stake_ids.has(id):
				problems.append("duplicate sect storyline stake " + id)
			stake_ids[id] = true
			if String(stake.get("name", "")).strip_edges() == "":
				problems.append("sect storyline stake %s has no name" % id)
			if String(stake.get("blurb", "")).strip_edges() == "":
				problems.append("sect storyline stake %s has no blurb" % id)
		if stake_ids.size() != CHAPTERS_PER_STORYLINE:
			problems.append("expected %d shared stakes, found %d" % [CHAPTERS_PER_STORYLINE, stake_ids.size()])

	var list: Variant = data.get("storylines", null)
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		problems.append("sect storylines are missing")
		return problems
	var rows: Array = list
	var seen: Dictionary = {}
	var by_id: Dictionary = {}
	var per_sect: Dictionary = {}
	var local_count := 0
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("a sect storyline is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("a sect storyline has no id")
			continue
		if seen.has(id):
			problems.append("duplicate sect storyline " + id)
		seen[id] = true
		by_id[id] = entry
		if String(entry.get("title", "")).strip_edges() == "":
			problems.append("sect storyline %s has no title" % id)
		if String(entry.get("summary", "")).strip_edges() == "":
			problems.append("sect storyline %s has no summary" % id)
		if String(entry.get("giver", "")).strip_edges() == "":
			problems.append("sect storyline %s has no giver" % id)
		var sect_id := String(entry.get("sect", ""))
		var sect := Sects.sect(sect_id)
		if sect.is_empty():
			problems.append("sect storyline %s names an unknown sect" % id)
		else:
			if per_sect.has(sect_id):
				problems.append("two storylines belong to %s" % sect_id)
			per_sect[sect_id] = true
			if bool(sect.get("local", false)):
				local_count += 1
		var unlock_value: Variant = entry.get("unlock", {})
		if typeof(unlock_value) != TYPE_DICTIONARY:
			problems.append("sect storyline %s has unreadable gates" % id)
		else:
			var unlock: Dictionary = unlock_value
			var realm := int(unlock.get("min_realm", 0))
			if realm < 0 or realm > 12:
				problems.append("sect storyline %s has an impossible realm gate" % id)
			var contribution := int(unlock.get("min_contribution", 0))
			if contribution < 0 or contribution > 100000:
				problems.append("sect storyline %s has an impossible contribution gate" % id)
		var required_value: Variant = entry.get("requires_storylines", [])
		if typeof(required_value) != TYPE_ARRAY:
			problems.append("sect storyline %s has malformed prerequisites" % id)
		else:
			for other in (required_value as Array):
				var other_id := String(other)
				if other_id == id:
					problems.append("sect storyline %s requires itself" % id)
				elif other_id != "" and not seen.has(other_id):
					problems.append("sect storyline %s requires unknown %s" % [id, other_id])
		var exclusion_value: Variant = entry.get("excludes", [])
		if typeof(exclusion_value) != TYPE_ARRAY:
			problems.append("sect storyline %s has malformed exclusions" % id)
		else:
			for other in (exclusion_value as Array):
				if String(other) == id:
					problems.append("sect storyline %s excludes itself" % id)
		_validate_chapters(entry, id, stake_ids, problems)
		_validate_endings(entry, id, problems)

	if rows.size() != Sects.count():
		problems.append("expected %d sect storylines, found %d" % [Sects.count(), rows.size()])
	if local_count != 1:
		problems.append("expected exactly one local sect storyline, found %d" % local_count)

	# Prerequisites must not cycle, and a refusal must be mutual: one house
	# cannot claim another will not take you while that house still would.
	for id in by_id.keys():
		var entry: Dictionary = by_id[id]
		var required_value: Variant = entry.get("requires_storylines", [])
		if typeof(required_value) == TYPE_ARRAY:
			for other in (required_value as Array):
				var other_id := String(other)
				if other_id != "" and not seen.has(other_id):
					problems.append("sect storyline %s requires unknown %s" % [String(id), other_id])
		var exclusion_value: Variant = entry.get("excludes", [])
		if typeof(exclusion_value) == TYPE_ARRAY:
			for other in (exclusion_value as Array):
				var other_id := String(other)
				if other_id == "" or not seen.has(other_id):
					problems.append("sect storyline %s excludes unknown %s" % [String(id), other_id])
					continue
				var back: Variant = (by_id[other_id] as Dictionary).get("excludes", [])
				if typeof(back) != TYPE_ARRAY or not (back as Array).has(String(id)):
					problems.append("sect storyline %s excludes %s but not the reverse" % [String(id), other_id])
	if problems.is_empty() and _has_cycle(by_id):
		problems.append("sect storyline prerequisites form a cycle")
	return problems


static func _validate_chapters(entry: Dictionary, id: String, stake_ids: Dictionary, problems: Array) -> void:
	var list_value: Variant = entry.get("chapters", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("sect storyline %s has no chapters" % id)
		return
	var rows: Array = list_value
	if rows.size() != CHAPTERS_PER_STORYLINE:
		problems.append("sect storyline %s has %d chapters, expected %d" % [id, rows.size(), CHAPTERS_PER_STORYLINE])
	var used_stakes: Dictionary = {}
	var chapter_ids: Dictionary = {}
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("sect storyline %s has a chapter that is not an object" % id)
			continue
		var chapter: Dictionary = value
		var chapter_id := String(chapter.get("id", ""))
		if chapter_id == "":
			problems.append("sect storyline %s has a chapter without id" % id)
			continue
		if chapter_ids.has(chapter_id):
			problems.append("duplicate chapter %s" % chapter_id)
		chapter_ids[chapter_id] = true
		if String(chapter.get("title", "")).strip_edges() == "":
			problems.append("chapter %s has no title" % chapter_id)
		if String(chapter.get("brief", "")).strip_edges() == "":
			problems.append("chapter %s has no brief" % chapter_id)
		var stake_id := String(chapter.get("stake", ""))
		if not stake_ids.has(stake_id):
			problems.append("chapter %s names unknown stake %s" % [chapter_id, stake_id])
		elif used_stakes.has(stake_id):
			problems.append("chapter %s reuses stake %s" % [chapter_id, stake_id])
		else:
			used_stakes[stake_id] = true
		var test_value: Variant = chapter.get("test", {})
		if typeof(test_value) != TYPE_DICTIONARY:
			problems.append("chapter %s has no test" % chapter_id)
		else:
			var test: Dictionary = test_value
			var kind := String(test.get("kind", ""))
			if not KINDS.has(kind):
				problems.append("chapter %s asks for unknown work %s" % [chapter_id, kind])
			if String(test.get("target", "")).strip_edges() == "":
				problems.append("chapter %s has a test without target" % chapter_id)
			var count := int(test.get("count", 1))
			if count < 1 or count > MAX_COUNT:
				problems.append("chapter %s has an impossible test count" % chapter_id)
			if String(test.get("text", "")).strip_edges() == "":
				problems.append("chapter %s has a test without text" % chapter_id)
		var choice_value: Variant = chapter.get("choices", null)
		if typeof(choice_value) != TYPE_ARRAY:
			problems.append("chapter %s has no choices" % chapter_id)
			continue
		var choices: Array = choice_value
		if choices.size() != CHOICES_PER_CHAPTER:
			problems.append("chapter %s has %d stances, expected %d" % [chapter_id, choices.size(), CHOICES_PER_CHAPTER])
		var seen_choices: Dictionary = {}
		for choice_data in choices:
			if typeof(choice_data) != TYPE_DICTIONARY:
				problems.append("chapter %s has a stance that is not an object" % chapter_id)
				continue
			var choice: Dictionary = choice_data
			var choice_id := String(choice.get("id", ""))
			if choice_id == "":
				problems.append("chapter %s has a stance without id" % chapter_id)
				continue
			if seen_choices.has(choice_id):
				problems.append("duplicate stance %s" % choice_id)
			seen_choices[choice_id] = true
			if String(choice.get("label", "")).strip_edges() == "":
				problems.append("stance %s has no label" % choice_id)
			if String(choice.get("detail", "")).strip_edges() == "":
				problems.append("stance %s has no detail" % choice_id)
			_validate_effects(choice, choice_id, problems)


static func _validate_effects(choice: Dictionary, choice_id: String, problems: Array) -> void:
	var value: Variant = choice.get("effects", null)
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		problems.append("stance %s changes nothing" % choice_id)
		return
	var effects: Dictionary = value
	for key in effects.keys():
		var name := String(key)
		if name == "regard":
			var amount := int(effects[key])
			if amount < -40 or amount > 40:
				problems.append("stance %s moves regard by an impossible amount" % choice_id)
		elif name == "stones":
			var stones := int(effects[key])
			if stones < 0 or stones > 10000:
				problems.append("stance %s pays an impossible stone amount" % choice_id)
		elif name == "contribution":
			var contribution := int(effects[key])
			if contribution < 0 or contribution > 1000:
				problems.append("stance %s pays impossible contribution" % choice_id)
		elif name == "notoriety":
			var notoriety := int(effects[key])
			if notoriety < -40 or notoriety > 40:
				problems.append("stance %s moves notoriety by an impossible amount" % choice_id)
		elif name == "karma":
			var karma := int(effects[key])
			if karma < -100 or karma > 100:
				problems.append("stance %s moves karma by an impossible amount" % choice_id)
		elif name == "technique":
			var technique_id := String(effects[key])
			if technique_id != "" and DB.technique(technique_id).is_empty():
				problems.append("stance %s grants unknown technique %s" % [choice_id, technique_id])
		elif name == "passive":
			var passive_id := String(effects[key])
			if passive_id != "" and DB.passive(passive_id).is_empty():
				problems.append("stance %s grants unknown passive %s" % [choice_id, passive_id])
		elif name == "standing":
			var standing_value: Variant = effects[key]
			if typeof(standing_value) != TYPE_DICTIONARY:
				problems.append("stance %s has unreadable standing" % choice_id)
				continue
			var standing: Dictionary = standing_value
			var faction_id := String(standing.get("faction", ""))
			if faction_id == "" or DB.faction(faction_id).is_empty():
				problems.append("stance %s names unknown faction %s" % [choice_id, faction_id])
			var amount := int(standing.get("amount", 0))
			if amount == 0 or amount < -30 or amount > 30:
				problems.append("stance %s moves standing by an impossible amount" % choice_id)
		else:
			problems.append("stance %s has an unknown effect %s" % [choice_id, name])


static func _validate_endings(entry: Dictionary, id: String, problems: Array) -> void:
	var value: Variant = entry.get("endings", null)
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 2:
		problems.append("sect storyline %s needs at least two endings" % id)
		return
	var rows: Array = value
	var last := MAX_REGARD + 1
	var has_zero := false
	for entry_value in rows:
		if typeof(entry_value) != TYPE_DICTIONARY:
			problems.append("sect storyline %s has an ending that is not an object" % id)
			continue
		var ending: Dictionary = entry_value
		if String(ending.get("title", "")).strip_edges() == "":
			problems.append("sect storyline %s has an ending without title" % id)
		if String(ending.get("text", "")).strip_edges() == "":
			problems.append("sect storyline %s has an ending without text" % id)
		var floor := int(ending.get("min_regard", -1))
		if floor < 0 or floor > MAX_REGARD:
			problems.append("sect storyline %s has an ending outside the regard scale" % id)
		elif floor >= last:
			problems.append("sect storyline %s endings are not ordered by regard" % id)
		else:
			last = floor
		if floor == 0:
			has_zero = true
	if not has_zero:
		problems.append("sect storyline %s has no ending for low regard" % id)


static func _has_cycle(table: Dictionary) -> bool:
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
	var value: Variant = entry.get("requires_storylines", [])
	if typeof(value) == TYPE_ARRAY:
		for other in (value as Array):
			var other_id := String(other)
			if table.has(other_id) and _cycle_visit(other_id, table, visiting, finished):
				return true
	visiting.erase(id)
	finished[id] = true
	return false
