class_name SectEconomy
extends RefCounted
## The Azure Cloud's books: contribution points, a daily stipend by rank, and a
## quartermaster who takes contribution for pills.
##
## Everything here is pure. The scene owns the purse and the saved counters; the
## system answers what a claim, a donation or a purchase would do, so a refused
## transaction can never leave half a cost behind.

const DEFAULT_CAP := 9999
const DEFAULT_STIPEND_DAY := -1


# ------------------------------------------------------------------ data ----


static func data() -> Dictionary:
	return DB.sect_economy_data


static func cap() -> int:
	return maxi(1, int(data().get("cap", DEFAULT_CAP)))


static func awards() -> Dictionary:
	var value: Variant = data().get("awards", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func quest_award() -> int:
	return maxi(0, int(awards().get("quest", 0)))


static func story_award() -> int:
	return maxi(0, int(awards().get("story", 0)))


static func boss_award() -> int:
	return maxi(0, int(awards().get("boss", 0)))


static func donations() -> Array:
	var value: Variant = data().get("donations", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func donation(id: String) -> Dictionary:
	for value in donations():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func stipends() -> Array:
	var value: Variant = data().get("stipends", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func stipend_for(rank_id: String) -> Dictionary:
	for value in stipends():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("rank", "")) == rank_id:
			return value
	return {}


static func stipend_stones(rank_id: String) -> int:
	return maxi(0, int(stipend_for(rank_id).get("stones", 0)))


static func stipend_dues(rank_id: String) -> int:
	return maxi(0, int(stipend_for(rank_id).get("dues", 0)))


static func stipend_net(rank_id: String) -> int:
	return maxi(0, stipend_stones(rank_id) - stipend_dues(rank_id))


static func services() -> Array:
	var value: Variant = data().get("services", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func service(id: String) -> Dictionary:
	for value in services():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


# --------------------------------------------------------------- actions ----


## Contribution is a record with a ceiling: awards never overflow and never go
## negative, whatever a malformed offer says.
static func award_contribution(current: int, amount: int) -> int:
	return clampi(current + maxi(0, amount), 0, cap())


static func can_claim(last_day: int, day: int) -> bool:
	return last_day < day


## Claims one day's stipend. Dues are deducted from the pay, never from the purse;
## a rank with dues above its stipend would pay nothing, but validation forbids it.
static func claim(rank_id: String, day: int, last_day: int, stones: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "stones": maxi(0, stones), "day": last_day,
		"stipend": 0, "dues": 0, "net": 0}
	if not can_claim(last_day, day):
		out["reason"] = "today's stipend is already paid"
		return out
	var entry := stipend_for(rank_id)
	if entry.is_empty():
		out["reason"] = "this station draws no stipend"
		return out
	var pay := stipend_stones(rank_id)
	var dues := stipend_dues(rank_id)
	var net := maxi(0, pay - dues)
	out["ok"] = true
	out["stones"] = maxi(0, stones) + net
	out["day"] = day
	out["stipend"] = pay
	out["dues"] = dues
	out["net"] = net
	return out


## Stones to contribution. The purse is only spent if the whole cost is there.
static func donate(donation_id: String, stones: int, contribution: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "stones": maxi(0, stones),
		"contribution": clampi(contribution, 0, cap()), "points": 0}
	var entry := donation(donation_id)
	if entry.is_empty():
		out["reason"] = "unknown donation"
		return out
	var cost := maxi(0, int(entry.get("stones", 0)))
	if stones < cost:
		out["reason"] = "not enough spirit stones"
		return out
	var points := maxi(0, int(entry.get("points", 0)))
	out["ok"] = true
	out["stones"] = stones - cost
	out["contribution"] = clampi(contribution + points, 0, cap())
	out["points"] = points
	return out


## Whether a station may buy a service at all: the quartermaster serves the rank
## it names and everyone above it, never below.
static func can_use(service_id: String, rank_id: String) -> bool:
	var entry := service(service_id)
	if entry.is_empty():
		return false
	return Hierarchy.level(rank_id) >= Hierarchy.level(String(entry.get("rank", "")))


## Contribution to a service. `rank_id` is the player's current station; the
## item itself is made by the scene, because only it owns the satchel.
static func buy(service_id: String, contribution: int, rank_id: String) -> Dictionary:
	var out := {"ok": false, "reason": "", "contribution": clampi(contribution, 0, cap()),
		"service": {}, "cost": 0}
	var entry := service(service_id)
	if entry.is_empty():
		out["reason"] = "unknown service"
		return out
	if not can_use(service_id, rank_id):
		out["reason"] = "this station is below the quartermaster's counter"
		return out
	var cost := maxi(0, int(entry.get("cost", 0)))
	out["cost"] = cost
	if contribution < cost:
		out["reason"] = "not enough contribution"
		return out
	out["ok"] = true
	out["contribution"] = contribution - cost
	out["service"] = entry
	return out


## "Contribution 24 · stipend 12 − 2 dues · today claimed" — the ledger's header.
static func summary_line(rank_id: String, contribution: int, last_day: int, day: int) -> String:
	var pay := stipend_stones(rank_id)
	var dues := stipend_dues(rank_id)
	var line := "Contribution %d · stipend %d stones − %d dues" % [contribution, pay, dues]
	if not can_claim(last_day, day):
		line += " · today claimed"
	return line


# ------------------------------------------------------------- validation ----


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no sect economy data defined")
		return problems
	if int(data.get("cap", 0)) < 1:
		problems.append("sect contribution cap must be positive")

	var awards_value: Variant = data.get("awards", null)
	if typeof(awards_value) != TYPE_DICTIONARY:
		problems.append("sect economy awards are missing")
	else:
		var awards_table: Dictionary = awards_value
		for key in ["quest", "story", "boss"]:
			if int(awards_table.get(key, 0)) < 1:
				problems.append("sect award %s must be positive" % key)

	var donation_list: Variant = data.get("donations", null)
	if typeof(donation_list) != TYPE_ARRAY or (donation_list as Array).is_empty():
		problems.append("sect donations are missing")
	else:
		var seen: Dictionary = {}
		for value in (donation_list as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("sect donation is not an object")
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			if id == "":
				problems.append("sect donation without id")
				continue
			if seen.has(id):
				problems.append("duplicate sect donation " + id)
			seen[id] = true
			if String(entry.get("label", "")).strip_edges() == "":
				problems.append("sect donation %s has no label" % id)
			if int(entry.get("stones", 0)) < 1:
				problems.append("sect donation %s costs no stones" % id)
			if int(entry.get("points", 0)) < 1:
				problems.append("sect donation %s pays no contribution" % id)

	var stipend_list: Variant = data.get("stipends", null)
	if typeof(stipend_list) != TYPE_ARRAY:
		problems.append("sect stipends are missing")
	else:
		var seen_ranks: Dictionary = {}
		for value in (stipend_list as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("sect stipend is not an object")
				continue
			var entry: Dictionary = value
			var rank_id := String(entry.get("rank", ""))
			if Hierarchy.rank(rank_id).is_empty() or Hierarchy.level(rank_id) < 0:
				problems.append("sect stipend names unknown rank %s" % rank_id)
				continue
			if seen_ranks.has(rank_id):
				problems.append("duplicate stipend for %s" % rank_id)
			seen_ranks[rank_id] = true
			var pay := int(entry.get("stones", -1))
			var dues := int(entry.get("dues", -1))
			if pay < 0 or dues < 0:
				problems.append("sect stipend %s is negative" % rank_id)
			elif dues > pay:
				problems.append("sect stipend %s pays less than its dues" % rank_id)
		for value in Hierarchy.ladder():
			if typeof(value) == TYPE_DICTIONARY:
				var rank_id := String((value as Dictionary).get("id", ""))
				if not seen_ranks.has(rank_id):
					problems.append("no stipend for rank %s" % rank_id)

	var service_list: Variant = data.get("services", null)
	if typeof(service_list) != TYPE_ARRAY or (service_list as Array).is_empty():
		problems.append("sect services are missing")
	else:
		var seen_services: Dictionary = {}
		for value in (service_list as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("sect service is not an object")
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			if id == "":
				problems.append("sect service without id")
				continue
			if seen_services.has(id):
				problems.append("duplicate sect service " + id)
			seen_services[id] = true
			if String(entry.get("name", "")).strip_edges() == "":
				problems.append("sect service %s has no name" % id)
			if int(entry.get("cost", 0)) < 1:
				problems.append("sect service %s costs no contribution" % id)
			var base_id := String(entry.get("base", ""))
			var base := DB.base_item(base_id)
			if base.is_empty():
				problems.append("sect service %s names unknown base %s" % [id, base_id])
			elif String(base.get("slot", "")) != "consumable":
				problems.append("sect service %s does not sell a consumable" % id)
			var rank_id := String(entry.get("rank", ""))
			if Hierarchy.rank(rank_id).is_empty() or Hierarchy.level(rank_id) < 0:
				problems.append("sect service %s names unknown rank %s" % [id, rank_id])

	return problems
