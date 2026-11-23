extends Node
## Headless unit suite.
##
##   godot --headless --path game res://tests/run_tests.tscn
##
## Exercises the real content database, the real stat pipeline, the real chunk
## streamer, the real quest machine and the real save code. Exit code 0 only
## when every check passes.

var _pass := 0
var _fail := 0
var _failures: Array = []


func _ready() -> void:
	print("=== Eternal Ascension — headless test suite ===")
	_log_tests()
	_db_tests()
	_attribute_tests()
	_stat_pipeline_tests()
	_extreme_tests()
	_secondary_tests()
	_root_system_tests()
	_physique_tests()
	_passive_system_tests()
	_technique_mastery_tests()
	_method_tests()
	_qi_meridian_tests()
	_realm_tests()
	_breakthrough_tests()
	_rng_tests()
	_item_tests()
	_cultivation_tests()
	_combat_tests()
	_world_tests()
	_chunk_delta_tests()
	_continent_tests()
	_biome_tests()
	_economy_tests()
	_location_tests()
	_travel_tests()
	_simulation_tests()
	_origin_tests()
	_camera_tests()
	_display_tests()
	_lighting_tests()
	_occlusion_tests()
	_sorting_tests()
	_motion_tests()
	_controller_tests()
	_animation_tests()
	_interaction_tests()
	_climate_tests()
	_npc_tests()
	_quest_tests()
	_hidden_realm_tests()
	_save_tests()
	print("-----------------------------------------------")
	print("RESULT: PASS %d / FAIL %d" % [_pass, _fail])
	for failure in _failures:
		print("  FAILED: " + String(failure))
	get_tree().quit(1 if _fail > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
	else:
		_fail += 1
		_failures.append(label)
		push_error("FAIL: " + label)


func approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


# ------------------------------------------------------------------- log ----

func _log_tests() -> void:
	print("[log] structured logging")
	Log.silent = true
	Log.clear()
	Log.debug("test", "debug line")
	Log.info("test", "info line")
	Log.warn("test", "warn line")
	Log.error("test", "error line")
	check(Log.count() == 4, "every level records into the buffer")
	check(Log.count(Log.Level.WARN) == 1, "counts filter by exact level")
	check(Log.count(Log.Level.WARN, true) == 2, "level-or-above counting works")
	check(Log.count_for(Log.Level.ERROR, "test") == 1, "counts filter by category")
	check(Log.dump().contains("error line"), "dump exposes recorded messages")
	check(Log.recent(2).size() == 2, "recent returns the requested window")

	for i in Log.MAX_ENTRIES + 25:
		Log.info("flood", "entry %d" % i)
	check(Log.entries.size() == Log.MAX_ENTRIES, "buffer stays bounded at %d entries" % Log.MAX_ENTRIES)
	check(String(Log.entries[Log.entries.size() - 1]["message"]).begins_with("entry"), "newest entries survive trimming")

	Log.clear()
	Log.silent = false
	check(Log.count() == 0, "log buffer can be cleared")


# ---------------------------------------------------------------- content ----

func _db_tests() -> void:
	print("[db] validating content")
	var problems: Array = DB.validate()
	for problem in problems:
		print("   problem: " + String(problem))
	check(problems.is_empty(), "content validates without problems")
	check(DB.counts()["realms"] == 12, "12 realms loaded")
	check(DB.counts()["roots"] == 12, "12 roots loaded")
	check(DB.counts()["techniques"] >= 6, "at least 6 techniques loaded")
	check(DB.counts()["passives"] >= 8, "passives loaded")
	check(DB.counts()["quests"] >= 1, "quests loaded")
	check(DB.counts()["archetypes"] >= 5, "npc archetypes loaded")
	check(not DB.passive("passive.iron_bone").is_empty(), "passive lookup by stable id works")
	check(not DB.quest("quest.azure_cloud.initiation").is_empty(), "quest lookup by stable id works")
	check(DB.technique("tech.does.not.exist").is_empty(), "unknown id returns empty, not a crash")
	var hidden_count := 0
	for tech in DB.techniques:
		if bool(tech.get("hidden", false)):
			hidden_count += 1
	check(hidden_count >= 2, "some techniques are discovery-only")


# ------------------------------------------------------------- attributes ----

func _attribute_tests() -> void:
	print("[attributes] saturation, cost curve, allocation")
	check(Attributes.soft(10.0, 20.0) < Attributes.soft(20.0, 20.0), "soft gains are monotonic")
	check(Attributes.soft(100000.0, 20.0) > Attributes.soft(10000.0, 20.0), "no hard cap on attribute effect")
	var gain_first := Attributes.soft(20.0, 20.0) - Attributes.soft(10.0, 20.0)
	var gain_later := Attributes.soft(30.0, 20.0) - Attributes.soft(20.0, 20.0)
	check(gain_first > gain_later, "diminishing returns on later points")
	check(Attributes.attr_cost(60) > Attributes.attr_cost(10) * 3, "attribute cost grows steeply")

	var attrs := Attributes.new()
	attrs.add("str", 4)
	check(attrs.get_attr("str") == 14, "allocation adds to an attribute")
	var restored := Attributes.new()
	restored.from_dict(attrs.to_dict())
	check(restored.get_attr("str") == 14, "attributes round-trip through a save dictionary")
	check(Attributes.KEYS.size() == 6, "six primary attributes")


# ----------------------------------------------------------- stat pipeline ----

func _stat_pipeline_tests() -> void:
	print("[stats] affixes, passives, equipment and realm feed one pipeline")
	var attrs := Attributes.new()
	var bare := StatBlock.new(attrs)
	bare.rebuild({}, [], 1, 1.0)

	check(bare.get_attr("str") == 10, "bare stats expose base attributes")
	check(bare.weapon_damage() == 0.0, "unarmed means no weapon damage")
	check(bare.armor() == 0.0, "no armour means no armour")

	var weapon := {
		"name": "Test Saber", "slot": "weapon", "base_damage": 12.0, "armor": 0.0,
		"mods": [
			{"stat": "physical_damage_pct", "value": 25.0},
			{"stat": "str", "value": 4},
		],
	}
	var armor_item := {
		"name": "Test Robe", "slot": "armor", "base_damage": 0.0, "armor": 9.0,
		"mods": [{"stat": "physical_resist", "value": 6.0}, {"stat": "qi_max_pct", "value": 10.0}],
	}
	var geared := StatBlock.new(attrs)
	geared.rebuild({"weapon": weapon, "armor": armor_item}, [], 1, 1.0)

	check(geared.weapon_damage() == 12.0, "equipped weapon supplies base damage")
	check(geared.armor() == 9.0, "equipped armour supplies armour")
	check(geared.get_attr("str") == 14, "affix flat attribute bonus applies")
	check(geared.physical_mult() > bare.physical_mult() * 1.2, "physical damage affix multiplies damage")
	check(geared.physical_resist() > bare.physical_resist(), "resistance affix applies")
	check(geared.max_qi_mult() > bare.max_qi_mult(), "Qi affix applies")

	var crit_gear := StatBlock.new(attrs)
	crit_gear.rebuild({"ring": {"name": "Crit Ring", "slot": "ring", "base_damage": 0.0, "armor": 0.0,
		"mods": [{"stat": "crit_chance", "value": 7.0}]}}, [], 1, 1.0)
	check(crit_gear.crit_chance() > bare.crit_chance(), "crit affix raises crit chance")

	var passive_stats := StatBlock.new(attrs)
	passive_stats.rebuild({}, ["passive.iron_bone"], 1, 1.0)
	check(passive_stats.get_attr("str") == 13, "passive flat attribute applies")
	check(passive_stats.physical_resist() > bare.physical_resist(), "passive resistance applies")
	check(passive_stats.passives.has("passive.iron_bone"), "applied passives are recorded")

	var realm_stats := StatBlock.new(attrs)
	realm_stats.rebuild({}, [], 3, 1.8)
	check(realm_stats.physical_mult() > bare.physical_mult() * 1.7, "realm multiplier scales power")

	var movement := StatBlock.new(attrs)
	movement.rebuild({"talisman": {"name": "Wind Charm", "slot": "talisman", "base_damage": 0.0, "armor": 0.0,
		"mods": [{"stat": "move_speed_pct", "value": 9.0}]}}, [], 1, 1.0)
	check(movement.move_speed() > bare.move_speed(), "movement affix raises speed")

	var unknown := StatBlock.new(attrs)
	unknown.rebuild({"ring": {"name": "Odd", "slot": "ring", "base_damage": 0.0, "armor": 0.0,
		"mods": [{"stat": "not_a_stat", "value": 5.0}]}}, [], 1, 1.0)
	check(true, "unknown modifier stats are ignored with a warning, not a crash")


# -------------------------------------------------------------------- rng ----

# ---------------------------------------------------------------- extremes ----

func _extreme_tests() -> void:
	print("[extremes] cursed gear, absurd values and cross-attribute interactions")
	var weak := Attributes.new()
	for key in Attributes.KEYS:
		weak.add(key, -50)
		check(weak.get_attr(key) == 0, "%s floors at zero" % key)

	var restored := Attributes.new()
	restored.from_dict({"str": -40, "wis": -1, "agi": 999999})
	check(restored.get_attr("str") == 0 and restored.get_attr("wis") == 0, "negative saved attributes are clamped")
	check(restored.get_attr("agi") == 999999, "huge saved attributes survive")

	check(Attributes.attr_cost(10000) > 0, "absurd attribute levels still cost something")
	check(Attributes.attr_cost(10000) <= 9223372036854775807, "attribute cost cannot overflow")
	check(Attributes.attr_cost(0) == Attributes.attr_cost(1), "cost is flat at the first level")
	check(Attributes.soft(-10.0, 20.0) == 0.0, "negative attributes contribute nothing")

	# Cursed gear: every derived number must stay usable.
	var cursed := StatBlock.new(Attributes.new())
	cursed.rebuild({"weapon": {
		"name": "cursed", "base_damage": -500.0, "armor": -500.0,
		"mods": [
			{"stat": "move_speed_pct", "value": -500.0},
			{"stat": "attack_speed_pct", "value": -500.0},
			{"stat": "physical_damage_pct", "value": -500.0},
			{"stat": "qi_max_pct", "value": -500.0},
			{"stat": "qi_regen_pct", "value": -500.0},
			{"stat": "cult_speed_pct", "value": -500.0},
			{"stat": "crit_chance", "value": -500.0},
			{"stat": "physical_resist", "value": -500.0},
			{"stat": "str", "value": -100},
		],
	}}, [], 1, 1.0)
	check(cursed.get_attr("str") == 0, "cursed gear floors attributes")
	check(cursed.move_speed() >= 24.0, "cursed gear cannot reverse movement")
	check(cursed.attack_speed() >= 0.2, "cursed gear cannot stop attacks")
	check(cursed.physical_mult() >= 0.05, "cursed gear cannot invert damage")
	check(cursed.max_qi_mult() >= 0.1, "cursed gear cannot erase Qi")
	check(cursed.qi_regen_mult() >= 0.0, "cursed gear cannot make regen negative")
	check(cursed.cultivation_rate_mult() >= 0.05, "cursed gear cannot stop cultivation")
	check(cursed.crit_chance() == 0.0, "cursed gear zeroes crit rather than going negative")
	check(cursed.physical_resist() == 0.0, "cursed gear cannot amplify damage through resistance")
	check(cursed.weapon_damage() == 0.0 and cursed.armor() == 0.0, "negative equipment values floor at zero")
	check(approx(Damage.mitigate_armor(100.0, -500.0), 100.0), "negative armour cannot become mitigation")
	check(approx(Damage.mitigate_armor(100.0, -30.0), 100.0), "mild negative armour is no armour")

	var finite := true
	var cursed_stats := cursed.derived()
	for key in cursed_stats.keys():
		var value := float(cursed_stats[key])
		if is_nan(value) or is_inf(value):
			finite = false
	check(finite, "every derived stat is finite under cursed gear")

	# Absurd positive values: saturate, never overflow.
	var huge := Attributes.new()
	for key in Attributes.KEYS:
		huge.add(key, 1000000)
	var god := StatBlock.new(huge)
	god.rebuild({}, [], 12, float(DB.realm(12).get("attr_mult", 1.0)))
	var god_finite := true
	var god_stats := god.derived()
	for key in god_stats.keys():
		var value := float(god_stats[key])
		if is_nan(value) or is_inf(value):
			god_finite = false
	check(god_finite, "a million points in every attribute stays finite")
	check(god.crit_chance() <= 0.95, "crit chance caps below certainty")
	check(god.lifesteal() <= 0.5, "lifesteal caps")
	check(god.recovery_reduction() <= 0.35, "recovery reduction caps")
	check(god.physical_resist() <= 0.85, "resistance caps")
	check(god.accuracy() <= 1.0, "accuracy caps at certainty")

	# Cross-interactions: each attribute owns its own axis.
	var plain := Attributes.new()
	var stats := StatBlock.new(plain)
	stats.rebuild({}, [], 1, 1.0)

	var str_only := Attributes.new()
	str_only.add("str", 40)
	var s := StatBlock.new(str_only)
	s.rebuild({}, [], 1, 1.0)
	check(s.physical_mult() > stats.physical_mult(), "STR raises physical damage")
	check(s.max_qi_mult() == stats.max_qi_mult(), "STR leaves Qi capacity alone")
	check(s.accuracy() == stats.accuracy(), "STR leaves accuracy alone")

	var wis_only := Attributes.new()
	wis_only.add("wis", 40)
	var w := StatBlock.new(wis_only)
	w.rebuild({}, [], 1, 1.0)
	check(w.max_qi_mult() > stats.max_qi_mult(), "WIS raises Qi capacity")
	check(w.qi_regen_mult() > stats.qi_regen_mult(), "WIS raises Qi regeneration")
	check(w.physical_mult() == stats.physical_mult(), "WIS leaves physical damage alone")

	var int_only := Attributes.new()
	int_only.add("int", 40)
	var intel := StatBlock.new(int_only)
	intel.rebuild({}, [], 1, 1.0)
	check(intel.comprehension_mult() > stats.comprehension_mult(), "INT raises comprehension")
	check(intel.crafting_quality_mult() > stats.crafting_quality_mult(), "INT raises crafting quality")
	check(intel.physical_mult() == stats.physical_mult(), "INT leaves physical damage alone")

	var agi_only := Attributes.new()
	agi_only.add("agi", 40)
	var agi := StatBlock.new(agi_only)
	agi.rebuild({}, [], 1, 1.0)
	check(agi.move_speed() > stats.move_speed() and agi.attack_speed() > stats.attack_speed(), "AGI raises speed")
	check(agi.dodge_bonus_frames() > stats.dodge_bonus_frames(), "AGI raises dodge frames")
	check(agi.physical_mult() == stats.physical_mult(), "AGI leaves physical damage alone")

	var dex_only := Attributes.new()
	dex_only.add("dex", 40)
	var dex := StatBlock.new(dex_only)
	dex.rebuild({}, [], 1, 1.0)
	check(dex.accuracy() > stats.accuracy(), "DEX raises accuracy")
	check(dex.crit_chance() > stats.crit_chance(), "DEX raises crit chance")
	check(dex.move_speed() == stats.move_speed(), "DEX leaves movement alone")

	var cha_only := Attributes.new()
	cha_only.add("char", 40)
	var cha := StatBlock.new(cha_only)
	cha.rebuild({}, [], 1, 1.0)
	check(cha.party_slots() > stats.party_slots(), "CHA raises party slots")
	check(cha.social_score(0, 0) > stats.social_score(0, 0), "CHA raises social score")
	check(cha.social_score(2, 1) > cha.social_score(0, 0), "reputation and rank add to social score")

	# Equipment flat attributes feed the same formulas, and realm multiplies once.
	var equipped := StatBlock.new(Attributes.new())
	equipped.rebuild({"ring": {"name": "test ring", "mods": [{"stat": "str", "value": 10}]}}, [], 1, 1.0)
	check(equipped.get_attr("str") == 20, "equipment adds flat attributes")
	check(equipped.physical_mult() > stats.physical_mult(), "equipment STR feeds the damage formula")

	var realm_two := StatBlock.new(Attributes.new())
	realm_two.rebuild({}, [], 1, 2.0)
	check(approx(realm_two.physical_mult(), stats.physical_mult() * 2.0), "realm multiplier applies once, multiplicatively")
	check(realm_two.crit_chance() == stats.crit_chance(), "realm does not change crit chance")


# -------------------------------------------------------------- secondary ----

func _secondary_tests() -> void:
	print("[secondary] evasion, penetration, cooldown, crit damage, regen, lifespan")
	var plain := StatBlock.new(Attributes.new())
	plain.rebuild({}, [], 1, 1.0)
	check(plain.evasion_chance() > 0.0 and plain.evasion_chance() < 0.1, "base evasion is small but real")
	check(plain.penetration_fraction() > 0.0, "base penetration is positive")
	check(plain.cooldown_reduction() > 0.0, "base cooldown reduction is positive")
	check(absf(plain.crit_multiplier() - 1.8) < 0.02, "base crit damage matches the old constant")
	check(plain.health_regen() > 0.0, "base health regen is positive")
	check(plain.base_lifespan_years() == 120, "realm one lifespan comes from data")
	check(plain.lifespan_years() >= 120, "a starting cultivator has years left")

	check(plain.evades(0.0), "a zero roll evades")
	check(not plain.evades(1.0), "a certain roll never evades")
	check(not plain.evades(plain.evasion_chance()), "the threshold itself is a hit")

	var agi := Attributes.new()
	agi.add("agi", 60)
	var agile := StatBlock.new(agi)
	agile.rebuild({}, [], 1, 1.0)
	check(agile.evasion_chance() > plain.evasion_chance(), "AGI raises evasion")
	check(agile.cooldown_reduction() > plain.cooldown_reduction(), "AGI lowers cooldowns")
	check(agile.crit_multiplier() == plain.crit_multiplier(), "AGI does not change crit damage")

	var dex := Attributes.new()
	dex.add("dex", 60)
	var precise := StatBlock.new(dex)
	precise.rebuild({}, [], 1, 1.0)
	check(precise.penetration_fraction() > plain.penetration_fraction(), "DEX raises penetration")
	check(precise.crit_multiplier() > plain.crit_multiplier(), "DEX raises crit damage")
	check(precise.evasion_chance() == plain.evasion_chance(), "DEX leaves evasion alone")

	var wis := Attributes.new()
	wis.add("wis", 60)
	var serene := StatBlock.new(wis)
	serene.rebuild({}, [], 1, 1.0)
	check(serene.health_regen() > plain.health_regen(), "WIS raises health regen")
	check(serene.lifespan_bonus() > plain.lifespan_bonus(), "WIS extends lifespan")
	check(serene.lifespan_years() > plain.lifespan_years(), "WIS raises total lifespan")

	var capped := StatBlock.new(Attributes.new())
	capped.rebuild({"ring": {"name": "capped", "mods": [
		{"stat": "evasion", "value": 500}, {"stat": "penetration", "value": 500},
		{"stat": "cooldown_reduction", "value": 500}, {"stat": "crit_damage", "value": 500},
		{"stat": "lifespan", "value": 25},
	]}}, [], 1, 1.0)
	check(capped.evasion_chance() == StatBlock.EVASION_CAP, "evasion caps")
	check(capped.penetration_fraction() == StatBlock.PENETRATION_CAP, "penetration caps")
	check(capped.cooldown_reduction() == StatBlock.COOLDOWN_CAP, "cooldown reduction caps")
	check(capped.crit_multiplier() == StatBlock.CRIT_DAMAGE_CAP, "crit damage caps")
	check(capped.lifespan_years() == plain.lifespan_years() + 25, "lifespan modifiers add years")

	var cursed := StatBlock.new(Attributes.new())
	cursed.rebuild({"ring": {"name": "cursed", "mods": [
		{"stat": "evasion", "value": -500}, {"stat": "penetration", "value": -500},
		{"stat": "cooldown_reduction", "value": -500}, {"stat": "crit_damage", "value": -500},
		{"stat": "health_regen", "value": -100}, {"stat": "lifespan", "value": -500},
	]}}, [], 1, 1.0)
	check(cursed.evasion_chance() == 0.0 and cursed.penetration_fraction() == 0.0, "cursed gear cannot push secondary stats negative")
	check(cursed.cooldown_reduction() == 0.0, "cursed gear cannot slow attacks below normal")
	check(cursed.crit_multiplier() == StatBlock.CRIT_DAMAGE_FLOOR, "cursed gear floors crit damage")
	check(cursed.health_regen() == 0.0, "cursed gear can stop regen but not reverse it")
	check(cursed.lifespan_bonus() == 0, "cursed gear cannot shorten lifespan below the realm's")

	var immortal := StatBlock.new(Attributes.new())
	immortal.rebuild({}, [], 12, 1.0)
	check(immortal.lifespan_years() == 0, "realm twelve has no lifespan limit")

	var derived := plain.derived()
	check(derived.has("evasion") and derived.has("penetration") and derived.has("cooldown_reduction"), "derived exposes the secondary stats")
	check(derived.has("crit_multiplier") and derived.has("health_regen") and derived.has("lifespan"), "derived exposes survival stats")


# ---------------------------------------------------------------- roots ----

func _root_system_tests() -> void:
	print("[roots] appraisal, hidden purity, marrow and evolution")
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3
	cultivation.purity_bonus = 0.2
	cultivation.identified = false
	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var base_purity := float(cultivation.root_data().get("purity", 0.55))
	check(approx(cultivation.effective_purity(), base_purity), "an unread root uses only its base purity")
	var unread_qi := cultivation.qi_max(stats)
	var unread_regen := cultivation.qi_regen_per_sec(stats)
	cultivation.identified = true
	check(approx(cultivation.effective_purity(), minf(1.0, base_purity + 0.2)), "a read root adds its hidden purity")
	check(cultivation.qi_max(stats) >= unread_qi, "reading a root never lowers Qi capacity")
	check(cultivation.qi_regen_per_sec(stats) > unread_regen, "reading a root never lowers Qi regeneration")

	var evolved := Cultivation.new()
	evolved.root_tier = 2
	var before := evolved.root_mult()
	evolved.root_tier = 3
	check(evolved.root_mult() > before, "a higher tier multiplies cultivation more")

	check(Roots.evolve_cost(3) > Roots.evolve_cost(2), "evolution costs more at higher tiers")
	var blocked := Roots.can_evolve(Roots.MAX_TIER, 5, 999999)
	check(not bool(blocked["ok"]) and String(blocked["reason"]) == "max_tier", "the twelfth tier cannot evolve")
	blocked = Roots.can_evolve(3, 0, 999999)
	check(not bool(blocked["ok"]) and String(blocked["reason"]) == "no_marrow", "evolution needs marrow")
	blocked = Roots.can_evolve(3, 1, 0)
	check(not bool(blocked["ok"]) and String(blocked["reason"]) == "no_stones", "evolution needs stones")
	var allowed := Roots.can_evolve(3, 1, Roots.evolve_cost(3))
	check(bool(allowed["ok"]) and int(allowed["cost"]) == Roots.evolve_cost(3), "marrow and stones allow evolution")

	var purity_a := Roots.roll_purity_bonus(42)
	check(approx(purity_a, Roots.roll_purity_bonus(42)), "purity rolls are deterministic")
	check(purity_a >= 0.0 and purity_a <= Roots.PURITY_BONUS_MAX, "purity rolls stay in range")

	check(Roots.marrow_found(Vector2i(4, 9), "mine") == Roots.marrow_found(Vector2i(4, 9), "mine"), "marrow drops are deterministic per site")
	var hits := 0
	for x in 20:
		for y in 15:
			if Roots.marrow_found(Vector2i(x, y), "mine"):
				hits += 1
	var ratio := float(hits) / 300.0
	check(ratio > 0.15 and ratio < 0.6, "marrow is findable but not everywhere (%.2f)" % ratio)

	check(Roots.purity_label(1.0) == "flawless", "purity reads as a word")
	check(Roots.purity_label(0.0) == "muddy", "low purity reads as muddy")
	check(Roots.affinity_text(cultivation.root_data()) != "", "affinities are listed")
	check(Roots.describe(cultivation.root_data(), 0.9).contains(String(cultivation.root_data().get("name", ""))), "a root describes itself")

	var round_trip := Cultivation.new()
	round_trip.identified = false
	round_trip.purity_bonus = 0.11
	var data := round_trip.to_dict()
	var loaded := Cultivation.new()
	loaded.from_dict(data)
	check(not loaded.identified and approx(loaded.purity_bonus, 0.11), "appraisal state survives a save")
	var legacy := Cultivation.new()
	legacy.from_dict({"realm": 2, "root_tier": 4})
	check(legacy.identified, "legacy saves keep the root they were played with")
	check(legacy.purity_bonus == 0.0, "legacy saves add no hidden purity")
	var wild := Cultivation.new()
	wild.from_dict({"purity_bonus": 9.0})
	check(wild.purity_bonus == Roots.PURITY_BONUS_MAX, "a wild purity bonus is clamped")


# ------------------------------------------------------------- physiques ----

func _physique_tests() -> void:
	print("[physiques] rolls, stat effects and inheritance")
	check(DB.physiques.size() >= 6, "at least six physiques exist (%d)" % DB.physiques.size())
	var seen := {}
	var known_stats: Array = []
	known_stats.append_array(Attributes.KEYS)
	known_stats.append_array(StatBlock.PERCENT_STATS)
	known_stats.append_array(StatBlock.FLAT_STATS)
	for entry in DB.physiques:
		var id := String(entry.get("id", ""))
		seen[id] = true
		check(id != "" and String(entry.get("name", "")) != "", "every physique is named")
		check(int(entry.get("tier", 0)) >= 1 and int(entry.get("tier", 0)) <= Physiques.MAX_TIER, "%s has a valid tier" % id)
		for mod in entry.get("mods", []):
			check(known_stats.has(String(mod.get("stat", ""))), "%s uses a known stat (%s)" % [id, String(mod.get("stat", ""))])
	check(seen.size() == DB.physiques.size(), "physique ids are unique")
	check(not Physiques.find("physique.mortal_frame").is_empty(), "physiques are indexed by id")

	var first := Physiques.roll(7)
	check(first != "" and not Physiques.find(first).is_empty(), "a roll returns a real physique")
	check(Physiques.roll(7) == first, "rolls are deterministic")
	var tiers := {}
	for key in 120:
		tiers[Physiques.tier_of(Physiques.roll(key))] = true
	check(tiers.size() >= 3, "rolls reach several tiers (%d)" % tiers.size())

	check(Physiques.tier_of("physique.chaotic_embryo") > Physiques.tier_of("physique.iron_bone"), "tiers are ordered")
	check(Physiques.best_of("physique.iron_bone", "physique.sword_bone") == "physique.sword_bone", "a better body wins")
	check(Physiques.best_of("physique.sword_bone", "physique.iron_bone") == "physique.sword_bone", "a worse body is rejected")
	check(Physiques.best_of("physique.iron_bone", "physique.iron_bone") == "physique.iron_bone", "a tie keeps the current body")
	check(not Physiques.describe("physique.iron_bone").is_empty(), "physiques describe themselves")

	var bare := StatBlock.new(Attributes.new())
	bare.rebuild({}, [], 1, 1.0)
	var iron := StatBlock.new(Attributes.new())
	iron.rebuild({}, [], 1, 1.0, "physique.iron_bone")
	check(iron.armor() > bare.armor(), "a physique adds armour")
	check(iron.get_attr("str") == bare.get_attr("str") + 2, "a physique adds attributes")
	var unknown := StatBlock.new(Attributes.new())
	unknown.rebuild({}, [], 1, 1.0, "physique.nonexistent")
	check(unknown.armor() == bare.armor(), "an unknown physique adds nothing")

	var body := Player.new()
	body.attrs = Attributes.new()
	body.stats = StatBlock.new(body.attrs)
	body.cultivation = Cultivation.new()
	body.physique_id = "physique.mortal_frame"
	body.rebuild_stats()
	check(not body.inherit_physique("physique.mortal_frame"), "an equal body is not inherited")
	check(not body.inherit_physique("physique.nonexistent"), "an unknown body is not inherited")
	check(body.inherit_physique("physique.sword_bone"), "a better body is inherited")
	check(body.physique_id == "physique.sword_bone", "the inherited body is kept")
	check(not body.inherit_physique("physique.iron_bone"), "inheritance cannot downgrade")
	body.free()

	var saved := Player.new()
	saved.attrs = Attributes.new()
	saved.stats = StatBlock.new(saved.attrs)
	saved.cultivation = Cultivation.new()
	saved.physique_id = "physique.pure_yang"
	var data := saved.to_dict()
	var loaded := Player.new()
	loaded.attrs = Attributes.new()
	loaded.stats = StatBlock.new(loaded.attrs)
	loaded.cultivation = Cultivation.new()
	loaded.from_dict(data)
	check(loaded.physique_id == "physique.pure_yang", "the physique survives a save")
	var legacy := Player.new()
	legacy.attrs = Attributes.new()
	legacy.stats = StatBlock.new(legacy.attrs)
	legacy.cultivation = Cultivation.new()
	legacy.from_dict({"display_name": "Old"})
	check(legacy.physique_id == Physiques.DEFAULT_ID, "legacy saves get the default body")
	loaded.free()
	saved.free()
	legacy.free()


# --------------------------------------------------------------- passives ----

func _passive_system_tests() -> void:
	print("[passives] requirements, conflicts, conditions and synergies")
	var state := {
		"attrs": Attributes.new(),
		"realm": 1,
		"physique_tier": 1,
		"affinities": ["metal"],
		"hp_ratio": 1.0,
		"karma": 0,
	}
	var jade := Passives.find("passive.jade_skin")
	check(not jade.is_empty(), "the jade skin passive exists")
	check(not bool(Passives.meets_requirements(jade, state)["ok"]), "requirements reject a weak body")
	var strong_attrs := Attributes.new()
	strong_attrs.add("str", 6)
	var strong := state.duplicate()
	strong["attrs"] = strong_attrs
	check(bool(Passives.meets_requirements(jade, strong)["ok"]), "requirements accept a qualified body")

	var realm_state := state.duplicate()
	realm_state["realm"] = 1
	check(bool(Passives.meets_requirements(Passives.find("passive.iron_bone"), realm_state)["ok"]), "a passive without requirements always qualifies")
	var affinity_state := state.duplicate()
	affinity_state["affinities"] = ["fire"]
	var affinity_passive := {"requires": {"affinity": "metal"}}
	check(not bool(Passives.meets_requirements(affinity_passive, affinity_state)["ok"]), "an affinity requirement is enforced")
	var low_realm := {"requires": {"min_realm": 3}}
	check(not bool(Passives.meets_requirements(low_realm, realm_state)["ok"]), "a realm requirement is enforced")

	check(Passives.resolve(["passive.jade_skin", "passive.iron_bone"], strong) == ["passive.jade_skin"], "the first acquired passive wins a conflict")
	check(Passives.resolve(["passive.iron_bone", "passive.jade_skin"], strong) == ["passive.iron_bone"], "conflict order follows acquisition")
	var dormant := Passives.issues(["passive.jade_skin", "passive.iron_bone"], strong)
	check(dormant.size() == 1 and String(dormant[0]["id"]) == "passive.iron_bone", "the conflicting passive is reported dormant")
	check(String(dormant[0]["reason"]).contains("conflicts"), "the dormancy reason names the conflict")

	var trance := Passives.find("passive.battle_trance")
	check(not bool(Passives.condition_met(trance, state)["ok"]), "a wounded passive is dormant at full health")
	var hurt := state.duplicate()
	hurt["hp_ratio"] = 0.2
	check(bool(Passives.condition_met(trance, hurt)["ok"]), "a wounded passive wakes when wounded")
	check(Passives.resolve(["passive.battle_trance"], hurt) == ["passive.battle_trance"], "conditional passives resolve")
	var karma_passive := {"condition": {"karma_above": 10}}
	check(not bool(Passives.condition_met(karma_passive, state)["ok"]), "a karma condition is enforced")

	check(Passives.synergy_mods(["passive.flowing_water"]).is_empty(), "a synergy needs both halves")
	var paired := Passives.synergy_mods(["passive.flowing_water", "passive.swift_steps"])
	check(paired.size() == 1 and String(paired[0]["stat"]) == "attack_speed_pct", "a synergy adds its mods")

	var solo := StatBlock.new(Attributes.new())
	solo.rebuild({}, ["passive.flowing_water"], 1, 1.0)
	var together := StatBlock.new(Attributes.new())
	together.rebuild({}, ["passive.flowing_water", "passive.swift_steps"], 1, 1.0)
	check(together.attack_speed() > solo.attack_speed(), "a synergy reaches the stat pipeline")

	for entry in DB.passives:
		var id := String(entry.get("id", ""))
		for other in entry.get("conflicts", []):
			check(not DB.passive(String(other)).is_empty(), "%s conflicts with a real passive" % id)
		var synergy: Dictionary = entry.get("synergy", {})
		if not synergy.is_empty():
			check(not DB.passive(String(synergy.get("with", ""))).is_empty(), "%s names a real synergy partner" % id)
		var min_attr: Dictionary = (entry.get("requires", {}) as Dictionary).get("min_attr", {})
		for key in min_attr.keys():
			check(Attributes.KEYS.has(String(key)), "%s requires a real attribute" % id)

	var learner := Player.new()
	learner.attrs = Attributes.new()
	learner.stats = StatBlock.new(learner.attrs)
	learner.cultivation = Cultivation.new()
	learner.hp_max = 100.0
	learner.hp = 100.0
	learner.rebuild_stats()
	check(not bool(learner.try_learn_passive("passive.jade_skin")["ok"]), "learning refuses an unmet requirement")
	check(not bool(learner.try_learn_passive("passive.flowing_water")["ok"]), "AGI 10 fails the AGI 12 requirement")
	learner.attrs.add("str", 4)
	check(bool(learner.try_learn_passive("passive.jade_skin")["ok"]), "learning succeeds once the requirement is met")
	check(not bool(learner.try_learn_passive("passive.jade_skin")["ok"]), "a known passive is not learned twice")
	check(not bool(learner.try_learn_passive("passive.nonexistent")["ok"]), "an unknown passive is refused")

	learner.add_passive("passive.battle_trance")
	check(not learner.active_passives().has("passive.battle_trance"), "battle trance is dormant at full health")
	var damage_full := learner.stats.physical_mult()
	learner.hp = learner.hp_max * 0.2
	learner._refresh_passive_conditions()
	check(learner.active_passives().has("passive.battle_trance"), "battle trance wakes at low health")
	check(learner.stats.physical_mult() > damage_full, "the wounded state reaches the stats")
	learner.hp = learner.hp_max
	learner._refresh_passive_conditions()
	check(not learner.active_passives().has("passive.battle_trance"), "battle trance sleeps again at full health")
	learner.free()


# -------------------------------------------------------------- techniques ----

func _technique_mastery_tests() -> void:
	print("[techniques] mastery curve, teachers and observation")
	check(Mastery.tier_for(0) == 0, "zero xp is untrained")
	check(Mastery.tier_for(Mastery.total_xp(1)) == 1, "the first threshold promotes")
	check(Mastery.tier_for(Mastery.total_xp(3)) == 3, "thresholds are cumulative")
	check(Mastery.tier_for(99999) == Mastery.MAX_TIER, "xp stops at the top tier")
	check(Mastery.clamp_xp(99999) == Mastery.total_xp(Mastery.MAX_TIER), "xp is capped")
	check(Mastery.damage_mult(5) > Mastery.damage_mult(0), "mastery raises damage")
	check(Mastery.cooldown_mult(5) < Mastery.cooldown_mult(0), "mastery shortens cooldowns")
	check(Mastery.qi_mult(5) < Mastery.qi_mult(0), "mastery cheapens Qi")
	check(Mastery.LABELS.size() == Mastery.MAX_TIER + 1, "every tier is named")
	check(is_equal_approx(Mastery.progress(0), 0.0), "progress starts at zero")
	check(is_equal_approx(Mastery.progress(Mastery.total_xp(Mastery.MAX_TIER)), 1.0), "progress ends at the top")
	check(Mastery.progress(int(Mastery.xp_to_next(0) * 0.5)) > 0.4, "progress tracks the current tier")

	var state := {"realm": 1, "attrs": Attributes.new()}
	check(not bool(Techniques.can_learn("tech.sword.falling_petal", state)["ok"]), "a low realm cannot learn")
	state["realm"] = 2
	check(not bool(Techniques.can_learn("tech.sword.falling_petal", state)["ok"]), "an unmet attribute blocks learning")
	state["attrs"].add("dex", 4)
	check(bool(Techniques.can_learn("tech.sword.falling_petal", state)["ok"]), "requirements pass when met")
	check(not bool(Techniques.can_learn("tech.nonexistent", state)["ok"]), "an unknown technique cannot be learned")
	check(is_equal_approx(Techniques.observation_progress(3), 1.0), "three observations finish a lesson")
	check(is_equal_approx(Techniques.observation_progress(1), 1.0 / 3.0), "observation progress is fractional")

	var tech := DB.technique("tech.sword.azure_cleave")
	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var plain_damage := Damage.technique_damage(tech, stats)
	check(is_equal_approx(Damage.technique_damage(tech, stats, 0.0, 1.0), plain_damage), "default mastery changes nothing")
	check(is_equal_approx(Damage.technique_damage(tech, stats, 0.0, 2.0), plain_damage * 2.0), "mastery scales technique damage")

	var learner := Player.new()
	learner.attrs = Attributes.new()
	learner.stats = StatBlock.new(learner.attrs)
	learner.cultivation = Cultivation.new()
	learner.hp_max = 100.0
	learner.hp = 100.0
	learner.rebuild_stats()
	check(not bool(learner.try_learn_technique("tech.sword.falling_petal")["ok"]), "a teacher cannot teach an unready body")
	learner.attrs.add("dex", 4)
	learner.cultivation.realm = 2
	check(bool(learner.try_learn_technique("tech.sword.falling_petal")["ok"]), "a qualified body learns")
	check(not bool(learner.try_learn_technique("tech.sword.falling_petal")["ok"]), "a known technique is not learned twice")
	check(not bool(learner.try_learn_technique("tech.nonexistent")["ok"]), "an unknown technique is refused")
	check(learner.learn_technique("tech.blood.crimson_moon"), "a grant path still bypasses requirements")
	learner.free()

	var watcher := Player.new()
	watcher.attrs = Attributes.new()
	watcher.stats = StatBlock.new(watcher.attrs)
	watcher.cultivation = Cultivation.new()
	watcher.hp_max = 100.0
	watcher.hp = 100.0
	watcher.rebuild_stats()
	check(not bool(watcher.observe_technique("tech.sword.falling_petal")["ok"]), "observation refuses an unready body")
	watcher.cultivation.realm = 2
	watcher.attrs.add("dex", 4)
	var first := watcher.observe_technique("tech.sword.falling_petal")
	check(bool(first["ok"]) and not bool(first["learned"]), "the first observation only teaches")
	check(is_equal_approx(float(first["progress"]), 1.0 / 3.0), "observation progress is tracked")
	watcher.observe_technique("tech.sword.falling_petal")
	var third := watcher.observe_technique("tech.sword.falling_petal")
	check(bool(third["learned"]), "the third observation completes the lesson")
	check(watcher.technique_ids.has("tech.sword.falling_petal"), "observation teaches the technique")
	check(watcher.observed.is_empty(), "finished observation progress is cleared")

	watcher.add_technique_xp("tech.sword.falling_petal", 200)
	check(watcher.mastery_tier("tech.sword.falling_petal") == Mastery.MAX_TIER, "xp raises the mastery tier")
	check(watcher.mastery_label("tech.sword.falling_petal") == "Perfected", "the top tier is named")
	var saved := watcher.to_dict()
	var restored := Player.new()
	restored.attrs = Attributes.new()
	restored.stats = StatBlock.new(restored.attrs)
	restored.cultivation = Cultivation.new()
	restored.from_dict(saved)
	check(restored.mastery_tier("tech.sword.falling_petal") == Mastery.MAX_TIER, "mastery survives a save")
	var legacy := Player.new()
	legacy.attrs = Attributes.new()
	legacy.stats = StatBlock.new(legacy.attrs)
	legacy.cultivation = Cultivation.new()
	legacy.from_dict({"display_name": "Old"})
	check(legacy.technique_xp.is_empty(), "legacy saves carry no mastery")
	check(legacy.observed.is_empty(), "legacy saves carry no observation")
	watcher.free()
	restored.free()
	legacy.free()


# --------------------------------------------------------------- methods ----

func _method_tests() -> void:
	print("[methods] requirements, meditation fit, insight")
	check(DB.methods.size() == 7, "all seven methods are defined (%d)" % DB.methods.size())
	for method in DB.methods:
		var id := String(method.get("id", ""))
		check(float(method.get("cult_mult", 0.0)) > 0.0, "%s has a cultivation multiplier" % id)
		check(String(method.get("mechanic", "")) != "", "%s names a mechanic" % id)
		var method_attrs: Dictionary = (method.get("requires", {}) as Dictionary).get("attrs", {})
		for key in method_attrs.keys():
			check(Attributes.KEYS.has(String(key)), "%s requires a real attribute" % id)

	var state := {"attrs": Attributes.new(), "realm": 1, "kills": 0, "physique_tier": 1}
	check(bool(Methods.qualifies("method.traditional", state)["ok"]), "the traditional path is always open")
	check(not bool(Methods.qualifies("method.body", state)["ok"]), "body tempering needs STR 18")
	check(not bool(Methods.qualifies("method.sword", state)["ok"]), "the sword method needs DEX and WIS")
	check(not bool(Methods.qualifies("method.slaughter", state)["ok"]), "the slaughter dao needs 50 kills")
	check(not bool(Methods.qualifies("method.dual", state)["ok"]), "dual cultivation needs CHAR 20")
	check(not bool(Methods.qualifies("method.heavenly", state)["ok"]), "heavenly absorption needs realm 2")
	check(not bool(Methods.qualifies("method.nonexistent", state)["ok"]), "an unknown method is refused")

	var strong := state.duplicate()
	strong["attrs"] = Attributes.new()
	strong["attrs"].add("str", 8)
	check(bool(Methods.qualifies("method.body", strong)["ok"]), "STR 18 opens body tempering")
	var bloody := state.duplicate()
	bloody["physique_tier"] = 3
	check(bool(Methods.qualifies("method.blood", bloody)["ok"]), "a stronger physique opens the blood sea")
	var killer := state.duplicate()
	killer["kills"] = 50
	check(bool(Methods.qualifies("method.slaughter", killer)["ok"]), "50 kills open the slaughter dao")
	var high_realm := state.duplicate()
	high_realm["realm"] = 2
	check(bool(Methods.qualifies("method.heavenly", high_realm)["ok"]), "realm 2 opens heavenly absorption")

	check(is_equal_approx(Methods.meditation_multiplier("method.traditional", state), 1.0), "the traditional path meditates at baseline")
	check(Methods.meditation_multiplier("method.body", strong) > Methods.meditation_multiplier("method.body", state), "body tempering feeds on strength")
	check(is_equal_approx(Methods.meditation_multiplier("method.sword", state), 0.3), "a sword cultivator gains little from sitting")
	var fighting := state.duplicate()
	fighting["recent_combat"] = true
	check(Methods.meditation_multiplier("method.sword", fighting) > 1.5, "sword intent feeds on combat")
	var charged := state.duplicate()
	charged["blood_charge"] = 100.0
	check(Methods.meditation_multiplier("method.blood", charged) > Methods.meditation_multiplier("method.blood", state), "blood essence feeds the blood sea")
	check(Methods.meditation_multiplier("method.slaughter", killer) > Methods.meditation_multiplier("method.slaughter", state), "the slaughter dao feeds on kills")
	var partnered := state.duplicate()
	partnered["partner"] = true
	check(Methods.meditation_multiplier("method.dual", partnered) > Methods.meditation_multiplier("method.dual", state), "dual cultivation needs a partner")
	var night := state.duplicate()
	night["night"] = true
	check(Methods.meditation_multiplier("method.heavenly", night) > Methods.meditation_multiplier("method.heavenly", state), "heavenly absorption feeds on the night sky")

	check(is_equal_approx(Methods.insight_bonus(0), 1.0), "no insight is no bonus")
	check(is_equal_approx(Methods.insight_bonus(100), 1.2), "insight caps at a fifth")
	var options := Methods.available(state)
	check(options.has("method.traditional"), "the traditional path is always available")
	check(not options.has("method.slaughter"), "unqualified methods are not offered")
	check(Methods.next("method.traditional", high_realm) != "method.traditional", "the stele cycles to another method")
	check(Methods.next("method.traditional", state) == "method.traditional", "with one option the stele stays put")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3
	var plain := cultivation.effective_method_mult()
	cultivation.add_method_insight("method.traditional", 100)
	check(cultivation.effective_method_mult() > plain, "insight raises the method multiplier")
	cultivation.add_method_insight("method.traditional", 50)
	check(cultivation.method_insight_points("method.traditional") == 100, "insight is capped")
	cultivation.add_blood_charge(150.0)
	check(is_equal_approx(cultivation.blood_charge, 100.0), "blood charge is capped")
	cultivation.consume_blood_charge(30.0)
	check(is_equal_approx(cultivation.blood_charge, 70.0), "blood charge is spent")

	var plain_qi := Cultivation.new()
	plain_qi.root_tier = 3
	plain_qi.cultivate(stats, 1.0, 1.0, 1.0)
	var fed_qi := Cultivation.new()
	fed_qi.root_tier = 3
	fed_qi.cultivate(stats, 1.0, 1.0, 2.0)
	check(fed_qi.qi > plain_qi.qi, "a good method fit doubles the Qi gain")

	cultivation.method_id = "method.blood"
	var saved := cultivation.to_dict()
	var restored := Cultivation.new()
	restored.from_dict(saved)
	check(restored.method_id == "method.blood", "the method survives a save")
	check(restored.method_insight_points("method.traditional") == 100, "insight survives a save")
	check(is_equal_approx(restored.blood_charge, 70.0), "blood charge survives a save")
	var legacy := Cultivation.new()
	legacy.from_dict({})
	check(legacy.method_insight.is_empty(), "legacy saves carry no insight")
	check(is_equal_approx(legacy.blood_charge, 0.0), "legacy saves carry no blood charge")


# -------------------------------------------------------- qi & meridians ----

func _qi_meridian_tests() -> void:
	print("[meridians] channels, contamination and Qi density")
	check(DB.meridians.size() == 12, "twelve meridians are defined (%d)" % DB.meridians.size())
	for meridian in DB.meridians:
		var id := String(meridian.get("id", ""))
		check(String(meridian.get("stat", "")) != "", "%s names a stat" % id)
		check(int(meridian.get("realm", 0)) >= 1 and int(meridian.get("realm", 0)) <= 12, "%s has a valid realm" % id)
		check(int(meridian.get("stones", -1)) >= 0, "%s has a stone cost" % id)

	check(Meridians.count(["meridian.lung", "meridian.lung", "meridian.none"]) == 1, "meridians count once")
	check(is_equal_approx(Meridians.capacity_mult(["meridian.lung", "meridian.stomach"]), 1.08), "each meridian adds capacity")
	var mods := Meridians.bonus_mods(["meridian.lung"])
	check(mods.size() == 1 and String(mods[0]["stat"]) == "wis", "a meridian contributes its stat")
	check(not bool(Meridians.can_open("meridian.heart", [], 1)["ok"]), "a realm-locked meridian is refused")
	check(bool(Meridians.can_open("meridian.heart", [], 2)["ok"]), "the right realm opens it")
	check(not bool(Meridians.can_open("meridian.lung", ["meridian.lung"], 9)["ok"]), "a meridian opens once")
	check(not bool(Meridians.can_open("meridian.none", [], 9)["ok"]), "an unknown meridian is refused")
	check(String(Meridians.next_available([], 1)["id"]) == "meridian.lung", "opening follows data order")
	check(String(Meridians.next_available(["meridian.lung"], 1)["id"]) == "meridian.large_intestine", "the next channel follows")
	check(Meridians.next_available([], 0).is_empty(), "no realm opens nothing")
	check(is_equal_approx(Meridians.qi_cost("meridian.lung", 100.0), 35.0), "opening costs a share of capacity")

	var bare := StatBlock.new(Attributes.new())
	bare.rebuild({}, [], 1, 1.0)
	var opened := StatBlock.new(Attributes.new())
	opened.rebuild({}, [], 1, 1.0, "", Meridians.bonus_mods(["meridian.lung", "meridian.large_intestine"]))
	check(opened.get_attr("wis") == bare.get_attr("wis") + 1, "meridians add attributes")
	check(opened.armor() > bare.armor(), "meridians add armour")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3
	var cap_before := cultivation.qi_max(stats)
	check(cultivation.open_meridian("meridian.lung"), "a meridian opens")
	check(cultivation.meridian_count() == 1, "the count follows")
	check(cultivation.qi_max(stats) > cap_before, "open channels raise Qi capacity")
	check(not cultivation.open_meridian("meridian.lung"), "a meridian does not open twice")
	check(not cultivation.open_meridian("meridian.heart"), "a realm-locked channel refuses")

	var gain_before := cultivation.qi_gain_per_sec(stats)
	cultivation.add_contamination(50.0)
	check(cultivation.contamination_mult() < 1.0, "contamination slows gain")
	check(cultivation.qi_gain_per_sec(stats) < gain_before, "contaminated channels gain less Qi")
	check(cultivation.qi_regen_per_sec(stats) >= 0.0, "regeneration never inverts")
	cultivation.cleanse(100.0)
	check(is_equal_approx(cultivation.contamination, 0.0), "cleansing clears the channels")

	cultivation.add_contamination(20.0)
	var saved := cultivation.to_dict()
	var restored := Cultivation.new()
	restored.from_dict(saved)
	check(restored.has_meridian("meridian.lung"), "meridians survive a save")
	check(is_equal_approx(restored.contamination, 20.0), "contamination survives a save")
	var legacy := Cultivation.new()
	legacy.from_dict({})
	check(legacy.meridians.is_empty() and is_equal_approx(legacy.contamination, 0.0), "legacy saves have clean channels")

	check(is_equal_approx(Biome.qi_density({}), 1.0), "a biome without density is neutral")
	check(is_equal_approx(Biome.qi_density({"qi_density": 1.5}), 1.5), "biome density reads its data")

	var failing := Cultivation.new()
	failing.root_tier = 3
	failing.sublevel = Cultivation.SUBLEVELS
	failing.qi = failing.qi_max(stats)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var result := failing.attempt_breakthrough(stats, rng, 0, 0)
	if bool(result["success"]):
		check(is_equal_approx(failing.contamination, 0.0), "a clean breakthrough does not contaminate")
	else:
		check(failing.contamination > 0.0, "a failed breakthrough contaminates the channels")


# ---------------------------------------------------------------- realms ----

func _realm_tests() -> void:
	print("[realms] 12x10 ladder, sublevel bands, unlocks and realm arts")
	check(Realms.count() == 12, "twelve realms are registered")
	check(Cultivation.SUBLEVELS == Realms.SUBLEVELS, "the rules and the data agree on ten sublevels")
	var realm_ids := {}
	var unlock_ids := {}
	var previous_qi := 0.0
	var previous_attr := 0.0
	var previous_life := -1
	for n in range(1, Realms.count() + 1):
		var entry := Realms.find(n)
		check(int(entry.get("n", 0)) == n, "realm %d is indexed in order" % n)
		check(Realms.sublevels(n) == 10, "realm %d has ten sublevels" % n)
		check(Realms.qi_mult(n) > previous_qi, "realm %d raises the Qi multiplier" % n)
		check(Realms.attr_mult(n) > previous_attr, "realm %d raises the attribute multiplier" % n)
		previous_qi = Realms.qi_mult(n)
		previous_attr = Realms.attr_mult(n)
		realm_ids[String(entry.get("id", ""))] = true
		check(Realms.ability(n).has("id") and String(Realms.ability(n).get("name", "")) != "", "realm %d names its realm art" % n)
		check(not (Realms.ability(n).get("mods", []) as Array).is_empty(), "realm %d realm art has a real effect" % n)
		check(not Realms.unlocks_at(n).is_empty(), "realm %d declares unlocks" % n)
		for unlock in Realms.unlocks_at(n):
			var unlock_id := String(unlock.get("id", ""))
			var unlock_name := String(unlock.get("name", ""))
			check(unlock_id != "" and unlock_name != "", "realm %d unlock is named" % n)
			check(not unlock_ids.has(unlock_id), "unlock %s is introduced once" % unlock_id)
			unlock_ids[unlock_id] = true
		var life := Realms.lifespan(n)
		if n < 12:
			check(life > previous_life, "realm %d extends lifespan" % n)
			previous_life = life
		else:
			check(life == 0, "the final realm has no lifespan limit")
		check(Realms.color(n).begins_with("#"), "realm %d has a colour" % n)
	check(realm_ids.size() == 12, "realm ids are unique")

	check(Realms.sublevel_label(1) == "Early" and Realms.sublevel_label(3) == "Early", "sublevels 1-3 are early")
	check(Realms.sublevel_label(4) == "Middle" and Realms.sublevel_label(6) == "Middle", "sublevels 4-6 are middle")
	check(Realms.sublevel_label(7) == "Late" and Realms.sublevel_label(9) == "Late", "sublevels 7-9 are late")
	check(Realms.sublevel_label(10) == "Peak", "sublevel ten is the peak")
	check(Realms.sublevel_label(0) == "Early" and Realms.sublevel_label(99) == "Peak", "sublevel bands clamp")
	check(is_equal_approx(Realms.sublevel_factor(1), 1.0), "the first sublevel is the baseline")
	check(is_equal_approx(Realms.sublevel_factor(10), 1.0 + 0.35 * 9.0), "the peak sublevel follows the curve")
	check(Realms.sublevel_factor(5) > Realms.sublevel_factor(4), "capacity grows every sublevel")
	check(Realms.stage_label(2, 5) == "Foundation Establishment 5", "stage labels keep their old shape")
	check(Realms.stage_title(2, 5).contains("Middle"), "stage titles name the sublevel band")
	check(Realms.stage_title(2, 5).contains("Foundation Establishment"), "stage titles name the realm")
	check(Realms.stage_power(2, 10) > Realms.stage_power(2, 1), "sublevels raise stage power")
	check(Realms.stage_power(3, 1) > Realms.stage_power(2, 1), "a realm jump raises stage power")

	check(not Realms.has_unlock(1, "dash_cancel"), "realm one cannot dash-cancel")
	check(Realms.has_unlock(2, "dash_cancel"), "foundation establishes dash-cancelling")
	check(Realms.has_unlock(12, "qi_sense"), "unlocks are cumulative")
	check(not Realms.has_unlock(6, "dao_comprehension"), "future unlocks stay locked")
	check(not Realms.has_unlock(99, "qi_sense"), "a realm outside the ladder unlocks nothing")
	check(not Realms.can_dash_cancel(1) and Realms.can_dash_cancel(2), "dash cancel follows its unlock")
	check(is_equal_approx(Realms.technique_mult(4), 1.0), "low realms weave nothing")
	check(is_equal_approx(Realms.technique_mult(5), Realms.WEAVING_MULT), "spirit transformation weaves techniques")
	check(is_equal_approx(Realms.technique_mult(12), Realms.WEAVING_MULT), "weaving persists once learned")
	check(Realms.unlock_ids(1).size() == Realms.unlocks_at(1).size(), "realm one owns exactly its own unlocks")
	check(Realms.unlock_ids(2).size() == Realms.unlocks_at(1).size() + Realms.unlocks_at(2).size(), "cumulative unlocks add up")
	check(Realms.new_unlocks(1, 2).size() == Realms.unlocks_at(2).size(), "a breakthrough reports only what is new")
	check(Realms.new_unlocks(1, 1).is_empty(), "no realm change means no new unlock")
	check(Realms.new_unlocks(5, 3).is_empty(), "unlocks never travel backwards")
	check(String(Realms.new_unlocks(2, 3)[0]["id"]) == String(Realms.unlocks_at(3)[0]["id"]), "the reported unlock is the next realm's")

	var bare := StatBlock.new(Attributes.new())
	bare.rebuild({}, [], 1, 1.0)
	var realm_one := StatBlock.new(Attributes.new())
	realm_one.rebuild({}, [], 1, 1.0, "", [], Realms.ability_mods(1))
	check(realm_one.qi_regen_mult() > bare.qi_regen_mult(), "a realm art enters the stat pipeline")
	check(is_equal_approx(realm_one.pct("qi_regen_pct"), 5.0), "the art contributes its declared mod")
	var realm_two := StatBlock.new(Attributes.new())
	realm_two.rebuild({}, [], 2, 1.0, "", [], Realms.ability_mods(2))
	check(realm_two.max_qi_mult() > bare.max_qi_mult(), "the next realm art changes the pipeline")
	check(is_equal_approx(realm_two.pct("qi_regen_pct"), 0.0), "only the current realm art applies")

	check(bare.base_lifespan_years() == Realms.lifespan(1), "StatBlock reads lifespan from Realms")
	var realm_twelve := StatBlock.new(Attributes.new())
	realm_twelve.rebuild({}, [], 12, 1.0)
	check(realm_twelve.lifespan_years() == 0, "the final realm is unbounded through the pipeline")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3
	check(cultivation.realm_ability().has("name"), "the cultivation state exposes its realm art")
	check(cultivation.stage_title().contains("Early"), "a new cultivator is early in Qi Condensation")
	cultivation.sublevel = 10
	var peak_cap := cultivation.qi_max(stats)
	cultivation.sublevel = 1
	check(peak_cap > cultivation.qi_max(stats), "sublevels really raise Qi capacity")

	var apex := Cultivation.new()
	apex.root_tier = 3
	apex.realm = 12
	apex.sublevel = 10
	apex.qi = apex.qi_max(stats)
	var apex_result := apex.attempt_breakthrough(stats, Rng.stream("apex", 0, 0), 0, 0)
	check(String(apex_result.get("reason", "")) == "apex", "there is no realm above the twelfth")
	check(apex.realm == 12 and not bool(apex_result.get("success", true)), "an apex attempt changes nothing")

	var climber := Cultivation.new()
	climber.root_tier = 3
	climber.sublevel = 10
	climber.qi = climber.qi_max(stats)
	var attempt := climber.attempt_breakthrough(stats, Rng.stream("realm_unlocks", 0, 0), 0, 0)
	if bool(attempt.get("success", false)):
		check(int(attempt.get("realm", 0)) == 2, "a breakthrough lands one realm higher")
		check((attempt.get("unlocks", []) as Array).size() == Realms.unlocks_at(2).size(), "a breakthrough reports its new unlocks")
		check(String(attempt.get("ability", "")) == Realms.ability_name(2), "a breakthrough names the realm art")
	else:
		check(climber.realm == 1, "a failed breakthrough stays in realm one")

	var clamped := Cultivation.new()
	clamped.from_dict({"realm": 99, "sublevel": 99})
	check(clamped.realm == 12 and clamped.sublevel == 10, "a corrupt save is clamped to the ladder")
	var legacy := Cultivation.new()
	legacy.from_dict({})
	check(legacy.realm == 1 and legacy.sublevel == 1, "legacy saves start at the first stage")


# --------------------------------------------------------- breakthroughs ----

func _breakthrough_tests() -> void:
	print("[breakthrough] preparation, method profiles and failure fallout")
	var calm := {"recent_combat": false, "partner": false, "night": false, "blood_charge": 0.0}
	var hot := {"recent_combat": true, "partner": true, "night": true, "blood_charge": 40.0}

	var plain := Methods.breakthrough_profile("method.traditional", calm)
	check(approx(float(plain["chance"]), 0.0) and approx(float(plain["tribulation"]), 1.0), "traditional cultivation is neutral")
	check(approx(float(plain["harm"]), 1.0), "traditional failure costs the baseline")
	check(String(plain["note"]) != "", "every profile explains itself")

	var body := Methods.breakthrough_profile("method.body", calm)
	check(float(body["chance"]) > 0.0, "a tempered body faces heaven better")
	check(float(body["tribulation"]) > 1.0, "a tempered body draws a heavier heaven")
	check(float(body["harm"]) < 1.0, "a tempered body takes failure better")

	var sword_calm := Methods.breakthrough_profile("method.sword", calm)
	var sword_hot := Methods.breakthrough_profile("method.sword", hot)
	check(float(sword_hot["chance"]) > float(sword_calm["chance"]), "sword intent rewards recent combat")
	check(float(sword_calm["chance"]) < 0.0, "a sword cultivator without a fight is punished")

	var dual_alone := Methods.breakthrough_profile("method.dual", calm)
	var dual_paired := Methods.breakthrough_profile("method.dual", hot)
	check(float(dual_paired["chance"]) > float(dual_alone["chance"]), "dual cultivation needs a partner")
	check(float(dual_alone["chance"]) < 0.0, "a lone dual practitioner is handicapped")

	var heavenly_day := Methods.breakthrough_profile("method.heavenly", calm)
	var heavenly_night := Methods.breakthrough_profile("method.heavenly", hot)
	check(float(heavenly_night["chance"]) > float(heavenly_day["chance"]), "the night sky helps the celestial method")

	var blood_dry := Methods.breakthrough_profile("method.blood", calm)
	var blood_full := Methods.breakthrough_profile("method.blood", hot)
	check(float(blood_full["chance"]) > float(blood_dry["chance"]), "blood charge helps the Blood Sea")
	check(float(blood_full["harm"]) > 1.0 and float(blood_dry["harm"]) > 1.0, "the Blood Sea always makes failure worse")

	var slaughter := Methods.breakthrough_profile("method.slaughter", calm)
	check(float(slaughter["tribulation"]) > 1.0 and float(slaughter["harm"]) > 1.0, "slaughter draws a heavier, harsher heaven")

	var unknown := Methods.breakthrough_profile("method.none", calm)
	check(approx(float(unknown["chance"]), 0.0) and approx(float(unknown["tribulation"]), 1.0), "an unknown method is neutral")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3
	cultivation.sublevel = 10
	check(cultivation.preparation == 0, "a fresh cultivator has no preparations")
	var bare_chance := cultivation.estimated_chance(stats, 0, 0, calm)
	var bare_trib := cultivation.tribulation_with(0, 0, calm)
	var bare_harm := cultivation.failure_harm(calm)
	check(cultivation.prepare(), "a preparation can be banked")
	check(cultivation.prepare() and cultivation.prepare(), "preparations stack")
	check(cultivation.preparation == Cultivation.MAX_PREPARATION, "preparations cap at three")
	check(not cultivation.prepare(), "a full bank refuses more")
	check(cultivation.estimated_chance(stats, 0, 0, calm) > bare_chance, "preparation raises the chance")
	check(cultivation.tribulation_with(0, 0, calm) < bare_trib, "preparation lightens heaven")
	check(cultivation.failure_harm(calm) < bare_harm, "preparation softens failure")
	check(approx(cultivation.failure_harm(calm), 1.0 - Cultivation.PREP_HARM * 3.0), "preparation softens failure by its declared share")

	var sword := Cultivation.new()
	sword.root_tier = 3
	sword.method_id = "method.sword"
	sword.sublevel = 10
	check(sword.estimated_chance(stats, 0, 0, hot) > sword.estimated_chance(stats, 0, 0, calm), "the live method changes the roll")
	var paired := Cultivation.new()
	paired.root_tier = 3
	paired.method_id = "method.dual"
	paired.sublevel = 10
	check(paired.estimated_chance(stats, 0, 0, hot) > paired.estimated_chance(stats, 0, 0, calm), "a nearby partner changes the roll")

	var attempt := Cultivation.new()
	attempt.root_tier = 3
	attempt.sublevel = 10
	attempt.qi = attempt.qi_max(stats)
	attempt.prepare()
	attempt.prepare()
	var predicted := attempt.estimated_chance(stats, 0, 0, calm)
	var prepared_result := attempt.attempt_breakthrough(stats, Rng.stream("prep_test", 0, 0), 0, 0, calm)
	check(approx(float(prepared_result["chance"]), predicted, 0.0001), "the attempt rolls the chance the HUD shows")
	check(int(prepared_result["preparation"]) == 2, "the attempt reports what it spent")
	check(attempt.preparation == 0, "preparation is consumed by the attempt")
	check(String(prepared_result["method"]) == "method.traditional", "the attempt reports its method")

	var deterministic_a := Cultivation.new()
	deterministic_a.root_tier = 3
	deterministic_a.sublevel = 10
	deterministic_a.qi = deterministic_a.qi_max(stats)
	var deterministic_b := Cultivation.new()
	deterministic_b.root_tier = 3
	deterministic_b.sublevel = 10
	deterministic_b.qi = deterministic_b.qi_max(stats)
	var roll_a := deterministic_a.attempt_breakthrough(stats, Rng.stream("bt_det", 3, 0), 0, 0, calm)
	var roll_b := deterministic_b.attempt_breakthrough(stats, Rng.stream("bt_det", 3, 0), 0, 0, calm)
	check(float(roll_a["roll"]) == float(roll_b["roll"]) and bool(roll_a["success"]) == bool(roll_b["success"]), "the same seed rolls the same tribulation")

	var failed_bare := _probe_failed_breakthrough(0)
	var failed_prepared := _probe_failed_breakthrough(3)
	check(not failed_bare.is_empty() and not failed_prepared.is_empty(), "a failing roll can be found for comparison")
	if not failed_bare.is_empty() and not failed_prepared.is_empty():
		check(float(failed_prepared["hp_cost_ratio"]) < float(failed_bare["hp_cost_ratio"]), "preparation reduces the wound of failure")
		check(float(failed_prepared["contamination"]) < float(failed_bare["contamination"]), "preparation reduces the corruption of failure")

	var blood_failure := _probe_failed_breakthrough(0, "method.blood")
	if not blood_failure.is_empty() and not failed_bare.is_empty():
		check(float(blood_failure["hp_cost_ratio"]) > float(failed_bare["hp_cost_ratio"]), "the Blood Sea makes failure cost more")

	cultivation.prepare()
	var saved := cultivation.to_dict()
	var restored := Cultivation.new()
	restored.from_dict(saved)
	check(restored.preparation == Cultivation.MAX_PREPARATION, "preparation survives a save")
	var legacy := Cultivation.new()
	legacy.from_dict({})
	check(legacy.preparation == 0, "legacy saves have no preparation")
	var corrupt := Cultivation.new()
	corrupt.from_dict({"preparation": 99})
	check(corrupt.preparation == Cultivation.MAX_PREPARATION, "a corrupt preparation is clamped")


## Finds a seed whose breakthrough fails, so failure fallout can be compared
## without depending on a lucky roll.
func _probe_failed_breakthrough(prep: int, method_id: String = "method.traditional") -> Dictionary:
	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	for seed_value in 200:
		var cultivation := Cultivation.new()
		cultivation.root_tier = 3
		cultivation.method_id = method_id
		cultivation.sublevel = 10
		cultivation.qi = cultivation.qi_max(stats)
		for i in prep:
			cultivation.prepare()
		var result := cultivation.attempt_breakthrough(stats, Rng.stream("fail_probe", seed_value, 0), 0, 0, {})
		if not bool(result["success"]):
			result["contamination"] = cultivation.contamination
			return result
	return {}


func _rng_tests() -> void:
	print("[rng] determinism of generation streams")
	var a: RandomNumberGenerator = Rng.stream("test.domain", 7, 3)
	var b: RandomNumberGenerator = Rng.stream("test.domain", 7, 3)
	var same := true
	for i in 20:
		if a.randi() != b.randi():
			same = false
			break
	check(same, "same stream arguments produce the same sequence")

	var c: RandomNumberGenerator = Rng.stream("test.domain", 8, 3)
	var differs := false
	for i in 20:
		if c.randi() != Rng.stream("test.domain", 7, 3).randi():
			differs = true
			break
	check(differs, "different keys produce different sequences")
	check(Rng.stream("other.domain", 7, 3).randf() != Rng.stream("test.domain", 7, 3).randf(), "domains are independent")

	var weighted: RandomNumberGenerator = Rng.stream("weights", 0, 0)
	var index: int = int(Rng.pick_weighted([1, 0, 3], weighted))
	check(index == 0 or index == 2, "weighted pick never selects a zero-weight entry")

	var save_seed := Rng.world_seed
	Rng.set_world_seed(12345)
	var first: float = float(Rng.roll_float("seedcheck", 1, 1))
	Rng.set_world_seed(99999)
	var second: float = float(Rng.roll_float("seedcheck", 1, 1))
	check(first != second, "changing the world seed changes generated results")
	Rng.set_world_seed(save_seed)


# ------------------------------------------------------------------ items ----

func _item_tests() -> void:
	print("[items] deterministic generation and affix rules")
	var generator := ItemGen.new(DB, Rng)
	var one := generator.generate(10, 42, 0)
	check(not one.is_empty(), "item generation returns an item")
	check(JSON.stringify(one) == JSON.stringify(generator.generate(10, 42, 0)), "same seed and counter produce an identical item")
	check(JSON.stringify(one) != JSON.stringify(generator.generate(10, 43, 0)), "a different key produces a different item")

	var ids := {}
	var checked := 0
	for i in 300:
		var item := generator.generate(1 + i % 20, 100 + i, i)
		if item.is_empty():
			continue
		checked += 1
		ids[String(item.get("id", ""))] = true
		var slot := String(item.get("slot", ""))
		var rarity := int(item.get("rarity", 0))
		var mods: Array = item.get("mods", [])
		if ItemGen.is_equipment_slot(slot):
			var expected: int = [0, 2, 4, 6][rarity]
			if mods.size() != expected:
				check(false, "rarity %d %s item has %d mods, expected %d" % [rarity, slot, mods.size(), expected])
				break
		elif not mods.is_empty():
			check(false, "non-equipment items do not roll affixes")
			break
	check(checked >= 290, "300 generations produce usable items (%d)" % checked)
	check(ids.size() == checked, "generated item ids are unique")

	var treasure := generator.generate(20, 500, 0, 3, "weapon")
	check(int(treasure.get("rarity", 0)) == 3, "rarity can be forced for special loot tables")
	check((treasure.get("mods", []) as Array).size() == 6, "treasure items carry 3 prefixes and 3 suffixes")
	check(String(generator.describe(treasure)).length() > 0, "items have a readable description")


# ------------------------------------------------------------ cultivation ----

func _cultivation_tests() -> void:
	print("[cultivation] Qi, sublevels, breakthroughs")
	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var cultivation := Cultivation.new()
	cultivation.root_tier = 3

	check(cultivation.qi_max(stats) > 0.0, "Qi capacity is positive")
	check(cultivation.qi_gain_per_sec(stats) > 0.0, "meditation grants Qi")
	check(cultivation.qi_regen_per_sec(stats) > 0.0, "passive Qi regeneration exists")

	cultivation.cultivate(stats, 1.0)
	check(cultivation.qi > 0.0, "cultivating increases stored Qi")
	cultivation.cultivate(stats, 10000.0)
	check(approx(cultivation.qi, cultivation.qi_max(stats), 0.5), "Qi never exceeds its cap")
	check(cultivation.advance_sublevel(stats), "a full sublevel advances")
	check(cultivation.sublevel == 2, "sublevel incremented")
	check(approx(cultivation.qi, 0.0), "Qi resets on advancement")
	check(not Cultivation.new().advance_sublevel(stats), "cannot advance a sublevel without full Qi")

	var peak := Cultivation.new()
	peak.sublevel = 10
	peak.qi = peak.qi_max(stats)
	check(String(Cultivation.new().attempt_breakthrough(stats, Rng.stream("bt", 0, 0)).get("reason", "")) == "not_at_peak", "breakthrough is refused before the peak")

	var result := peak.attempt_breakthrough(stats, Rng.stream("bt", 0, 0), 0, 0)
	check(float(result.get("chance", -1.0)) >= 0.0 and float(result.get("chance", 2.0)) <= 1.0, "breakthrough chance is in range")
	check(float(result.get("hp_cost_ratio", 0.0)) > 0.0, "every breakthrough costs something")
	check(approx(peak.qi, 0.0), "Qi is consumed by the attempt")
	check(peak.realm >= 1 and peak.sublevel >= 1, "realm state stays valid after success or failure")

	var rooted := Cultivation.new()
	rooted.root_tier = 12
	var mortal := Cultivation.new()
	mortal.root_tier = 1
	check(rooted.qi_gain_per_sec(stats) > mortal.qi_gain_per_sec(stats) * 5.0, "higher roots cultivate dramatically faster")
	check(Cultivation.new().tribulation_scale(900, 40) > Cultivation.new().tribulation_scale(0, 0), "tribulations scale with behaviour")


# ----------------------------------------------------------------- combat ----

func _combat_tests() -> void:
	print("[combat] resist curves and technique scaling")
	check(Damage.mitigate_armor(100.0, 50.0) < 100.0, "armor reduces incoming damage")
	check(approx(Damage.mitigate_armor(100.0, 0.0), 100.0), "no armor means no mitigation")
	check(Damage.effective_resist(100.0, 0.0) > Damage.effective_resist(100.0, 40.0), "higher realm attackers penetrate resistance")
	check(Damage.resolve(50.0, 999.0, 0.0) > 0.0, "resistance never makes a hit zero")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var tech := DB.technique("tech.fist.iron_bone")
	var raw := Damage.technique_damage(tech, stats)
	check(raw > 0.0, "techniques produce damage")
	check(Damage.poise_damage(tech, stats) > 0.0, "techniques produce poise damage")

	var strong_attrs := Attributes.new()
	strong_attrs.add("str", 40)
	var strong := StatBlock.new(strong_attrs)
	strong.rebuild({}, [], 1, 1.0)
	check(Damage.technique_damage(tech, strong) > raw, "STR scaling raises technique damage")


# ------------------------------------------------------------------ world ----

func _world_tests() -> void:
	print("[world] province streaming and determinism")
	var manager := ChunkManager.new()
	add_child(manager)
	manager.configure(12345)
	manager.stream_around(Vector2(5632, 5632))
	check(manager.chunk_count() == 25, "a 5x5 ring streams around the player (got %d)" % manager.chunk_count())

	var center := manager.world_to_chunk(Vector2(5632, 5632))
	var sig := manager.signature_at(center)
	check(sig != 0, "chunks carry a deterministic signature")

	var second := ChunkManager.new()
	add_child(second)
	second.configure(12345)
	second.stream_around(Vector2(5632, 5632))
	check(second.signature_at(center) == sig, "same seed and coordinate give the same chunk")

	var other_seed := ChunkManager.new()
	add_child(other_seed)
	other_seed.configure(999)
	other_seed.stream_around(Vector2(5632, 5632))
	check(other_seed.signature_at(center) != sig, "a different world seed changes the province")

	manager.stream_around(Vector2(5632 + 3072, 5632))
	check(manager.chunk_count() == 25, "streaming stays bounded after moving three chunks")
	# Moving 3 chunks overlaps 2 columns with the old ring, so 15 chunks load
	# and 10 stay resident: 25 + 15 = 40 total loads, never unbounded growth.
	check(manager.streamed_chunks == 40, "only the newly exposed chunks load (%d)" % manager.streamed_chunks)
	check(manager.world_to_chunk(Vector2(-1, -1)) == Vector2i(-1, -1), "negative coordinates are handled")
	check(not manager.in_province(Vector2i(-1, 0)), "the province has hard edges")

	manager.queue_free()
	second.queue_free()
	other_seed.queue_free()


# ---------------------------------------------------------- chunk payloads ----

func _chunk_delta_tests() -> void:
	print("[chunks] pure payloads, deltas and background regrowth")
	check(ChunkManager.ProvinceChunk.FEATURES == ChunkGen.FEATURES, "payload generator and chunk agree on the feature count")

	var coord := Vector2i(4, 7)
	var payload := ChunkGen.payload_for(coord, 4242)
	check(int(payload["signature"]) == ChunkGen.signature_for(coord, 4242), "the payload carries its signature")
	check((payload["features"] as Array).size() == ChunkGen.FEATURES, "a payload holds every decoration")

	var again := ChunkGen.payload_for(coord, 4242)
	check(String(again["features"][0]["kind"]) == String(payload["features"][0]["kind"]), "payload generation is deterministic")
	check((again["features"][0]["pos"] as Vector2).is_equal_approx(payload["features"][0]["pos"] as Vector2), "feature positions are deterministic")
	check(int(ChunkGen.payload_for(coord, 4243)["signature"]) != int(payload["signature"]), "a different seed changes the chunk")

	var static_stream := Rng.stream_from(Rng.world_seed, "chunk", 7, 0)
	var instance_stream := Rng.stream("chunk", 7, 0)
	check(approx(static_stream.randf(), instance_stream.randf()), "the explicit-seed stream matches the autoload stream")

	var herb_total := 0
	var herb_ids := {}
	var herb_names := {}
	for cx in range(0, 6):
		for cy in range(0, 6):
			for entry in ChunkGen.payload_for(Vector2i(cx, cy), 4242)["herbs"]:
				herb_total += 1
				herb_ids[String(entry["id"])] = true
				herb_names[String(entry["label"])] = true
	check(herb_total > 0, "the province grows resources somewhere (%d herbs)" % herb_total)
	check(herb_ids.size() == herb_total, "every chunk resource has a unique id")
	check(herb_names.size() >= 2, "chunk resources vary in name (%d names)" % herb_names.size())

	var delta := WorldDelta.new()
	var id := "herb.chunk.4.7.0"
	check(not delta.is_spent(coord, id, 10), "nothing is spent in a fresh delta")
	delta.mark_spent(coord, id, 10)
	check(delta.is_spent(coord, id, 10), "a harvested resource is spent the same day")
	check(delta.is_spent(coord, id, 12), "a harvested resource stays spent inside its window")
	check(not delta.is_spent(coord, id, 13), "a harvested resource regrows after the window")
	check(not delta.is_spent(Vector2i(4, 8), id, 10), "deltas are per chunk")
	check(delta.total_entries() == 1 and delta.chunk_count() == 1, "a delta counts chunks and entries")
	check(delta.prune(coord, 12) == 0, "pruning keeps living entries")
	check(delta.prune(coord, 13) == 1, "pruning drops regrown entries")
	check(delta.total_entries() == 0 and delta.chunk_count() == 0, "an emptied delta forgets its chunk")

	delta.mark_spent(coord, id, 20)
	var restored := WorldDelta.from_dict(JSON.parse_string(JSON.stringify(delta.to_dict())) as Dictionary)
	check(restored.is_spent(coord, id, 21), "chunk deltas survive a JSON round trip")
	check(not restored.is_spent(coord, id, 23), "the regrow window survives the round trip")

	var holder := Node2D.new()
	add_child(holder)
	var manager := ChunkManager.new()
	add_child(manager)
	manager.set_resource_parent(holder)
	var spawned: Array = []
	manager.on_resource_spawned = func(node: Interactable) -> void: spawned.append(node)
	manager.configure(4242)
	manager.set_delta(WorldDelta.new())
	manager.today = 5
	manager.stream_around(Vector2(5632, 5632))
	check(manager.chunk_count() == 25, "chunks still stream synchronously when threading is off")
	check(spawned.size() > 0, "chunk resources stream in as interactables (%d)" % spawned.size())
	check(spawned.size() == manager.resource_count(), "the manager counts its own resources")

	var herb: Interactable = null
	for node in spawned:
		if String((node as Interactable).id).begins_with("herb.chunk."):
			herb = node as Interactable
			break
	check(herb != null, "chunk herbs stream in among the other resources")
	check(herb != null and herb.chunk_owned, "streamed resources know they belong to a chunk")
	check(herb != null and herb.id.begins_with("herb.chunk."), "streamed resource ids are namespaced")
	check(herb.can_interact(), "a fresh streamed herb can be gathered")

	var before := manager.resource_count()
	manager.delta.mark_spent(herb.chunk_coord, herb.id, manager.today)
	manager.resync(Vector2(5632, 5632))
	check(manager.resource_count() == before - 1, "a resynced chunk honours its delta")
	check(manager.delta.is_spent(herb.chunk_coord, herb.id, manager.today), "the delta survives a resync")
	manager.today += WorldDelta.HERB_REGROW_DAYS
	manager.resync(Vector2(5632, 5632))
	check(manager.resource_count() == before, "the resource returns once the regrow window passes")
	check(not manager.delta.is_spent(herb.chunk_coord, herb.id, manager.today), "a regrown resource is no longer spent")
	manager.queue_free()
	holder.queue_free()

	var threaded_manager := ChunkManager.new()
	add_child(threaded_manager)
	threaded_manager.threaded = true
	threaded_manager.configure(4242)
	threaded_manager.stream_around(Vector2(5632, 5632))
	threaded_manager.settle()
	check(threaded_manager.chunk_count() == 25, "worker threads fill the ring too (%d)" % threaded_manager.chunk_count())
	check(threaded_manager.signature_at(Vector2i(5, 5)) == ChunkGen.signature_for(Vector2i(5, 5), 4242), "threaded chunks match the pure generator")
	threaded_manager.queue_free()


# ------------------------------------------------------------- continent ----

func _continent_tests() -> void:
	print("[continent] land, names, connectivity and map layout")
	var data := Continent.generate(777)
	check((data["cells"] as Array).size() == Continent.COLS * Continent.ROWS, "the continent is a %dx%d lattice" % [Continent.COLS, Continent.ROWS])
	check(int(data["capital"]) == Continent.index_of(Continent.CAPITAL), "the capital is the playable cell")
	check(bool((data["cells"] as Array)[int(data["capital"])]["land"]), "the capital cell is always land")

	var regions: Array = data["regions"]
	check(regions.size() >= Continent.MIN_REGIONS, "a continent has at least %d regions (%d)" % [Continent.MIN_REGIONS, regions.size()])
	check(regions.size() <= Continent.COLS * Continent.ROWS, "there cannot be more regions than cells")

	var names := {}
	for region in regions:
		names[String(region["name"])] = true
	check(names.size() == regions.size(), "region names are unique")

	var region_map := {}
	for region in regions:
		region_map[int(region["index"])] = region
	var capital_region: Dictionary = region_map[int(data["capital"])]
	check(bool(capital_region["capital"]), "the capital region is flagged")
	check(int(capital_region["tier"]) == 1, "the capital is tier one")

	var seen := {int(data["capital"]): true}
	var queue: Array = [int(data["capital"])]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbour in (region_map[current] as Dictionary)["neighbours"]:
			if not seen.has(int(neighbour)):
				seen[int(neighbour)] = true
				queue.append(int(neighbour))
	check(seen.size() == regions.size(), "every land region connects to the capital (%d/%d)" % [seen.size(), regions.size()])

	var every_tier := true
	for region in regions:
		if int(region["tier"]) < 1:
			every_tier = false
	check(every_tier, "every region has a distance tier")

	var mask := ""
	for cell in data["cells"]:
		mask += "1" if bool(cell["land"]) else "0"
	var repeat := Continent.generate(777)
	var repeat_mask := ""
	for cell in repeat["cells"]:
		repeat_mask += "1" if bool(cell["land"]) else "0"
	check(mask == repeat_mask, "the same seed redraws the same land")
	check(String(data["name"]) == String(repeat["name"]), "the continent keeps its name across generations")

	var other_mask := ""
	for cell in Continent.generate(778)["cells"]:
		other_mask += "1" if bool(cell["land"]) else "0"
	check(mask != other_mask, "a different seed redraws the land")

	check(Continent.region_for_world_position(Vector2(5632, 5632)) == int(data["capital"]), "the playable province is the capital region")
	check(int(Continent.region_by_index(data, int(data["capital"]))["index"]) == int(data["capital"]), "regions can be looked up by index")
	check(Continent.region_by_index(data, -5).is_empty(), "an unknown region index returns nothing")

	var area := Rect2(0, 0, 500, 400)
	var first := Continent.map_rect(Vector2i(0, 0), area)
	var east := Continent.map_rect(Vector2i(1, 0), area)
	var south := Continent.map_rect(Vector2i(0, 1), area)
	check(area.encloses(first) and area.encloses(east) and area.encloses(south), "map cells stay inside the drawing area")
	check(east.position.x > first.position.x and south.position.y > first.position.y, "map cells advance east and south")
	check(not first.intersects(east), "map cells do not overlap")
	check(Continent.coord_of(Continent.index_of(Vector2i(3, 2))) == Vector2i(3, 2), "cell coordinates round trip")


# ---------------------------------------------------------------- biomes ----

func _biome_tests() -> void:
	print("[biomes] definitions, chunk identity and tables")
	check(DB.biomes.size() >= 4, "the registry holds biomes (%d)" % DB.biomes.size())
	check(not DB.biome("biome.verdant").is_empty(), "biomes can be looked up by id")
	check(DB.biome("biome.none").is_empty(), "an unknown biome returns nothing")
	check(DB.biome_table().size() == DB.biomes.size(), "the biome snapshot covers every definition")

	var seen_ids := {}
	for biome in DB.biomes:
		var id := String(biome["id"])
		seen_ids[id] = true
		check(String(biome["name"]) != "", "%s has a name" % id)
		check(not (biome["palette"] as Array).is_empty(), "%s has a palette" % id)
		check(not (biome["resources"] as Array).is_empty(), "%s has resources" % id)
		check(not (biome["enemies"] as Array).is_empty(), "%s has enemies" % id)
	check(seen_ids.size() == DB.biomes.size(), "biome ids are unique")

	var coord := Vector2i(3, 2)
	check(Biome.for_chunk(coord, 4242) == Biome.for_chunk(coord, 4242), "biome identity is deterministic")
	check(Biome.for_chunk(Biome.HOME_CHUNK, 4242) == Biome.BANDS[0], "the settlement chunk is the starting biome")
	check(Biome.for_chunk(Biome.HOME_CHUNK + Vector2i(Biome.HOME_RADIUS, 0), 4242) == Biome.BANDS[0], "the starting biome has a radius")

	var bands := {}
	for x in range(0, 12):
		for y in range(0, 12):
			bands[Biome.for_chunk(Vector2i(x, y), 4242)] = true
	check(bands.size() >= 3, "the province contains several biomes (%d)" % bands.size())
	var unknown_bands := 0
	for id in bands.keys():
		if DB.biome(String(id)).is_empty():
			unknown_bands += 1
	check(unknown_bands == 0, "every band id exists in the registry")

	var layout_a := ""
	var layout_b := ""
	for x in range(0, 12):
		layout_a += Biome.for_chunk(Vector2i(x, 0), 4242)
		layout_b += Biome.for_chunk(Vector2i(x, 0), 4243)
	check(layout_a != layout_b, "a different seed lays out different biomes")

	var payload := ChunkGen.payload_for(Vector2i(2, 9), 4242, DB.biome_table())
	check(String(payload["biome"]) == Biome.for_chunk(Vector2i(2, 9), 4242), "a payload carries its biome id")
	check((payload["palette"] as Array).size() == 4, "a payload carries the biome palette")
	var biome_def: Dictionary = DB.biome(String(payload["biome"]))
	var allowed_features: Dictionary = biome_def["features"]
	var kinds := {}
	var bad_features := 0
	for feature in payload["features"]:
		var kind := String(feature["kind"])
		kinds[kind] = true
		if not allowed_features.has(kind):
			bad_features += 1
	check(bad_features == 0, "chunk props come from the biome's weight table")
	check(kinds.size() >= 2, "chunk props still vary inside a biome (%d kinds)" % kinds.size())

	var allowed_resources := {}
	for entry in biome_def["resources"]:
		allowed_resources[String(entry["name"])] = true
	var bad_herbs := 0
	for herb in payload["herbs"]:
		if not allowed_resources.has(String(herb["label"])):
			bad_herbs += 1
	check(bad_herbs == 0, "chunk herbs come from the biome's resources")

	var r := Rng.stream("biome_test", 2)
	var enemy := Biome.pick_enemy(biome_def, r)
	check(not enemy.is_empty(), "an enemy can be picked from a biome table")
	var enemy_names := {}
	for entry in biome_def["enemies"]:
		enemy_names[String(entry["name"])] = true
	check(enemy_names.has(String(enemy["name"])), "picked enemies come from the table")
	check(Biome.pick_enemy({}, r).is_empty(), "an empty enemy table picks nothing")
	check(Biome.pick_resource({}, r).is_empty(), "an empty resource table picks nothing")

	var bare := ChunkGen.payload_for(Vector2i(1, 1), 4242)
	check((bare["palette"] as Array).size() >= 1, "payloads fall back to a default palette")
	check((bare["features"] as Array).size() == ChunkGen.FEATURES, "fallback payloads still hold every decoration")


# --------------------------------------------------------------- economy ----

func _economy_tests() -> void:
	print("[economy] prices, merchant stock and services")
	var cheap := {"value": 10, "rarity": 0}
	var rich := {"value": 100, "rarity": 3}
	check(Economy.buy_price(cheap) == 10, "buying costs an item's value")
	check(Economy.buy_price(rich) > Economy.buy_price(cheap), "better items cost more")
	check(Economy.sell_price(cheap) == 4, "selling pays a fraction of the value")
	check(Economy.sell_price(cheap) < Economy.buy_price(cheap), "buying and selling cannot round-trip for profit")
	check(Economy.sell_price({"value": 0}) >= 1, "worthless items still sell for something")
	check(Economy.rest_cost() > 0, "resting has a price")
	check(Economy.can_afford(10, 10) and not Economy.can_afford(9, 10), "affordability is inclusive at the price")
	check(Economy.after_purchase(10, 10) == 0, "a purchase can spend everything")
	check(Economy.after_purchase(5, 10) == -1, "an unaffordable purchase returns -1")

	var a := Merchant.new()
	a.id = "merchant.test"
	a.refresh(DB, Rng, 4)
	check(a.stock.size() == Merchant.STOCK_SIZE, "a merchant stocks %d items" % a.stock.size())
	check(a.day == 4, "the merchant remembers its stock day")
	var bad_prices := 0
	for item in a.stock:
		if Economy.buy_price(item) <= 0:
			bad_prices += 1
	check(bad_prices == 0, "every stock item has a price")

	var ids_a: Array = []
	for item in a.stock:
		ids_a.append(String(item["id"]))
	var b := Merchant.new()
	b.id = "merchant.test"
	b.refresh(DB, Rng, 4)
	var ids_b: Array = []
	for item in b.stock:
		ids_b.append(String(item["id"]))
	check(ids_a == ids_b, "the same merchant and day stock the same goods")

	var first: Dictionary = a.stock[0]
	var taken := a.take(0)
	check(String(taken["id"]) == String(first["id"]), "taking an item returns it")
	check(a.stock.size() == Merchant.STOCK_SIZE - 1, "taking an item removes it from stock")
	check(a.sold.has(String(first["id"])), "bought goods are remembered")
	check(a.take(99).is_empty(), "an out-of-range purchase returns nothing")

	var restored := Merchant.new()
	restored.id = "merchant.test"
	restored.from_dict(a.to_dict())
	restored.refresh(DB, Rng, 4)
	var restored_ids: Array = []
	for item in restored.stock:
		restored_ids.append(String(item["id"]))
	check(not restored_ids.has(String(first["id"])), "bought goods stay sold after a reload")
	check(restored.stock.size() == Merchant.STOCK_SIZE - 1, "a reload restores the rest of the stock")

	restored.refresh(DB, Rng, 5)
	check(not restored.sold.has(String(first["id"])), "a new day clears the purchase record")
	check(restored.stock.size() == Merchant.STOCK_SIZE, "a new day stocks a full shop")
	restored_ids.clear()
	for item in restored.stock:
		restored_ids.append(String(item["id"]))
	check(restored_ids != ids_a, "the next day's stock differs")


# -------------------------------------------------------------- locations ----

func _location_tests() -> void:
	print("[locations] overworld sites, discovery windows and permanence")
	check(ChunkGen.POI_KINDS.size() == 3, "three kinds of overworld site")

	var total := 0
	var kinds := {}
	var unique_ids := {}
	var outside := 0
	for x in range(0, 8):
		for y in range(0, 8):
			var payload := ChunkGen.payload_for(Vector2i(x, y), 5150)
			for poi in payload["pois"]:
				total += 1
				kinds[String(poi["kind"])] = true
				unique_ids[String(poi["id"])] = true
				var pos: Vector2 = poi["pos"]
				if pos.x < 0.0 or pos.y < 0.0 or pos.x > ChunkGen.SIZE or pos.y > ChunkGen.SIZE:
					outside += 1
	check(total > 0, "the province contains overworld sites (%d over 64 chunks)" % total)
	check(kinds.size() >= 2, "site kinds vary (%d)" % kinds.size())
	check(unique_ids.size() == total, "site ids are unique")
	check(outside == 0, "sites stay inside their chunk")

	var first: Array = ChunkGen.payload_for(Vector2i(3, 3), 5150)["pois"]
	var again: Array = ChunkGen.payload_for(Vector2i(3, 3), 5150)["pois"]
	check(first.size() == again.size(), "site placement is deterministic")
	if not first.is_empty():
		check(String(first[0]["id"]) == String(again[0]["id"]), "the same chunk yields the same site")

	var delta := WorldDelta.new()
	var coord := Vector2i(2, 2)
	delta.mark_spent(coord, "poi.mine.2.2", 10, 10)
	check(delta.is_spent(coord, "poi.mine.2.2", 19), "a mine stays mined inside its window")
	check(not delta.is_spent(coord, "poi.mine.2.2", 20), "a mine refills after ten days")
	delta.mark_spent(coord, "poi.ruin.2.2", 10, WorldDelta.PERMANENT)
	check(delta.is_spent(coord, "poi.ruin.2.2", 900), "a searched ruin stays searched")
	delta.mark_spent(coord, "herb.chunk.2.2.0", 10)
	check(delta.prune(coord, 14) == 1, "pruning removes only expired entries")
	check(delta.is_spent(coord, "poi.ruin.2.2", 14), "permanent sites survive pruning")
	check(delta.is_spent(coord, "poi.mine.2.2", 14), "living windows survive pruning")

	var legacy := WorldDelta.from_dict({"2,2": {"herb.old": 10}})
	check(legacy.is_spent(coord, "herb.old", 12), "legacy day-only deltas still read")
	check(not legacy.is_spent(coord, "herb.old", 13), "legacy deltas keep the herb regrow window")

	check(Interactable.poi_regrow("ruin") == WorldDelta.PERMANENT, "ruins are permanent")
	check(Interactable.poi_regrow("mine") > Interactable.poi_regrow("deposit"), "mines take longer than deposits")

	for kind_name in ChunkGen.POI_KINDS:
		var site := Interactable.new()
		site.setup_poi("poi.%s.1.1" % kind_name, String(kind_name), Vector2i(1, 1))
		check(site.chunk_owned, "%s sites are chunk-owned" % kind_name)
		check(site.can_interact(), "%s sites can be searched" % kind_name)
		check(site.display_label() != "", "%s sites are labelled" % kind_name)
		check(site.regrow_days == Interactable.poi_regrow(String(kind_name)), "%s sites carry their regrow window" % kind_name)
		site.used = true
		check(not site.can_interact(), "a spent %s site is not offered" % kind_name)
		site.free()


# ----------------------------------------------------------------- travel ----

func _travel_tests() -> void:
	print("[travel] cost, bearing, destinations and arrival")
	check(approx(Travel.hours_for(0.0), Travel.MIN_HOURS), "a short trip still costs the minimum time")
	check(approx(Travel.hours_for(1000000.0), Travel.MAX_HOURS), "a cross-province trip is capped")
	check(Travel.hours_for(4000.0) > Travel.hours_for(1000.0), "longer trips cost more time")
	check(approx(Travel.hours_for(1000.0), Travel.MIN_HOURS), "short trips are floored at the minimum")
	check(approx(Travel.hours_for(4000.0), 1.4), "four thousand units costs 1.4 hours")

	check(approx(Travel.bearing(Vector2.ZERO, Vector2(10, 0)), 0.0), "east is zero radians")
	check(approx(Travel.bearing(Vector2.ZERO, Vector2(0, 10)), PI * 0.5), "south is a quarter turn")
	check(approx(Travel.bearing(Vector2.ZERO, Vector2(0, -10)), -PI * 0.5), "north points up")

	check(Travel.distance_label(0.0) == "0 m", "distance is labelled in metres")
	check(Travel.distance_label(1234.6) == "1235 m", "distance rounds to whole metres")

	check(Travel.can_travel(true, false, false), "travel is allowed on the overworld")
	check(not Travel.can_travel(true, true, false), "travel is blocked inside a realm")
	check(not Travel.can_travel(false, false, false), "travel needs a target")

	var landmarks := [
		{"id": "landmark.a", "name": "Plaza", "position": Vector2(10, 10)},
		{"id": "landmark.b", "name": "Shrine", "position": Vector2(20, 20)},
	]
	var sites := {}
	for i in 8:
		sites["poi.site.%d" % i] = {"name": "Site %d" % i, "x": float(i * 100), "y": 50.0}
	var list := Travel.destinations(landmarks, sites)
	check(list.size() == Travel.MAX_ROWS, "the travel list is capped at %d rows" % Travel.MAX_ROWS)
	check(String(list[0]["id"]) == "landmark.a", "landmarks come first")
	var site_count := 0
	for row in list:
		if String(row["id"]).begins_with("poi."):
			site_count += 1
	check(site_count == Travel.MAX_ROWS - landmarks.size(), "sites fill the remaining rows")
	var first_site: Dictionary = list[landmarks.size()]
	check(String(first_site["id"]) == "poi.site.0", "discovered sites are listed in id order")
	check(Travel.destinations([], {}).is_empty(), "no landmarks and no sites means no routes")

	check(Travel.has_arrived(Vector2(100, 100), Vector2(120, 100)), "arrival is generous")
	check(not Travel.has_arrived(Vector2(100, 100), Vector2(300, 100)), "a distant waypoint is not arrived")
	check(not Travel.has_arrived(Vector2(100, 100), Vector2.ZERO), "an unset waypoint never counts as reached")


# ------------------------------------------------------------- simulation ----

func _simulation_tests() -> void:
	print("[simulation] NPCs sleep, wake and snap to their schedule")
	var npc := Npc.new()
	npc.npc_id = "test_npc"
	npc.display_name = "Test Cultivator"
	npc.schedule = DB.schedules().get("disciple", [])

	check(npc.simulated, "an NPC starts simulated")
	npc.sleep()
	check(not npc.simulated, "sleeping stops the NPC simulating")
	npc.sleep()
	check(not npc.simulated, "sleeping twice is harmless")
	npc.wake()
	check(npc.simulated, "waking resumes the NPC")

	# Waking snaps to the schedule that passed while it slept.
	var settlement := Settlement.new()
	settlement.global_position = Vector2(200.0, 100.0)
	npc.settlement = settlement
	var previous_hour := Clock.hour
	Clock.hour = 10.0
	npc.current_activity = "idle"
	npc.current_location = "plaza"
	npc.sleep()
	Clock.hour = 19.0
	npc.wake()
	check(npc.current_activity == String(npc.resolve_schedule(19).get("activity", "")),
		"a woken NPC picks up the current activity")
	check(npc.current_location == String(npc.resolve_schedule(19).get("location", "")), "a woken NPC moves to the current location")
	check(npc.global_position.distance_to(settlement.position_for(npc.current_location)) < 0.01, "a woken NPC stands where the schedule puts them")
	check(npc.target == npc.global_position, "a woken NPC has nothing left to walk")

	Clock.hour = 23.0
	npc.snap_to_schedule()
	check(npc.current_activity == String(npc.resolve_schedule(23).get("activity", "")), "snapping follows the clock")
	Clock.hour = previous_hour

	npc.settlement = null
	npc.snap_to_schedule()
	check(npc.current_activity != "", "an NPC without a home does not crash when snapping")
	npc.free()
	settlement.free()


# -------------------------------------------------------------- origins ----

func _origin_tests() -> void:
	print("[origins] circumstances, references and appearance")
	check(DB.origins.size() >= 4, "at least four origins are defined (%d)" % DB.origins.size())
	var seen := {}
	for entry in DB.origins:
		var fx := Origin.effects(entry)
		var id := String(fx["id"])
		check(id != "", "every origin has an id")
		seen[id] = true
		check(String(fx["name"]) != "", "%s has a name" % id)
		check(String(fx["blurb"]) != "" and String(fx["condition"]) != "", "%s has circumstances" % id)
		check(int(fx["stones"]) >= 0 and int(fx["stones"]) <= Origin.MAX_STONES, "%s keeps its purse sane" % id)
		check(DB.has("method", String(fx["method_id"])), "%s names a real method" % id)
		if String(fx["passive"]) != "":
			check(DB.has("passive", String(fx["passive"])), "%s names a real passive" % id)
		check(Origin.summary(entry).begins_with(String(fx["name"])), "%s summarises itself" % id)
	check(seen.size() == DB.origins.size(), "origin ids are unique")

	check(String(DB.origin("origin.fallen_clan").get("name", "")) == "Fallen Clan Heir", "origins are indexed by id")
	check(DB.origin("origin.missing").is_empty(), "an unknown origin is empty")

	var first := String((DB.origins[0] as Dictionary).get("id", ""))
	var second := Origin.next(DB.origins, first, 1)
	check(second != first, "cycling moves to another origin")
	check(Origin.next(DB.origins, second, -1) == first, "cycling back returns to the first")
	check(Origin.next(DB.origins, "origin.none", 1) == second, "an unknown current origin starts from the first")
	var last_id := String((DB.origins[DB.origins.size() - 1] as Dictionary).get("id", ""))
	check(Origin.next(DB.origins, last_id, 1) == first, "the origin list wraps")

	var appearance := Appearance.new()
	check(appearance.robe_color() == Color(Appearance.ROBES[0]), "the default robe is the first palette entry")
	check(appearance.pronouns() == Appearance.PRESENTATIONS[0], "the default presentation is the first entry")
	appearance.cycle("robe")
	check(appearance.robe == 1 and appearance.robe_color() == Color(Appearance.ROBES[1]), "cycling changes the robe")
	appearance.cycle("robe", -1)
	check(appearance.robe == 0, "cycling backwards returns")
	appearance.cycle("robe", -1)
	check(appearance.robe == Appearance.ROBES.size() - 1, "the palette wraps backwards")
	appearance.cycle("hair")
	appearance.cycle("skin")
	appearance.cycle("presentation")
	check(appearance.hair == 1 and appearance.skin == 1 and appearance.presentation == 1, "hair, skin and presentation cycle")
	check(appearance.label() != "", "appearance labels itself")

	var saved := appearance.to_dict()
	var restored := Appearance.new()
	restored.from_dict(saved)
	check(restored.to_dict() == saved, "appearance round-trips through a save")
	var crazy := Appearance.new()
	crazy.from_dict({"robe": 999, "hair": -4, "skin": 40, "presentation": -1})
	check(crazy.robe == Appearance.ROBES.size() - 1, "a wild robe index is clamped")
	check(crazy.hair == 0 and crazy.skin == Appearance.SKINS.size() - 1 and crazy.presentation == 0, "other appearance fields clamp too")


# -------------------------------------------------------------------- npc ----

func _npc_tests() -> void:
	print("[npc] schedules resolve by hour")
	var schedules: Dictionary = DB.schedules()
	check(schedules.has("disciple"), "disciple schedule exists")
	var npc := Npc.new()
	npc.schedule = schedules.get("disciple", [])
	check(npc.schedule.size() >= 4, "schedule has several phases")

	var morning := npc.resolve_schedule(6)
	var midday := npc.resolve_schedule(10)
	var evening := npc.resolve_schedule(19)
	var night := npc.resolve_schedule(23)
	check(String(morning.get("location", "")) == "shrine", "06:00 sends disciples to the shrine")
	check(String(midday.get("location", "")) == "training", "10:00 sends disciples to train")
	check(String(evening.get("location", "")) == "tavern", "19:00 sends disciples to the tavern")
	check(String(night.get("location", "")) == "dorms", "23:00 sends disciples to sleep")
	check(not npc.resolve_schedule(4).is_empty(), "wrapped sleep shifts resolve after midnight")
	npc.free()


# ----------------------------------------------------------------- quests ----

func _quest_tests() -> void:
	print("[quests] the Azure Cloud line advances only on real events")
	var log := QuestLog.new()
	check(log.is_valid(), "quest data loads")
	check(log.step_index == 0, "quest starts at the first step")
	check(log.current_kind() == "talk", "first step is a conversation")

	check(not log.track("kill", "beast"), "kills do not advance a conversation step")
	check(log.track("talk", "elder_bai"), "talking to Elder Bai advances the quest")
	check(log.current_kind() == "kill", "the next step asks for kills")

	log.track("kill", "beast")
	log.track("kill", "beast")
	check(log.step_index == 1, "partial kill progress does not advance")
	check(log.objective_text().contains("2/3"), "objective text shows progress")
	log.track("kill", "beast")
	check(log.current_kind() == "collect", "three kills advance the quest")

	log.track("collect", "spirit_herb")
	check(log.step_index == 2, "partial herb progress does not advance")
	log.track("collect", "spirit_herb")
	check(log.current_kind() == "channel", "two herbs advance the quest")

	log.track("channel", "shrine")
	check(log.current_kind() == "return", "attuning advances the quest")
	check(log.track("return", "elder_bai"), "returning to Elder Bai completes the quest")
	check(log.completed, "quest is marked complete")
	check(log.objective_text().length() > 0, "completed quest has status text")

	var copy := QuestLog.new()
	copy.from_dict(log.to_dict())
	check(copy.completed and copy.step_index == log.step_index, "quest state round-trips through a save dictionary")


# ---------------------------------------------------------- hidden realms ----

func _hidden_realm_tests() -> void:
	print("[realms] the tomb generates, connects and fills")
	var realm := HiddenRealm.new()
	add_child(realm)
	realm.generate(4242)

	check(realm.cells.size() == 20, "template lays out a 5x4 room grid")
	check(realm.links.size() >= 19, "corridors form a spanning tree plus loops")
	check(realm.all_rooms_reachable(), "every room is reachable from the entry")
	check(realm.spawn_points.size() >= 10, "combat rooms are populated")
	check(realm.hazards.size() > 0, "hazards are placed")
	check(realm.hazard_dps_at(realm.hazards[0]["rect"].get_center()) > 0.0, "hazards report damage at their position")
	check(realm.hazard_dps_at(Vector2(-99999, -99999)) == 0.0, "safe ground reports no hazard damage")

	var has_altar := false
	var has_exit := false
	var chests := 0
	for node in realm.interactables:
		if node.id == "realm.altar":
			has_altar = true
		elif node.id == "realm.exit":
			has_exit = true
		elif String(node.id).begins_with("realm.chest"):
			chests += 1
	check(has_altar, "the inheritance altar exists")
	check(has_exit, "an exit always exists")
	check(chests >= 2, "treasure rooms hold chests")

	var bounds: Rect2 = realm.world_bounds()
	check(bounds.size.x >= HiddenRealm.ROOM_W * HiddenRealm.COLS, "realm bounds cover the whole room grid")
	check(bounds.position.x <= -HiddenRealm.ROOM_W * 0.5, "realm bounds include the leftmost room")
	check(realm.interactables[0].get_parent() == realm, "standalone realms own their entities")

	var twin := HiddenRealm.new()
	add_child(twin)
	twin.generate(4242)
	check(JSON.stringify(realm.links) == JSON.stringify(twin.links), "same seed rebuilds the same corridors")
	var same_kinds := true
	for cell in realm.cells:
		if String(realm.kinds[cell]) != String(twin.kinds.get(cell, "")):
			same_kinds = false
			break
	check(same_kinds, "same seed rebuilds the same room roles")

	realm.queue_free()
	twin.queue_free()


# ------------------------------------------------------------------- save ----

func _save_tests() -> void:
	print("[save] atomic writes, checksums, backup recovery")
	var slot := 97
	Save.delete_slot(slot)

	check(not Save.has_save(slot), "empty slot reports no save")
	check(Save.load_game(slot).is_empty(), "loading an empty slot returns empty")

	var first := {"marker": 1, "player": {"hp": 42.5, "passives": ["passive.iron_bone"], "cultivation": {"realm": 2, "sublevel": 4}}}
	check(Save.save_game(slot, first.duplicate(true)), "save file is written")
	var loaded: Dictionary = Save.load_game(slot)
	check(int(loaded.get("marker", 0)) == 1, "saved data loads back")
	check(int(loaded.get("schema", 0)) == Save.CURRENT_SCHEMA, "save carries a schema version")
	check(approx(float(loaded.get("player", {}).get("hp", 0.0)), 42.5), "nested values survive the round trip")
	check((loaded.get("player", {}).get("passives", []) as Array).has("passive.iron_bone"), "passive lists survive the round trip")

	check(Save.save_game(slot, {"marker": 2}), "second save is written")
	check(FileAccess.file_exists(Save.backup_path(slot, 1)), "saving rotates a backup")

	var file := FileAccess.open(Save.path_for(slot), FileAccess.WRITE)
	file.store_string("{ this is not a valid save")
	file.close()
	var recovered: Dictionary = Save.load_game(slot)
	check(int(recovered.get("marker", 0)) == 1, "corrupt newest save falls back to the valid backup")

	Save.delete_slot(slot)
	check(not Save.has_save(slot), "slot can be deleted")

	# --- schema migration: hand-write a legacy payload and prove it upgrades ---
	var legacy_slot := 96
	Save.delete_slot(legacy_slot)
	var legacy := {"schema": 0, "player": {"hp": 55.0}, "clock": {"day": 3}}
	var legacy_body := JSON.stringify(legacy)
	var legacy_payload := JSON.stringify({"checksum": legacy_body.sha256_text(), "body": legacy_body})
	var legacy_file := FileAccess.open(Save.path_for(legacy_slot), FileAccess.WRITE)
	legacy_file.store_string(legacy_payload)
	legacy_file.close()

	var migrated: Dictionary = Save.load_game(legacy_slot)
	check(int(migrated.get("schema", -1)) == Save.CURRENT_SCHEMA, "a legacy save migrates to the current schema")
	check(int(migrated.get("migrated_from", -1)) == 0, "migration records the source schema")
	check(approx(float(migrated.get("player", {}).get("hp", 0.0)), 55.0), "migration preserves existing data")
	Save.delete_slot(legacy_slot)
	check(not Save.has_save(legacy_slot), "migration test slot is cleaned up")


# --------------------------------------------------------------- rendering ----

func _camera_tests() -> void:
	print("[camera] bounds clamping and zoom levels")
	var area := Rect2(0, 0, 12288, 12288)
	var view := Vector2(1280, 720)
	check(CameraRig.clamp_center(Vector2(6000, 6000), view, 1.0, area) == Vector2(6000, 6000), "a centre inside the bounds is untouched")
	var edge := CameraRig.clamp_center(Vector2(-500, 20000), view, 1.0, area)
	check(approx(edge.x, 640.0), "the camera stops half a screen from the left edge")
	check(approx(edge.y, 12288.0 - 360.0), "the camera stops half a screen from the bottom edge")
	var zoomed := CameraRig.clamp_center(Vector2(-500, 20000), view, 2.0, area)
	check(approx(zoomed.x, 320.0), "zooming in shrinks the clamp margin")
	var small := CameraRig.clamp_center(Vector2(900, -900), view, 1.0, Rect2(0, 0, 400, 300))
	check(small == Vector2(200, 150), "an area smaller than the view is centred")
	check(CameraRig.clamp_center(Vector2(-500, -500), view, 0.75, area).x > 640.0, "zooming out keeps the larger view inside the bounds")

	var rig := CameraRig.new()
	add_child(rig)
	rig.set_bounds(area)
	check(rig.limit_left == 0 and rig.limit_right == 12288, "bounds become horizontal camera limits")
	check(rig.limit_top == 0 and rig.limit_bottom == 12288, "bounds become vertical camera limits")
	check(approx(rig.zoom.x, 1.0), "the default zoom is the authored field of view")
	rig.zoom_in()
	check(approx(rig.zoom.x, 1.25), "zoom_in steps to the next level")
	rig.zoom_out()
	check(approx(rig.zoom.x, 1.0), "zoom_out steps back")
	rig.set_zoom_index(999)
	check(approx(rig.zoom.x, CameraRig.MAX_ZOOM), "zoom clamps at the maximum level")
	rig.set_zoom_index(-999)
	check(approx(rig.zoom.x, CameraRig.MIN_ZOOM), "zoom clamps at the minimum level")
	rig.set_bounds(Rect2(100, 50, 800, 600))
	check(rig.limit_left == 100 and rig.limit_bottom == 650, "bounds can be swapped for another context")
	rig.queue_free()


func _display_tests() -> void:
	print("[display] resolution scaling policy")
	check(DisplayPolicy.BASE_SIZE == Vector2i(1280, 720), "the game is authored at 1280x720")
	check(DisplayPolicy.integer_scale(Vector2i(2560, 1440)) == 2, "1440p is an exact 2x multiple")
	check(DisplayPolicy.integer_scale(Vector2i(3840, 2160)) == 3, "4K is an exact 3x multiple")
	check(DisplayPolicy.integer_scale(Vector2i(1920, 1080)) == 1, "1.5x is not an integer multiple")
	check(DisplayPolicy.integer_scale(Vector2i(640, 360)) == 1, "a small window never scales to zero")
	check(DisplayPolicy.uses_integer_stretch(Vector2i(2560, 1440)), "exact multiples use integer stretching")
	check(not DisplayPolicy.uses_integer_stretch(Vector2i(1920, 1080)), "fractional sizes do not")
	check(not DisplayPolicy.uses_integer_stretch(Vector2i(1280, 720)), "1x does not need integer stretching")
	check(DisplayPolicy.stretch_for(Vector2i(2560, 1440)) == Window.CONTENT_SCALE_STRETCH_INTEGER, "the stretch mode follows the multiple")
	check(DisplayPolicy.stretch_for(Vector2i(1600, 900)) == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "odd sizes stretch fractionally")
	check(DisplayPolicy.min_window_size() == Vector2i(960, 540), "the window has a playable minimum size")

	var window := get_window()
	DisplayPolicy.apply(window)
	check(window.content_scale_size == DisplayPolicy.BASE_SIZE, "apply sets the canvas base size")
	check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "apply keeps canvas_items stretching")
	check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "apply shows more world instead of bars")
	check(window.min_size == DisplayPolicy.min_window_size(), "apply sets the minimum window size")


