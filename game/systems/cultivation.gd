class_name Cultivation
extends RefCounted
## Qi accumulation, sublevels, realms and breakthroughs.
##
## Power comes from two different places on purpose:
##   * sublevels are incremental (Qi, small attribute growth), and
##   * realms are qualitative (a multiplier plus a new system unlock).
## Realm gaps are meant to be lethal. Within a realm, technique and timing decide.

const SUBLEVELS := 10
## Breakthrough preparation: banked at the tribulation ground, spent by the
## attempt itself (win or lose), so it is a decision rather than a buff.
const MAX_PREPARATION := 3
const PREP_COST := 60
const PREP_CHANCE := 0.06
const PREP_TRIBULATION := 0.10
const PREP_HARM := 0.15
## Accumulated understanding needed before an epiphany can strike. Sources are
## real play: meditation, kills, a survived tribulation, a breakthrough.
const ENLIGHTENMENT_GOAL := 100.0

var realm: int = 1
var sublevel: int = 1
var qi: float = 0.0
var root_tier: int = 3
## Appraisal state. The hidden purity bonus only applies once the root has been
## read; the tier's own purity always applies, so nothing is lost by not knowing.
var identified := false
var purity_bonus := 0.0
var method_id: String = "method.traditional"
var method_affixes: Dictionary = {}
var secondary_method_id: String = ""
var pair_affixes: Dictionary = {}
## Method id -> insight 0..100, earned by meditating well with that method.
var method_insight: Dictionary = {}
## Blood Sea resource: gained by kills, burned while meditating.
var blood_charge: float = 0.0
## Opened meridians, in the order they were opened.
var meridians: Array = []
## Impurity in the channels, 0..100. Slows gain and regeneration until purged.
var contamination: float = 0.0
var breakthrough_attempts: int = 0
var failures: int = 0
## Banked preparations for the next breakthrough, 0..MAX_PREPARATION.
var preparation: int = 0
## Understanding, 0..ENLIGHTENMENT_GOAL. Full means an insight is due.
var enlightenment_meter: float = 0.0
## How many epiphanies have been rolled; also the deterministic pick's counter.
var enlightenment_attempts: int = 0


func realm_data() -> Dictionary:
	return DB.realm(realm)


func root_data() -> Dictionary:
	return DB.get_root(root_tier)


func method_data() -> Dictionary:
	return DB.by_id("method", method_id)


func attr_mult() -> float:
	return float(realm_data().get("attr_mult", 1.0))


func root_mult() -> float:
	return float(root_data().get("cult_mult", 1.0))


## Purity the formulas actually use: the tier's base purity plus the hidden bonus
## once the root has been appraised.
func effective_purity() -> float:
	var base := float(root_data().get("purity", 0.55))
	return clampf(base + (purity_bonus if identified else 0.0), 0.0, 1.0)


func method_mult() -> float:
	return float(method_data().get("cult_mult", 1.0))


func method_insight_points(id: String) -> int:
	return int(round(float(method_insight.get(id, 0.0))))


## The method's own multiplier plus the slow insight bonus for it.
func effective_method_mult() -> float:
	return method_mult() * Methods.insight_bonus(method_insight_points(method_id))


## Fractional on purpose: a second of meditation must eventually count even
## though each frame adds a small slice.
func add_method_insight(id: String, amount: float) -> void:
	if id == "" or amount <= 0.0:
		return
	method_insight[id] = clampf(float(method_insight.get(id, 0.0)) + amount, 0.0, 100.0)


func add_blood_charge(amount: float) -> void:
	blood_charge = clampf(blood_charge + amount, 0.0, 100.0)


func consume_blood_charge(amount: float) -> void:
	blood_charge = clampf(blood_charge - maxf(0.0, amount), 0.0, 100.0)


func base_qi() -> float:
	return 100.0 * float(realm_data().get("qi_mult", 1.0)) * Realms.sublevel_factor(sublevel)


