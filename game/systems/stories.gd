class_name Stories
extends RefCounted
## The market's tongue: what happened, who knows it, and what a person might ask.
##
## Nothing here is authored per playthrough. A beat is either a real simulation
## event (a breakthrough or a failed one) or a small daily happening drawn from
## an archetype's goals and the place its routine put it. Both are pure functions
## of the world seed, the day and stable ids, so a save needs to carry only what
## the player has already heard.
##
## The chronicle is a bounded, chronological list of entries. An entry names its
## actors and the witnesses who will repeat it; an entry with a `request` also
## becomes an offer the player can answer — deliver a pill, or thin the beasts.

## Daily beats draw from this stream. Every entry id is `story.<day>.<slot>`.
const DOMAIN := "story_ambient"
const WITNESS_DOMAIN := "story_witness"
const DELIVER := "deliver"
const HUNT := "hunt"
const BREAKTHROUGH := "breakthrough"
const DEVIATION := "deviation"
const MAX_CHRONICLE := 80
const MAX_OFFERS := 8


# ------------------------------------------------------------------ data ----


static func rules() -> Dictionary:
	return DB.story_rules()


static func templates() -> Array:
	return DB.story_templates()


static func template(id: String) -> Dictionary:
	return DB.story_template(id)


static func _per_day() -> int:
	return maxi(0, int(rules().get("per_day", 0)))


static func _offer_days() -> int:
	return maxi(1, int(rules().get("offer_days", 4)))


# ---------------------------------------------------------------- people ----