func _lighting_tests() -> void:
	print("[lighting] clock-driven ambient light and point lights")
	var was_paused := Clock.paused
	Clock.paused = true
	check(Clock.ambient_for_hour(12.0) == Color(1, 1, 1), "midday ambient light is neutral")
	check(Clock.ambient_for_hour(23.0).b > Clock.ambient_for_hour(23.0).r, "night ambient light is cold")
	check(Clock.ambient_for_hour(19.0).r > Clock.ambient_for_hour(19.0).b, "dusk ambient light is warm")
	check(Clock.ambient_for_hour(30.0) == Clock.ambient_for_hour(6.0), "the tint wraps past midnight")
	check(WorldLighting.light_energy_for_hour(12.0) == 0.0, "point lights are off at noon")
	check(WorldLighting.light_energy_for_hour(23.0) == 1.0, "point lights are full at midnight")
	var dawn := WorldLighting.light_energy_for_hour(6.0)
	check(dawn > 0.0 and dawn < 1.0, "point lights fade out through dawn")
	var dusk := WorldLighting.light_energy_for_hour(18.5)
	check(dusk > 0.0 and dusk < 1.0, "point lights fade in through dusk")

	Clock.hour = 23.0
	var lighting := WorldLighting.new()
	add_child(lighting)
	lighting.refresh()
	check(lighting.color == Clock.ambient_for_hour(23.0), "the canvas modulate follows the clock")
	var holder := Node2D.new()
	add_child(holder)
	var light := lighting.add_light(holder, Vector2(40, 40), Color("#ffd9a0"), 200.0, 1.0)
	check(lighting.lights.size() == 1, "lights register with the lighting rig")
	check(approx(light.energy, 1.0), "a light takes the night energy")
	check(light.texture != null, "point lights have a generated falloff texture")
	Clock.hour = 12.0
	lighting.refresh()
	check(approx(light.energy, 0.0), "point lights switch off by day")
	Clock.hour = 8.0
	lighting.queue_free()
	holder.queue_free()
	Clock.paused = was_paused