## Everything this stage has unlocked. Cumulative across realms.
func unlock_ids() -> Array:
	return Realms.unlock_ids(realm)


func has_unlock(id: String) -> bool:
	return Realms.has_unlock(realm, id)


## The current realm's art. Only the newest one applies to the stat pipeline.
func realm_ability() -> Dictionary:
	return Realms.ability(realm)


## What leaving this realm costs in Heaven's terms. Data-declared per realm.
func tribulation_id() -> String:
	return Tribulation.for_realm(realm)


func qi_max(stats: StatBlock) -> float:
	return (base_qi() * stats.max_qi_mult() * (0.75 + 0.5 * effective_purity()) + stats.qi_max_flat()) \
		* Meridians.capacity_mult(meridians)


func meridian_count() -> int:
	return Meridians.count(meridians)


func has_meridian(id: String) -> bool:
	return meridians.has(id)


## Permanent. Returns false for unknown, duplicate or realm-locked channels;
## the caller is responsible for having paid for it.
func open_meridian(id: String) -> bool:
	if not bool(Meridians.can_open(id, meridians, realm)["ok"]):
		return false
	meridians.append(id)
	return true


## Contamination cuts Qi gain and regeneration by up to half. It never inverts
## and never reaches zero output.
func contamination_mult() -> float:
	return 1.0 - clampf(contamination, 0.0, Meridians.MAX_CONTAMINATION) / (Meridians.MAX_CONTAMINATION * 2.0)


func add_contamination(amount: float) -> void:
	contamination = clampf(contamination + maxf(0.0, amount), 0.0, Meridians.MAX_CONTAMINATION)


func cleanse(amount: float) -> void:
	contamination = clampf(contamination - maxf(0.0, amount), 0.0, Meridians.MAX_CONTAMINATION)


func qi_gain_per_sec(stats: StatBlock, environment: float = 1.0) -> float:
	return 4.0 * root_mult() * effective_method_mult() * stats.cultivation_rate_mult() \
		* maxf(environment, 0.0) * contamination_mult()


## Passive regeneration while not meditating. Small, but real: a wounded
## cultivator recovers between fights without sitting down.
func qi_regen_per_sec(stats: StatBlock) -> float:
	return ((0.6 + Attributes.soft(float(stats.get_attr("wis")), 25.0) / 22.0) * effective_purity() * stats.qi_regen_mult() + stats.qi_regen_flat()) * contamination_mult()


func regenerate(stats: StatBlock, delta: float) -> float:
	var cap := qi_max(stats)
	var before := qi
	qi = minf(cap, qi + qi_regen_per_sec(stats) * delta)
	return qi - before


## Meditating for `delta` seconds. `method_factor` is how well the current
## moment feeds the method (see Methods.meditation_multiplier). Returns the Qi
## actually gained.
func cultivate(stats: StatBlock, delta: float, environment: float = 1.0, method_factor: float = 1.0) -> float:
	var cap := qi_max(stats)
	var before := qi
	var gain := qi_gain_per_sec(stats, environment) * maxf(method_factor, 0.0) * delta
	qi = minf(cap, qi + gain)
	return qi - before


func is_full(stats: StatBlock) -> bool:
	return qi >= qi_max(stats) - 0.001


func is_peak() -> bool:
	return sublevel >= SUBLEVELS


## Advances a sublevel when Qi is full. Returns true if a sublevel was gained.
func advance_sublevel(stats: StatBlock) -> bool:
	if not is_full(stats) or is_peak():
		return false
	sublevel += 1
	qi = 0.0
	Bus.realm_advanced.emit(realm, sublevel)
	return true


## How dangerous this character's tribulation is. Reads accumulated power,
## behaviour and realm, exactly as designed: a slaughter cultivator draws a
## heavier heaven than a healer of the same realm.
func tribulation_scale(kills: int = 0, karma: int = 0) -> float:
	var scale := 0.25 + float(realm) * 0.06 + float(kills) * 0.002 + absf(float(karma)) * 0.003
	return clampf(scale, 0.0, 2.0)


