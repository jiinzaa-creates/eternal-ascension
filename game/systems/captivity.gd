class_name Captivity
extends RefCounted
## People held against their will: the legal, moral and economic half of the
## subsystem, kept apart from the bodies that were beaten into it.
##
## The design rule is explicit: captivity is a **status with consequences**, not
## an inventory slot. A record is a person — name, realm, loyalty, the day they
## were bound and the terms they are kept under — and every consequence falls
## out of those numbers:
##
##   labour    a captive works; a well-kept one works better than a broken one,
##             and harsh terms extract more while burning loyalty.
##   upkeep    fair terms cost rations; the stones come out of the same purse
##             the labour fills, so the trade is visible every day.
##   escape    a real chance, rolled from the person's id and the day, so a
##             loaded game cannot reroll a breakout.
##   rebellion when enough desperate people share a yard, they leave together.
##   notoriety holding people is a crime the market remembers; handing one to
##             the watch buys relief, and a high enough name closes the shops.
##
## Everything here is a pure static: records in, numbers out. The scene owns the
## roster, the clock and the stones, which is what lets the whole trade be
## tested without spawning a single body.
##
## Records are saved (unlike relationships, which regenerate) because a bond is
## a function of the seed while a captive's loyalty is the player's doing. The
## optional `captives` key is read through `sanitize()`, so schema stays 2.

const DEFAULT_POLICY := "captivity.fair"
## Escape rolls draw from this stream, keyed by the person and the day.
const ESCAPE_DOMAIN := "captivity_escape"
const HARD_POLICY := "captivity.harsh"
const BAND_BONDED := "bonded"
const BAND_STEADY := "steady"
const BAND_RESTLESS := "restless"
const BAND_REBELLIOUS := "rebellious"

# ------------------------------------------------------------- content ----