func _occlusion_tests() -> void:
	print("[occlusion] roofs fade for a player behind them")
	var footprint := Rect2(Vector2(100, 100), Vector2(160, 90))
	check(Occluder.occlusion_region(footprint, 40.0) == Rect2(Vector2(100, 60), Vector2(160, 130)), "the occlusion region includes the roof slope")
	check(approx(Occluder.alpha_for(Vector2(180, 140), footprint, 40.0), Occluder.MIN_ALPHA), "a player inside the footprint sees through the roof")
	check(approx(Occluder.alpha_for(Vector2(180, 80), footprint, 40.0), Occluder.MIN_ALPHA), "a player under the roof slope is occluded")
	check(approx(Occluder.alpha_for(Vector2(180, 700), footprint, 40.0), 1.0), "a player below the building is not occluded")
	check(approx(Occluder.alpha_for(Vector2(180, 10), footprint, 40.0), 1.0), "a player well above the roof is not occluded")
	var edge := Occluder.alpha_for(Vector2(180, 48), footprint, 40.0)
	check(edge > Occluder.MIN_ALPHA and edge < 1.0, "the fade ramps across the margin")
	check(Occluder.alpha_for(Vector2(180, 52), footprint, 40.0) < Occluder.alpha_for(Vector2(180, 40), footprint, 40.0), "the ramp gets more opaque with distance")


