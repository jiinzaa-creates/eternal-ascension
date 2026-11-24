class_name Factions
extends RefCounted
## Who the player stands with, and what that changes.
##
## A faction owns a standing in −100..100. The stored number is the raw record of
## what the player did; what a person actually feels is that number minus a
## lawful faction's memory of the player's notoriety. That keeps one source of
## truth: releasing captives improves the name without rewriting every faction.
##
## Taking an action for a faction ripples: its rivals cool and its allies warm a
## little. The ripple is part of `award()`, not a second ledger, so there is no
## per-faction action history to save and no way for two counters to disagree.

const MIN_STANDING := -100
const MAX_STANDING := 100
const DEFAULT_BAND := "standing.neutral"


# ------------------------------------------------------------------ data ----


static func factions() -> Array:
	return DB.factions()


static func bands() -> Array:
	return DB.faction_bands()


static func faction(id: String) -> Dictionary:
	return DB.faction(id)


static func award_rules() -> Dictionary:
	return DB.faction_awards()


static func default_standing() -> int:
	return clampi(int(award_rules().get("default_standing", 0)), MIN_STANDING, MAX_STANDING)


static func quest_award() -> int:
	return maxi(0, int(award_rules().get("quest_award", 0)))


static func story_award() -> int:
	return maxi(0, int(award_rules().get("story_award", 0)))


static func boss_penalty() -> int:
	return maxi(0, int(award_rules().get("boss_penalty", 0)))


# --------------------------------------------------------------- standing ----


## The stored value for one faction, clamped. Missing entries read as the
## default, so a save written before a faction existed is not hostile to it.
static func standing_of(faction_id: String, standing: Dictionary) -> int:
	if faction_id == "":
		return default_standing()
	return clampi(int(standing.get(faction_id, default_standing())), MIN_STANDING, MAX_STANDING)


## What the faction actually thinks of the player: the record, less the lawful
## memory of a holding yard. The divisor makes notoriety a real cost but never
## an absolute one.
static func effective_standing(faction_id: String, standing: Dictionary, notoriety: int = 0) -> int:
	var value := standing_of(faction_id, standing)
	var entry := faction(faction_id)
	if entry.is_empty() or not bool(entry.get("lawful", false)):
		return value
	var divisor := maxi(1, int(award_rules().get("notoriety_divisor", 4)))
	return clampi(value - int(float(maxi(0, notoriety)) / float(divisor)), MIN_STANDING, MAX_STANDING)


static func band_for(value: int) -> Dictionary:
	var clamped := clampi(value, MIN_STANDING, MAX_STANDING)
	for value_entry in bands():
		if typeof(value_entry) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = value_entry
		if clamped >= int(band.get("min", 0)) and clamped <= int(band.get("max", 0)):
			return band
	return DB.faction_band(DEFAULT_BAND)


static func band_id(value: int) -> String:
	return String(band_for(value).get("id", ""))


static func label(value: int) -> String:
	return String(band_for(value).get("label", "Neutral"))


static func blurb(value: int) -> String:
	return String(band_for(value).get("blurb", ""))


static func disposition_bonus(faction_id: String, standing: Dictionary, notoriety: int = 0) -> int:
	return int(band_for(effective_standing(faction_id, standing, notoriety)).get("disposition", 0))


static func price_multiplier(faction_id: String, standing: Dictionary, notoriety: int = 0) -> float:
	return maxf(0.5, float(band_for(effective_standing(faction_id, standing, notoriety)).get("price_mult", 1.0)))


## "Azure Cloud Sect — Trusted (+27)"
static func describe(faction_id: String, standing: Dictionary, notoriety: int = 0) -> String:
	var entry := faction(faction_id)
	if entry.is_empty():
		return ""
	var value := effective_standing(faction_id, standing, notoriety)
	return "%s — %s (%+d)" % [String(entry.get("name", faction_id)), label(value), value]


# ------------------------------------------------------------- membership ----


## Which faction a resident belongs to, by the archetype that generated them.
static func for_archetype(archetype_id: String) -> String:
	if archetype_id == "":
		return ""
	for value in factions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var members: Variant = entry.get("archetypes", [])
		if typeof(members) == TYPE_ARRAY and (members as Array).has(archetype_id):
			return String(entry.get("id", ""))
	return ""