## A plain snapshot of the residents, in stable id order. The system never reads
## a node: it receives names, goals and places, which is what makes the daily
## draw testable without a scene.
static func people_from(npcs: Array) -> Array:
	var out: Array = []
	for value in npcs:
		var npc := value as Npc
		if npc == null or npc.npc_id == "":
			continue
		var place := npc.current_location
		if place == "":
			place = "plaza"
		var goals: Array = []
		for goal in npc.goals:
			goals.append(String(goal))
		out.append({
			"id": npc.npc_id,
			"name": npc.display_name,
			"archetype": npc.archetype_id,
			"place": place,
			"goals": goals,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", "")))
	return out


## Everyone a template could plausibly concern: their goals must intersect the
## template's, and their routine must put them in one of its venues. A template
## with no goals or venues accepts anyone.
static func eligible(people: Array, entry: Dictionary) -> Array:
	var out: Array = []
	var wanted_goals := _string_list(entry.get("goals", []))
	var venues := _string_list(entry.get("venues", []))
	for value in people:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var person: Dictionary = value
		if String(person.get("id", "")) == "":
			continue
		if not venues.is_empty() and not venues.has(String(person.get("place", ""))):
			continue
		if not wanted_goals.is_empty():
			var goals := _string_list(person.get("goals", []))
			var shared := false
			for goal in goals:
				if wanted_goals.has(goal):
					shared = true
					break
			if not shared:
				continue
		out.append(person)
	return out


# ----------------------------------------------------------------- beats ----


## The day's small news: up to `per_day` weighted happenings, drawn from people
## whose goals and routine fit a template. Same (seed, day, slot) always picks
## the same template and the same actors, so two saves of one world agree.
static func ambient(people: Array, day: int, world_seed: int) -> Array:
	var out: Array = []
	var count := _per_day()
	var all := templates()
	if count <= 0 or all.is_empty() or people.is_empty():
		return out
	for slot in count:
		var rng: RandomNumberGenerator = Rng.stream_from(world_seed, DOMAIN, day, slot)
		var candidates: Array = []
		var total := 0
		for value in all:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = value
			var pool := eligible(people, candidate)
			if pool.size() < maxi(1, int(candidate.get("actors", 1))):
				continue
			candidates.append({"entry": candidate, "pool": pool})
			total += maxi(1, int(candidate.get("weight", 1)))
		if candidates.is_empty():
			continue
		var roll := rng.randi_range(1, total)
		var picked: Dictionary = candidates[0]
		for value in candidates:
			var candidate: Dictionary = value
			roll -= maxi(1, int((candidate.get("entry") as Dictionary).get("weight", 1)))
			if roll <= 0:
				picked = candidate
				break
		var entry: Dictionary = picked["entry"]
		var pool: Array = (picked["pool"] as Array).duplicate()
		var actors: Array = []
		var names: Array = []
		var chosen: Array = []
		for _i in maxi(1, int(entry.get("actors", 1))):
			if pool.is_empty():
				break
			var index := rng.randi_range(0, pool.size() - 1)
			var person: Dictionary = pool[index]
			actors.append(String(person.get("id", "")))
			names.append(String(person.get("name", "")))
			chosen.append(person)
			pool.remove_at(index)
		if actors.is_empty():
			continue
		var request: Dictionary = {}
		var raw_request: Variant = entry.get("request", {})
		if typeof(raw_request) == TYPE_DICTIONARY:
			request = (raw_request as Dictionary).duplicate(true)
		out.append({
			"id": "story.%d.%d" % [day, slot],
			"day": day,
			"kind": String(entry.get("kind", "ambient")),
			"template": String(entry.get("id", "")),
			"actors": actors,
			"names": names,
			"place": String((chosen[0] as Dictionary).get("place", "")),
			"headline": _headline(String(entry.get("headline", "")), names),
			"detail": String(entry.get("detail", "")),
			"request": request,
		})
	return out


## A real event, not a draw: someone gained a realm, or lost the attempt. The
## failed attempt carries a delivery request, because an injured body needs a
## mending pill and the market knows who sells them.
static func event_beat(kind: String, actor: Dictionary, day: int, extra: Dictionary = {}) -> Dictionary:
	var id := String(actor.get("id", ""))
	var person := String(actor.get("name", ""))
	if id == "" or person == "":
		return {}
	var headline := ""
	var detail := ""
	var request: Dictionary = {}
	if kind == BREAKTHROUGH:
		var realm := String(extra.get("realm_name", "a higher realm"))
		headline = "%s breaks through to %s." % [person, realm]
		detail = "The market will speak of it for a week."
	elif kind == DEVIATION:
		headline = "%s fails a breakthrough and is carried in from the shrine." % person
		detail = "The insight gathered for the attempt is gone, and the body will not trust itself again for a while."
		request = {"kind": DELIVER}
	else:
		return {}
	return {
		"id": "story.%d.progress.%s" % [day, id],
		"day": day,
		"kind": kind,
		"template": "",
		"actors": [id],
		"names": [person],
		"place": String(extra.get("place", "shrine")),
		"headline": headline,
		"detail": detail,
		"request": request,
	}


## Who repeats an entry: its actors, plus a deterministic handful of people
## standing in the same place. Gossip is local first, which is why the same news
## reaches the shrine before it reaches the gate.
static func witnesses(entry: Dictionary, people: Array, world_seed: int) -> Array:
	var out: Array = []
	for value in _string_list(entry.get("actors", [])):
		if not out.has(value):
			out.append(value)
	var pool: Array = []
	var wanted := _string_list(entry.get("actors", []))
	var place := String(entry.get("place", ""))
	for value in people:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var person: Dictionary = value
		var id := String(person.get("id", ""))
		if id == "" or wanted.has(id) or out.has(id):
			continue
		if place != "" and String(person.get("place", "")) != place:
			continue
		pool.append(id)
	var rng: RandomNumberGenerator = Rng.stream_from(world_seed, WITNESS_DOMAIN, hash(String(entry.get("id", ""))), 0)
	var count := clampi(int(rules().get("witnesses", 0)), 0, 8)
	for _i in count:
		if pool.is_empty():
			break
		var index := rng.randi_range(0, pool.size() - 1)
		out.append(String(pool[index]))
		pool.remove_at(index)
	return out


# ---------------------------------------------------------------- offers ----


## The player-facing side of a request, or {} when the entry asks for nothing.
static func offer_for(entry: Dictionary, _rule: Dictionary = {}) -> Dictionary:
	var request: Variant = entry.get("request", {})
	if typeof(request) != TYPE_DICTIONARY or (request as Dictionary).is_empty():
		return {}
	var kind := String((request as Dictionary).get("kind", ""))
	var rule := rules()
	var count := 1
	var target := ""
	var target_name := ""
	var regard := 0
	var stones := 0
	if kind == DELIVER:
		target = String(rule.get("deliver_base", ""))
		target_name = String(rule.get("deliver_name", "Mending Pill"))
		regard = maxi(0, int(rule.get("deliver_regard", 0)))
		stones = maxi(0, int(rule.get("deliver_stones", 0)))
	elif kind == HUNT:
		count = maxi(1, int((request as Dictionary).get("count", rule.get("hunt_target", 1))))
		regard = maxi(0, int(rule.get("hunt_regard", 0)))
		stones = maxi(0, int(rule.get("hunt_stones", 0)))
	else:
		return {}
	var actors := _string_list(entry.get("actors", []))
	var names := _string_list(entry.get("names", []))
	if actors.is_empty() or names.is_empty():
		return {}
	var day := maxi(0, int(entry.get("day", 0)))
	return {
		"id": "offer." + String(entry.get("id", "")),
		"entry": String(entry.get("id", "")),
		"day": day,
		"deadline": day + _offer_days(),
		"kind": kind,
		"actor": String(actors[0]),
		"actor_name": String(names[0]),
		"place": String(entry.get("place", "")),
		"count": count,
		"progress": 0,
		"target": target,
		"target_name": target_name,
		"regard": regard,
		"stones": stones,
	}


## "Lin Zhao asks you to thin the beasts near the gate before day 18."
static func offer_text(offer: Dictionary) -> String:
	var who := String(offer.get("actor_name", "Someone"))
	var deadline := int(offer.get("deadline", 0))
	if String(offer.get("kind", "")) == DELIVER:
		return "%s needs a %s before day %d." % [who, String(offer.get("target_name", "pill")), deadline]
	var place := String(offer.get("place", "")).replace("_", " ")
	var where := (" near the " + place) if place != "" else ""
	return "%s asks you to thin the beasts%s before day %d (%d/%d)." % [
		who, where, deadline, int(offer.get("progress", 0)), int(offer.get("count", 1))]


static func deliver_index(offers: Array, actor_id: String) -> int:
	for i in offers.size():
		if typeof(offers[i]) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offers[i]
		if String(offer.get("kind", "")) == DELIVER and String(offer.get("actor", "")) == actor_id:
			return i
	return -1


static func offer_index_for(offers: Array, actor_id: String) -> int:
	for i in offers.size():
		if typeof(offers[i]) != TYPE_DICTIONARY:
			continue
		if String((offers[i] as Dictionary).get("actor", "")) == actor_id:
			return i
	return -1


## One kill answers the oldest hunt request, never several at once.
static func advance_hunt(offers: Array, day: int) -> Dictionary:
	var kept: Array = []
	var completed: Array = []
	var answered := false
	for value in offers:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = (value as Dictionary).duplicate(true)
		if int(offer.get("deadline", 0)) < day:
			continue
		if not answered and String(offer.get("kind", "")) == HUNT:
			answered = true
			offer["progress"] = int(offer.get("progress", 0)) + 1
			if int(offer["progress"]) >= maxi(1, int(offer.get("count", 1))):
				completed.append(offer)
				continue
		kept.append(offer)
	return {"offers": kept, "completed": completed}


static func without(offers: Array, index: int) -> Array:
	var out: Array = []
	for i in offers.size():
		if i != index:
			out.append(offers[i])
	return out


static func expire_offers(offers: Array, day: int) -> Array:
	var out: Array = []
	for value in offers:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if int((value as Dictionary).get("deadline", 0)) >= day:
			out.append(value)
	return out


# ------------------------------------------------------------- chronicle ----


## Adds one entry, oldest first, refusing a duplicate id and trimming to the
## configured cap. Returns a new array; the caller's list is never mutated.
static func append(chronicle: Array, entry: Dictionary, cap: int = 0) -> Array:
	var out: Array = chronicle.duplicate(true)
	if entry.is_empty() or String(entry.get("id", "")) == "":
		return out
	for value in out:
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == String(entry.get("id", "")):
			return out
	out.append(entry.duplicate(true))
	var limit := cap
	if limit <= 0:
		limit = int(rules().get("chronicle_cap", 40))
	limit = clampi(limit, 1, MAX_CHRONICLE)
	while out.size() > limit:
		out.pop_front()
	return out


## The newest thing this person has heard, or {} when they have heard nothing
## recent. A rumour ages out: the market talks about today, not last season.
static func rumor_for(npc_id: String, chronicle: Array, day: int, days: int = 0) -> Dictionary:
	if npc_id == "":
		return {}
	var window := days
	if window <= 0:
		window = maxi(1, int(rules().get("rumor_days", 4)))
	for i in range(chronicle.size() - 1, -1, -1):
		if typeof(chronicle[i]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = chronicle[i]
		if day - int(entry.get("day", 0)) > window:
			continue
		if _string_list(entry.get("witnesses", [])).has(npc_id):
			return entry
	return {}


static func describe(entry: Dictionary) -> String:
	var detail := String(entry.get("detail", ""))
	var line := "Day %d — %s" % [int(entry.get("day", 0)), String(entry.get("headline", ""))]
	if detail != "":
		line += " " + detail
	return line


# ------------------------------------------------------------- sanitising ----


static func sanitize_chronicle(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var headline := String(entry.get("headline", ""))
		if id == "" or headline == "":
			continue
		var request: Dictionary = {}
		var raw_request: Variant = entry.get("request", {})
		if typeof(raw_request) == TYPE_DICTIONARY:
			var kind := String((raw_request as Dictionary).get("kind", ""))
			if kind == DELIVER or kind == HUNT:
				request = {"kind": kind}
		out.append({
			"id": id.substr(0, 120),
			"day": maxi(0, int(entry.get("day", 0))),
			"kind": String(entry.get("kind", "ambient")).substr(0, 40),
			"template": String(entry.get("template", "")).substr(0, 80),
			"actors": _string_list(entry.get("actors", [])),
			"names": _string_list(entry.get("names", [])),
			"witnesses": _string_list(entry.get("witnesses", [])),
			"place": String(entry.get("place", "")).substr(0, 40),
			"headline": headline.substr(0, 240),
			"detail": String(entry.get("detail", "")).substr(0, 400),
			"request": request,
		})
	var limit := clampi(int(rules().get("chronicle_cap", 40)), 1, MAX_CHRONICLE)
	while out.size() > limit:
		out.pop_front()
	return out


static func sanitize_offers(raw: Variant, day: int) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = value
		var kind := String(offer.get("kind", ""))
		var actor := String(offer.get("actor", ""))
		var id := String(offer.get("id", ""))
		if (kind != DELIVER and kind != HUNT) or actor == "" or id == "":
			continue
		var deadline := maxi(0, int(offer.get("deadline", 0)))
		if deadline < day:
			continue
		var count := maxi(1, int(offer.get("count", 1)))
		var progress := clampi(int(offer.get("progress", 0)), 0, count)
		if progress >= count:
			continue
		out.append({
			"id": id.substr(0, 140),
			"entry": String(offer.get("entry", "")).substr(0, 120),
			"day": maxi(0, int(offer.get("day", day))),
			"deadline": deadline,
			"kind": kind,
			"actor": actor,
			"actor_name": String(offer.get("actor_name", "")).substr(0, 80),
			"place": String(offer.get("place", "")).substr(0, 40),
			"count": count,
			"progress": progress,
			"target": String(offer.get("target", "")).substr(0, 80),
			"target_name": String(offer.get("target_name", "")).substr(0, 80),
			"regard": clampi(int(offer.get("regard", 0)), 0, 30),
			"stones": clampi(int(offer.get("stones", 0)), 0, 1000),
		})
		if out.size() >= MAX_OFFERS:
			break
	return out


# -------------------------------------------------------------- validation ----


## Content checks for `data/stories.json`. A template that names three actors in
## its text and two in its rules would produce a half-formatted headline at
## runtime, so that mismatch is rejected here rather than discovered in play.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no story data defined")
		return problems
	var rule: Variant = data.get("rules", {})
	if typeof(rule) != TYPE_DICTIONARY or (rule as Dictionary).is_empty():
		problems.append("story rules are missing")
	else:
		var rules_row: Dictionary = rule
		var per_day := int(rules_row.get("per_day", 0))
		if per_day < 1 or per_day > 6:
			problems.append("story rules ask for %d beats a day" % per_day)
		var cap := int(rules_row.get("chronicle_cap", 0))
		if cap < 1 or cap > MAX_CHRONICLE:
			problems.append("story chronicle cap %d is outside 1..%d" % [cap, MAX_CHRONICLE])
		var offers := int(rules_row.get("offer_cap", -1))
		if offers < 0 or offers > MAX_OFFERS:
			problems.append("story offer cap %d is outside 0..%d" % [offers, MAX_OFFERS])
		for key in ["offer_days", "rumor_days", "witnesses", "hunt_target"]:
			if int(rules_row.get(key, 0)) < 0:
				problems.append("story rule %s is negative" % key)
		if int(rules_row.get("offer_days", 0)) < 1:
			problems.append("story offers must last at least a day")
		if int(rules_row.get("hunt_target", 0)) < 1:
			problems.append("a hunt request must ask for at least one beast")
		var deliver_base := String(rules_row.get("deliver_base", ""))
		var deliver_entry: Dictionary = DB.by_id("base", deliver_base)
		if deliver_base == "" or deliver_entry.is_empty():
			problems.append("story delivery names unknown base %s" % deliver_base)
		elif String(deliver_entry.get("slot", "")) != "consumable":
			problems.append("story delivery base %s is not a consumable" % deliver_base)
		for key in ["deliver_regard", "deliver_stones", "hunt_regard", "hunt_stones"]:
			if int(rules_row.get(key, 0)) < 0:
				problems.append("story reward %s is negative" % key)

	var list: Variant = data.get("templates", null)
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		problems.append("no story templates defined")
		return problems
	var goal_ids: Dictionary = {}
	for value in DB.npc_goals:
		if typeof(value) == TYPE_DICTIONARY:
			goal_ids[String((value as Dictionary).get("id", ""))] = true
	var seen: Dictionary = {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("story template is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("story template without id")
			continue
		if seen.has(id):
			problems.append("duplicate story template id " + id)
		seen[id] = true
		if String(entry.get("kind", "")) == "":
			problems.append("story template %s has no kind" % id)
		if int(entry.get("weight", 0)) < 1:
			problems.append("story template %s has no weight" % id)
		var actors := int(entry.get("actors", 1))
		if actors < 1 or actors > 2:
			problems.append("story template %s names %d actors" % [id, actors])
		var headline := String(entry.get("headline", ""))
		if headline == "":
			problems.append("story template %s has no headline" % id)
		elif headline.count("%s") != actors:
			problems.append("story template %s headlines %d actors but places %d names" % [
				id, actors, headline.count("%s")])
		if String(entry.get("detail", "")) == "":
			problems.append("story template %s has no detail" % id)
		var goals: Variant = entry.get("goals", [])
		if typeof(goals) != TYPE_ARRAY:
			problems.append("story template %s has malformed goals" % id)
		else:
			for goal in goals:
				if not goal_ids.has(String(goal)):
					problems.append("story template %s names unknown goal %s" % [id, String(goal)])
		var venues: Variant = entry.get("venues", [])
		if typeof(venues) != TYPE_ARRAY or (venues as Array).is_empty():
			problems.append("story template %s has no venues" % id)
		else:
			for venue in venues:
				if String(venue) == "":
					problems.append("story template %s has an empty venue" % id)
		var request: Variant = entry.get("request", {})
		if typeof(request) == TYPE_DICTIONARY and not (request as Dictionary).is_empty():
			var kind := String((request as Dictionary).get("kind", ""))
			if kind != DELIVER and kind != HUNT:
				problems.append("story template %s asks for unknown work %s" % [id, kind])
	return problems


# ------------------------------------------------------------------ utils ----


static func _string_list(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		var text := String(value)
		if text != "":
			out.append(text)
	return out


static func _headline(pattern: String, names: Array) -> String:
	if pattern.count("%s") != names.size():
		return pattern
	return pattern % names
