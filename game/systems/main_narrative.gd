class_name MainNarrative
extends RefCounted
## The province's four archaeological threads.
##
## The main line is not a prophecy and the player is not chosen. Four questions
## are already written into the world — why the old ascent failed, where roots
## come from, who distributed the physiques, and who wrote the book that rewrites
## its readers. Each is a thread of four records. A record is uncovered by real
## state: a realm entered, an inheritance claimed, a quest or a house's story
## finished, a rank reached, work done at the forge or the cauldron, a place
## found. The last record of every thread needs records from two other threads,
## so the four converge without prescribing an order.
##
## The class is pure. The scene supplies a context snapshot, owns the toasts and
## draws the archive; nothing here reads a node or a screen.

const SAVE_VERSION := 1
const THREAD_COUNT := 4
const REVELATIONS_PER_THREAD := 4

## Every condition a record may be gated on. Adding a key here is the one place
## that decides what content may ask the world for.
const CONDITION_KEYS: Array[String] = [
	"min_realm", "min_kills", "min_contribution", "min_inheritances", "min_crafts",
	"min_rank", "sect_seat", "founded_sect", "quests", "any_quests",
	"storylines", "any_storylines", "storyline_regard", "discovered", "threads",
]

## lore id -> true. Only discovered records are ever stored.
var known: Dictionary = {}


func _init() -> void:
	reset()


# ------------------------------------------------------------------ data ----


func data() -> Dictionary:
	return DB.main_narrative_data


func threads() -> Array:
	var value: Variant = data().get("threads", [])
	return value if typeof(value) == TYPE_ARRAY else []


func thread(id: String) -> Dictionary:
	for value in threads():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


func revelations_of(thread_id: String) -> Array:
	var value: Variant = thread(thread_id).get("revelations", [])
	return value if typeof(value) == TYPE_ARRAY else []


func revelation(id: String) -> Dictionary:
	for thread_value in threads():
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		for value in revelations_of(String((thread_value as Dictionary).get("id", ""))):
			if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
				return value
	return {}


func thread_of(id: String) -> Dictionary:
	for thread_value in threads():
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		var thread_data: Dictionary = thread_value
		for value in revelations_of(String(thread_data.get("id", ""))):
			if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
				return thread_data
	return {}


func thread_id_of(id: String) -> String:
	return String(thread_of(id).get("id", ""))


func total_count() -> int:
	var total := 0
	for value in threads():
		if typeof(value) == TYPE_DICTIONARY:
			total += revelations_of(String((value as Dictionary).get("id", ""))).size()
	return total


func reset() -> void:
	known.clear()


func is_known(id: String) -> bool:
	return bool(known.get(id, false))


func known_in_thread(thread_id: String) -> int:
	var count := 0
	for value in revelations_of(thread_id):
		if typeof(value) == TYPE_DICTIONARY and is_known(String((value as Dictionary).get("id", ""))):
			count += 1
	return count


func progress_text(thread_id: String) -> String:
	return "%d / %d records" % [known_in_thread(thread_id), revelations_of(thread_id).size()]


## The first record of a thread still missing, whether or not its gates are met.
func next_in_thread(thread_id: String) -> Dictionary:
	for value in revelations_of(thread_id):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if not is_known(String(entry.get("id", ""))):
			return entry
	return {}


# ------------------------------------------------------------- discovery ----


## One evaluation pass reveals everything the context now supports, including a
## record opened by another record from the same pass. Returns the new records
## in authored order; calling it twice changes nothing the second time.
func evaluate(context: Dictionary = {}) -> Array:
	var out: Array = []
	var changed := true
	while changed:
		changed = false
		for thread_value in threads():
			if typeof(thread_value) != TYPE_DICTIONARY:
				continue
			var thread_data: Dictionary = thread_value
			for value in revelations_of(String(thread_data.get("id", ""))):
				if typeof(value) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = value
				var id := String(entry.get("id", ""))
				if id == "" or is_known(id):
					continue
				if not is_met(entry, context):
					continue
				known[id] = true
				changed = true
				out.append({
					"id": id,
					"title": String(entry.get("title", "")),
					"thread": String(thread_data.get("name", "")),
					"thread_id": String(thread_data.get("id", "")),
					"source": String(entry.get("source", "")),
				})
	return out