## The affix this life has drawn for the method being practised, rolled
## once when first needed and kept: a method's character, like a
## technique's, is something it grows into, not something chosen.
func method_affix() -> String:
	var existing := String(method_affixes.get(method_id, ""))
	if existing != "":
		return existing
	var rolled := Affixes.roll_method(Methods.find(method_id),
		method_id.hash() + breakthrough_attempts * 131 + failures * 17)
	if rolled != "":
		method_affixes[method_id] = rolled
	return rolled


## The fusion affix the current pairing has drawn, or "" unpaired.
## Rolled once per pair from the union of both methods' families.
func pair_affix() -> String:
	if secondary_method_id == "":
		return ""
	var key := "%s|%s" % [method_id, secondary_method_id]
	var existing := String(pair_affixes.get(key, ""))
	if existing != "":
		return existing
	var rolled := Affixes.roll_pair(Methods.find(method_id), Methods.find(secondary_method_id),
		key.hash() + breakthrough_attempts * 131 + failures * 17)
	if rolled != "":
		pair_affixes[key] = rolled
	return rolled


## The breakthrough profile with this method's affix laid over it.
func _affixed_profile(method_state: Dictionary) -> Dictionary:
	var profile := Methods.combined_profile(method_id, secondary_method_id, method_state)
	profile = Affixes.apply_method_profile(profile, method_affix())
	return Affixes.apply_method_profile(profile, pair_affix())


## Heaven's weight for this attempt: behaviour and realm, reshaped by the method
## being practised and lightened by banked preparations.
func tribulation_with(kills: int = 0, karma: int = 0, method_state: Dictionary = {}) -> float:
	var profile := _affixed_profile(method_state)
	var scale := tribulation_scale(kills, karma) * float(profile.get("tribulation", 1.0))
	return clampf(scale * (1.0 - PREP_TRIBULATION * float(preparation)), 0.0, 3.0)


## The profile the next attempt will use. Exposed for the HUD and for tests.
func method_breakthrough_profile(method_state: Dictionary = {}) -> Dictionary:
	return _affixed_profile(method_state)


## What the next failure would cost, as a multiplier on the base fallout.
func failure_harm(method_state: Dictionary = {}) -> float:
	var profile := _affixed_profile(method_state)
	return float(profile.get("harm", 1.0)) * (1.0 - PREP_HARM * float(preparation))


## The chance the HUD shows and the attempt rolls, from one formula.
func estimated_chance(stats: StatBlock, kills: int = 0, karma: int = 0, method_state: Dictionary = {}) -> float:
	var profile := _affixed_profile(method_state)
	var bonus := PREP_CHANCE * float(preparation) + float(profile.get("chance", 0.0))
	return breakthrough_chance(stats, tribulation_with(kills, karma, method_state), bonus, 0.0)


## Adds understanding. Returns true when the meter is full and an insight is
## due; the caller decides which insight and consumes the meter.
func add_comprehension(amount: float) -> bool:
	if amount <= 0.0:
		return false
	enlightenment_meter = minf(ENLIGHTENMENT_GOAL, enlightenment_meter + amount)
	return is_enlightenment_ready()


func is_enlightenment_ready() -> bool:
	return enlightenment_meter >= ENLIGHTENMENT_GOAL - 0.001


## Spends a full meter. Refused below the goal, so understanding is never lost
## to an unlucky moment with nothing eligible.
func take_enlightenment() -> bool:
	if not is_enlightenment_ready():
		return false
	enlightenment_meter = 0.0
	return true


## Banks one preparation. Payment (stones) is the caller's responsibility.
func prepare() -> bool:
	if preparation >= MAX_PREPARATION:
		return false
	preparation += 1
	return true