func _sorting_tests() -> void:
	print("[sorting] streamed props are Y-sorted siblings of the world")
	var holder := Node2D.new()
	holder.name = "SortHolder"
	holder.y_sort_enabled = true
	add_child(holder)
	var manager := ChunkManager.new()
	add_child(manager)
	manager.configure(12345)
	manager.set_prop_parent(holder)
	manager.stream_around(Vector2(5632, 5632))
	check(manager.chunk_count() == 25, "chunks still stream in a ring with props enabled")
	check(manager.props.size() == 25 * ChunkManager.ProvinceChunk.FEATURES, "every chunk feature becomes a prop (%d)" % manager.props.size())
	var first_prop = manager.props[0]
	check(first_prop.get_parent() == holder, "props live in the Y-sorted layer, not inside a chunk")
	check(String(first_prop.kind) != "", "props keep their drawn kind")
	var chunks_with_props := 0
	for coord in manager.chunks.keys():
		var chunk = manager.chunks[coord]
		if chunk.props.size() > 0:
			chunks_with_props += 1
	check(chunks_with_props == 25, "each chunk owns its props so unloading frees them")
	manager.stream_around(Vector2(5632 + 3072, 5632))
	check(manager.props.size() == 25 * ChunkManager.ProvinceChunk.FEATURES, "unloading a chunk frees exactly its own props")
	check(manager.streamed_chunks == 40, "prop streaming does not change chunk load counts")
	manager.set_props_visible(false)
	var visible_props := 0
	for prop in manager.props:
		if prop.visible:
			visible_props += 1
	check(visible_props == 0, "props hide with the overworld")
	manager.stream_around(Vector2(5632 + 6144, 5632))
	check(manager.props[0].visible == false, "props loaded while hidden stay hidden")
	manager.queue_free()
	holder.queue_free()


