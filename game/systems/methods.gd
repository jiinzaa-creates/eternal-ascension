class_name Methods
extends RefCounted
## Cultivation methods: who may practise one, and how well the current moment
## feeds it.
##
## Every method's `mechanic` is a different input to the same meditation loop:
## sitting is strong for the traditional path and nearly worthless for a sword
## cultivator between fights. The multiplier is pure so the whole matrix can be
## tested without a player, a clock or a world.

const SWITCH_COST := 150


static func all() -> Array:
	return DB.methods


static func find(id: String) -> Dictionary:
	return DB.by_id("method", id)


static func qualifies(id: String, state: Dictionary) -> Dictionary:
	var method := find(id)
	if method.is_empty():
		return {"ok": false, "reason": "unknown method"}
	var req: Dictionary = method.get("requires", {})
	var min_realm := int(req.get("realm", 0))
	if int(state.get("realm", 0)) < min_realm:
		return {"ok": false, "reason": "realm %d" % min_realm}
	var min_kills := int(req.get("kills", 0))
	if int(state.get("kills", 0)) < min_kills:
		return {"ok": false, "reason": "%d kills" % min_kills}
	var min_tier := int(req.get("physique_tier", 0))
	if min_tier > 0 and int(state.get("physique_tier", 0)) < min_tier:
		return {"ok": false, "reason": "physique tier %d" % min_tier}
	var attrs: Variant = state.get("attrs", null)
	var min_attr: Dictionary = req.get("attrs", {})
	for key in min_attr.keys():
		var have := 0
		if attrs != null:
			have = (attrs as Attributes).get_attr(String(key))
		var need := int(min_attr[key])
		if have < need:
			return {"ok": false, "reason": "%s %d" % [String(key).to_upper(), need]}
	return {"ok": true, "reason": ""}


## How productive meditation is right now for this method. 1.0 is the baseline
## the traditional path always gets; the others trade it for conditions.
static func meditation_multiplier(id: String, state: Dictionary) -> float:
	var method := find(id)
	var mechanic := String(method.get("mechanic", "qi_accumulation"))
	match mechanic:
		"physical_conditioning":
			var attrs: Variant = state.get("attrs", null)
			var strength := 0.0
			if attrs != null:
				strength = float((attrs as Attributes).get_attr("str"))
			return clampf(0.5 + Attributes.soft(strength, 30.0) / 30.0 * 0.9, 0.3, 1.5)
		"sword_intent":
			return 1.7 if bool(state.get("recent_combat", false)) else 0.3
		"blood_essence":
			return 0.4 + clampf(float(state.get("blood_charge", 0.0)), 0.0, 100.0) / 100.0 * 1.2
		"kills":
			return 1.0 + clampf(float(state.get("kills", 0)), 0.0, 100.0) * 0.006
		"partner":
			return 1.5 if bool(state.get("partner", false)) else 0.35
		"celestial":
			return 1.8 if bool(state.get("night", false)) else 0.35
		"beast_bond":
			return clampf(0.5 + float(state.get("allies", 0)) * 0.35, 0.5, 1.9)
		"pillfire":
			return clampf(1.0 + float(state.get("potions", 0)) * 0.04, 1.0, 1.5)
		"elemental_cycle":
			var biome := String(state.get("biome", ""))
			if (method.get("attuned_biomes", []) as Array).has(biome):
				return 1.6
			if (method.get("harsh_biomes", []) as Array).has(biome):
				return 0.55
			return 1.05
		"stillness":
			return clampf(0.5 + minf(float(state.get("still_seconds", 0.0)), 30.0) / 30.0 * 1.3, 0.5, 1.8)
		"forbidden":
			var frac := 0.0
			var max_taint := float(state.get("contamination_max", 0.0))
			if max_taint > 0.0:
				frac = clampf(float(state.get("contamination", 0.0)) / max_taint, 0.0, 1.0)
			return 0.7 + frac * 1.2
		_:
			return 1.0