func breakthrough_chance(stats: StatBlock, trib_scale: float, resources: float = 0.0, environment: float = 0.0) -> float:
	var base := 0.62 - 0.055 * float(realm - 1)
	var control := clampf(Attributes.soft(float(stats.get_attr("wis")), 30.0) / 30.0 * 0.35, 0.0, 0.35)
	var insight := clampf(Attributes.soft(float(stats.get_attr("int")), 30.0) / 30.0 * 0.22, 0.0, 0.22)
	var chance := base + control + insight + resources + environment - trib_scale * 0.35
	return clampf(chance, 0.02, 0.97)


## Attempts the realm breakthrough at peak. Always consumes Qi and always costs
## something: success wounds, failure injures and can regress a sublevel.
func attempt_breakthrough(stats: StatBlock, generator: RandomNumberGenerator, kills: int = 0, karma: int = 0,
		method_state: Dictionary = {}, composure: float = 0.0) -> Dictionary:
	if not is_peak():
		return {"success": false, "reason": "not_at_peak", "chance": 0.0, "roll": 0.0}
	if not is_full(stats):
		return {"success": false, "reason": "qi_not_full", "chance": 0.0, "roll": 0.0}
	# The ladder has twelve rungs. Without this guard realm 12 would "advance"
	# into a realm that has no data and every formula would read defaults.
	if realm >= Realms.count():
		return {"success": false, "reason": "apex", "chance": 0.0, "roll": 0.0,
			"realm": realm, "sublevel": sublevel, "consequences": []}

	var profile := Methods.breakthrough_profile(method_id, method_state)
	# Preparation is read first, then consumed by the attempt itself: a win does
	# not refund it and a loss cannot be retried with the same bank.
	var prep_used := preparation
	var trib := tribulation_with(kills, karma, method_state)
	var harm := failure_harm(method_state)
	preparation = 0
	var bonus := PREP_CHANCE * float(prep_used) + float(profile.get("chance", 0.0)) + clampf(composure, 0.0, 1.0)
	var chance := breakthrough_chance(stats, trib, bonus, 0.0)
	var roll := generator.randf()
	var success := roll < chance
	var consequences: Array = []
	var hp_cost := 0.0

	breakthrough_attempts += 1

	if success:
		realm += 1
		sublevel = 1
		qi = 0.0
		hp_cost = clampf(trib * 0.15, 0.05, 0.4)
		consequences.append("tribulation_wounds")
		Bus.realm_advanced.emit(realm, sublevel)
	else:
		failures += 1
		hp_cost = clampf(0.35 * harm, 0.1, 0.6)
		qi = 0.0
		add_contamination(Meridians.DEVIATION_CONTAMINATION * harm)
		consequences.append("qi_deviation")
		if roll < chance * 0.35:
			consequences.append("meridian_damage")
		if roll < 0.08 * (1.0 - 0.25 * float(prep_used)) and realm > 1:
			consequences.append("realm_regression")
			realm = maxi(1, realm - 1)
			sublevel = maxi(1, SUBLEVELS - 2)
		sublevel = maxi(1, sublevel)

	var result := {
		"success": success,
		"chance": chance,
		"roll": roll,
		"tribulation_scale": trib,
		"consequences": consequences,
		"hp_cost_ratio": hp_cost,
		"realm": realm,
		"sublevel": sublevel,
		"reason": "",
		"preparation": prep_used,
		"method": method_id,
		"method_note": String(profile.get("note", "")),
		"unlocks": Realms.unlocks_at(realm) if success else [],
		"ability": Realms.ability_name(realm) if success else "",
	}
	Bus.breakthrough_resolved.emit(result)
	return result