# --------------------------------------------------------------- movement ----

func _motion_tests() -> void:
	print("[motion] acceleration curve, braking, sprint and stick shaping")
	var target := Vector2(200, 0)
	var velocity := Motion.approach(Vector2.ZERO, target, 1200.0, 2000.0, 0.05)
	check(approx(velocity.x, 60.0, 0.01), "acceleration integrates at the given rate")
	velocity = Motion.approach(velocity, target, 1200.0, 2000.0, 1.0)
	check(approx(velocity.length(), 200.0, 0.01), "velocity never overshoots the target speed")
	velocity = Motion.approach(velocity, Vector2.ZERO, 1200.0, 2000.0, 0.05)
	check(approx(velocity.x, 100.0, 0.01), "releasing input decelerates at the deceleration rate")
	velocity = Motion.approach(velocity, Vector2.ZERO, 1200.0, 2000.0, 1.0)
	check(velocity == Vector2.ZERO, "deceleration stops exactly at rest")
	var reversing := Motion.approach(Vector2(200, 0), Vector2(-200, 0), 1200.0, 2000.0, 0.05)
	check(approx(reversing.x, 100.0, 0.01), "reversing brakes at the deceleration rate")
	check(Motion.approach(Vector2(10, 0), target, 1200.0, 2000.0, 0.0) == Vector2(10, 0), "a zero-length frame changes nothing")
	check(Motion.approach(Vector2.ZERO, target, 0.0, 0.0, 1.0) == Vector2.ZERO, "zero rates leave velocity alone")

	check(approx(Motion.sprint_speed(100.0, true), 145.0, 0.01), "sprinting multiplies move speed")
	check(approx(Motion.sprint_speed(100.0, false), 100.0), "walking uses the base speed")
	check(Motion.SPRINT_MULTIPLIER > 1.0, "sprint is faster than walking")

	check(Motion.deadzone(Vector2(0.1, 0.0), 0.2) == Vector2.ZERO, "stick noise inside the deadzone is ignored")
	check(approx(Motion.deadzone(Vector2(1.0, 0.0), 0.2).x, 1.0), "a full stick reaches full strength")
	var half := Motion.deadzone(Vector2(0.6, 0.0), 0.2)
	check(half.x > 0.0 and half.x < 1.0, "stick travel is rescaled past the deadzone")
	check(Motion.deadzone(Vector2(0.0, -0.6), 0.2).y < 0.0, "the deadzone keeps the stick direction")
	check(Motion.deadzone(Vector2(2.0, 0.0), 0.2).length() <= 1.0, "stick output is capped at full strength")