static func data() -> Dictionary:
	var raw: Variant = DB.captivity
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func policies() -> Array:
	var raw: Variant = data().get("policies", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


## One policy entry, or {} for an unknown id. Callers that must always have a
## usable policy use `policy_id_or_default()` first.
static func policy(id: String) -> Dictionary:
	for value in policies():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if String(entry.get("id", "")) == id:
			return entry
	return {}


static func default_policy_id() -> String:
	for value in policies():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id != "":
			return id
	return DEFAULT_POLICY


static func policy_id_or_default(id: String) -> String:
	if id != "" and not policy(id).is_empty():
		return id
	return default_policy_id()


static func policy_ids() -> Array:
	var out: Array = []
	for value in policies():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var id := String((value as Dictionary).get("id", ""))
		if id != "" and not out.has(id):
			out.append(id)
	return out


static func policy_name(id: String) -> String:
	return String(policy(policy_id_or_default(id)).get("name", "Keeping"))


static func policy_blurb(id: String) -> String:
	return String(policy(policy_id_or_default(id)).get("blurb", ""))


static func _section(name: String, defaults: Dictionary) -> Dictionary:
	var source: Variant = data().get(name, {})
	var out: Dictionary = defaults.duplicate()
	if typeof(source) != TYPE_DICTIONARY:
		return out
	var table: Dictionary = source
	for key in table.keys():
		out[key] = table[key]
	return out


static func loyalty_rules() -> Dictionary:
	return _section("loyalty", {
		"start": 35, "min": 0, "max": 100,
		"rebellious": 15, "restless": 34, "bonded": 70,
	})


static func escape_rules() -> Dictionary:
	return _section("escape", {
		"base": 0.02, "below": 34, "per_loyalty_below": 0.004,
		"per_captive": 0.015, "rebellious_mult": 1.8,
		"unpaid_penalty": 3, "max": 0.55,
	})


static func labor_rules() -> Dictionary:
	return _section("labor", {
		"base": 2, "per_realm": 1, "loyalty_floor": 0.5, "loyalty_span": 1.0,
	})


static func bounty_rules() -> Dictionary:
	return _section("bounty", {"base": 12, "per_realm": 8})


static func notoriety_rules() -> Dictionary:
	return _section("notoriety", {
		"per_capture": 4, "per_captive_day": 1, "harsh_mult": 2,
		"handover_relief": 6, "release_relief": 3, "decay": 1, "max": 100,
	})


static func binding_rules() -> Dictionary:
	return _section("binding", {
		"reach": 140.0, "subdue_seconds": 30.0, "max_held": 8,
		"weakened_ratio": 0.25,
		"rebellion_min": 3, "rebellion_loyalty": 18, "rebellion_harm": 0.12,
	})


## The health fraction below which a body can be taken. Captivity is a
## deliberate act on a beaten foe, not an automatic replacement for killing, so
## ordinary deaths, loot and the kill count are untouched by this subsystem.
static func weakened_ratio() -> float:
	return clampf(float(binding_rules().get("weakened_ratio", 0.25)), 0.01, 0.95)


static func legal_bands() -> Array:
	var raw: Variant = data().get("legal", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


## The subsystem can be switched off on an existing save: the roster is kept
## intact and nothing is settled, so turning it back on loses no one.
static func enabled() -> bool:
	return bool(Settings.content.get("captivity", true))


static func max_held() -> int:
	return clampi(int(binding_rules().get("max_held", 8)), 1, 64)


static func bind_reach() -> float:
	return maxf(16.0, float(binding_rules().get("reach", 140.0)))


static func subdue_seconds() -> float:
	return maxf(1.0, float(binding_rules().get("subdue_seconds", 30.0)))


static func rebellion_min() -> int:
	return maxi(2, int(binding_rules().get("rebellion_min", 3)))


static func rebellion_loyalty() -> int:
	return clampi(int(binding_rules().get("rebellion_loyalty", 18)), 0, int(loyalty_rules().get("max", 100)))


static func rebellion_harm() -> float:
	return clampf(float(binding_rules().get("rebellion_harm", 0.12)), 0.0, 1.0)


# -------------------------------------------------------------- records ----


## Why the player may not add another person, written for the player. An empty
## reason means yes.
static func can_bind(records: Array) -> Dictionary:
	if not enabled():
		return {"ok": false, "reason": "You do not traffic in bound people."}
	if records.size() >= max_held():
		return {"ok": false, "reason": "Your holding yard is full."}
	return {"ok": true, "reason": ""}


## A captive is a person, not a stat line: the name and the realm come from the
## body that was beaten, and the terms are the policy in force at the binding.
static func new_record(id: String, display_name: String, realm: int, bond_score: int,
		day: int, policy_id: String) -> Dictionary:
	var bounds := loyalty_rules()
	var swing := clampi(bond_score / 8, -8, 8)
	var start := clampi(int(bounds.get("start", 35)) + swing,
		int(bounds.get("min", 0)), int(bounds.get("max", 100)))
	return {
		"id": id,
		"name": display_name if display_name != "" else "Unnamed Captive",
		"realm": clampi(realm, 1, 12),
		"loyalty": start,
		"bound_day": maxi(0, day),
		"policy": policy_id_or_default(policy_id),
		"labor": 0,
	}


## A record read back from a save, with every field clamped. Unknown policies
## fall back to the first authored one rather than to a zero-labor ghost.
static func normalize(record: Dictionary) -> Dictionary:
	var bounds := loyalty_rules()
	return {
		"id": String(record.get("id", "")),
		"name": String(record.get("name", "Unnamed Captive")),
		"realm": clampi(int(record.get("realm", 1)), 1, 12),
		"loyalty": clampi(int(record.get("loyalty", int(bounds.get("start", 35)))),
			int(bounds.get("min", 0)), int(bounds.get("max", 100))),
		"bound_day": maxi(0, int(record.get("bound_day", 0))),
		"policy": policy_id_or_default(String(record.get("policy", ""))),
		"labor": maxi(0, int(record.get("labor", 0))),
	}


static func _held(records: Array, id: String) -> bool:
	for value in records:
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return true
	return false


static func sanitize(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := normalize(value as Dictionary)
		if String(record.get("id", "")) == "" or _held(out, String(record.get("id", ""))):
			continue
		if out.size() >= max_held():
			break
		out.append(record)
	return out


# -------------------------------------------------------------- loyalty ----


static func loyalty_of(record: Dictionary) -> int:
	var bounds := loyalty_rules()
	return clampi(int(record.get("loyalty", int(bounds.get("start", 35)))),
		int(bounds.get("min", 0)), int(bounds.get("max", 100)))


static func loyalty_band(loyalty: int) -> String:
	var bounds := loyalty_rules()
	if loyalty <= int(bounds.get("rebellious", 15)):
		return BAND_REBELLIOUS
	if loyalty <= int(bounds.get("restless", 34)):
		return BAND_RESTLESS
	if loyalty < int(bounds.get("bonded", 70)):
		return BAND_STEADY
	return BAND_BONDED


static func loyalty_label(loyalty: int) -> String:
	match loyalty_band(loyalty):
		BAND_BONDED:
			return "Bonded"
		BAND_STEADY:
			return "Steady"
		BAND_RESTLESS:
			return "Restless"
		_:
			return "Rebellious"


static func loyalty_colour(loyalty: int) -> String:
	match loyalty_band(loyalty):
		BAND_BONDED:
			return "#9fe0c0"
		BAND_STEADY:
			return "#d8c070"
		BAND_RESTLESS:
			return "#e0a070"
		_:
			return "#d06060"


# --------------------------------------------------------------- labour ----


## Stones a captive's work is worth in a day. Realm is skill, loyalty is
## willingness and the policy is how hard the terms are: no term makes a person
## worth a negative amount.
static func daily_labor(record: Dictionary) -> int:
	var rules := labor_rules()
	var terms := policy(String(record.get("policy", "")))
	var base := maxf(0.0, float(rules.get("base", 2))
		+ float(maxi(1, int(record.get("realm", 1)))) * float(rules.get("per_realm", 1)))
	var loyalty := float(loyalty_of(record)) / 100.0
	var factor := maxf(0.0, float(rules.get("loyalty_floor", 0.5))
		+ float(rules.get("loyalty_span", 1.0)) * loyalty)
	var pay := base * maxf(0.0, float(terms.get("labor", 1.0))) * factor
	return maxi(0, int(floor(pay)))


static func upkeep(record: Dictionary) -> int:
	return maxi(0, int(policy(String(record.get("policy", ""))).get("upkeep", 0)))


# --------------------------------------------------------------- escape ----


## The chance one person slips their bonds on a given day. Restless people run
## more often, a crowded yard is harder to watch, and desperation multiplies.
static func escape_chance(record: Dictionary, held: int) -> float:
	var rules := escape_rules()
	var chance := maxf(0.0, float(rules.get("base", 0.02)))
	var below := int(rules.get("below", 34))
	var loyalty := loyalty_of(record)
	if loyalty < below:
		chance += float(below - loyalty) * maxf(0.0, float(rules.get("per_loyalty_below", 0.004)))
	chance += float(maxi(0, held - 1)) * maxf(0.0, float(rules.get("per_captive", 0.015)))
	if loyalty_band(loyalty) == BAND_REBELLIOUS:
		chance *= maxf(1.0, float(rules.get("rebellious_mult", 1.8)))
	return clampf(chance, 0.0, clampf(float(rules.get("max", 0.55)), 0.0, 1.0))


## A real check, not a scripted escape: the roll is keyed by the person's stable
## id and the day, so reloading the same save cannot reroll the same night.
static func escapes(record: Dictionary, day: int, held: int) -> bool:
	var chance := escape_chance(record, held)
	if chance <= 0.0:
		return false
	var roll := float(Rng.roll_float(ESCAPE_DOMAIN, hash(String(record.get("id", ""))), day))
	return roll < chance


static func rebellion_risk(records: Array) -> bool:
	if records.size() < rebellion_min():
		return false
	var total := 0
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		total += loyalty_of(value as Dictionary)
	var average := float(total) / float(maxi(1, records.size()))
	return average < float(rebellion_loyalty())


# --------------------------------------------------------------- bounty ----


static func bounty(record: Dictionary) -> int:
	var rules := bounty_rules()
	return maxi(0, int(rules.get("base", 12))
		+ maxi(1, int(record.get("realm", 1))) * int(rules.get("per_realm", 8)))


static func capture_notoriety() -> int:
	return maxi(0, int(notoriety_rules().get("per_capture", 4)))


static func daily_notoriety(records: Array) -> int:
	var rules := notoriety_rules()
	var per := maxi(0, int(rules.get("per_captive_day", 1)))
	var harsh := maxi(1, int(rules.get("harsh_mult", 2)))
	var total := 0
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = value
		total += per
		if String(record.get("policy", "")) == HARD_POLICY:
			total += per * (harsh - 1)
	return total


static func handover_relief() -> int:
	return maxi(0, int(notoriety_rules().get("handover_relief", 6)))


static func release_relief() -> int:
	return maxi(0, int(notoriety_rules().get("release_relief", 3)))


static func notoriety_decay() -> int:
	return maxi(0, int(notoriety_rules().get("decay", 1)))


static func notoriety_cap() -> int:
	return maxi(1, int(notoriety_rules().get("max", 100)))


static func legal_band(value: int) -> Dictionary:
	var clamped := clampi(value, 0, notoriety_cap())
	for band_value in legal_bands():
		if typeof(band_value) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = band_value
		if clamped >= int(band.get("min", 0)) and clamped <= int(band.get("max", 0)):
			return band
	return {}


static func legal_label(value: int) -> String:
	return String(legal_band(value).get("label", "Unmarked"))


static func legal_blurb(value: int) -> String:
	return String(legal_band(value).get("blurb", ""))


static func wanted(value: int) -> bool:
	return String(legal_band(value).get("id", "")) == "legal.wanted"


# ----------------------------------------------------------------- days ----


## One day of holding people. Pure: the input records are never mutated, and the
## caller decides what to do with the answer. Labour is earned first and rations
## are paid out of the labour and the purse together, so a poor keeper's people
## eat before the keeper profits.
static func settle_day(records: Array, day: int, stones: int) -> Dictionary:
	var labor_total := 0
	var upkeep_total := 0
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = value
		labor_total += daily_labor(record)
		upkeep_total += upkeep(record)

	var available := maxi(0, stones) + labor_total
	var paid := mini(upkeep_total, available)
	var unpaid := upkeep_total - paid
	var net := labor_total - paid
	var rebellion := rebellion_risk(records)
	var rules := escape_rules()
	var accrued := daily_notoriety(records)
	var kept: Array = []
	var escaped: Array = []
	var notes: Array = []

	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := normalize(value as Dictionary)
		var terms := policy(String(record.get("policy", "")))
		var drift := int(terms.get("loyalty_drift", 0))
		if unpaid > 0:
			drift -= maxi(0, int(rules.get("unpaid_penalty", 3)))
		var bounds := loyalty_rules()
		record["loyalty"] = clampi(loyalty_of(record) + drift,
			int(bounds.get("min", 0)), int(bounds.get("max", 100)))
		record["labor"] = maxi(0, int(record.get("labor", 0))) + daily_labor(record)
		var slips := rebellion and loyalty_of(record) <= rebellion_loyalty()
		if not slips:
			slips = escapes(record, day, records.size())
		if slips:
			escaped.append(String(record.get("name", "A captive")))
		else:
			kept.append(record)

	if rebellion:
		notes.append("The yard rises together; the frightened run.")
	if unpaid > 0:
		notes.append("%d stones of rations went unpaid." % unpaid)
	if not escaped.is_empty() and not rebellion:
		notes.append("%s slipped the guards." % ", ".join(escaped))

	return {
		"records": kept,
		"labor": labor_total,
		"upkeep": upkeep_total,
		"paid": paid,
		"unpaid": unpaid,
		"net": net,
		"notoriety": accrued,
		"escaped": escaped,
		"rebellion": rebellion,
		"notes": notes,
	}


## "Lin Zhao · realm 3 · Steady (41) · 4 stones/day" — the one line the ledger's
## footer and the tests read.
static func describe(record: Dictionary) -> String:
	return "%s · realm %d · %s (%d) · %d stones/day" % [
		String(record.get("name", "?")),
		maxi(1, int(record.get("realm", 1))),
		loyalty_label(loyalty_of(record)),
		loyalty_of(record),
		daily_labor(record),
	]


# ------------------------------------------------------------ validation ----


## Content checks for `data/captivity.json`. A gap in the legal bands, a policy
## that pays nothing, or a loyalty ladder out of order would surface only as a
## captive nobody can describe, so they fail at boot instead.
static func validate(content: Dictionary) -> Array:
	var problems: Array = []
	var policy_list_value: Variant = content.get("policies", [])
	if typeof(policy_list_value) != TYPE_ARRAY or (policy_list_value as Array).is_empty():
		problems.append("captivity has no policies")
		return problems

	var seen: Dictionary = {}
	for value in policy_list_value:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("captivity policy is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("captivity policy without id")
			continue
		if seen.has(id):
			problems.append("duplicate captivity policy id " + id)
		seen[id] = true
		if String(entry.get("name", "")) == "":
			problems.append("captivity policy %s has no name" % id)
		if String(entry.get("blurb", "")) == "":
			problems.append("captivity policy %s has no blurb" % id)
		if float(entry.get("labor", 0.0)) <= 0.0:
			problems.append("captivity policy %s pays no labour" % id)
		if int(entry.get("upkeep", 0)) < 0:
			problems.append("captivity policy %s has negative upkeep" % id)
		var drift := int(entry.get("loyalty_drift", 0))
		if drift < -20 or drift > 20:
			problems.append("captivity policy %s drifts loyalty too far" % id)

	var bounds: Dictionary = content.get("loyalty", {})
	var low := int(bounds.get("min", 0))
	var high := int(bounds.get("max", 100))
	var rebellious := int(bounds.get("rebellious", 15))
	var restless := int(bounds.get("restless", 34))
	var bonded := int(bounds.get("bonded", 70))
	var start := int(bounds.get("start", 35))
	if low >= high:
		problems.append("captivity loyalty range is empty")
	if not (low < rebellious and rebellious < restless and restless < bonded and bonded < high):
		problems.append("captivity loyalty thresholds are out of order")
	if start < low or start > high:
		problems.append("captivity starting loyalty is outside its range")

	var escape_data: Dictionary = content.get("escape", {})
	var base := float(escape_data.get("base", 0.02))
	var chance_max := float(escape_data.get("max", 0.55))
	if base < 0.0 or base > 1.0:
		problems.append("captivity escape base is not a chance")
	if chance_max <= 0.0 or chance_max > 1.0:
		problems.append("captivity escape cap is not a chance")
	if float(escape_data.get("per_loyalty_below", 0.0)) < 0.0:
		problems.append("captivity escape punishes loyalty negatively")
	if float(escape_data.get("per_captive", 0.0)) < 0.0:
		problems.append("captivity escape crowds negatively")
	if float(escape_data.get("rebellious_mult", 1.0)) < 1.0:
		problems.append("captivity despair does not raise escape risk")
	if int(escape_data.get("unpaid_penalty", 0)) < 0:
		problems.append("captivity unpaid rations raise loyalty")

	var labor: Dictionary = content.get("labor", {})
	if float(labor.get("base", 0.0)) < 0.0 or float(labor.get("per_realm", 0.0)) < 0.0:
		problems.append("captivity labour is negative")
	if float(labor.get("loyalty_floor", 0.0)) < 0.0 or float(labor.get("loyalty_span", 0.0)) < 0.0:
		problems.append("captivity loyalty does not scale labour")

	var bounty_data: Dictionary = content.get("bounty", {})
	if int(bounty_data.get("base", 0)) < 0 or int(bounty_data.get("per_realm", 0)) < 0:
		problems.append("captivity bounty is negative")

	var legal_rules: Dictionary = content.get("notoriety", {})
	var cap := int(legal_rules.get("max", 100))
	if cap <= 0:
		problems.append("captivity notoriety has no cap")
	for key in ["per_capture", "per_captive_day", "handover_relief", "release_relief", "decay"]:
		if int(legal_rules.get(key, 0)) < 0:
			problems.append("captivity notoriety %s is negative" % key)
	if int(legal_rules.get("harsh_mult", 1)) < 1:
		problems.append("captivity harsh terms do not raise notoriety")

	var bands_value: Variant = content.get("legal", [])
	if typeof(bands_value) != TYPE_ARRAY or (bands_value as Array).is_empty():
		problems.append("captivity has no legal bands")
	else:
		var ranges: Array = []
		var seen_bands: Dictionary = {}
		for value in bands_value:
			if typeof(value) != TYPE_DICTIONARY:
				problems.append("captivity legal band is not an object")
				continue
			var band: Dictionary = value
			var id := String(band.get("id", ""))
			if id == "":
				problems.append("captivity legal band without id")
				continue
			if seen_bands.has(id):
				problems.append("duplicate captivity legal band " + id)
			seen_bands[id] = true
			if String(band.get("label", "")) == "":
				problems.append("captivity legal band %s has no label" % id)
			var band_low := int(band.get("min", -1))
			var band_high := int(band.get("max", -1))
			if band_low > band_high or band_low < 0 or band_high > cap:
				problems.append("captivity legal band %s is outside 0..%d" % [id, cap])
				continue
			ranges.append({"min": band_low, "max": band_high})
		ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("min", 0)) < int(b.get("min", 0)))
		var cursor := 0
		for value in ranges:
			var row: Dictionary = value
			var row_low := int(row.get("min", 0))
			if row_low > cursor:
				problems.append("captivity legal bands leave a gap at %d" % cursor)
			elif row_low < cursor:
				problems.append("captivity legal bands overlap at %d" % row_low)
			cursor = maxi(cursor, int(row.get("max", 0)) + 1)
		if cursor != cap + 1:
			problems.append("captivity legal bands stop at %d, not %d" % [cursor - 1, cap])

	var binding: Dictionary = content.get("binding", {})
	if float(binding.get("reach", 0.0)) <= 0.0:
		problems.append("captivity binding reach is not positive")
	if float(binding.get("subdue_seconds", 0.0)) <= 0.0:
		problems.append("captivity subdued window is not positive")
	var weakened := float(binding.get("weakened_ratio", 0.0))
	if weakened <= 0.0 or weakened >= 1.0:
		problems.append("captivity weakened threshold is not a fraction below full health")
	if int(binding.get("max_held", 0)) <= 0:
		problems.append("captivity holds nobody")
	if int(binding.get("rebellion_min", 0)) < 2:
		problems.append("captivity rebellion needs fewer than two people")
	if int(binding.get("rebellion_loyalty", 0)) < low or int(binding.get("rebellion_loyalty", 0)) > high:
		problems.append("captivity rebellion loyalty is outside its range")
	if float(binding.get("rebellion_harm", 0.0)) < 0.0 or float(binding.get("rebellion_harm", 0.0)) > 1.0:
		problems.append("captivity rebellion harm is not a fraction")
	return problems
