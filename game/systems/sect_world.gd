class_name SectWorld
extends RefCounted
## The twelve houses, living without the player.
##
## Each established sect carries strength, treasury and membership, derived
## at first from its population tier and then settled day by day: income
## from its economy, upkeep for its disciples, recruitment when the vault
## is full, strength trailing the other two. Rivalries seeded in the data
## can ignite into feuds that bleed both houses until a truce roll ends
## them; allies quietly hold each other up. Every draw is a pure function
## of (world seed, day, sect), so the world the player returns to is the
## world that would have been — and a reload can never reroll it.

const TIER_BASE := {
	"small": {"strength": 42, "treasury": 120, "members": 60, "cap": 90},
	"standard": {"strength": 60, "treasury": 220, "members": 140, "cap": 220},
	"great": {"strength": 80, "treasury": 380, "members": 260, "cap": 400},
}
const FEUD_IGNITE := 0.02
const FEUD_TRUCE := 0.05


static func initial(day: int) -> Dictionary:
	var sects: Dictionary = {}
	for value in Sects.sects():
		var sect: Dictionary = value
		var base: Dictionary = TIER_BASE.get(String(sect.get("population", "standard")), TIER_BASE["standard"])
		sects[String(sect.get("id", ""))] = {
			"strength": int(base["strength"]),
			"treasury": int(base["treasury"]),
			"members": int(base["members"]),
		}
	return {"day": day, "sects": sects, "feuds": []}


static func sanitize(raw: Variant, day: int) -> Dictionary:
	var out := initial(day)
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = raw
	out["day"] = int(source.get("day", day))
	var raw_sects: Dictionary = source.get("sects", {})
	for id in (out["sects"] as Dictionary).keys():
		if raw_sects.has(id):
			var entry: Dictionary = raw_sects[id]
			(out["sects"] as Dictionary)[id] = {
				"strength": clampi(int(entry.get("strength", 0)), 0, 130),
				"treasury": clampi(int(entry.get("treasury", 0)), -100, 2000),
				"members": clampi(int(entry.get("members", 0)), 0, 600),
			}
	var feuds: Array = []
	for pair in source.get("feuds", []):
		if typeof(pair) == TYPE_ARRAY and (pair as Array).size() == 2:
			var a := String(pair[0])
			var b := String(pair[1])
			if not Sects.sect(a).is_empty() and not Sects.sect(b).is_empty() and a != b:
				feuds.append([a, b] if a < b else [b, a])
	out["feuds"] = feuds
	return out


static func feuding_with(state: Dictionary, sect_id: String) -> Array:
	var out: Array = []
	for pair in state.get("feuds", []):
		if String(pair[0]) == sect_id:
			out.append(String(pair[1]))
		elif String(pair[1]) == sect_id:
			out.append(String(pair[0]))
	return out


static func _income(sect: Dictionary) -> int:
	var economy := String(sect.get("economy", "")).to_lower()
	var base := 9
	for keyword in ["trade", "market", "forge", "mine", "pill", "cores", "pleasure"]:
		if economy.contains(keyword):
			base = 13
			break
	return base


## Settle every day in (state.day, to_day]. Returns the new state and the
## day's notable events, oldest first, capped so a long absence reports
## only its loudest news.
static func settle_days(state: Dictionary, to_day: int, world_seed: int) -> Dictionary:
	var next := state.duplicate(true)
	var events: Array = []
	var from_day := int(next.get("day", to_day))
	if to_day <= from_day:
		return {"state": next, "events": events}
	for day in range(from_day + 1, to_day + 1):
		_settle_day(next, day, world_seed, events)
	next["day"] = to_day
	while events.size() > 6:
		events.pop_front()
	return {"state": next, "events": events}


static func _settle_day(state: Dictionary, day: int, world_seed: int, events: Array) -> void:
	var sects: Dictionary = state["sects"]
	for value in Sects.sects():
		var sect: Dictionary = value
		var id := String(sect.get("id", ""))
		if not sects.has(id):
			continue
		var entry: Dictionary = sects[id]
		var r := Rng.stream_from(world_seed, "sect_world", day * 31 + id.hash())
		entry["treasury"] = int(entry["treasury"]) + _income(sect) \
			+ int(entry["members"]) / 12 - int(entry["members"]) / 8
		if int(entry["treasury"]) > 40 and int(entry["members"]) < int(TIER_BASE.get(
				String(sect.get("population", "standard")), TIER_BASE["standard"])["cap"]):
			entry["members"] = int(entry["members"]) + r.randi_range(0, 2)
		elif int(entry["treasury"]) < 0:
			entry["members"] = maxi(0, int(entry["members"]) - r.randi_range(0, 2))
			entry["treasury"] = maxi(-100, int(entry["treasury"]))
		var target := clampf(float(entry["members"]) * 0.32 + float(entry["treasury"]) / 12.0, 5.0, 120.0)
		var strength := float(entry["strength"])
		entry["strength"] = int(round(strength + clampf(target - strength, -1.0, 1.0)))
		sects[id] = entry
	# Feuds: ignition, bleeding, truces — one pass over the rival web.
	var feuds: Array = state.get("feuds", [])
	for value in Sects.sects():
		var sect: Dictionary = value
		var a := String(sect.get("id", ""))
		for rival in sect.get("rivals", []):
			var b := String(rival)
			if a >= b:
				continue
			var pair: Array = [a, b]
			var r := Rng.stream_from(world_seed, "sect_feud", day * 17 + (a + b).hash())
			if feuds.has(pair):
				for id in pair:
					if sects.has(id):
						var entry: Dictionary = sects[id]
						entry["strength"] = maxi(0, int(entry["strength"]) - r.randi_range(1, 2))
						entry["members"] = maxi(0, int(entry["members"]) - r.randi_range(0, 1))
						sects[id] = entry
				if r.randf() < FEUD_TRUCE:
					feuds.erase(pair)
					events.append("%s and %s call a truce; the feud cools." % [
						String(Sects.sect(a).get("name", a)), String(Sects.sect(b).get("name", b))])
			elif r.randf() < FEUD_IGNITE:
				feuds.append(pair)
				events.append("%s and %s are at feud — old rivalry, new blood." % [
					String(Sects.sect(a).get("name", a)), String(Sects.sect(b).get("name", b))])
	state["feuds"] = feuds
	# Allies hold each other up.
	for value in Sects.sects():
		var sect: Dictionary = value
		var a := String(sect.get("id", ""))
		for ally in sect.get("allies", []):
			var b := String(ally)
			if a >= b or not sects.has(a) or not sects.has(b):
				continue
			if int((sects[a] as Dictionary)["strength"]) > 60 and int((sects[b] as Dictionary)["strength"]) > 60:
				for id in [a, b]:
					var entry: Dictionary = sects[id]
					entry["strength"] = mini(130, int(entry["strength"]) + 1)
					sects[id] = entry
	state["sects"] = sects