func _controller_tests() -> void:
	print("[input] gamepad bindings beside the keyboard")
	check(InputMap.has_action("sprint"), "sprint is a rebindable action")
	check(InputMap.has_action("aim_right"), "aiming has its own actions")
	var stick := false
	for ev in InputMap.action_get_events("move_right"):
		if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_LEFT_X and ev.axis_value > 0.0:
			stick = true
	check(stick, "the left stick drives movement")
	var aim_stick := false
	for ev in InputMap.action_get_events("aim_right"):
		if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_RIGHT_X:
			aim_stick = true
	check(aim_stick, "the right stick drives aiming")

	var pad_attack := false
	var key_attack := false
	for ev in InputMap.action_get_events("attack"):
		if ev is InputEventJoypadButton:
			pad_attack = true
		elif ev is InputEventMouseButton:
			key_attack = true
	check(pad_attack and key_attack, "attack works from mouse and gamepad")

	var pad_dodge := false
	for ev in InputMap.action_get_events("dodge"):
		if ev is InputEventJoypadButton:
			pad_dodge = true
	check(pad_dodge, "dodge has a gamepad button")

	Settings.rebind("dodge", KEY_CTRL)
	var kept_pad := false
	for ev in InputMap.action_get_events("dodge"):
		if ev is InputEventJoypadButton:
			kept_pad = true
	check(kept_pad, "rebinding a key keeps the gamepad button")
	Settings.rebind("dodge", KEY_SPACE)
	check(Settings.action_keycode("dodge") == OS.get_keycode_string(KEY_SPACE), "dodge is restored after the rebind probe")


