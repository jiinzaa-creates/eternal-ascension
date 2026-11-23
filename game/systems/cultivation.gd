class_name Cultivation
extends RefCounted
## Qi accumulation, sublevels, realms and breakthroughs.
##
## Power comes from two different places on purpose:
##   * sublevels are incremental (Qi, small attribute growth), and
##   * realms are qualitative (a multiplier plus a new system unlock).
## Realm gaps are meant to be lethal. Within a realm, technique and timing decide.

const SUBLEVELS := 10

var realm: int = 1
var sublevel: int = 1
var qi: float = 0.0
var root_tier: int = 3
## Appraisal state. The hidden purity bonus only applies once the root has been
## read; the tier's own purity always applies, so nothing is lost by not knowing.
var identified := false
var purity_bonus := 0.0
var method_id: String = "method.traditional"
var breakthrough_attempts: int = 0
var failures: int = 0


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


func base_qi() -> float:
	return 100.0 * float(realm_data().get("qi_mult", 1.0)) * (1.0 + 0.35 * float(sublevel - 1))


func qi_max(stats: StatBlock) -> float:
	return base_qi() * stats.max_qi_mult() * (0.75 + 0.5 * effective_purity()) + stats.qi_max_flat()


func qi_gain_per_sec(stats: StatBlock, environment: float = 1.0) -> float:
	return 4.0 * root_mult() * method_mult() * stats.cultivation_rate_mult() * maxf(environment, 0.0)


## Passive regeneration while not meditating. Small, but real: a wounded
## cultivator recovers between fights without sitting down.
func qi_regen_per_sec(stats: StatBlock) -> float:
	return (0.6 + Attributes.soft(float(stats.get_attr("wis")), 25.0) / 22.0) * effective_purity() * stats.qi_regen_mult() + stats.qi_regen_flat()


func regenerate(stats: StatBlock, delta: float) -> float:
	var cap := qi_max(stats)
	var before := qi
	qi = minf(cap, qi + qi_regen_per_sec(stats) * delta)
	return qi - before


## Meditating for `delta` seconds. Returns the Qi actually gained.
func cultivate(stats: StatBlock, delta: float, environment: float = 1.0) -> float:
	var cap := qi_max(stats)
	var before := qi
	qi = minf(cap, qi + qi_gain_per_sec(stats, environment) * delta)
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


func breakthrough_chance(stats: StatBlock, trib_scale: float, resources: float = 0.0, environment: float = 0.0) -> float:
	var base := 0.62 - 0.055 * float(realm - 1)
	var control := clampf(Attributes.soft(float(stats.get_attr("wis")), 30.0) / 30.0 * 0.35, 0.0, 0.35)
	var insight := clampf(Attributes.soft(float(stats.get_attr("int")), 30.0) / 30.0 * 0.22, 0.0, 0.22)
	var chance := base + control + insight + resources + environment - trib_scale * 0.35
	return clampf(chance, 0.02, 0.97)


## Attempts the realm breakthrough at peak. Always consumes Qi and always costs
## something: success wounds, failure injures and can regress a sublevel.
func attempt_breakthrough(stats: StatBlock, generator: RandomNumberGenerator, kills: int = 0, karma: int = 0) -> Dictionary:
	if not is_peak():
		return {"success": false, "reason": "not_at_peak", "chance": 0.0, "roll": 0.0}
	if not is_full(stats):
		return {"success": false, "reason": "qi_not_full", "chance": 0.0, "roll": 0.0}

	var trib := tribulation_scale(kills, karma)
	var chance := breakthrough_chance(stats, trib)
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
		hp_cost = 0.35
		qi = 0.0
		consequences.append("qi_deviation")
		if roll < chance * 0.35:
			consequences.append("meridian_damage")
		if roll < 0.08 and realm > 1:
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
	}
	Bus.breakthrough_resolved.emit(result)
	return result


func realm_name() -> String:
	return String(realm_data().get("name", "Unknown"))


func stage_label() -> String:
	return "%s %d" % [realm_name(), sublevel]


func to_dict() -> Dictionary:
	return {
		"realm": realm,
		"sublevel": sublevel,
		"qi": qi,
		"root_tier": root_tier,
		"identified": identified,
		"purity_bonus": purity_bonus,
		"method_id": method_id,
		"breakthrough_attempts": breakthrough_attempts,
		"failures": failures,
	}


func from_dict(data: Dictionary) -> void:
	realm = maxi(1, int(data.get("realm", 1)))
	sublevel = clampi(int(data.get("sublevel", 1)), 1, SUBLEVELS)
	qi = float(data.get("qi", 0.0))
	root_tier = clampi(int(data.get("root_tier", 3)), 1, 12)
	# Legacy saves were played with a visible root, so they keep it appraised.
	identified = bool(data.get("identified", true))
	purity_bonus = clampf(float(data.get("purity_bonus", 0.0)), 0.0, Roots.PURITY_BONUS_MAX)
	method_id = String(data.get("method_id", "method.traditional"))
	breakthrough_attempts = int(data.get("breakthrough_attempts", 0))
	failures = int(data.get("failures", 0))