static func for_boss(boss_id: String) -> String:
	if boss_id == "":
		return ""
	for value in factions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var bosses: Variant = entry.get("bosses", [])
		if typeof(bosses) == TYPE_ARRAY and (bosses as Array).has(boss_id):
			return String(entry.get("id", ""))
	return ""


## "Ally: Verdant Market League · Rival: Hollow Moon Cult" — the relations line
## the faction screen shows.
static func relation_text(faction_id: String) -> String:
	var entry := faction(faction_id)
	if entry.is_empty():
		return ""
	var parts: Array[String] = []
	for ally in _ids(entry.get("allies", [])):
		parts.append("Ally: " + String(faction(ally).get("name", ally)))
	for rival in _ids(entry.get("rivals", [])):
		parts.append("Rival: " + String(faction(rival).get("name", rival)))
	return " · ".join(parts)


# ------------------------------------------------------------------ award ----


## The whole standing map after one action. Pure: the caller's dictionary is
## never touched. Rivals lose half the amount and allies gain a quarter, both
## truncated toward zero, so a friendly act has a cost somewhere.
static func award(standing: Dictionary, faction_id: String, amount: int) -> Dictionary:
	var out := sanitize(standing)
	if amount == 0 or faction(faction_id).is_empty():
		return out
	out[faction_id] = clampi(standing_of(faction_id, out) + amount, MIN_STANDING, MAX_STANDING)
	var rule := award_rules()
	var rival_share := float(rule.get("rival_shift", 0.0))
	var ally_share := float(rule.get("ally_shift", 0.0))
	for value in factions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var other: Dictionary = value
		var other_id := String(other.get("id", ""))
		if other_id == "" or other_id == faction_id:
			continue
		var delta := 0
		if _ids(faction(faction_id).get("rivals", [])).has(other_id):
			delta = int(float(-amount) * rival_share)
		elif _ids(faction(faction_id).get("allies", [])).has(other_id):
			delta = int(float(amount) * ally_share)
		if delta != 0:
			out[other_id] = clampi(standing_of(other_id, out) + delta, MIN_STANDING, MAX_STANDING)
	return out


## A save never trusts the numbers it is handed: unknown factions are dropped and
## every value is clamped. Known factions missing from the file read as default.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	for value in factions():
		if typeof(value) == TYPE_DICTIONARY:
			out[String((value as Dictionary).get("id", ""))] = default_standing()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var stored: Dictionary = raw
	for key in stored.keys():
		var id := String(key)
		if not out.has(id):
			continue
		out[id] = clampi(int(stored[key]), MIN_STANDING, MAX_STANDING)
	return out


# ------------------------------------------------------------- validation ----