# -------------------------------------------------------------- animation ----

func _animation_tests() -> void:
	print("[animation] clip selection, clocks and poses")
	check(Animator.state_for(0.0, false, false, false, false, false, false) == "idle", "standing still is idle")
	check(Animator.state_for(0.1, false, false, false, false, false, false) == "walk", "slow movement walks")
	check(Animator.state_for(0.8, false, false, false, false, false, false) == "run", "fast movement runs")
	check(Animator.state_for(0.8, true, false, false, false, false, false) == "sprint", "sprinting overrides running")
	check(Animator.state_for(0.0, true, false, false, false, false, false) == "idle", "sprint needs movement")
	check(Animator.state_for(0.0, false, true, false, false, false, false) == "attack", "attacking overrides idle")
	check(Animator.state_for(0.8, true, true, false, false, false, false) == "attack", "attacking overrides sprint")
	check(Animator.state_for(0.0, false, true, true, false, false, false) == "dodge", "dodging overrides attacking")
	check(Animator.state_for(0.0, false, true, false, true, false, false) == "hurt", "hurt overrides attacking")
	check(Animator.state_for(0.0, false, false, false, false, true, false) == "meditate", "meditation has its own clip")
	check(Animator.state_for(0.0, false, false, false, false, false, true) == "dead", "death has absolute priority")

	var animator := Animator.new()
	check(animator.update(0.5, 0.0, false, false, false, false, false, false) == "idle", "the animator starts idle")
	check(approx(animator.time, 0.5), "time accumulates inside a clip")
	animator.update(0.25, 0.8, false, false, false, false, false, false)
	check(animator.state == "run", "the animator switches clips from speed")
	check(approx(animator.time, 0.0), "changing clips rewinds the clock")
	check(animator.previous == "idle", "the previous clip is recorded")
	animator.update(0.1, 0.8, false, false, false, false, false, false)
	check(approx(animator.time, 0.1), "time resumes after the switch")

	var idle := Animator.pose("idle", 0.4, 0.0)
	var run := Animator.pose("run", 0.4, 0.8)
	var sprint := Animator.pose("sprint", 0.4, 1.0)
	var idle_bob: Vector2 = idle["bob"]
	var run_bob: Vector2 = run["bob"]
	var sprint_bob: Vector2 = sprint["bob"]
	check(absf(idle_bob.y) < absf(run_bob.y) + 0.001, "running bobs more than idling")
	check(absf(sprint_bob.y) >= absf(run_bob.y), "sprinting bobs at least as much as running")
	check(float(sprint["lean"]) > float(run["lean"]), "sprinting leans further forward")
	check(approx(float(idle["swing"]), 0.0, 0.01), "idling does not swing the limbs")

	var dodge := Animator.pose("dodge", 0.2, 0.0)
	var dodge_squash: Vector2 = dodge["squash"]
	check(dodge_squash.x > 1.0 and dodge_squash.y < 1.0, "dodging squashes the body")
	var dead := Animator.pose("dead", 0.2, 0.0)
	var dead_squash: Vector2 = dead["squash"]
	check(dead_squash.y < 0.6, "the death pose collapses the body")
	for clip in Animator.STATES:
		var p := Animator.pose(String(clip), 0.7, 0.6)
		var p_bob: Vector2 = p["bob"]
		check(is_finite(p_bob.x) and is_finite(p_bob.y) and is_finite(float(p["swing"])), "clip %s produces a finite pose" % clip)

	check(approx(Animator.attack_swing("startup", 0.0), 0.0), "the wind-up starts neutral")
	check(Animator.attack_swing("startup", 1.0) <= -0.9, "the wind-up ends drawn back")
	check(Animator.attack_swing("active", 0.0) > 0.5, "the strike snaps forward on the first active frame")
	check(Animator.attack_swing("active", 0.5) > Animator.attack_swing("startup", 0.5), "active frames are ahead of the wind-up")
	check(approx(Animator.attack_swing("recovery", 1.0), 0.0), "recovery returns to neutral")
	check(absf(Animator.attack_swing("active", 2.0)) <= 1.0, "swing is clamped at the ends")
	check(approx(Animator.attack_swing("idle", 0.5), 0.0), "a non-attack phase has no swing")


