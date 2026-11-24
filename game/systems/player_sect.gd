class_name PlayerSect
extends RefCounted
## The sect the player founds: a name, a doctrine, a treasury, and a roster of
## people who already trust them enough to leave their old hall.
##
## The model is pure. The scene owns the purse and the bodies; this answers what
## founding, recruiting or collecting would do, and the saved sheet is only the
## decisions: name, doctrine, day, treasury, member ids and the last levy day.
## Member realms are never stored, because progression belongs to the seed.

const EXPECTED_DOCTRINES := 3
const ROSTER_CAP := 12


# ------------------------------------------------------------------ data ----


static func data() -> Dictionary:
	return DB.player_sect_data


static func founding() -> Dictionary:
	var value: Variant = data().get("founding", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func founding_cost() -> int:
	return maxi(1, int(founding().get("stones", 500)))


static func recruit_cost() -> int:
	return maxi(0, int(founding().get("recruit_cost", 25)))


static func min_rank() -> String:
	return String(founding().get("min_rank", "rank.deputy"))


static func doctrines() -> Array:
	var value: Variant = data().get("doctrines", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func doctrine(id: String) -> Dictionary:
	for value in doctrines():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func member_ranks() -> Array:
	var value: Variant = data().get("member_ranks", [])
	return value if typeof(value) == TYPE_ARRAY else []


## The rank a member holds in the new hall, read from their own realm.
static func member_rank(realm: int) -> String:
	var best := "Initiate"
	var level := maxi(1, realm)
	for value in member_ranks():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if level >= int(entry.get("min_realm", 1)):
			best = String(entry.get("name", best))
	return best


# --------------------------------------------------------------- founding ----


## Why the player cannot found a sect yet, in the screen's words. Empty means the
## three conditions are met: no hall yet, the Deputy station, and the stones.
static func can_found(sect: Dictionary, stones: int, rank_id: String) -> Array:
	var reasons: Array = []
	if not sect.is_empty():
		reasons.append("you already hold a hall")
	if Hierarchy.level(rank_id) < Hierarchy.level(min_rank()):
		reasons.append("the station of %s" % Hierarchy.title(min_rank()))
	if stones < founding_cost():
		reasons.append("%d spirit stones (have %d)" % [founding_cost(), stones])
	return reasons


## Founds the hall and moves the endowment into its treasury. The founding fee is
## not lost to the world: it becomes the first purse the hall can spend from.
static func found(doctrine_id: String, stones: int, day: int) -> Dictionary:
	var entry := doctrine(doctrine_id)
	if entry.is_empty():
		return {"ok": false, "reason": "unknown doctrine", "stones": stones, "sect": {}}
	if stones < founding_cost():
		return {"ok": false, "reason": "not enough spirit stones", "stones": stones, "sect": {}}
	return {
		"ok": true,
		"reason": "",
		"stones": stones - founding_cost(),
		"sect": {
			"name": String(entry.get("sect_name", "New Hall")),
			"doctrine": doctrine_id,
			"founded_day": maxi(1, day),
			"treasury": founding_cost(),
			"members": [],
			"tribute_day": -1,
		},
	}


static func capacity(sect: Dictionary) -> int:
	var entry := doctrine(String(sect.get("doctrine", "")))
	return clampi(int(entry.get("capacity", 0)), 0, ROSTER_CAP)


static func member_count(sect: Dictionary) -> int:
	var value: Variant = sect.get("members", [])
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0


static func is_member(sect: Dictionary, npc_id: String) -> bool:
	var value: Variant = sect.get("members", [])
	if typeof(value) != TYPE_ARRAY:
		return false
	return (value as Array).has(npc_id)


# ----------------------------------------------------------------- levy ----


## One day's levy from the people actually standing in the hall. A member's realm
## decides their share; the doctrine adds a flat amount per member.
static func tribute_for(doctrine_id: String, realms: Array) -> int:
	var entry := doctrine(doctrine_id)
	if entry.is_empty():
		return 0
	var bonus := maxi(0, int(entry.get("tribute", 0)))
	var total := 0
	for value in realms:
		total += 1 + floori(float(maxi(1, int(value))) / 2.0)
	return total + bonus * realms.size()


static func can_collect(sect: Dictionary, day: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "day": day}
	if sect.is_empty():
		out["reason"] = "no hall has been founded"
		return out
	if member_count(sect) == 0:
		out["reason"] = "the hall has no members to levy"
		return out
	if int(sect.get("tribute_day", -1)) >= day:
		out["reason"] = "today's levy is already gathered"
		return out
	out["ok"] = true
	return out


## Collects the levy into the treasury and records the day. The caller supplies
## the realms of the members it can actually find; a missing body earns nothing.
static func collect(sect: Dictionary, day: int, realms: Array) -> Dictionary:
	var check := can_collect(sect, day)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": String(check.get("reason", "")), "amount": 0, "sect": sect}
	var amount := tribute_for(String(sect.get("doctrine", "")), realms)
	var out := sect.duplicate(true)
	out["treasury"] = maxi(0, int(sect.get("treasury", 0))) + amount
	out["tribute_day"] = day
	return {"ok": true, "reason": "", "amount": amount, "sect": out}


# ------------------------------------------------------------- recruiting ----


## A candidate must be a friend, unknown to the roster, and affordable out of the
## hall's own treasury. The scene filters sleeping, party and captive bodies
## before asking; this answers the rules the sheet owns.
static func can_recruit(sect: Dictionary, npc_id: String, bond_score: int, members: int) -> Dictionary:
	var out := {"ok": false, "reason": ""}
	if sect.is_empty():
		out["reason"] = "no hall has been founded"
		return out
	if npc_id == "":
		out["reason"] = "there is nobody to ask"
		return out
	if is_member(sect, npc_id):
		out["reason"] = "already stands in the hall"
		return out
	if not Relationships.warns(bond_score):
		out["reason"] = "does not trust you that far"
		return out
	if members >= capacity(sect):
		out["reason"] = "the hall is full"
		return out
	if int(sect.get("treasury", 0)) < recruit_cost():
		out["reason"] = "the treasury cannot pay the gift"
		return out
	out["ok"] = true
	return out


static func recruit(sect: Dictionary, npc_id: String, bond_score: int, members: int) -> Dictionary:
	var check := can_recruit(sect, npc_id, bond_score, members)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": String(check.get("reason", "")), "cost": 0, "sect": sect}
	var out := sect.duplicate(true)
	out["treasury"] = maxi(0, int(sect.get("treasury", 0))) - recruit_cost()
	var roster: Array = []
	var value: Variant = sect.get("members", [])
	if typeof(value) == TYPE_ARRAY:
		roster = (value as Array).duplicate()
	roster.append(npc_id)
	out["members"] = roster
	return {"ok": true, "reason": "", "cost": recruit_cost(), "sect": out}


# --------------------------------------------------------------- cleaning ----


## A save carries only decisions. Unknown doctrines discard the hall; a missing
## name falls back to the doctrine's own, members are unique known ids capped at
## the roster, and treasury/day counters are clamped.
static func sanitize(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var doctrine_id := String(source.get("doctrine", ""))
	var entry := doctrine(doctrine_id)
	if entry.is_empty():
		return {}
	var name := String(source.get("name", "")).strip_edges()
	if name == "":
		name = String(entry.get("sect_name", "New Hall"))
	var roster: Array = []
	var seen: Dictionary = {}
	var limit := capacity({"doctrine": doctrine_id})
	var raw: Variant = source.get("members", [])
	if typeof(raw) == TYPE_ARRAY:
		for item in (raw as Array):
			var id := String(item)
			if id == "" or seen.has(id) or roster.size() >= limit:
				continue
			seen[id] = true
			roster.append(id)
	return {
		"name": name,
		"doctrine": doctrine_id,
		"founded_day": maxi(1, int(source.get("founded_day", 1))),
		"treasury": maxi(0, int(source.get("treasury", 0))),
		"members": roster,
		"tribute_day": int(source.get("tribute_day", -1)),
	}


static func summary_line(sect: Dictionary) -> String:
	if sect.is_empty():
		return "No hall founded"
	return "%s · %s · %d/%d members · %d stones" % [String(sect.get("name", "")),
		String(doctrine(String(sect.get("doctrine", ""))).get("name", "")),
		member_count(sect), capacity(sect), int(sect.get("treasury", 0))]


# ------------------------------------------------------------- validation ----


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no player sect data defined")
		return problems

	var founding_value: Variant = data.get("founding", null)
	if typeof(founding_value) != TYPE_DICTIONARY:
		problems.append("player sect founding rules are missing")
	else:
		var table: Dictionary = founding_value
		if int(table.get("stones", 0)) < 1:
			problems.append("founding a sect costs no stones")
		if int(table.get("recruit_cost", -1)) < 0:
			problems.append("recruiting costs a negative gift")
		var rank_id := String(table.get("min_rank", ""))
		if Hierarchy.rank(rank_id).is_empty() or Hierarchy.level(rank_id) < 0:
			problems.append("player sect founding names unknown rank %s" % rank_id)

	var doctrine_list: Variant = data.get("doctrines", null)
	if typeof(doctrine_list) != TYPE_ARRAY or (doctrine_list as Array).is_empty():
		problems.append("player sect doctrines are missing")
	else:
		var rows: Array = doctrine_list
		if rows.size() != EXPECTED_DOCTRINES:
			problems.append("expected %d doctrines, found %d" % [EXPECTED_DOCTRINES, rows.size()])
		var seen: Dictionary = {}
		for value in rows:
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("player sect doctrine is not an object")
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			if id == "":
				problems.append("player sect doctrine without id")
				continue
			if seen.has(id):
				problems.append("duplicate player sect doctrine " + id)
			seen[id] = true
			for key in ["name", "sect_name", "motto", "blurb"]:
				if String(entry.get(key, "")).strip_edges() == "":
					problems.append("player sect doctrine %s has no %s" % [id, key])
			var capacity_value := int(entry.get("capacity", 0))
			if capacity_value < 1 or capacity_value > ROSTER_CAP:
				problems.append("player sect doctrine %s has an invalid roster size" % id)
			if int(entry.get("tribute", -1)) < 0:
				problems.append("player sect doctrine %s has a negative levy" % id)

	var rank_list: Variant = data.get("member_ranks", null)
	if typeof(rank_list) != TYPE_ARRAY or (rank_list as Array).is_empty():
		problems.append("player sect member ranks are missing")
	else:
		var last := 0
		for value in (rank_list as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("player sect member rank is not an object")
				continue
			var entry: Dictionary = value
			var min_realm := int(entry.get("min_realm", 0))
			if min_realm < 1 or min_realm > 12:
				problems.append("player sect member rank has an invalid realm")
			if min_realm < last:
				problems.append("player sect member ranks are out of order")
			last = maxi(last, min_realm)
			if String(entry.get("name", "")).strip_edges() == "":
				problems.append("player sect member rank has no name")

	return problems
