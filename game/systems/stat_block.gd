class_name StatBlock
extends RefCounted
## The single stat pipeline.
##
## Order, fixed and non-negotiable:
##   base attributes -> flat attribute bonuses (affixes/passives)
##   -> percentage modifiers (affixes/passives)
##   -> equipment base values (weapon damage, armour)
##   -> realm multiplier
##
## Nothing else in the game computes a derived stat. That is what lets hundreds
## of affixes, passives and 12 realms coexist without multiplying into nonsense.

const PERCENT_STATS: Array[String] = [
	"physical_damage_pct", "attack_speed_pct", "crit_chance", "qi_max_pct",
	"physical_resist", "move_speed_pct", "cult_speed_pct", "qi_regen_pct",
	"lightning_damage_pct",
	# Secondary stats. Percent values are points, not fractions: +8 means 8%.
	"evasion", "penetration", "cooldown_reduction", "crit_damage",
]
const FLAT_STATS: Array[String] = [
	"qi_regen_flat", "qi_max_flat", "armor", "weapon_damage", "lifesteal",
	"health_regen", "lifespan",
]

# Secondary stat caps. They exist so a stack of affixes cannot make a character
# untouchable, unkillable or infinitely long-lived.
const EVASION_CAP := 0.55
const PENETRATION_CAP := 0.6
const COOLDOWN_CAP := 0.5
const CRIT_DAMAGE_CAP := 3.0
const CRIT_DAMAGE_FLOOR := 1.2

var base: Attributes
var realm: int = 1
var realm_mult: float = 1.0
## The realm body (R4): a flat bonus to every attribute, derived
## from the realm multiplier at rebuild. A higher realm is a
## remade body, not only a bigger damage scalar.
var realm_body_bonus := 0

var flat_attrs: Dictionary = {}
var add_pct: Dictionary = {}
var flat_stats: Dictionary = {}
var passives: Array = []
var sources: Array = []
## Fraction of STR/DEX/AGI lost to old age, 0..0.9. Applied to the total of base
## and flat attributes so the raw sheet is never rewritten.
var aging_penalty: float = 0.0


func _init(base_attributes: Attributes = null) -> void:
	base = base_attributes if base_attributes != null else Attributes.new()
	reset()


func reset() -> void:
	flat_attrs.clear()
	for key in Attributes.KEYS:
		flat_attrs[key] = 0
	add_pct.clear()
	flat_stats.clear()
	passives.clear()
	sources.clear()


## Rebuilds every modifier from equipment and passives. Called whenever the
## player equips something, gains a passive, or advances a realm.
func rebuild(equipment: Dictionary, passive_ids: Array, realm_number: int, realm_attribute_mult: float,
		physique_id: String = "", meridian_mods: Array = [], realm_ability_mods: Array = [],
		enlightenment_mods: Array = [], aging: float = 0.0, transient_mods: Array = [], physique_stage: int = 0) -> void:
	reset()
	aging_penalty = clampf(aging, 0.0, 0.9)
	realm = realm_number
	realm_mult = realm_attribute_mult
	realm_body_bonus = int(round(maxf(0.0, realm_attribute_mult - 1.0) * 2.0))

	for slot in equipment.keys():
		var item: Dictionary = equipment[slot]
		if item.is_empty():
			continue
		flat_stats["weapon_damage"] = flat("weapon_damage") + float(item.get("base_damage", 0.0))
		flat_stats["armor"] = flat("armor") + float(item.get("armor", 0.0))
		apply_mods(item.get("mods", []), String(item.get("name", "item")))

	if physique_id != "":
		var physique: Dictionary = DB.physique(physique_id)
		if not physique.is_empty():
			# Gifts and weakness together, scaled by the awakening stage —
			# still the one mods path, never a physique-specific stat rule.
			apply_mods(Physiques.mods_for(physique_id, physique_stage, realm), String(physique.get("name", "physique")))

	for id in passive_ids:
		var passive: Dictionary = DB.by_id("passive", String(id))
		if passive.is_empty():
			continue
		passives.append(String(id))
		apply_mods(passive.get("mods", []), String(passive.get("name", "passive")))

	# The current realm's art. Only one applies at a time, so twelve sets of
	# mods can never stack; its behavioural flags are separate and cumulative.
	if not realm_ability_mods.is_empty():
		apply_mods(realm_ability_mods, "realm art")

	# Insights are permanent and cumulative, so unlike realm arts every learned
	# enlightenment contributes its mods here.
	if not enlightenment_mods.is_empty():
		apply_mods(enlightenment_mods, "enlightenment")

	if not meridian_mods.is_empty():
		apply_mods(meridian_mods, "meridians")

	# Synergies are bonus mods for pairs the host has already activated.
	var synergy: Array = Passives.synergy_mods(passive_ids)
	if not synergy.is_empty():
		apply_mods(synergy, "synergy")

	# Timed body arts (technique buffs) ride the same pipeline while they live.
	# The caller owns their clocks; the pipeline only sums their mods.
	if not transient_mods.is_empty():
		apply_mods(transient_mods, "body art")