# ------------------------------------------------------------- interaction ----

func _interaction_tests() -> void:
	print("[interaction] kinds, prompts and one-shot state")
	var herb := Interactable.new()
	herb.setup(Interactable.Kind.HERB, "herb.test", "Spirit Herb")
	check(herb.can_interact(), "a fresh herb can be gathered")
	herb.used = true
	check(not herb.can_interact(), "a picked herb is no longer offered")
	check(herb.display_label() == "Picked clean", "a picked herb reads as picked clean")

	var chest := Interactable.new()
	chest.setup(Interactable.Kind.CHEST, "chest.test", "Sealed Chest")
	chest.used = true
	check(not chest.can_interact(), "a looted chest stops offering a prompt")

	var container := Interactable.new()
	container.setup_container("crate.test", "Market crate", 77)
	check(container.kind == Interactable.Kind.CONTAINER, "containers have their own kind")
	check(container.can_interact(), "a container offers a search")
	check(container.item_seed == 77, "a container keeps its loot seed")
	container.used = true
	check(not container.can_interact(), "a searched container is spent")
	check(container.display_label().contains("Searched"), "a searched container says so")

	var manual := Interactable.new()
	manual.setup_manual("manual.test", "Forbidden manual", "tech.blood.crimson_moon")
	check(manual.kind == Interactable.Kind.MANUAL, "manuals have their own kind")
	check(manual.manual_technique == "tech.blood.crimson_moon", "a manual carries its technique id")
	check(not DB.technique(manual.manual_technique).is_empty(), "manual techniques exist in the database")
	check(bool(DB.technique(manual.manual_technique).get("hidden", false)), "the manual teaches a hidden technique")
	manual.used = true
	check(not manual.can_interact(), "a studied manual is spent")

	var door := Interactable.new()
	door.setup_door("door.test", "Sect Hall door", null)
	check(door.can_interact(), "a door always offers a prompt")
	check(door.display_label().contains("open"), "a closed door offers to open")
	door.open = true
	check(door.display_label().contains("close"), "an open door offers to close")
	check(door.can_interact(), "an open door can still be closed")

	var stele := Interactable.new()
	stele.setup_examine("stele.test", "Stele", "The stele is worn.")
	check(stele.examine_text == "The stele is worn.", "examination keeps its text")
	check(stele.can_interact(), "examination is repeatable")

	var building := Building.new()
	building.setup(Vector2(100, 100), Vector2(160, 90), Color.WHITE, Color.GRAY, "test_hall")
	check(approx(building.occlusion_target(Vector2(180, 700)), 1.0), "a closed building is opaque from below")
	building.set_interior_open(true)
	check(approx(building.occlusion_target(Vector2(180, 700)), Occluder.MIN_ALPHA), "an open interior stays transparent from any angle")

	herb.free()
	chest.free()
	container.free()
	manual.free()
	door.free()
	stele.free()
	building.free()


# ----------------------------------------------------------------- climate ----

func _climate_tests() -> void:
	print("[climate] seasons, weather determinism and effects")
	check(Climate.SEASON_DAYS == 30, "a season is thirty days")
	check(Climate.season_for_day(1) == Climate.Season.SPRING, "day one is spring")
	check(Climate.season_for_day(30) == Climate.Season.SPRING, "spring runs to day thirty")
	check(Climate.season_for_day(31) == Climate.Season.SUMMER, "summer follows spring")
	check(Climate.season_for_day(61) == Climate.Season.AUTUMN, "autumn follows summer")
	check(Climate.season_for_day(91) == Climate.Season.WINTER, "winter follows autumn")
	check(Climate.season_for_day(121) == Climate.Season.SPRING, "seasons cycle in the second year")
	check(Climate.season_for_day(0) == Climate.Season.SPRING, "day zero is treated as day one")
	check(Climate.season_name(Climate.Season.WINTER) == "Winter", "seasons have names")

	check(Climate.block_for_hour(0.0) == 0, "midnight opens the first block")
	check(Climate.block_for_hour(5.9) == 0, "the first block holds until six")
	check(Climate.block_for_hour(6.0) == 1, "six starts the second block")
	check(Climate.block_for_hour(23.9) == 3, "the last block ends at midnight")

	var a := Climate.weather_for(3, 9.0)
	var b := Climate.weather_for(3, 9.0)
	check(String(a["kind"]) == String(b["kind"]), "the same hour gives the same weather")
	check(approx(float(a["intensity"]), float(b["intensity"])), "the same hour gives the same intensity")
	check(Climate.KINDS.has(String(a["kind"])), "weather kinds come from the known list")
	check(int(a["season"]) == Climate.season_for_day(3), "weather reports its season")
	check(String(Climate.weather_for(3, 8.0)["kind"]) == String(Climate.weather_for(3, 9.5)["kind"]), "weather holds inside a six-hour block")

	var spring := {}
	for day in range(1, 31):
		for block in 4:
			spring[String(Climate.weather_for(day, block * 6.0)["kind"])] = true
	check(spring.size() >= 4, "a month of spring brings %d kinds of weather" % spring.size())

	var winter := {}
	for day in range(91, 121):
		for block in 4:
			winter[String(Climate.weather_for(day, block * 6.0)["kind"])] = true
	check(not winter.has("storm"), "winter never storms")
	check(not winter.has("rain"), "winter precipitation falls as snow")
	check(winter.has("snow"), "winter brings snow")

	var saved_seed: int = Rng.world_seed
	var first := ""
	var second := ""
	for day in range(1, 15):
		first += String(Climate.weather_for(day, 0.0)["kind"])
	Rng.set_world_seed(saved_seed + 17)
	for day in range(1, 15):
		second += String(Climate.weather_for(day, 0.0)["kind"])
	Rng.set_world_seed(saved_seed)
	check(first != second, "a different world seed gives different weather")

	check(approx(Climate.cultivation_bonus({"kind": "clear", "intensity": 0.0}), 1.0), "clear weather leaves cultivation alone")
	check(approx(Climate.cultivation_bonus({"kind": "rain", "intensity": 1.0}), 0.9), "full rain thins the Qi")
	check(Climate.cultivation_bonus({"kind": "storm", "intensity": 1.0}) > 1.0, "storms charge the air")
	check(approx(Climate.cultivation_bonus({"kind": "rain", "intensity": 0.0}), 1.0), "a mild sky has no effect")

	var white := Color(1, 1, 1)
	check(Climate.lighting_modulate(white, {"kind": "clear", "intensity": 1.0}) == white, "clear weather keeps the ambient tint")
	var storm_light := Climate.lighting_modulate(white, {"kind": "storm", "intensity": 1.0})
	check(storm_light.r < 0.7 and storm_light.b > storm_light.r, "storms darken and cool the light")
	check(Climate.lighting_modulate(white, {"kind": "snow", "intensity": 1.0}).b > 0.9, "snow light stays bright")

	check(Climate.flash_strength("clear", 1.0) == 0.0, "only storms flash")
	check(Climate.flash_strength("storm", 0.0) == 1.0, "a storm flash starts at full strength")
	check(Climate.flash_strength("storm", 3.0) == 0.0, "flashes are brief")

	var saved_day: int = Clock.day
	var saved_hour: float = Clock.hour
	Clock.paused = true
	Clock.day = 91
	Clock.hour = 3.0
	Weather.refresh(true)
	check(Weather.season() == Climate.Season.WINTER, "the weather autoload reads the calendar")
	check(Weather.season_name() == "Winter", "the weather autoload names the season")
	check(Weather.label().contains("Winter") and Weather.label().contains(Weather.kind().capitalize()), "the weather label names season and sky")
	check(int(Weather.current["day"]) == 91, "the weather autoload tracks the day")
	Clock.day = saved_day
	Clock.hour = saved_hour
	Clock.paused = false
	Weather.refresh(true)