## A record is met when its earlier records are known and every world condition
## it names is true of the context. `threads` is checked against this ledger,
## never against the caller's dictionary, so a context cannot fake convergence.
func is_met(entry: Dictionary, context: Dictionary = {}) -> bool:
	if entry.is_empty():
		return false
	var requires_value: Variant = entry.get("requires", {})
	if typeof(requires_value) != TYPE_DICTIONARY:
		return false
	var requires: Dictionary = requires_value
	var prior_value: Variant = requires.get("threads", [])
	if typeof(prior_value) == TYPE_ARRAY:
		for value in (prior_value as Array):
			if not is_known(String(value)):
				return false
	if int(context.get("realm", 0)) < int(requires.get("min_realm", 0)):
		return false
	if int(context.get("kills", 0)) < int(requires.get("min_kills", 0)):
		return false
	if int(context.get("contribution", 0)) < int(requires.get("min_contribution", 0)):
		return false
	if int(context.get("inheritances", 0)) < int(requires.get("min_inheritances", 0)):
		return false
	if int(context.get("crafts", 0)) < int(requires.get("min_crafts", 0)):
		return false
	var min_rank := String(requires.get("min_rank", ""))
	if min_rank != "" and Hierarchy.level(String(context.get("rank", ""))) < Hierarchy.level(min_rank):
		return false
	if bool(requires.get("sect_seat", false)) and not bool(context.get("sect_seat", false)):
		return false
	if bool(requires.get("founded_sect", false)) and not bool(context.get("founded_sect", false)):
		return false
	if not _all_in(context, "quests", requires.get("quests", [])):
		return false
	if not _any_in(context, "quests", requires.get("any_quests", [])):
		return false
	if not _all_in(context, "storylines", requires.get("storylines", [])):
		return false
	if not _any_in(context, "storylines", requires.get("any_storylines", [])):
		return false
	if not _all_in(context, "discovered", requires.get("discovered", [])):
		return false
	var regard_value: Variant = requires.get("storyline_regard", {})
	if typeof(regard_value) == TYPE_DICTIONARY:
		var regard_table: Dictionary = regard_value
		var have_value: Variant = context.get("storyline_regard", {})
		var have: Dictionary = have_value if typeof(have_value) == TYPE_DICTIONARY else {}
		for id in regard_table.keys():
			if int(have.get(String(id), 0)) < int(regard_table[id]):
				return false
	return true


