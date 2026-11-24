class_name Endgame
extends RefCounted
## The blank page: the run's one irreversible choice.
##
## The four narrative threads end in four records that describe one instrument:
## a road cut out of the world, roots fitted to climb it, bloodlines stocked to
## supply climbers and a book written to make each climber believe the road was
## theirs. The book's last page is blank. This class owns that page: what the
## reader may write, what the world must already have proved, and which single
## answer this save keeps.
##
## A resolution is never earned by reading alone. The threshold needs all four
## final records, and each page asks a different proof of the life lived: the
## altars a body has claimed, a hall it has founded, a house's regard, or — for
## the refusal — nothing but the reading. The choice is permanent for the save.
##
## The class is pure. The scene supplies a context snapshot, owns the toasts and
## draws the page; nothing here reads a node or a screen.

const SAVE_VERSION := 1
const ENDING_COUNT := 4
const PROOF_KINDS: Array[String] = ["altars", "hall", "regard", "none"]

## The ending id this save has committed to, or "" while the page is unwritten.
var chosen_id := ""


func _init() -> void:
	reset()


func reset() -> void:
	chosen_id = ""


# ------------------------------------------------------------------ data ----


func data() -> Dictionary:
	return DB.endgame_data


func threshold() -> Dictionary:
	var value: Variant = data().get("threshold", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func threshold_text() -> String:
	return String(threshold().get("text", ""))


func threshold_summary() -> String:
	return String(threshold().get("summary", ""))


func threshold_title() -> String:
	return String(threshold().get("title", "The Blank Page"))


func endings() -> Array:
	var value: Variant = data().get("endings", [])
	return value if typeof(value) == TYPE_ARRAY else []


func ending(id: String) -> Dictionary:
	for value in endings():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func is_chosen() -> bool:
	return chosen_id != "" and not chosen().is_empty()


func chosen() -> Dictionary:
	return ending(chosen_id)


func epilogue_text() -> String:
	return String(chosen().get("epilogue", ""))


# -------------------------------------------------------------- threshold ----


func threshold_requirements() -> Array:
	var value: Variant = threshold().get("requires", [])
	return value if typeof(value) == TYPE_ARRAY else []


## Final records the archive has not yet recovered. A save or a screen may ask
## this without knowing anything else about the run.
func missing_finals(narrative: MainNarrative) -> Array:
	var out: Array = []
	for value in threshold_requirements():
		var id := String(value)
		if narrative == null or not narrative.is_known(id):
			out.append(id)
	return out


func ready(narrative: MainNarrative) -> bool:
	return narrative != null and missing_finals(narrative).is_empty()


## The missing pages as the screen reads them: id, title and the record's own
## summary. Empty once the book is complete.
func missing_final_rows(narrative: MainNarrative) -> Array:
	var out: Array = []
	for value in missing_finals(narrative):
		var id := String(value)
		var entry: Dictionary = narrative.revelation(id) if narrative != null else {}
		out.append({
			"id": id,
			"title": String(entry.get("title", id)),
			"summary": String(entry.get("summary", "")),
		})
	return out


func progress_text(narrative: MainNarrative) -> String:
	return "%d / %d final records" % [
		threshold_requirements().size() - missing_finals(narrative).size(),
		threshold_requirements().size()]


# ----------------------------------------------------------------- proof ----


func proof(entry: Dictionary) -> Dictionary:
	var value: Variant = entry.get("proof", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func proof_kind(entry: Dictionary) -> String:
	return String(proof(entry).get("kind", ""))


## What the page asks for, in the page's words.
func proof_text(entry: Dictionary) -> String:
	var block := proof(entry)
	match String(block.get("kind", "")):
		"altars":
			return "%d altars claimed" % int(block.get("amount", 0))
		"hall":
			return "a hall of your own"
		"regard":
			return "%d regard with %s" % [
				int(block.get("amount", 0)),
				_storyline_title(String(block.get("storyline", "")))]
		"none":
			return "nothing but the reading"
	return "an unreadable condition"


func proof_met(entry: Dictionary, context: Dictionary = {}) -> bool:
	var block := proof(entry)
	match String(block.get("kind", "")):
		"altars":
			return int(context.get("altars", 0)) >= int(block.get("amount", 0))
		"hall":
			return bool(context.get("founded_sect", false))
		"regard":
			var have_value: Variant = context.get("regard", {})
			var have: Dictionary = have_value if typeof(have_value) == TYPE_DICTIONARY else {}
			return int(have.get(String(block.get("storyline", "")), 0)) >= int(block.get("amount", 0))
		"none":
			return true
	return false


## Why this page cannot be written right now, in one sentence. Empty when it can.
func blocked_reason(entry: Dictionary, narrative: MainNarrative, context: Dictionary = {}) -> String:
	if entry.is_empty():
		return "There is no such page."
	if is_chosen():
		return "The page is already written."
	if not ready(narrative):
		return "The book still lacks %d of its four final records." % missing_finals(narrative).size()
	if not proof_met(entry, context):
		return "The page asks for " + proof_text(entry) + "."
	return ""


## The four pages as the screen reads them. `unlocked` is a reading of both the
## threshold and the page's own proof, never a stored flag.
func available(narrative: MainNarrative, context: Dictionary = {}) -> Array:
	var out: Array = []
	var ready_now := ready(narrative)
	for value in endings():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			continue
		var unlocked := ready_now and proof_met(entry, context)
		out.append({
			"id": id,
			"title": String(entry.get("title", "")),
			"approach": String(entry.get("approach", "")),
			"promise": String(entry.get("promise", "")),
			"cost": String(entry.get("cost", "")),
			"colour": String(entry.get("colour", "#c8d8e0")),
			"proof": proof_text(entry),
			"unlocked": unlocked,
			"chosen": id == chosen_id,
			"reason": blocked_reason(entry, narrative, context),
		})
	return out


# ----------------------------------------------------------------- choice ----


## Writes the page. Refuses an unknown id, a second writing, an incomplete book
## and a page whose proof the run has not given. Returns true only when the save
## has just changed.
func choose(id: String, narrative: MainNarrative, context: Dictionary = {}) -> bool:
	if is_chosen():
		return false
	var entry := ending(id)
	if entry.is_empty():
		return false
	if not blocked_reason(entry, narrative, context).is_empty():
		return false
	chosen_id = id
	return true


# ------------------------------------------------------------ persistence ----


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "chosen": chosen_id}


## A save carries the written page only. An unknown id, or one written into a
## save whose archive does not hold all four final records, is dropped: a
## hand-edited save cannot claim an ending the run never reached.
func from_dict(data: Dictionary, narrative: MainNarrative = null) -> void:
	reset()
	if data.is_empty():
		return
	var id := String(data.get("chosen", ""))
	if id == "" or ending(id).is_empty():
		return
	if not ready(narrative):
		return
	chosen_id = id


# ------------------------------------------------------------- validation ----


## Boot safety for `data/endgame.json`: one threshold naming the last record of
## each thread, four distinct resolutions, real prose, valid colours, and a
## proof vocabulary this class actually understands.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no endgame data defined")
		return problems

	var threshold_value: Variant = data.get("threshold", null)
	if typeof(threshold_value) != TYPE_DICTIONARY:
		problems.append("endgame threshold is missing")
	else:
		_validate_threshold(threshold_value, problems)

	var list_value: Variant = data.get("endings", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("endgame endings are missing")
		return problems
	var rows: Array = list_value
	if rows.size() != ENDING_COUNT:
		problems.append("expected %d endings, found %d" % [ENDING_COUNT, rows.size()])
	var seen_ids: Dictionary = {}
	var seen_proofs: Dictionary = {}
	var silent := 0
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("an ending is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("an ending has no id")
			continue
		if not id.begins_with("ending."):
			problems.append("ending %s does not use an ending.* id" % id)
		if seen_ids.has(id):
			problems.append("duplicate ending " + id)
		seen_ids[id] = true
		for field in ["title", "approach", "promise", "cost", "epilogue"]:
			if String(entry.get(field, "")).strip_edges() == "":
				problems.append("ending %s has no %s" % [id, field])
		if not Color.html_is_valid(String(entry.get("colour", ""))):
			problems.append("ending %s has an invalid colour" % id)
		_validate_proof(entry, id, seen_proofs, problems)
		var block: Dictionary = {}
		var proof_value: Variant = entry.get("proof", {})
		if typeof(proof_value) == TYPE_DICTIONARY:
			block = proof_value
		if String(block.get("kind", "")) == "none":
			silent += 1
	if silent != 1:
		problems.append("exactly one ending must ask nothing of the run")
	if seen_proofs.size() != PROOF_KINDS.size():
		problems.append("the endings do not use every kind of proof")
	return problems


static func _validate_threshold(threshold: Dictionary, problems: Array) -> void:
	for field in ["title", "summary", "text"]:
		if String(threshold.get(field, "")).strip_edges() == "":
			problems.append("the endgame threshold has no %s" % field)
	var value: Variant = threshold.get("requires", null)
	if typeof(value) != TYPE_ARRAY:
		problems.append("the endgame threshold has no records")
		return
	var ids: Array = value
	if ids.size() != 4:
		problems.append("the endgame threshold needs four final records, found %d" % ids.size())
	var threads: Dictionary = {}
	for entry in ids:
		var id := String(entry)
		var thread_id := _thread_of(id)
		if thread_id == "":
			problems.append("the endgame threshold names unknown record %s" % id)
			continue
		if threads.has(thread_id):
			problems.append("the endgame threshold names two records from " + thread_id)
			continue
		threads[thread_id] = true
		var records := _records_of(thread_id)
		if records.is_empty() or String((records[records.size() - 1] as Dictionary).get("id", "")) != id:
			problems.append("the endgame threshold names %s, which is not its thread's final record" % id)
	if threads.size() != 4:
		problems.append("the endgame threshold does not name all four narrative threads")


static func _validate_proof(entry: Dictionary, id: String, seen: Dictionary, problems: Array) -> void:
	var value: Variant = entry.get("proof", null)
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		problems.append("ending %s has no proof" % id)
		return
	var block: Dictionary = value
	var kind := String(block.get("kind", ""))
	if not PROOF_KINDS.has(kind):
		problems.append("ending %s has an unknown proof %s" % [id, kind])
		return
	if seen.has(kind):
		problems.append("two endings ask the same proof: " + kind)
	seen[kind] = true
	match kind:
		"altars":
			var amount := int(block.get("amount", 0))
			if amount < 1 or amount > 9:
				problems.append("ending %s asks an impossible number of altars" % id)
		"regard":
			var storyline := String(block.get("storyline", ""))
			if not _storyline_ids().has(storyline):
				problems.append("ending %s names unknown storyline %s" % [id, storyline])
			var amount := int(block.get("amount", 0))
			if amount < 1 or amount > 100:
				problems.append("ending %s asks an impossible regard" % id)
		"hall":
			if block.has("amount") and int(block.get("amount", 0)) != 0:
				problems.append("ending %s gives a hall a number" % id)
		"none":
			pass


# ------------------------------------------------------------------ utils ----


static func _thread_of(record_id: String) -> String:
	var value: Variant = DB.main_narrative_data.get("threads", [])
	if typeof(value) != TYPE_ARRAY:
		return ""
	for thread_value in (value as Array):
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		var thread_data: Dictionary = thread_value
		for record in _records_of(String(thread_data.get("id", ""))):
			if String((record as Dictionary).get("id", "")) == record_id:
				return String(thread_data.get("id", ""))
	return ""


static func _records_of(thread_id: String) -> Array:
	var value: Variant = DB.main_narrative_data.get("threads", [])
	if typeof(value) != TYPE_ARRAY:
		return []
	for thread_value in (value as Array):
		if typeof(thread_value) == TYPE_DICTIONARY \
				and String((thread_value as Dictionary).get("id", "")) == thread_id:
			var records_value: Variant = (thread_value as Dictionary).get("revelations", [])
			return records_value if typeof(records_value) == TYPE_ARRAY else []
	return []


static func _storyline_title(id: String) -> String:
	var value: Variant = DB.sect_storylines_data.get("storylines", [])
	if typeof(value) == TYPE_ARRAY:
		for entry in (value as Array):
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) == id:
				return String((entry as Dictionary).get("title", id))
	return id


static func _storyline_ids() -> Dictionary:
	var out: Dictionary = {}
	var value: Variant = DB.sect_storylines_data.get("storylines", [])
	if typeof(value) == TYPE_ARRAY:
		for entry in (value as Array):
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) != "":
				out[String((entry as Dictionary).get("id", ""))] = true
	return out