func apply_mods(mods: Array, source_name: String = "") -> void:
	if mods.is_empty():
		return
	if source_name != "":
		sources.append(source_name)
	for mod in mods:
		var stat := String(mod.get("stat", ""))
		var value := float(mod.get("value", 0.0))
		if value == 0.0 or stat == "":
			continue
		if Attributes.KEYS.has(stat):
			flat_attrs[stat] = int(flat_attrs.get(stat, 0)) + int(value)
		elif PERCENT_STATS.has(stat):
			add_pct[stat] = float(add_pct.get(stat, 0.0)) + value
		elif FLAT_STATS.has(stat):
			flat_stats[stat] = float(flat_stats.get(stat, 0.0)) + value
		else:
			push_warning("[StatBlock] unknown modifier stat '%s' from %s" % [stat, source_name])


## Every derived number separates base from gear, then floors. Cursed modifiers
## can cripple a stat but must never invert it: negative movement walks backwards,
## negative Qi capacity divides by a negative, negative armour becomes mitigation.
static func factor(percent: float) -> float:
	return maxf(0.0, 1.0 + percent / 100.0)


func get_attr(key: String) -> int:
	var raw := maxi(0, base.get_attr(key) + int(flat_attrs.get(key, 0)) + realm_body_bonus)
	if aging_penalty > 0.0 and Aging.AGING_KEYS.has(key):
		return int(round(float(raw) * (1.0 - aging_penalty)))
	return raw


func attr_bonus(key: String) -> int:
	return int(flat_attrs.get(key, 0)) + realm_body_bonus


func pct(key: String) -> float:
	return float(add_pct.get(key, 0.0))


func flat(key: String) -> float:
	return float(flat_stats.get(key, 0.0))


# --- combat -----------------------------------------------------------------

func physical_mult() -> float:
	return maxf(0.05, (1.0 + Attributes.soft(float(get_attr("str")), 22.0) / 22.0) \
		* factor(pct("physical_damage_pct")) * maxf(0.0, realm_mult))


func weapon_damage() -> float:
	return maxf(0.0, flat("weapon_damage"))


func armor() -> float:
	return maxf(0.0, flat("armor"))


func accuracy() -> float:
	return clampf(0.78 + 0.22 * (1.0 - exp(-float(get_attr("dex")) / 45.0)), 0.0, 1.0)


func crit_chance() -> float:
	var curve := 1.0 - exp(-(float(get_attr("dex")) * 0.45) / 130.0)
	return clampf(curve + pct("crit_chance") / 100.0, 0.0, 0.95)


func physical_resist() -> float:
	return clampf(Attributes.soft(float(get_attr("str")), 40.0) / 40.0 * 0.35 + pct("physical_resist") / 100.0, 0.0, 0.85)


func carry_slots() -> int:
	return 8 + int(Attributes.soft(float(get_attr("str")), 15.0) / 3.0)


func lifesteal() -> float:
	return clampf(flat("lifesteal"), 0.0, 0.5)


# --- secondary stats ----------------------------------------------------------

## Chance to avoid a physical hit entirely. Rolled by the victim, never by the
## attacker, so one evasion stat cannot double-dip.
func evasion_chance() -> float:
	var curve := (1.0 - exp(-float(get_attr("agi")) / 70.0)) * 0.32
	return clampf(curve + pct("evasion") / 100.0, 0.0, EVASION_CAP)


## Pure decision helper: strict less-than keeps a 0% evasion character from ever
## evading a roll of exactly 0.0.
func evades(roll: float) -> bool:
	return roll >= 0.0 and roll < evasion_chance()


## Fraction of a target's armour ignored. Capped below 1 so armour always means
## something, even against a dedicated piercer.
func penetration_fraction() -> float:
	return clampf(Attributes.soft(float(get_attr("dex")), 45.0) / 45.0 * 0.25 + pct("penetration") / 100.0, 0.0, PENETRATION_CAP)


func cooldown_reduction() -> float:
	return clampf(Attributes.soft(float(get_attr("agi")), 40.0) / 40.0 * 0.15 + pct("cooldown_reduction") / 100.0, 0.0, COOLDOWN_CAP)