func _all_in(context: Dictionary, key: String, value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return true
	var have_value: Variant = context.get(key, [])
	var have: Array = have_value if typeof(have_value) == TYPE_ARRAY else []
	for entry in (value as Array):
		if not have.has(String(entry)):
			return false
	return true


func _any_in(context: Dictionary, key: String, value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return true
	var have_value: Variant = context.get(key, [])
	var have: Array = have_value if typeof(have_value) == TYPE_ARRAY else []
	for entry in (value as Array):
		if have.has(String(entry)):
			return true
	return false


## What the record still wants, in the archive's words. Empty when met.
func missing_requirements(entry: Dictionary, context: Dictionary = {}) -> Array:
	var out: Array = []
	if entry.is_empty():
		return out
	var requires_value: Variant = entry.get("requires", {})
	if typeof(requires_value) != TYPE_DICTIONARY:
		return out
	var requires: Dictionary = requires_value
	for value in _string_list(requires.get("threads", [])):
		if not is_known(value):
			out.append("the record " + _record_title(value))
	if int(context.get("realm", 0)) < int(requires.get("min_realm", 0)):
		out.append("realm %d" % int(requires.get("min_realm", 0)))
	if int(context.get("kills", 0)) < int(requires.get("min_kills", 0)):
		out.append("%d kills" % int(requires.get("min_kills", 0)))
	if int(context.get("contribution", 0)) < int(requires.get("min_contribution", 0)):
		out.append("%d contribution" % int(requires.get("min_contribution", 0)))
	if int(context.get("inheritances", 0)) < int(requires.get("min_inheritances", 0)):
		out.append("%d altar claims" % int(requires.get("min_inheritances", 0)))
	if int(context.get("crafts", 0)) < int(requires.get("min_crafts", 0)):
		out.append("%d finished works" % int(requires.get("min_crafts", 0)))
	var min_rank := String(requires.get("min_rank", ""))
	if min_rank != "" and Hierarchy.level(String(context.get("rank", ""))) < Hierarchy.level(min_rank):
		out.append("the station of %s" % Hierarchy.title(min_rank))
	if bool(requires.get("sect_seat", false)) and not bool(context.get("sect_seat", false)):
		out.append("the open master's seat")
	if bool(requires.get("founded_sect", false)) and not bool(context.get("founded_sect", false)):
		out.append("a hall of your own")
	for id in _string_list(requires.get("quests", [])):
		var value: Variant = context.get("quests", [])
		if typeof(value) != TYPE_ARRAY or not (value as Array).has(id):
			out.append("the completed quest " + String(DB.quest(id).get("title", id)))
	var any_quests := _string_list(requires.get("any_quests", []))
	if not any_quests.is_empty() and not _any_in(context, "quests", any_quests):
		out.append("one of the quests " + _titles(any_quests, "quest"))
	for id in _string_list(requires.get("storylines", [])):
		var value: Variant = context.get("storylines", [])
		if typeof(value) != TYPE_ARRAY or not (value as Array).has(id):
			out.append("the completed story " + _storyline_title(id))
	var any_storylines := _string_list(requires.get("any_storylines", []))
	if not any_storylines.is_empty() and not _any_in(context, "storylines", any_storylines):
		out.append("a completed story from " + _titles(any_storylines, "storyline"))
	var regard_value: Variant = requires.get("storyline_regard", {})
	if typeof(regard_value) == TYPE_DICTIONARY:
		var regard_table: Dictionary = regard_value
		var have_value: Variant = context.get("storyline_regard", {})
		var have: Dictionary = have_value if typeof(have_value) == TYPE_DICTIONARY else {}
		for id in regard_table.keys():
			if int(have.get(String(id), 0)) < int(regard_table[id]):
				out.append("%d regard with %s" % [int(regard_table[id]), _storyline_title(String(id))])
	for id in _string_list(requires.get("discovered", [])):
		var value: Variant = context.get("discovered", [])
		if typeof(value) != TYPE_ARRAY or not (value as Array).has(id):
			out.append("the discovery of " + String(RealmAccess.site(id).get("name", id)))
	return out


func condition_hint(entry: Dictionary, context: Dictionary = {}) -> String:
	var missing := missing_requirements(entry, context)
	if missing.is_empty():
		return ""
	return "The record waits on: " + ", ".join(missing) + "."


# ------------------------------------------------------------ persistence ----


func to_dict() -> Dictionary:
	var list: Array = []
	for thread_value in threads():
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		for value in revelations_of(String((thread_value as Dictionary).get("id", ""))):
			if typeof(value) == TYPE_DICTIONARY:
				var id := String((value as Dictionary).get("id", ""))
				if id != "" and is_known(id):
					list.append(id)
	return {"version": SAVE_VERSION, "known": list}


## A save carries only discovered ids. Unknown ids are dropped, and a record is
## only accepted once the earlier records it names are accepted too, so a
## hand-edited save cannot skip the archaeology or fake a convergence.
func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	var saved_value: Variant = data.get("known", [])
	if typeof(saved_value) != TYPE_ARRAY:
		return
	var wanted: Dictionary = {}
	for value in (saved_value as Array):
		var id := String(value)
		if id != "":
			wanted[id] = true
	var changed := true
	while changed:
		changed = false
		for thread_value in threads():
			if typeof(thread_value) != TYPE_DICTIONARY:
				continue
			for value in revelations_of(String((thread_value as Dictionary).get("id", ""))):
				if typeof(value) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = value
				var id := String(entry.get("id", ""))
				if id == "" or is_known(id) or not wanted.has(id):
					continue
				if _prior_known(entry):
					known[id] = true
					changed = true


func _prior_known(entry: Dictionary) -> bool:
	var requires_value: Variant = entry.get("requires", {})
	if typeof(requires_value) != TYPE_DICTIONARY:
		return false
	for value in _string_list((requires_value as Dictionary).get("threads", [])):
		if not is_known(value):
			return false
	return true


# ------------------------------------------------------------- validation ----


## Boot safety for `data/main_narrative.json`: four threads of four records, an
## ordered chain per thread, real ids for everything a record names, no cycles,
## and a final record in every thread that needs two other threads.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no main narrative data defined")
		return problems
	var list_value: Variant = data.get("threads", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("main narrative threads are missing")
		return problems
	var rows: Array = list_value
	if rows.size() != THREAD_COUNT:
		problems.append("expected %d narrative threads, found %d" % [THREAD_COUNT, rows.size()])
	var seen_threads: Dictionary = {}
	var all_ids: Dictionary = {}
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("a narrative thread is not an object")
			continue
		var thread_data: Dictionary = value
		var id := String(thread_data.get("id", ""))
		if id == "":
			problems.append("a narrative thread has no id")
			continue
		if not id.begins_with("thread."):
			problems.append("narrative thread %s does not use a thread.* id" % id)
		if seen_threads.has(id):
			problems.append("duplicate narrative thread " + id)
		seen_threads[id] = true
		if String(thread_data.get("name", "")).strip_edges() == "":
			problems.append("narrative thread %s has no name" % id)
		if String(thread_data.get("question", "")).strip_edges() == "":
			problems.append("narrative thread %s has no question" % id)
		if String(thread_data.get("blurb", "")).strip_edges() == "":
			problems.append("narrative thread %s has no blurb" % id)
		var colour := String(thread_data.get("colour", ""))
		if not Color.html_is_valid(colour):
			problems.append("narrative thread %s has an invalid colour" % id)
		var list: Variant = thread_data.get("revelations", null)
		if typeof(list) != TYPE_ARRAY:
			problems.append("narrative thread %s has no records" % id)
			continue
		var records: Array = list
		if records.size() != REVELATIONS_PER_THREAD:
			problems.append("narrative thread %s has %d records, expected %d" % [
				id, records.size(), REVELATIONS_PER_THREAD])
		for record_value in records:
			if typeof(record_value) != TYPE_DICTIONARY:
				problems.append("narrative thread %s has a record that is not an object" % id)
				continue
			var record: Dictionary = record_value
			var record_id := String(record.get("id", ""))
			if record_id == "":
				problems.append("narrative thread %s has a record without id" % id)
				continue
			if not record_id.begins_with("lore."):
				problems.append("narrative record %s does not use a lore.* id" % record_id)
			if all_ids.has(record_id):
				problems.append("duplicate narrative record " + record_id)
			all_ids[record_id] = record
			for field in ["title", "summary", "text", "source"]:
				if String(record.get(field, "")).strip_edges() == "":
					problems.append("narrative record %s has no %s" % [record_id, field])
			_validate_requires(record, record_id, problems)

	# Every record may only point at an authored record, and the thread chain must
	# be ordered with an explicit previous-record requirement.
	for thread_value in rows:
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		var thread_data: Dictionary = thread_value
		var thread_id := String(thread_data.get("id", ""))
		var records: Array = revelations_of_data(thread_data)
		var earlier: Dictionary = {}
		for index in records.size():
			if typeof(records[index]) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = records[index]
			var record_id := String(record.get("id", ""))
			var requires_value: Variant = record.get("requires", {})
			if typeof(requires_value) != TYPE_DICTIONARY:
				continue
			var requires: Dictionary = requires_value
			var links := _string_list(requires.get("threads", []))
			for link in links:
				if link == record_id:
					problems.append("narrative record %s requires itself" % record_id)
					continue
				if not all_ids.has(link):
					problems.append("narrative record %s requires unknown record %s" % [record_id, link])
					continue
				var link_thread := _thread_id_of(rows, link)
				if link_thread == thread_id and not earlier.has(link):
					problems.append("narrative record %s requires a later record of its own thread" % record_id)
			if index > 0:
				var previous_value: Variant = records[index - 1]
				if typeof(previous_value) == TYPE_DICTIONARY:
					var previous_id := String((previous_value as Dictionary).get("id", ""))
					if previous_id != "" and not links.has(previous_id):
						problems.append("narrative record %s does not require its predecessor" % record_id)
			elif not links.is_empty():
				problems.append("narrative record %s cannot start from another record" % record_id)
			if index == records.size() - 1:
				var outside := 0
				var seen_outside: Dictionary = {}
				for link in links:
					var link_thread := _thread_id_of(rows, link)
					if link_thread != "" and link_thread != thread_id and not seen_outside.has(link_thread):
						seen_outside[link_thread] = true
						outside += 1
				if outside < 2:
					problems.append("narrative record %s does not converge two other threads" % record_id)
			if record_id != "":
				earlier[record_id] = true
	if problems.is_empty() and _has_cycle(all_ids):
		problems.append("narrative records form a prerequisite cycle")
	return problems


static func revelations_of_data(thread_data: Dictionary) -> Array:
	var value: Variant = thread_data.get("revelations", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func _validate_requires(record: Dictionary, record_id: String, problems: Array) -> void:
	var value: Variant = record.get("requires", null)
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		problems.append("narrative record %s has no requirements" % record_id)
		return
	var requires: Dictionary = value
	for key in requires.keys():
		var name := String(key)
		if not CONDITION_KEYS.has(name):
			problems.append("narrative record %s has an unknown condition %s" % [record_id, name])
			continue
		if name == "min_realm":
			var realm := int(requires[key])
			if realm < 1 or realm > 12:
				problems.append("narrative record %s has an impossible realm gate" % record_id)
		elif name == "min_kills" or name == "min_contribution" or name == "min_crafts":
			if int(requires[key]) < 1 or int(requires[key]) > 1000000:
				problems.append("narrative record %s has an impossible %s" % [record_id, name])
		elif name == "min_inheritances":
			var count := int(requires[key])
			if count < 1 or count > 9:
				problems.append("narrative record %s has an impossible inheritance gate" % record_id)
		elif name == "min_rank":
			var rank_id := String(requires[key])
			if Hierarchy.rank(rank_id).is_empty():
				problems.append("narrative record %s names unknown rank %s" % [record_id, rank_id])
		elif name == "sect_seat" or name == "founded_sect":
			if typeof(requires[key]) != TYPE_BOOL or not bool(requires[key]):
				problems.append("narrative record %s has a malformed %s" % [record_id, name])
		elif name == "quests" or name == "any_quests":
			_validate_id_list(requires[key], record_id, name, problems, "quest")
		elif name == "storylines" or name == "any_storylines":
			_validate_storyline_list(requires[key], record_id, name, problems)
		elif name == "storyline_regard":
			if typeof(requires[key]) != TYPE_DICTIONARY:
				problems.append("narrative record %s has malformed storyline regard" % record_id)
			else:
				var table: Dictionary = requires[key]
				for storyline_id in table.keys():
					if not _storyline_ids().has(String(storyline_id)):
						problems.append("narrative record %s names unknown storyline %s" % [
							record_id, String(storyline_id)])
					var amount := int(table[storyline_id])
					if amount < 0 or amount > 100:
						problems.append("narrative record %s has an impossible regard gate" % record_id)
		elif name == "discovered":
			if typeof(requires[key]) != TYPE_ARRAY or (requires[key] as Array).is_empty():
				problems.append("narrative record %s has malformed discoveries" % record_id)
			else:
				for site_id in (requires[key] as Array):
					if RealmAccess.site(String(site_id)).is_empty():
						problems.append("narrative record %s names unknown site %s" % [
							record_id, String(site_id)])
		elif name == "threads":
			if typeof(requires[key]) != TYPE_ARRAY or (requires[key] as Array).is_empty():
				problems.append("narrative record %s has malformed record links" % record_id)


static func _validate_id_list(value: Variant, record_id: String, key: String, problems: Array,
		kind: String) -> void:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		problems.append("narrative record %s has malformed %s" % [record_id, key])
		return
	for entry in (value as Array):
		var id := String(entry)
		if kind == "quest" and DB.quest(id).is_empty():
			problems.append("narrative record %s names unknown quest %s" % [record_id, id])


static func _validate_storyline_list(value: Variant, record_id: String, key: String,
		problems: Array) -> void:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		problems.append("narrative record %s has malformed %s" % [record_id, key])
		return
	for entry in (value as Array):
		var id := String(entry)
		if not _storyline_ids().has(id):
			problems.append("narrative record %s names unknown storyline %s" % [record_id, id])


static func _storyline_ids() -> Dictionary:
	var out: Dictionary = {}
	var value: Variant = DB.sect_storylines_data.get("storylines", [])
	if typeof(value) == TYPE_ARRAY:
		for entry in (value as Array):
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) != "":
				out[String((entry as Dictionary).get("id", ""))] = true
	return out


static func _thread_id_of(rows: Array, record_id: String) -> String:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var thread_data: Dictionary = value
		for entry in revelations_of_data(thread_data):
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) == record_id:
				return String(thread_data.get("id", ""))
	return ""


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
	var requires_value: Variant = entry.get("requires", {})
	if typeof(requires_value) == TYPE_DICTIONARY:
		for link in _string_list((requires_value as Dictionary).get("threads", [])):
			if table.has(link) and _cycle_visit(link, table, visiting, finished):
				return true
	visiting.erase(id)
	finished[id] = true
	return false


# ------------------------------------------------------------------ utils ----


func _record_title(id: String) -> String:
	var entry := revelation(id)
	return String(entry.get("title", id)) if not entry.is_empty() else id


func _storyline_title(id: String) -> String:
	var value: Variant = DB.sect_storylines_data.get("storylines", [])
	if typeof(value) == TYPE_ARRAY:
		for entry in (value as Array):
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) == id:
				return String((entry as Dictionary).get("title", id))
	return id


func _titles(ids: Array, kind: String) -> String:
	var names: Array[String] = []
	for id in ids:
		if kind == "quest":
			names.append(String(DB.quest(String(id)).get("title", String(id))))
		else:
			names.append(_storyline_title(String(id)))
	return ", ".join(names)


static func _string_list(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in (raw as Array):
		var text := String(value)
		if text != "":
			out.append(text)
	return out