## Content checks for `data/factions.json`: the bands must tile −100..100, every
## archetype and boss may belong to one faction only, and allies and rivals must
## name each other back, so a relation can never be one-sided by accident.
static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no faction data defined")
		return problems

	var band_list: Variant = data.get("bands", null)
	if typeof(band_list) != TYPE_ARRAY or (band_list as Array).is_empty():
		problems.append("no faction standing bands defined")
	else:
		var ranges: Array = []
		var seen_bands: Dictionary = {}
		for value in band_list:
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("faction band is not an object")
				continue
			var band: Dictionary = value
			var id := String(band.get("id", ""))
			if id == "":
				problems.append("faction band without id")
				continue
			if seen_bands.has(id):
				problems.append("duplicate faction band " + id)
			seen_bands[id] = true
			if String(band.get("label", "")) == "" or String(band.get("blurb", "")) == "":
				problems.append("faction band %s has no label or blurb" % id)
			var low := int(band.get("min", MAX_STANDING + 1))
			var high := int(band.get("max", MIN_STANDING - 1))
			if low > high or low < MIN_STANDING or high > MAX_STANDING:
				problems.append("faction band %s has a range outside %d..%d" % [id, MIN_STANDING, MAX_STANDING])
				continue
			var disposition := int(band.get("disposition", 0))
			if disposition < -20 or disposition > 20:
				problems.append("faction band %s has an out-of-range disposition" % id)
			var mult := float(band.get("price_mult", 0.0))
			if mult < 0.5 or mult > 2.0:
				problems.append("faction band %s has an unfair price multiplier" % id)
			ranges.append({"id": id, "min": low, "max": high})
		ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("min", 0)) < int(b.get("min", 0)))
		var cursor := MIN_STANDING
		for value in ranges:
			var row: Dictionary = value
			var low := int(row.get("min", 0))
			if low > cursor:
				problems.append("faction bands leave a gap at %d" % cursor)
			elif low < cursor:
				problems.append("faction bands overlap at %d" % low)
			cursor = maxi(cursor, int(row.get("max", 0)) + 1)
		if cursor != MAX_STANDING + 1:
			problems.append("faction bands stop at %d, not %d" % [cursor - 1, MAX_STANDING])

	var rules: Variant = data.get("awards", null)
	if typeof(rules) != TYPE_DICTIONARY or (rules as Dictionary).is_empty():
		problems.append("faction awards are missing")
	else:
		var rule: Dictionary = rules
		var default_value := int(rule.get("default_standing", MAX_STANDING + 1))
		if default_value < MIN_STANDING or default_value > MAX_STANDING:
			problems.append("faction default standing is outside the ladder")
		for key in ["quest_award", "story_award", "boss_penalty"]:
			if int(rule.get(key, 0)) < 1:
				problems.append("faction award %s must be positive" % key)
		if int(rule.get("notoriety_divisor", 0)) < 1:
			problems.append("faction notoriety divisor must be positive")
		for key in ["rival_shift", "ally_shift"]:
			var share := float(rule.get(key, -1.0))
			if share < 0.0 or share > 1.0:
				problems.append("faction award %s is outside 0..1" % key)

	var list: Variant = data.get("factions", null)
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		problems.append("no factions defined")
		return problems
	var seen: Dictionary = {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("faction is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("faction without id")
			continue
		if seen.has(id):
			problems.append("duplicate faction id " + id)
		seen[id] = entry
		if String(entry.get("name", "")) == "" or String(entry.get("kind", "")) == "":
			problems.append("faction %s has no name or kind" % id)
		if String(entry.get("colour", "")) == "":
			problems.append("faction %s has no colour" % id)
	for value in seen.values():
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		for other in _ids(entry.get("allies", [])):
			if other == id or not seen.has(other):
				problems.append("faction %s names a bad ally %s" % [id, other])
			elif not _ids((seen[other] as Dictionary).get("allies", [])).has(id):
				problems.append("faction ally %s and %s do not name each other" % [id, other])
		for other in _ids(entry.get("rivals", [])):
			if other == id or not seen.has(other):
				problems.append("faction %s names a bad rival %s" % [id, other])
			elif not _ids((seen[other] as Dictionary).get("rivals", [])).has(id):
				problems.append("faction rival %s and %s do not name each other" % [id, other])
			elif _ids(entry.get("allies", [])).has(other):
				problems.append("faction %s calls %s both ally and rival" % [id, other])

	var archetype_owner: Dictionary = {}
	var archetype_ids: Dictionary = {}
	for value in DB.archetypes():
		if typeof(value) == TYPE_DICTIONARY:
			archetype_ids[String((value as Dictionary).get("id", ""))] = true
	var boss_ids: Dictionary = {}
	for boss in DB.bosses:
		if typeof(boss) == TYPE_DICTIONARY:
			boss_ids[String((boss as Dictionary).get("id", ""))] = true
	for value in seen.values():
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		for archetype in _ids(entry.get("archetypes", [])):
			if not archetype_ids.has(archetype):
				problems.append("faction %s names unknown archetype %s" % [id, archetype])
			if archetype_owner.has(archetype):
				problems.append("archetype %s belongs to %s and %s" % [archetype, String(archetype_owner[archetype]), id])
			archetype_owner[archetype] = id
		for boss in _ids(entry.get("bosses", [])):
			if not boss_ids.has(boss):
				problems.append("faction %s names unknown boss %s" % [id, boss])
	return problems


static func _ids(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		var id := String(value)
		if id != "":
			out.append(id)
	return out