## How a method changes the tribulation itself. `chance` is added to the roll,
## `tribulation` multiplies Heaven's weight, `harm` scales what failure costs.
## Pure, like meditation_multiplier, so the whole matrix is testable without a
## player: a sword cultivator between fights faces Heaven worse than a body
## temperer, and a Blood Sea practitioner is helped and poisoned at once.
static func breakthrough_profile(id: String, state: Dictionary) -> Dictionary:
	var method := find(id)
	var mechanic := String(method.get("mechanic", "qi_accumulation"))
	var profile := {"chance": 0.0, "tribulation": 1.0, "harm": 1.0, "note": "steady circulation"}
	match mechanic:
		"physical_conditioning":
			profile["chance"] = 0.04
			profile["tribulation"] = 1.1
			profile["harm"] = 0.75
			profile["note"] = "a conditioned body endures"
		"sword_intent":
			if bool(state.get("recent_combat", false)):
				profile["chance"] = 0.1
				profile["note"] = "sword intent still sharp"
			else:
				profile["chance"] = -0.06
				profile["note"] = "no edge without a fight"
		"blood_essence":
			if float(state.get("blood_charge", 0.0)) >= 20.0:
				profile["chance"] = 0.05
				profile["harm"] = 1.4
				profile["note"] = "the sea lends and takes"
			else:
				profile["chance"] = -0.04
				profile["harm"] = 1.2
				profile["note"] = "the sea is dry"
		"kills":
			profile["tribulation"] = 1.15
			profile["harm"] = 1.2
			profile["note"] = "heaven counts the dead"
		"partner":
			if bool(state.get("partner", false)):
				profile["chance"] = 0.08
				profile["note"] = "two circulations share the weight"
			else:
				profile["chance"] = -0.05
				profile["note"] = "a lone half-circulation"
		"celestial":
			if bool(state.get("night", false)):
				profile["chance"] = 0.09
				profile["note"] = "the stars answer"
			else:
				profile["chance"] = -0.05
				profile["note"] = "the sky is closed"
		"beast_bond":
			var allies := int(state.get("allies", 0))
			profile["chance"] = minf(0.03 * float(allies), 0.09)
			profile["note"] = "the pack shares the storm" if allies > 0 else "no beast stands with you"
		"pillfire":
			var potions := int(state.get("potions", 0))
			profile["chance"] = minf(0.02 * float(potions), 0.10)
			profile["harm"] = 0.9
			profile["note"] = "pills cushion the fall" if potions > 0 else "the furnace is empty"
		"elemental_cycle":
			var biome := String(state.get("biome", ""))
			if (method.get("attuned_biomes", []) as Array).has(biome):
				profile["chance"] = 0.07
				profile["tribulation"] = 0.95
				profile["note"] = "the land shields its own"
			elif (method.get("harsh_biomes", []) as Array).has(biome):
				profile["chance"] = -0.04
				profile["note"] = "the phases starve here"
			else:
				profile["note"] = "the cycle turns, unhurried"
		"stillness":
			if float(state.get("still_seconds", 0.0)) >= 60.0:
				profile["chance"] = 0.08
				profile["harm"] = 0.85
				profile["note"] = "the array holds"
			else:
				profile["chance"] = -0.03
				profile["note"] = "the array is not yet set"
		"forbidden":
			profile["chance"] = 0.06
			profile["tribulation"] = 1.25
			profile["harm"] = 1.5
			profile["note"] = "Heaven answers defiance"
	return profile


## Whether two methods can be practised as a pair (Directive s.7.1:
## combinable where compatible). The data is kept symmetric; the AND here
## means a one-sided edit to the data fails safe instead of half-working.
static func compatible(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var first := find(a)
	var second := find(b)
	if first.is_empty() or second.is_empty():
		return false
	return (first.get("combines_with", []) as Array).has(b) \
		and (second.get("combines_with", []) as Array).has(a)


## Meditation for a pair: the primary method drives, the secondary bends
## the result halfway toward its own fit. An unpaired method is itself.
static func combined_meditation(primary: String, secondary: String, state: Dictionary) -> float:
	var base := meditation_multiplier(primary, state)
	if secondary == "" or not compatible(primary, secondary):
		return base
	return base + (meditation_multiplier(secondary, state) - 1.0) * 0.5


## A breakthrough for a pair: the chances average, Heaven's weight
## averages, and the worse harm rules - two circulations share the storm,
## but the frailer one sets what failure costs.
static func combined_profile(primary: String, secondary: String, state: Dictionary) -> Dictionary:
	var profile := breakthrough_profile(primary, state)
	if secondary == "" or not compatible(primary, secondary):
		return profile
	var other := breakthrough_profile(secondary, state)
	profile["chance"] = (float(profile["chance"]) + float(other["chance"])) / 2.0
	profile["tribulation"] = (float(profile["tribulation"]) + float(other["tribulation"])) / 2.0
	profile["harm"] = maxf(float(profile["harm"]), float(other["harm"]))
	profile["note"] = "%s · paired with %s" % [String(profile["note"]), String(find(secondary).get("name", secondary))]
	return profile


## Insight is a long, slow bonus: at most +20% to the method's own multiplier.
static func insight_bonus(insight: int) -> float:
	return 1.0 + clampf(float(insight), 0.0, 100.0) * 0.002


static func available(state: Dictionary) -> Array:
	var out: Array = []
	for method in all():
		var id := String(method.get("id", ""))
		if bool(qualifies(id, state)["ok"]):
			out.append(id)
	return out


## The stele cycles, so a method nobody qualifies for is simply skipped.
static func next(current: String, state: Dictionary) -> String:
	var options := available(state)
	if options.is_empty():
		return ""
	var index := options.find(current)
	if index < 0:
		return String(options[0])
	return String(options[(index + 1) % options.size()])