## Critical damage multiplier. The DEX curve alone lands near the old 1.8 at
## DEX 10, so existing combat numbers do not silently change.
func crit_multiplier() -> float:
	return clampf(1.7 + Attributes.soft(float(get_attr("dex")), 30.0) / 30.0 * 0.35 + pct("crit_damage") / 100.0,
		CRIT_DAMAGE_FLOOR, CRIT_DAMAGE_CAP)


## Health per second, only while out of combat (the player enforces that).
func health_regen() -> float:
	return maxf(0.0, 0.35 + Attributes.soft(float(get_attr("wis")), 30.0) / 30.0 * 0.9 + flat("health_regen"))


## Years the current realm allows, before any longevity bonus. Realm 12 declares
## lifespan 0, which means "no limit".
func base_lifespan_years() -> int:
	return Realms.lifespan(realm)


func lifespan_bonus() -> int:
	return maxi(0, int(Attributes.soft(float(get_attr("wis")), 40.0) / 40.0 * 25.0) + int(flat("lifespan")))


## Total lifespan in years; 0 means unbounded.
func lifespan_years() -> int:
	var base := base_lifespan_years()
	if base <= 0:
		return 0
	return base + lifespan_bonus()


# --- mobility ---------------------------------------------------------------

func move_speed() -> float:
	return maxf(24.0, 96.0 * (1.0 + Attributes.soft(float(get_attr("agi")), 15.0) / 55.0) \
		* factor(pct("move_speed_pct")))


func attack_speed() -> float:
	return maxf(0.2, (1.0 + Attributes.soft(float(get_attr("agi")), 18.0) / 45.0) \
		* factor(pct("attack_speed_pct")))


func dodge_bonus_frames() -> int:
	return int(Attributes.soft(float(get_attr("agi")), 20.0) / 8.0)


func recovery_reduction() -> float:
	return minf(0.35, Attributes.soft(float(get_attr("agi")), 30.0) / 30.0 * 0.4)


# --- cultivation ------------------------------------------------------------

func max_qi_mult() -> float:
	return maxf(0.1, (1.0 + Attributes.soft(float(get_attr("wis")), 30.0) / 48.0) \
		* factor(pct("qi_max_pct")))


func qi_max_flat() -> float:
	return flat("qi_max_flat")


func qi_regen_mult() -> float:
	return maxf(0.0, 1.0 + Attributes.soft(float(get_attr("wis")), 25.0) / 60.0 + pct("qi_regen_pct") / 100.0)


func qi_regen_flat() -> float:
	return flat("qi_regen_flat")


func cultivation_rate_mult() -> float:
	return maxf(0.05, (1.0 + Attributes.soft(float(get_attr("wis")), 40.0) / 70.0) \
		* factor(pct("cult_speed_pct")))


func comprehension_mult() -> float:
	return maxf(0.1, 1.0 + Attributes.soft(float(get_attr("int")), 25.0) / 25.0)


func crafting_quality_mult() -> float:
	return maxf(0.1, 1.0 + Attributes.soft(float(get_attr("int")), 30.0) / 30.0)


func mental_resist() -> float:
	return Attributes.soft(float(get_attr("wis")), 35.0) / 35.0 * 0.5


# --- social -----------------------------------------------------------------

func social_score(reputation_tier: int = 0, sect_rank: int = 0) -> float:
	return Attributes.soft(float(get_attr("char")), 25.0) + float(reputation_tier) * 4.0 + float(sect_rank) * 2.0


func party_slots() -> int:
	return 3 + int(Attributes.soft(float(get_attr("char")), 40.0) / 18.0)


func derived() -> Dictionary:
	return {
		"move_speed": move_speed(),
		"attack_speed": attack_speed(),
		"physical_mult": physical_mult(),
		"accuracy": accuracy(),
		"crit_chance": crit_chance(),
		"physical_resist": physical_resist(),
		"armor": armor(),
		"weapon_damage": weapon_damage(),
		"max_qi_mult": max_qi_mult(),
		"qi_regen_mult": qi_regen_mult(),
		"cultivation_rate_mult": cultivation_rate_mult(),
		"comprehension_mult": comprehension_mult(),
		"mental_resist": mental_resist(),
		"party_slots": party_slots(),
		"carry_slots": carry_slots(),
		"evasion": evasion_chance(),
		"penetration": penetration_fraction(),
		"cooldown_reduction": cooldown_reduction(),
		"crit_multiplier": crit_multiplier(),
		"health_regen": health_regen(),
		"lifespan": lifespan_years(),
	}


func summary() -> String:
	var parts: Array[String] = []
	for key in Attributes.KEYS:
		var bonus := attr_bonus(key)
		if bonus == 0:
			parts.append("%s %d" % [Attributes.LABELS[key], get_attr(key)])
		else:
			parts.append("%s %d (%+d)" % [Attributes.LABELS[key], get_attr(key), bonus])
	return "  ".join(parts)