## The playable encounter was lost. Heaven already answered, so this applies the
## failure fallout without a success roll; only the regression roll stays random.
func break_through_failure(generator: RandomNumberGenerator, kills: int = 0, karma: int = 0,
		method_state: Dictionary = {}) -> Dictionary:
	var profile := Methods.breakthrough_profile(method_id, method_state)
	var prep_used := preparation
	var harm := failure_harm(method_state)
	preparation = 0
	failures += 1
	qi = 0.0
	add_contamination(Meridians.DEVIATION_CONTAMINATION * harm)
	var hp_cost := clampf(0.35 * harm, 0.1, 0.6)
	var consequences := ["qi_deviation", "tribulation_broken"]
	if realm > 1 and generator != null and generator.randf() < 0.08 * (1.0 - 0.25 * float(prep_used)):
		consequences.append("realm_regression")
		realm = maxi(1, realm - 1)
		sublevel = maxi(1, SUBLEVELS - 2)
	var result := {
		"success": false,
		"broken": true,
		"chance": 0.0,
		"roll": 0.0,
		"tribulation_scale": tribulation_with(kills, karma, method_state),
		"consequences": consequences,
		"hp_cost_ratio": hp_cost,
		"realm": realm,
		"sublevel": sublevel,
		"reason": "",
		"preparation": prep_used,
		"method": method_id,
		"method_note": String(profile.get("note", "")),
		"unlocks": [],
		"ability": "",
	}
	Bus.breakthrough_resolved.emit(result)
	return result


func realm_name() -> String:
	return String(realm_data().get("name", "Unknown"))


func stage_label() -> String:
	return "%s %d" % [realm_name(), sublevel]


## Realm, sublevel and band: "Foundation Establishment 5 · Middle".
func stage_title() -> String:
	return Realms.stage_title(realm, sublevel)


func to_dict() -> Dictionary:
	return {
		"realm": realm,
		"sublevel": sublevel,
		"qi": qi,
		"root_tier": root_tier,
		"identified": identified,
		"purity_bonus": purity_bonus,
		"method_id": method_id,
		"method_insight": method_insight.duplicate(),
		"method_affixes": method_affixes.duplicate(),
		"secondary_method_id": secondary_method_id,
		"pair_affixes": pair_affixes.duplicate(),
		"blood_charge": blood_charge,
		"meridians": meridians.duplicate(),
		"contamination": contamination,
		"breakthrough_attempts": breakthrough_attempts,
		"failures": failures,
		"preparation": preparation,
		"enlightenment_meter": enlightenment_meter,
		"enlightenment_attempts": enlightenment_attempts,
	}


func from_dict(data: Dictionary) -> void:
	# Clamp to the ladder: a corrupt or outdated save must not index a realm that
	# does not exist, which would silently read every multiplier as a default.
	realm = clampi(int(data.get("realm", 1)), 1, maxi(1, Realms.count()))
	sublevel = clampi(int(data.get("sublevel", 1)), 1, SUBLEVELS)
	qi = float(data.get("qi", 0.0))
	root_tier = clampi(int(data.get("root_tier", 3)), 1, 12)
	# Legacy saves were played with a visible root, so they keep it appraised.
	identified = bool(data.get("identified", true))
	purity_bonus = clampf(float(data.get("purity_bonus", 0.0)), 0.0, Roots.PURITY_BONUS_MAX)
	method_id = String(data.get("method_id", "method.traditional"))
	method_insight = data.get("method_insight", {}).duplicate()
	method_affixes = data.get("method_affixes", {}).duplicate()
	secondary_method_id = String(data.get("secondary_method_id", ""))
	if not Methods.compatible(method_id, secondary_method_id):
		secondary_method_id = ""
	pair_affixes = data.get("pair_affixes", {}).duplicate()
	blood_charge = clampf(float(data.get("blood_charge", 0.0)), 0.0, 100.0)
	meridians = data.get("meridians", []).duplicate()
	contamination = clampf(float(data.get("contamination", 0.0)), 0.0, Meridians.MAX_CONTAMINATION)
	breakthrough_attempts = int(data.get("breakthrough_attempts", 0))
	failures = int(data.get("failures", 0))
	preparation = clampi(int(data.get("preparation", 0)), 0, MAX_PREPARATION)
	enlightenment_meter = clampf(float(data.get("enlightenment_meter", 0.0)), 0.0, ENLIGHTENMENT_GOAL)
	enlightenment_attempts = maxi(0, int(data.get("enlightenment_attempts", 0)))
