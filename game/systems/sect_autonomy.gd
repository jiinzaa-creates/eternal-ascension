class_name SectAutonomy
extends RefCounted
## The hall runs while the player is elsewhere.
##
## Each world day gathers the levy, pays every member's upkeep and resolves one
## weighted event. The event is a pure draw from `(world_seed, sect name, day)`,
## and a doctrine's guard reduces a raid's cost, so a reload cannot reroll a bad
## day and two halls do not live the same life.

const DOMAIN := "sect_autonomy"
const DEFAULT_MAX_DAYS := 60


static func data() -> Dictionary:
	return DB.sect_autonomy_data


static func upkeep_per_member() -> int:
	return maxi(0, int(data().get("upkeep_per_member", 1)))


static func steward_bonus() -> int:
	return maxi(0, int(data().get("steward_bonus", 2)))


static func events() -> Array:
	var value: Variant = data().get("events", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func event(id: String) -> Dictionary:
	for value in events():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func guard_for(doctrine_id: String) -> float:
	var value: Variant = data().get("guard", {})
	if typeof(value) != TYPE_DICTIONARY:
		return 1.0
	return clampf(float((value as Dictionary).get(doctrine_id, 1.0)), 0.0, 1.0)


## The one event a day brings. Weighted by data and keyed by the hall's own name,
## so the same day rebuilds the same news for the same hall and seed.
static func event_for(day: int, world_seed: int, sect: Dictionary) -> Dictionary:
	var table := events()
	var weights: Array = []
	for value in table:
		if typeof(value) != TYPE_DICTIONARY:
			weights.append(0)
			continue
		weights.append(int((value as Dictionary).get("weight", 0)))
	var rng := Rng.stream_from(world_seed, DOMAIN, hash(String(sect.get("name", "sect"))), day)
	var index := Rng.pick_weighted(weights, rng)
	if index < 0:
		return {}
	return table[index]


## One day of the hall. `realms` are the members actually present; an empty hall
## has no levy, no upkeep and no event. The returned sect is a copy.
static func settle_day(sect: Dictionary, realms: Array, day: int, world_seed: int,
		force_event: String = "") -> Dictionary:
	if sect.is_empty():
		return {"ok": false, "reason": "no hall", "income": 0, "upkeep": 0, "event": {},
			"treasury": 0, "line": "", "sect": sect}
	var out := sect.duplicate(true)
	out["autonomy_day"] = day
	if realms.is_empty():
		out["treasury"] = maxi(0, int(sect.get("treasury", 0)))
		return {"ok": true, "reason": "", "income": 0, "upkeep": 0, "event": {},
			"treasury": int(out["treasury"]), "line": "", "sect": out}

	var doctrine_id := String(sect.get("doctrine", ""))
	var income := PlayerSect.tribute_for(doctrine_id, realms) + steward_bonus()
	var upkeep := upkeep_per_member() * realms.size()
	var entry: Dictionary = event(force_event) if force_event != "" else event_for(day, world_seed, sect)
	var stones := int(entry.get("stones", 0))
	if stones < 0 and bool(entry.get("guarded", false)):
		stones = -floori(float(-stones) * guard_for(doctrine_id))
	var before := int(sect.get("treasury", 0))
	var treasury := before + income - upkeep + stones
	var shortfall := treasury < 0
	out["treasury"] = maxi(0, treasury)
	var effect := "+%d" % stones
	if stones < 0:
		effect = "−%d" % -stones
	var line := "Day %d — %s  (levy +%d, upkeep −%d, event %s; treasury %d)" % [day,
		String(entry.get("label", "The hall endures.")), income, upkeep, effect, int(out["treasury"])]
	if shortfall:
		line += " The treasury cannot cover it."
	return {
		"ok": true,
		"reason": "",
		"income": income,
		"upkeep": upkeep,
		"event": entry,
		"event_stones": stones,
		"treasury": int(out["treasury"]),
		"shortfall": shortfall,
		"line": line,
		"sect": out,
	}


## Settles every skipped day one at a time, bounded so a long rest cannot hold a
## frame. Any remaining days are picked up by the next call.
static func settle_days(sect: Dictionary, realms: Array, from_day: int, to_day: int,
		world_seed: int) -> Dictionary:
	var out := sect.duplicate(true)
	var lines: Array = []
	var income := 0
	var upkeep := 0
	if out.is_empty():
		return {"sect": out, "lines": lines, "income": 0, "upkeep": 0, "days": 0}
	var start := maxi(1, from_day)
	var last := mini(maxi(start, to_day), start + DEFAULT_MAX_DAYS - 1)
	if realms.is_empty():
		out["autonomy_day"] = last
		return {"sect": out, "lines": lines, "income": 0, "upkeep": 0, "days": last - start + 1}
	var log: Array = []
	var old: Variant = out.get("log", [])
	if typeof(old) == TYPE_ARRAY:
		log = (old as Array).duplicate()
	for day in range(start, last + 1):
		var result := settle_day(out, realms, day, world_seed)
		out = (result.get("sect", out) as Dictionary).duplicate(true)
		income += int(result.get("income", 0))
		upkeep += int(result.get("upkeep", 0))
		var line := String(result.get("line", ""))
		if line != "":
			lines.append(line)
			log.append(line)
	while log.size() > 8:
		log.pop_front()
	out["log"] = log
	return {"sect": out, "lines": lines, "income": income, "upkeep": upkeep,
		"days": last - start + 1}


# ------------------------------------------------------------- validation ----


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no sect autonomy data defined")
		return problems
	if int(data.get("upkeep_per_member", -1)) < 0:
		problems.append("sect autonomy has negative upkeep")
	if int(data.get("steward_bonus", -1)) < 0:
		problems.append("sect autonomy has a negative steward bonus")

	var list_value: Variant = data.get("events", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("sect autonomy events are missing")
	else:
		var seen: Dictionary = {}
		var total_weight := 0
		for value in (list_value as Array):
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("sect autonomy event is not an object")
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			if id == "":
				problems.append("sect autonomy event without id")
				continue
			if seen.has(id):
				problems.append("duplicate sect autonomy event " + id)
			seen[id] = true
			if String(entry.get("label", "")).strip_edges() == "":
				problems.append("sect autonomy event %s has no label" % id)
			var weight := int(entry.get("weight", 0))
			if weight < 1:
				problems.append("sect autonomy event %s cannot happen" % id)
			total_weight += maxi(0, weight)
		if total_weight < 1:
			problems.append("sect autonomy has no event weight")

	var guard_value: Variant = data.get("guard", null)
	if typeof(guard_value) != TYPE_DICTIONARY:
		problems.append("sect autonomy doctrine guards are missing")
	else:
		var table: Dictionary = guard_value
		for doctrine_id in table.keys():
			if PlayerSect.doctrine(String(doctrine_id)).is_empty():
				problems.append("sect autonomy guards unknown doctrine %s" % String(doctrine_id))
			var value: float = float(table[doctrine_id])
			if value < 0.0 or value > 1.0:
				problems.append("sect autonomy guard for %s is not a fraction" % String(doctrine_id))
		for value in PlayerSect.doctrines():
			if typeof(value) == TYPE_DICTIONARY:
				var id := String((value as Dictionary).get("id", ""))
				if not table.has(id):
					problems.append("no sect autonomy guard for doctrine %s" % id)

	return problems
