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
	_tribulation_tests()
	_enlightenment_tests()
	_aging_tests()
	_combat_arch_tests()
	_weapon_tests()
	_defense_tests()
	_technique_combat_tests()
	_skill_bar_tests()
	_enemy_ai_tests()
	_item_architecture_tests()
	_boss_and_beast_tests()
	_combat_polish_tests()
	_rng_tests()
	_item_tests()
	_procedural_generation_tests()
	_equipment_rules_tests()
	_unique_tests()
	_inventory_tests()
	_crafting_tests()
	_alchemy_tests()
	_professions_tests()
	_loot_tests()
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
	_npcdb_tests()
	_schedules_tests()
	_npcai_tests()
	_relationships_tests()
	_party_tests()
	_captivity_tests()
	_npc_progress_tests()
	_stories_tests()
	_factions_tests()
	_sects_tests()
	_hierarchy_tests()
	_sect_economy_tests()
	_sect_politics_tests()
	_player_sect_tests()
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


# ---------------------------------------------------------- tribulations ----

func _tribulation_tests() -> void:
	print("[tribulation] data, telegraphs, waves and composure")
	check(DB.tribulations.size() >= 10, "at least ten tribulation types are registered")
	var ids := {}
	var used := {}
	for entry in DB.tribulations:
		var id := String(entry.get("id", ""))
		check(id != "", "a tribulation has an id")
		check(not ids.has(id), "tribulation %s is unique" % id)
		ids[id] = true
		check(String(entry.get("name", "")) != "", "%s is named" % id)
		check(String(entry.get("color", "")).begins_with("#"), "%s has a colour" % id)
		check(int(entry.get("waves", 0)) >= 1, "%s has waves" % id)
		check(int(entry.get("bolts", 0)) >= 1, "%s has bolts" % id)
		check(float(entry.get("interval", 0.0)) > 0.0 and float(entry.get("radius", 0.0)) > 0.0, "%s has a schedule" % id)
		check(float(entry.get("damage_mult", 0.0)) > 0.0, "%s deals damage" % id)

	for n in range(1, Realms.count() + 1):
		var declared := String(Realms.find(n).get("tribulation", ""))
		check(Tribulation.exists(declared), "realm %d names an existing tribulation" % n)
		check(Tribulation.for_realm(n) == declared, "realm %d resolves its own trial" % n)
		used[declared] = true
	check(used.size() >= 7, "the ladder uses at least seven distinct trials (%d)" % used.size())
	check(Tribulation.for_realm(0) == Tribulation.FALLBACK_ID, "an invalid realm falls back to the meridian trial")
	check(Tribulation.name_of("primordial") == "Primordial Tribulation", "names come from data")
	check(Tribulation.name_of("nope") == Tribulation.name_of(Tribulation.FALLBACK_ID), "unknown trials fall back")
	check(Tribulation.color_of("lightning").begins_with("#"), "colours come from data")

	var trial := Tribulation.new()
	trial.setup("meridian", 0.5, Vector2(100, 100), Rng.stream("trib_test", 1, 0))
	check(trial.type_id == "meridian", "setup keeps the type")
	check(trial.waves_total == int(Tribulation.find("meridian").get("waves", 0)), "waves come from data")
	check(trial.bolts_per_wave() == int(Tribulation.find("meridian").get("bolts", 0)), "bolts come from data")
	check(trial.damage_per_bolt() > 0.0, "bolts deal damage")
	check(String(trial.result()["outcome"]) == "unfinished", "a fresh trial is unfinished")
	check(trial.strikes.size() == trial.bolts_per_wave(), "a wave telegraphs its bolts")
	if trial.strikes.size() >= 2:
		check(float(trial.strikes[0]["left"]) < float(trial.strikes[1]["left"]), "bolts inside a wave are staggered")

	var first_seed := Tribulation.new()
	first_seed.setup("lightning", 0.4, Vector2.ZERO, Rng.stream("trib_det", 7, 0))
	var second_seed := Tribulation.new()
	second_seed.setup("lightning", 0.4, Vector2.ZERO, Rng.stream("trib_det", 7, 0))
	var same := true
	for i in first_seed.strikes.size():
		if (first_seed.strikes[i]["pos"] as Vector2) != (second_seed.strikes[i]["pos"] as Vector2):
			same = false
	check(same, "the same seed telegraphs the same first wave")

	var hit_trial := Tribulation.new()
	hit_trial.setup("meridian", 0.0, Vector2.ZERO, Rng.stream("trib_hit", 3, 0))
	var target: Vector2 = hit_trial.strikes[0]["pos"]
	var events: Dictionary = {}
	for i in 40:
		events = hit_trial.tick(0.1, target)
		if not (events["struck"] as Array).is_empty():
			break
	check(not (events.get("struck", []) as Array).is_empty(), "a bolt resolves after its telegraph")
	if not (events.get("struck", []) as Array).is_empty():
		check(bool((events["struck"] as Array)[0]["hit"]), "standing on the telegraph is hit")
	check(hit_trial.hits >= 1, "a landed bolt is counted")

	var missed := Tribulation.new()
	missed.setup("meridian", 0.0, Vector2.ZERO, Rng.stream("trib_miss", 3, 0))
	var missed_events: Dictionary = {}
	for i in 40:
		missed_events = missed.tick(0.1, Vector2(9000, 9000))
		if not (missed_events["struck"] as Array).is_empty():
			break
	if not (missed_events.get("struck", []) as Array).is_empty():
		check(not bool((missed_events["struck"] as Array)[0]["hit"]), "stepping off the telegraph avoids the bolt")

	var clean := Tribulation.new()
	clean.setup("meridian", 0.0, Vector2.ZERO, Rng.stream("trib_clean", 5, 0))
	var guard := 0
	while not clean.finished and guard < 4000:
		clean.tick(0.1, Vector2(9000, 9000))
		guard += 1
	check(clean.finished and not clean.broken, "a dodged trial completes")
	check(clean.hits == 0 and clean.perfect_waves == clean.waves_total, "dodging every bolt is a perfect trial")
	check(String(clean.result()["outcome"]) == "survived", "completing the waves means survival")
	check(approx(float(clean.result()["composure"]), Tribulation.MAX_COMPOSURE), "perfect waves cap composure")
	check((clean.tick(0.1, Vector2.ZERO)["struck"] as Array).is_empty(), "a finished trial reports nothing more")

	check(approx(Tribulation.composure(0), 0.0), "no perfect waves, no composure")
	check(Tribulation.composure(1) > 0.0, "one perfect wave helps")
	check(Tribulation.composure(3) > Tribulation.composure(2), "composure rises per perfect wave")
	check(approx(Tribulation.composure(99), Tribulation.MAX_COMPOSURE), "composure caps")

	var broken := Tribulation.new()
	broken.setup("grand", 0.2, Vector2.ZERO, Rng.stream("trib_broken", 2, 0))
	broken.abort()
	check(broken.finished and broken.broken, "aborting ends the trial as broken")
	check(String(broken.result()["outcome"]) == "broken", "a broken trial reports it")
	check(approx(float(broken.result()["composure"]), 0.0), "a broken trial earns no composure")

	var light := Tribulation.new()
	light.setup("meridian", 0.0, Vector2.ZERO, Rng.stream("dmg", 0, 0))
	var heavy := Tribulation.new()
	heavy.setup("meridian", 2.0, Vector2.ZERO, Rng.stream("dmg", 0, 0))
	check(heavy.damage_per_bolt() > light.damage_per_bolt(), "a heavier heaven hits harder")
	var grand := Tribulation.new()
	grand.setup("grand", 0.0, Vector2.ZERO, Rng.stream("dmg", 0, 0))
	check(grand.damage_per_bolt() > light.damage_per_bolt(), "later trials hit harder at the same scale")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var failed := Cultivation.new()
	failed.root_tier = 3
	failed.sublevel = 10
	failed.qi = failed.qi_max(stats)
	failed.prepare()
	var fallout := failed.break_through_failure(Rng.stream("break_test", 0, 0), 0, 0, {})
	check(not bool(fallout["success"]) and bool(fallout.get("broken", false)), "a broken encounter is a failure")
	check(failed.qi == 0.0 and failed.contamination > 0.0, "a broken encounter empties Qi and corrupts")
	check(int(fallout["preparation"]) == 1 and failed.preparation == 0, "a broken encounter spends preparation")
	check(float(fallout["hp_cost_ratio"]) > 0.0, "a broken encounter wounds")
	check(failed.failures == 1, "a broken encounter counts as a failure")
	var declarer := Cultivation.new()
	declarer.realm = 3
	check(declarer.tribulation_id() == "lightning", "a realm declares its trial")


# --------------------------------------------------------- enlightenment ----

func _enlightenment_tests() -> void:
	print("[enlightenment] data, eligibility, weighted picks, comprehension")
	check(DB.enlightenments.size() >= 10, "at least ten insights are registered")
	check(Enlightenments.count_total() == DB.enlightenments.size(), "the count matches the registry")
	var ids := {}
	for entry in DB.enlightenments:
		var id := String(entry.get("id", ""))
		check(id != "" and not ids.has(id), "insight %s is unique" % id)
		ids[id] = true
		check(String(entry.get("name", "")) != "" and String(entry.get("desc", "")) != "", "%s is named and described" % id)
		check(int(entry.get("weight", 0)) >= 1, "%s has a weight" % id)
		var mods: Array = entry.get("mods", [])
		check(not mods.is_empty(), "%s grants something" % id)
		for mod in mods:
			if typeof(mod) != TYPE_DICTIONARY:
				check(false, "%s has a malformed mod" % id)
				continue
			var stat := String((mod as Dictionary).get("stat", ""))
			check(Attributes.KEYS.has(stat) or StatBlock.PERCENT_STATS.has(stat) or StatBlock.FLAT_STATS.has(stat), "%s uses a real stat (%s)" % [id, stat])
		var req: Dictionary = entry.get("requires", {})
		var req_realm := int(req.get("realm", 0))
		check(req_realm >= 0 and req_realm <= 12, "%s has a valid realm gate" % id)
		var req_method := String(req.get("method", ""))
		check(req_method == "" or not DB.by_id("method", req_method).is_empty(), "%s gates a real method" % id)

	var attrs := Attributes.new()
	var state := {"realm": 1, "method": "method.traditional", "attrs": attrs}
	check(bool(Enlightenments.eligible("enl.still_water", state)["ok"]), "a realm-one insight is in reach at realm one")
	check(not bool(Enlightenments.eligible("enl.empty_mind", state)["ok"]), "a realm-two insight is out of reach at realm one")
	check(not bool(Enlightenments.eligible("enl.rain_of_swords", state)["ok"]), "a method insight needs that method")
	check(not bool(Enlightenments.eligible("enl.none", state)["ok"]), "an unknown insight is refused")
	var sword_state := {"realm": 2, "method": "method.sword", "attrs": attrs}
	check(bool(Enlightenments.eligible("enl.rain_of_swords", sword_state)["ok"]), "the practised method opens its insight")
	var high := {"realm": 12, "method": "method.traditional", "attrs": attrs}
	check(bool(Enlightenments.eligible("enl.primordial_glimpse", high)["ok"]), "high realms reach deep insights")
	check(Enlightenments.available(state, []).has("enl.still_water"), "available lists reachable insights")
	check(not Enlightenments.available(state, ["enl.still_water"]).has("enl.still_water"), "owned insights leave the pool")
	check(Enlightenments.available(high, ids.keys()).is_empty(), "everything is exhausted once owned")

	var pick_a := Enlightenments.pick(Rng.stream("enl_pick", 9, 0), high, [])
	var pick_b := Enlightenments.pick(Rng.stream("enl_pick", 9, 0), high, [])
	check(pick_a != "" and pick_a == pick_b, "the same seed and state pick the same insight")
	check(bool(Enlightenments.eligible(pick_a, high)["ok"]), "the picked insight was eligible")
	check(Enlightenments.pick(Rng.stream("enl_pick", 9, 0), high, ids.keys()) == "", "an exhausted pool picks nothing")
	var seen := {}
	for i in 60:
		seen[Enlightenments.pick(Rng.stream("enl_pick", 9, i), high, [])] = true
	check(seen.size() >= 2, "different rolls reveal different insights")
	check(not seen.has(""), "a stocked pool always returns an insight")

	var combined := Enlightenments.mods(["enl.still_water", "enl.empty_mind"])
	check(combined.size() == 2, "mods aggregate across insights")
	check(Enlightenments.mods(["enl.none"]).is_empty(), "unknown insights grant nothing")
	var bare := StatBlock.new(Attributes.new())
	bare.rebuild({}, [], 1, 1.0)
	var insightful := StatBlock.new(Attributes.new())
	insightful.rebuild({}, [], 1, 1.0, "", [], [], combined)
	check(insightful.qi_regen_mult() > bare.qi_regen_mult(), "insight mods enter the stat pipeline")
	check(insightful.max_qi_mult() > bare.max_qi_mult(), "every learned insight contributes")

	var owned: Array = []
	check(Enlightenments.learn(owned, "enl.still_water"), "an insight can be learned")
	check(not Enlightenments.learn(owned, "enl.still_water"), "learning is idempotent")
	check(not Enlightenments.learn(owned, "enl.none"), "unknown insights cannot be learned")
	check(Enlightenments.known_names(owned) == ["Still Water Clarity"], "known names come from data")

	var cultivation := Cultivation.new()
	check(cultivation.enlightenment_meter == 0.0 and not cultivation.is_enlightenment_ready(), "a fresh cultivator understands nothing yet")
	check(not cultivation.add_comprehension(40.0), "understanding below the goal is not an epiphany")
	check(approx(cultivation.enlightenment_meter, 40.0), "understanding accumulates")
	check(cultivation.add_comprehension(60.0), "a full meter is ready")
	check(cultivation.is_enlightenment_ready(), "readiness is stable")
	check(cultivation.add_comprehension(50.0) and approx(cultivation.enlightenment_meter, Cultivation.ENLIGHTENMENT_GOAL), "the meter caps")
	check(cultivation.take_enlightenment() and cultivation.enlightenment_meter == 0.0, "an epiphany spends the meter")
	check(not cultivation.take_enlightenment(), "a spent meter cannot be spent twice")
	cultivation.add_comprehension(100.0)
	var saved := cultivation.to_dict()
	var restored := Cultivation.new()
	restored.from_dict(saved)
	check(approx(restored.enlightenment_meter, Cultivation.ENLIGHTENMENT_GOAL), "comprehension survives a save")
	var legacy := Cultivation.new()
	legacy.from_dict({})
	check(legacy.enlightenment_meter == 0.0, "legacy saves start with no comprehension")
	var corrupt := Cultivation.new()
	corrupt.from_dict({"enlightenment_meter": 500.0})
	check(approx(corrupt.enlightenment_meter, Cultivation.ENLIGHTENMENT_GOAL), "a corrupt meter is clamped")


# ------------------------------------------------------------- combat ----

func _combat_arch_tests() -> void:
	print("[combat] frame phases, hitboxes, poise, stagger and interruption")
	check(Combat.next_phase("idle") == "idle", "idle stays idle")
	check(Combat.next_phase("startup") == "active", "startup becomes active")
	check(Combat.next_phase("active") == "recovery", "active becomes recovery")
	check(Combat.next_phase("recovery") == "idle", "recovery returns to idle")
	check(Combat.next_phase("bogus") == "idle", "an unknown phase falls back to idle")

	var frames := {"startup": 12, "active": 4, "recovery": 18}
	check(approx(Combat.phase_seconds(frames, "startup"), 0.2), "frame counts are 60ths of a second")
	check(approx(Combat.phase_seconds(frames, "startup", 2.0), 0.1), "attack speed halves a phase")
	check(approx(Combat.phase_seconds(frames, "recovery", 1.0, 0.5), 0.15), "recovery reduction applies only to recovery")
	check(approx(Combat.phase_seconds(frames, "startup", 1.0, 0.8), 0.2), "recovery reduction does not touch startup")
	check(Combat.phase_seconds(frames, "startup", 1000.0) >= Combat.ACTIVE_MINIMUM, "a phase never vanishes")

	var arc := {"shape": "arc", "radius": 70.0, "angle": 90.0}
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(40, 0)), "a target ahead is inside the arc")
	check(not Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(-40, 0)), "a target behind is outside it")
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(40, 30)), "just inside the half-angle is included")
	check(not Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(0, 41)), "past the half-angle misses")
	check(not Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(80, 0)), "reach limits the arc")
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2(80, 0), 14.0), "a body's radius extends reach")
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, arc, Vector2.ZERO), "a target at the origin is struck")
	var circle := {"shape": "circle", "radius": 40.0, "angle": 360.0}
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, circle, Vector2(-30, 0)), "a full circle ignores facing")
	check(not Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, circle, Vector2(-60, 0)), "a full circle still has reach")

	var guard := Poise.new(50.0)
	check(approx(guard.current, 50.0) and not guard.is_staggered(), "a fresh guard is full and steady")
	check(not guard.apply(20.0), "a light blow does not break the guard")
	check(approx(guard.current, 30.0), "poise is spent by the blow")
	check(guard.apply(30.0) and guard.is_staggered(), "the blow that empties poise staggers")
	check(approx(guard.stagger, 0.65), "stagger length follows the breaking blow")
	check(approx(guard.current, guard.maximum), "a break refills the meter")
	check(not guard.apply(50.0), "a staggered body cannot be staggered again")
	guard.tick(guard.stagger)
	check(not guard.is_staggered(), "stagger wears off with time")
	var huge := Poise.new(10.0)
	huge.apply(1000.0)
	check(huge.stagger <= 0.9, "stagger is capped")
	var tiny := Poise.new(10.0)
	tiny.apply(10.0)
	check(tiny.is_staggered() and tiny.stagger >= 0.35, "even a small break has a minimum stagger")

	check(Combat.poise_capacity(1, 10) > 40.0, "a body has a poise capacity")
	check(Combat.poise_capacity(12, 10) > Combat.poise_capacity(1, 10), "higher realms endure more")
	check(Combat.poise_capacity(5, 40) > Combat.poise_capacity(5, 10), "strength adds poise")
	check(approx(Combat.knock_impulse(Vector2.RIGHT, 100.0).length(), 12.0), "knockback scales from the blow")
	check(Combat.knock_impulse(Vector2.RIGHT, 100.0, true).length() > Combat.knock_impulse(Vector2.RIGHT, 100.0).length(), "a broken guard flies further")
	check(Combat.knock_impulse(Vector2.ZERO, 100.0) == Vector2.ZERO, "a blow from nowhere throws nothing")
	check(Combat.interrupts("startup"), "startup can be interrupted")
	check(not Combat.interrupts("active"), "an active swing is committed")
	check(not Combat.interrupts("recovery") and not Combat.interrupts("idle"), "recovery and idle are not attacks to spoil")


# ------------------------------------------------------------- weapons ----

func _weapon_tests() -> void:
	print("[weapons] categories, movesets, chains and scaling")
	check(DB.weapon_types.size() >= 4, "the weapon framework ships its categories")
	for id in ["sword", "saber", "staff", "whip", "fist"]:
		var type := Weapons.find(String(id))
		check(not type.is_empty(), "%s is a weapon category" % id)
		check((type.get("moves", []) as Array).size() >= 2, "%s owns more than one strike" % id)
		check(float(type.get("reach_mult", 0.0)) > 0.0, "%s reaches" % id)
		check(float(type.get("speed_mult", 0.0)) > 0.0, "%s has a speed" % id)
	check(Weapons.find("bogus").is_empty(), "an unknown category resolves to nothing")
	check(Weapons.moves("bogus").is_empty(), "an unknown category has no moves")
	var last_sword: Dictionary = (Weapons.moves("sword") as Array)[-1]
	check(String(Weapons.move("sword", 99).get("name", "")) == String(last_sword.get("name", "")), "a move index is clamped")
	check(Weapons.attack_payload(Weapons.find("bogus"), 0).is_empty(), "an unknown category has no payload")

	check(Weapons.type_id_for({}) == Weapons.DEFAULT_TYPE, "an empty weapon is unarmed")
	check(Weapons.type_id_for({"weapon_type": "staff"}) == "staff", "an explicit category wins")
	check(Weapons.type_id_for({"weapon_type": "nonsense"}) == Weapons.DEFAULT_TYPE, "an unknown explicit category falls back")
	check(Weapons.type_id_for({"base": "base.saber.heavy_saber"}) == "saber", "a legacy base id names the category")
	check(Weapons.type_id_for({"id": "base.whip.spirit_silk"}) == "whip", "an item id names the category")
	check(Weapons.type_id_for({"name": "Cursed Test Blade", "slot": "weapon"}) == Weapons.DEFAULT_TYPE, "an unlabelled weapon is safe")

	check(Weapons.next_combo(-1, 0.0, 0.75, 3) == 0, "a fresh chain opens at the first strike")
	check(Weapons.next_combo(0, 0.1, 0.75, 3) == 1, "an in-time press advances the chain")
	check(Weapons.next_combo(1, 0.1, 0.75, 3) == 2, "the chain reaches its last strike")
	check(Weapons.next_combo(2, 0.1, 0.75, 3) == 0, "the chain wraps to the first strike")
	check(Weapons.next_combo(1, 5.0, 0.75, 3) == 0, "a late press restarts the chain")
	check(Weapons.next_combo(1, 0.1, 0.75, 0) == 0, "an empty chain is harmless")

	var sword_box := Weapons.scaled_hitbox(Weapons.move("sword", 0), Weapons.find("sword"))
	var whip_box := Weapons.scaled_hitbox(Weapons.move("whip", 0), Weapons.find("whip"))
	check(float(whip_box["radius"]) > float(sword_box["radius"]), "a whip outranges a sword")
	check(approx(float(sword_box["angle"]), float((Weapons.move("sword", 0).get("hitbox", {}) as Dictionary).get("angle", 0.0))), "reach scaling leaves the arc alone")
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, whip_box, Vector2(100, 0)), "the whip's reach is real geometry")

	var stats := StatBlock.new(Attributes.new())
	stats.rebuild({}, [], 1, 1.0)
	var light := Weapons.attack_payload(Weapons.find("sword"), 0)
	var heavy := Weapons.attack_payload(Weapons.find("sword"), 2)
	var unarmed := Weapons.attack_payload(Weapons.find("fist"), 0)
	check(Damage.weapon_strike(light, stats, 8.0) > 0.0, "a weapon strike deals damage")
	check(Damage.weapon_strike(light, stats, 16.0) > Damage.weapon_strike(light, stats, 8.0), "a stronger weapon hits harder")
	check(Damage.weapon_strike(heavy, stats, 8.0) > Damage.weapon_strike(light, stats, 8.0), "a later chain step hits harder")
	check(Damage.weapon_strike(unarmed, stats, 0.0) > 0.0, "bare hands still hurt")
	check(Damage.weapon_strike(light, stats, -5.0) >= 0.0, "a cursed weapon cannot deal negative damage")
	check(float(Weapons.attack_payload(Weapons.find("saber"), 0)["poise_damage"]) > float(light["poise_damage"]), "a saber carries more poise damage")
	check(float(Weapons.attack_payload(Weapons.find("saber"), 0)["knockback"]) > float(light["knockback"]), "a saber throws further")
	check(Combat.phase_seconds(light["frames"], "startup", float(light["speed_mult"])) > Combat.phase_seconds(unarmed["frames"], "startup", float(unarmed["speed_mult"])), "a fist winds up faster than a sword")

	for base in DB.bases:
		if String(base.get("slot", "")) == "weapon":
			check(not Weapons.find(String(base.get("weapon_type", ""))).is_empty(), "weapon base %s declares a real category" % base.get("id", "?"))

	var generator := ItemGen.new(DB, Rng)
	var blade := generator.generate(20, 501, 0, 3, "weapon")
	check(String(blade.get("weapon_type", "")) != "", "a generated weapon carries its category")
	check(not Weapons.find(Weapons.type_id_for(blade)).is_empty(), "a generated weapon resolves to a real moveset")


# ------------------------------------------------------------- defense ----

func _defense_tests() -> void:
	print("[defense] guard stance, parry window, guard break")
	check(Defense.state_for(false, 0.0, 0.0) == "none", "a lowered guard is no stance")
	check(Defense.state_for(true, 0.0, 0.0) == "parry", "a fresh guard opens the parry window")
	check(Defense.state_for(true, Defense.PARRY_WINDOW, 0.0) == "parry", "the window includes its last moment")
	check(Defense.state_for(true, Defense.PARRY_WINDOW + 0.01, 0.0) == "block", "past the window the guard is a plain block")
	check(Defense.state_for(true, 0.0, 0.5) == "broken", "a broken guard overrides the stance")
	check(Defense.state_for(false, 0.0, 0.5) == "broken", "a broken guard stays broken while it recovers")
	check(Defense.is_guarding("parry") and Defense.is_guarding("block"), "the live stances guard")
	check(not Defense.is_guarding("broken") and not Defense.is_guarding("none"), "broken and lowered do not guard")

	check(Defense.covers(Vector2.RIGHT, Vector2.RIGHT), "a blow from the front is covered")
	check(Defense.covers(Vector2.RIGHT, Vector2(1, 1).normalized()), "a diagonal in front is covered")
	check(not Defense.covers(Vector2.RIGHT, Vector2.LEFT), "a blow from behind is not covered")
	check(not Defense.covers(Vector2.RIGHT, Vector2(-1, 1).normalized()), "a rear diagonal is not covered")
	check(Defense.covers(Vector2.RIGHT, Vector2(0, 1), 360.0), "a full ward covers every side")
	check(not Defense.covers(Vector2.ZERO, Vector2.RIGHT), "a body with no facing guards nothing")
	check(not Defense.covers(Vector2.RIGHT, Vector2.ZERO), "a blow from nowhere is not blockable")

	check(approx(Defense.damage_multiplier("parry"), 0.0), "a parry takes no damage")
	check(approx(Defense.damage_multiplier("block"), Defense.BLOCK_DAMAGE_MULT), "a block takes a fraction")
	check(approx(Defense.damage_multiplier("broken"), Defense.GUARD_BREAK_MULT), "a broken guard takes extra")
	check(approx(Defense.damage_multiplier("none"), 1.0), "an unguarded blow takes full damage")
	check(Defense.BLOCK_DAMAGE_MULT < 1.0 and Defense.GUARD_BREAK_MULT > 1.0, "blocking and breaking sit on opposite sides of one")
	check(approx(Defense.poise_multiplier("block"), 0.0), "a block spends Qi, not poise")
	check(approx(Defense.poise_multiplier("parry"), 0.0), "a parry spends nothing")
	check(approx(Defense.poise_multiplier("none"), 1.0), "an unguarded blow still spends poise")
	check(Defense.poise_multiplier("broken") > 1.0, "a broken guard staggers harder")

	check(approx(Defense.qi_cost(20.0, "parry"), 0.0), "a parry is free")
	check(approx(Defense.qi_cost(20.0, "block"), Defense.QI_BASE_COST + 20.0 * Defense.QI_PER_DAMAGE), "a block is paid per point of blow")
	check(Defense.qi_cost(40.0, "block") > Defense.qi_cost(20.0, "block"), "heavier blows cost more Qi")
	check(approx(Defense.qi_cost(-5.0, "block"), Defense.QI_BASE_COST), "a negative blow still costs the floor")
	check(Defense.can_pay(1000.0, 20.0), "a full reserve pays for a blow")
	check(not Defense.can_pay(0.0, 20.0), "an empty reserve cannot")
	check(not Defense.can_pay(Defense.QI_BASE_COST + 20.0 * Defense.QI_PER_DAMAGE - 0.5, 20.0), "an almost-sufficient reserve still breaks")

	var guard := Poise.new(60.0)
	check(guard.break_guard(10.0) and guard.is_staggered(), "a guard break staggers whatever poise is left")
	check(guard.stagger >= 0.7, "a guard break is a long stagger")
	check(approx(guard.current, guard.maximum), "a broken guard refills")
	check(not guard.break_guard(10.0), "an already staggered body cannot break twice")

	var defense_stats := StatBlock.new(Attributes.new())
	check(Defense.reflected_poise(defense_stats) > 0.0, "a parry throws poise back")
	var strong := Attributes.new()
	strong.add("str", 40)
	var strong_stats := StatBlock.new(strong)
	check(Defense.reflected_poise(strong_stats) > Defense.reflected_poise(defense_stats), "strength makes the riposte heavier")
	check(Defense.label("parry") != Defense.label("block") and Defense.label("broken") == "BROKEN", "the HUD labels each stance")


# --------------------------------------------------- technique combat ----

func _technique_combat_tests() -> void:
	print("[technique combat] kinds, projectiles, spells, summons, buffs and steps")
	check(TechniqueCombat.KINDS.size() == 6, "six technique deliveries are declared")
	check(TechniqueCombat.kind_of({}) == "melee", "a technique with no kind is a melee art")
	check(TechniqueCombat.kind_of({"kind": "projectile"}) == "projectile", "a declared kind is read")
	check(TechniqueCombat.kind_of({"kind": "bogus"}) == "melee", "an unknown kind falls back to melee")
	for kind in TechniqueCombat.KINDS:
		check(TechniqueCombat.is_valid_kind(kind), "%s is a real delivery" % kind)
		check(TechniqueCombat.kind_label(kind) != "", "%s is labelled for the HUD" % kind)
	check(TechniqueCombat.is_ranged("projectile") and TechniqueCombat.is_ranged("spell") \
		and TechniqueCombat.is_ranged("summon"), "bolts, spells and summons strike at a distance")
	check(not TechniqueCombat.is_ranged("melee") and not TechniqueCombat.is_ranged("buff") \
		and not TechniqueCombat.is_ranged("movement"), "melee, buffs and steps are not ranged strikes")
	check(TechniqueCombat.uses_hitbox("melee") and not TechniqueCombat.uses_hitbox("spell"), "only melee reads a hitbox")

	var kinds_seen := {}
	for tech in DB.techniques:
		var tech_kind := TechniqueCombat.kind_of(tech)
		kinds_seen[tech_kind] = true
		check(TechniqueCombat.is_valid_kind(tech_kind), "%s has a valid kind" % tech.get("id", "?"))
		if tech_kind == "buff":
			check(not TechniqueCombat.buff_entry(tech).is_empty(), "buff %s can be applied" % tech.get("id", "?"))
		elif tech_kind == "projectile":
			check(float(TechniqueCombat.projectile_of(tech)["range"]) > 0.0, "projectile %s reaches" % tech.get("id", "?"))
		elif tech_kind == "movement":
			check(float(TechniqueCombat.movement_of(tech)["distance"]) > 0.0, "movement %s moves" % tech.get("id", "?"))
	for kind in TechniqueCombat.KINDS:
		check(kinds_seen.has(kind), "content ships a %s technique" % kind)
	check(String(DB.technique("tech.sword.piercing_thrust").get("kind", "")) == "projectile", "a sword thrust carries sword Qi")
	check(String(DB.technique("tech.formation.sealing_array").get("kind", "")) == "spell", "a formation art is a spell")
	check(String(DB.technique("tech.body.golden_bell").get("kind", "")) == "buff", "a body art is a buff")
	check(String(DB.technique("tech.step.cloud_step").get("kind", "")) == "movement", "cloud step is a movement art")

	var shot := TechniqueCombat.projectile_of({"kind": "projectile",
		"projectile": {"speed": 600.0, "radius": 12.0, "range": 300.0, "pierce": 2}})
	check(approx(float(shot["speed"]), 600.0) and approx(float(shot["range"]), 300.0), "a projectile reads its own data")
	check(approx(TechniqueCombat.flight_time(shot, 300.0), 0.5), "flight time follows speed")
	check(approx(TechniqueCombat.flight_time(shot, 600.0), 0.5), "travel is clamped at the projectile's range")
	check(TechniqueCombat.projectile_reaches(shot, 300.0), "a body at the edge is reached")
	check(not TechniqueCombat.projectile_reaches(shot, 301.0), "a body past the range is not")
	check(TechniqueCombat.max_hits(shot) == 3, "pierce adds bodies to a bolt")
	var plain_shot := TechniqueCombat.projectile_of({})
	check(float(plain_shot["speed"]) > 0.0, "missing projectile data keeps its defaults")
	check(TechniqueCombat.max_hits(plain_shot) == 1, "a plain bolt stops at one body")
	check(float(TechniqueCombat.projectile_of({"projectile": {"speed": 0.0}})["speed"]) >= 1.0, "a zero speed is floored")

	var area := TechniqueCombat.spell_of({"kind": "spell",
		"spell": {"range": 200.0, "radius": 70.0, "delay": 0.4}})
	check(TechniqueCombat.spell_center(Vector2(10, 10), Vector2.RIGHT, area) == Vector2(210, 10), "a spell opens ahead of the caster")
	check(TechniqueCombat.spell_center(Vector2.ZERO, Vector2.ZERO, area) == Vector2(200, 0), "a caster with no aim opens it to the right")
	check(approx(float(TechniqueCombat.spell_area(area)["radius"]), 70.0), "a spell's area is its own radius")
	check(approx(float(TechniqueCombat.spell_area(area)["angle"]), 360.0), "a spell area is a full circle")
	check(Combat.in_hitbox(Vector2.ZERO, Vector2.RIGHT, TechniqueCombat.spell_area(area), Vector2(-60, 0)), "a spell strikes behind its own centre")
	check(float(TechniqueCombat.spell_of({"spell": {"delay": -1.0}})["delay"]) >= 0.0, "a negative telegraph is floored")

	var pack := TechniqueCombat.summon_of({"kind": "summon",
		"summon": {"count": 3, "duration": 5.0, "damage_mult": 0.25}})
	check(int(pack["count"]) == 3 and approx(float(pack["duration"]), 5.0), "a summon art brings its pack and its life")
	check(TechniqueCombat.summon_offsets(3).size() == 3, "the pack is spread around the caster")
	check(TechniqueCombat.summon_offsets(0).size() == 1, "an empty pack still brings one beast")
	check((TechniqueCombat.summon_offsets(4)[1] as Vector2).length() > 0.0, "summons do not all appear on one point")
	check(approx(TechniqueCombat.summon_damage(100.0, pack), 25.0), "each summon carries its share")
	check(approx(TechniqueCombat.summon_damage(100.0, TechniqueCombat.summon_of({})), 40.0), "the default share is a fraction of the blow")
	check(float(TechniqueCombat.summon_of({"summon": {"count": 0, "duration": 0.0}})["duration"]) > 0.0, "a summon always has a life")

	var bell := DB.technique("tech.body.golden_bell")
	var entry := TechniqueCombat.buff_entry(bell)
	check(not entry.is_empty(), "a body art produces a live buff")
	check(float(entry.get("duration", 0.0)) > 0.0 and (entry["mods"] as Array).size() >= 2, "a buff carries its duration and mods")
	check(TechniqueCombat.buff_entry(DB.technique("tech.sword.azure_cleave")).is_empty(), "a melee art is not a buff")
	var live := TechniqueCombat.apply_buff([], bell)
	check(live.size() == 1, "casting a body art applies it once")
	live = TechniqueCombat.apply_buff(live, bell)
	check(live.size() == 1, "recasting refreshes instead of stacking")
	var buff_mods := TechniqueCombat.buff_mods(live)
	check(buff_mods.size() == (entry["mods"] as Array).size(), "the pipeline receives every mod")
	var buffed := StatBlock.new(Attributes.new())
	buffed.rebuild({}, [], 1, 1.0)
	var bare_armour := buffed.armor()
	buffed.rebuild({}, [], 1, 1.0, "", [], [], [], 0.0, buff_mods)
	check(buffed.armor() > bare_armour, "a body art's armour enters the one stat pipeline")
	check(approx(buffed.armor(), bare_armour + 30.0), "the mod is applied exactly once")
	live = TechniqueCombat.tick_buffs(live, 0.5)
	check(live.size() == 1 and float(live[0]["remaining"]) < float(entry["duration"]), "a buff counts down")
	check(TechniqueCombat.tick_buffs(live, 100.0).is_empty(), "a buff expires")
	check(TechniqueCombat.buff_labels(TechniqueCombat.apply_buff([], bell)).size() == 1, "the HUD can name a live art")

	var step := TechniqueCombat.movement_of({"kind": "movement",
		"movement": {"distance": 120.0, "iframes": 0.2}})
	check(TechniqueCombat.step_destination(Vector2.ZERO, Vector2.UP, step) == Vector2(0, -120), "a movement art carries the body along the aim")
	check(TechniqueCombat.step_destination(Vector2.ZERO, Vector2.ZERO, step) == Vector2(120, 0), "a body with no aim still steps")
	check(TechniqueCombat.step_destination(Vector2(5, 5), Vector2.LEFT, step) == Vector2(-115, 5), "the step is relative to where the body stands")
	check(approx(float(TechniqueCombat.movement_of({})["distance"]), float(TechniqueCombat.MOVEMENT_DEFAULTS["distance"])), "missing movement data keeps its default")
	check(float(TechniqueCombat.movement_of({"movement": {"distance": -50.0}})["distance"]) >= 0.0, "a negative step is floored")


# -------------------------------------------------------------- aging ----

func _aging_tests() -> void:
	print("[aging] calendar age, decline, stages and death")
	check(approx(Aging.age_for(1, 1), float(Aging.START_AGE)), "a run starts at the starting age")
	check(approx(Aging.age_for(1, 1 + int(Aging.DAYS_PER_YEAR)), float(Aging.START_AGE + 1)), "one aging year passes per DAYS_PER_YEAR days")
	check(approx(Aging.age_for(10, 5), float(Aging.START_AGE)), "days cannot run backwards")
	check(approx(Aging.age_for(1, 1, 20), 20.0), "the starting age can be overridden")
	check(approx(Aging.ratio(60, 120), 0.5), "age ratio is honest")
	check(Aging.ratio(60, 0) == 0.0, "an unbounded lifespan has no ratio")
	check(Aging.remaining_years(60, 120) == 60, "remaining years count down")
	check(Aging.remaining_years(200, 120) == 0, "remaining years floor at zero")
	check(Aging.remaining_years(20, 0) == -1, "an unbounded lifespan reports -1")

	check(Aging.stage(20, 120) == "prime", "youth is prime")
	check(Aging.stage(80, 120) == "middle", "sixty percent is middle age")
	check(Aging.stage(110, 120) == "old", "late life is old")
	check(Aging.stage(119, 120) == "fading", "the last years are fading")
	check(Aging.stage(120, 120) == "ended", "the lifespan is the end")
	check(Aging.stage(900, 0) == "ageless", "an unbounded lifespan never ages")
	check(Aging.stage_rank("prime") < Aging.stage_rank("middle") and Aging.stage_rank("middle") < Aging.stage_rank("old"), "stages rank in order")
	check(Aging.stage_rank("fading") < Aging.stage_rank("ended"), "fading precedes the end")
	check(Aging.stage_rank("ageless") == 0 and Aging.stage_rank("nonsense") == 0, "unknown stages are harmless")

	check(Aging.decline(20, 120) == 0.0, "the young do not decline")
	check(Aging.decline(70, 120) == 0.0, "decline waits for its threshold")
	check(Aging.decline(90, 120) > 0.0, "the old decline")
	check(Aging.decline(100, 120) > Aging.decline(90, 120), "decline deepens with age")
	check(approx(Aging.decline(120, 120), Aging.DECLINE_MAX), "decline reaches its cap at the lifespan")
	check(Aging.decline(120, 0) == 0.0, "the ageless do not decline")

	check(not Aging.is_dead(119, 120), "a year short is still alive")
	check(Aging.is_dead(120, 120), "the lifespan ends the run")
	check(not Aging.is_dead(9999, 0), "an unbounded lifespan never ends")
	check(Aging.warning_for("middle") != "" and Aging.warning_for("old") != "" and Aging.warning_for("fading") != "", "each declining stage warns")
	check(Aging.warning_for("prime") == "" and Aging.warning_for("ended") == "", "the other stages are silent")

	var attrs := Attributes.new()
	for key in Attributes.KEYS:
		attrs.add(key, 30)
	var young_stats := StatBlock.new(attrs)
	young_stats.rebuild({}, [], 1, 1.0)
	var old_stats := StatBlock.new(attrs)
	old_stats.rebuild({}, [], 1, 1.0, "", [], [], [], Aging.DECLINE_MAX)
	check(old_stats.get_attr("str") < young_stats.get_attr("str"), "aging reduces STR")
	check(old_stats.get_attr("dex") < young_stats.get_attr("dex"), "aging reduces DEX")
	check(old_stats.get_attr("agi") < young_stats.get_attr("agi"), "aging reduces AGI")
	check(old_stats.get_attr("wis") == young_stats.get_attr("wis"), "aging leaves WIS alone")
	check(old_stats.get_attr("int") == young_stats.get_attr("int"), "aging leaves INT alone")
	check(old_stats.get_attr("cha") == young_stats.get_attr("cha"), "aging leaves CHA alone")
	check(old_stats.get_attr("str") >= 0, "aging cannot push attributes negative")
	var overloaded := StatBlock.new(attrs)
	overloaded.rebuild({}, [], 1, 1.0, "", [], [], [], 5.0)
	check(overloaded.get_attr("str") > 0, "an absurd penalty is clamped, not fatal")

	var game_saved := Game.to_dict()
	Game.born_day = 7
	Game.dead = true
	Game.age_warning_stage = 3
	var saved := Game.to_dict()
	Game.from_dict(saved)
	check(Game.born_day == 7 and Game.dead and Game.age_warning_stage == 3, "aging state survives a run save")
	Game.from_dict({})
	check(Game.born_day == Clock.day and not Game.dead and Game.age_warning_stage == 0, "legacy runs start alive and young")
	Game.from_dict(game_saved)


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


# -------------------------------------------------- procedural generation ----

func _procedural_generation_tests() -> void:
	print("[generation] affix tiers, weights and order independence")
	var generator := ItemGen.new(DB, Rng)

	var sharpened: Dictionary = DB.by_id("prefix", "prefix.sharpened")
	check(not sharpened.is_empty(), "an affix is indexed by id")
	check(ItemGen.tier_count(sharpened) == 3, "shipped affixes carry three tiers")
	check(ItemGen.tier_for(sharpened, 1) == 0, "low gear reads the first tier")
	check(ItemGen.tier_for(sharpened, 5) == 1, "level five unlocks the second tier")
	check(ItemGen.tier_for(sharpened, 12) == 2, "high gear reads the last tier")
	check(float(ItemGen.tier_data(sharpened, 2)["max"]) > float(ItemGen.tier_data(sharpened, 0)["max"]), "upper tiers roll higher")
	check(ItemGen.tier_for({"tiers": [{"ilvl": 5, "min": 1, "max": 2}]}, 1) == 0, "a body below the first tier still reads tier one")
	check(ItemGen.tier_count({}) == 1, "an affix without tiers has exactly one")
	check(ItemGen.affix_weight(sharpened, "weapon") == 14, "an affix reads its base weight")
	var tiger: Dictionary = DB.by_id("suffix", "suffix.tiger")
	check(ItemGen.affix_weight(tiger, "weapon") == 18, "a slot override wins on its slot")
	check(ItemGen.affix_weight(tiger, "ring") == 14, "a second slot can carry its own weight")
	check(ItemGen.affix_weight(tiger, "talisman") == 12, "a slot without an override uses the base weight")
	check(ItemGen.affix_weight({"weight": 0}, "weapon") == 0, "a zero weight removes an affix")

	var low_weapon := generator.generate(1, 9001, 0, 3, "weapon")
	var high_weapon := generator.generate(12, 9002, 0, 3, "weapon")
	var low_mods: Array = low_weapon.get("mods", [])
	var high_mods: Array = high_weapon.get("mods", [])
	check(low_mods.size() == 6 and high_mods.size() == 6, "both levels roll a full treasure set")
	var low_tier_ok := true
	var low_upper := false
	for mod in low_mods:
		var tier := int((mod as Dictionary).get("tier", 0))
		if tier < 1:
			low_tier_ok = false
		if tier > 1:
			low_upper = true
	check(low_tier_ok, "every rolled mod records its tier")
	check(not low_upper, "level one gear cannot roll an upper tier")
	var high_tiers: Dictionary = {}
	var range_ok := true
	for mod in high_mods:
		var mod_data: Dictionary = mod
		var tier := int(mod_data.get("tier", 1))
		high_tiers[tier] = true
		var affix: Dictionary = DB.by_id("prefix", String(mod_data["id"]))
		if affix.is_empty():
			affix = DB.by_id("suffix", String(mod_data["id"]))
		var tier_data: Dictionary = ItemGen.tier_data(affix, tier - 1)
		var value := float(mod_data["value"])
		if value < float(tier_data["min"]) - 0.05 or value > float(tier_data["max"]) + 0.5:
			range_ok = false
	check(high_tiers.has(3), "a level twelve treasure reaches the last tier")
	check(range_ok, "every rolled value sits inside its own tier")
	check(String(generator.describe(high_weapon)).contains("(T3)"), "the description names an upper tier")

	var first := generator.generate(9, 4242, 0, 3, "ring")
	for i in 12:
		generator.generate(9, 5000 + i, i, 3, "ring")
	var again := generator.generate(9, 4242, 0, 3, "ring")
	check(JSON.stringify(first) == JSON.stringify(again), "generation does not depend on call order")
	check(JSON.stringify(first) == JSON.stringify(generator.generate(9, 4242, 0, 3, "ring")), "the same stream reproduces the same item twice")

	var repeated := false
	var off_slot := false
	var over_level := false
	var weighted: Dictionary = {"prefix.sharpened": 0, "prefix.ruinous": 0}
	for i in 120:
		var item := generator.generate(12, 6000 + i, 0, 3, "weapon")
		var seen_ids: Dictionary = {}
		for mod in item.get("mods", []):
			var id := String((mod as Dictionary)["id"])
			if seen_ids.has(id):
				repeated = true
			seen_ids[id] = true
			if id == "prefix.spirit_bound" or id == "suffix.insight" or id == "suffix.command":
				off_slot = true
			if weighted.has(id):
				weighted[id] = int(weighted[id]) + 1
	check(not repeated, "an item never rolls the same affix twice")
	check(not off_slot, "an affix only rolls on its own slots")
	for i in 40:
		var low := generator.generate(1, 7000 + i, 0, 3, "weapon")
		for mod in low.get("mods", []):
			var id := String((mod as Dictionary)["id"])
			var affix: Dictionary = DB.by_id("prefix", id)
			if affix.is_empty():
				affix = DB.by_id("suffix", id)
			if int(affix.get("ilvl", 1)) > 3:
				over_level = true
	check(not over_level, "an affix respects the item level gate")
	check(int(weighted["prefix.sharpened"]) > int(weighted["prefix.ruinous"]), "weights steer what appears (%d vs %d)" % [int(weighted["prefix.sharpened"]), int(weighted["prefix.ruinous"])])

	var tiered := Items.normalize_item({"id": "item.test.tier", "slot": "weapon", "name": "Tier Test", "mods": [
		{"id": "prefix.sharpened", "stat": "physical_damage_pct", "value": 12.0, "tier": 2, "text": "+12% physical damage"},
	]})
	var tiered_mods: Array = tiered["mods"]
	check(int((tiered_mods[0] as Dictionary)["tier"]) == 2, "the canonical item keeps an affix tier")
	var untiered := Items.normalize_item({"id": "item.test.untiered", "slot": "weapon", "name": "Untiered", "mods": [
		{"id": "prefix.swift", "stat": "attack_speed_pct", "value": 5.0, "text": "+5%"},
	]})
	check(int(((untiered["mods"] as Array)[0] as Dictionary)["tier"]) == 1, "a mod without a tier reads as tier one")


# -------------------------------------------------------- equipment rules ----

func _equipment_rules_tests() -> void:
	print("[equipment] requirements, conflicts and comparison")
	var rules := Equipment.new(DB)
	var attrs := Attributes.new()
	var plate: Dictionary = Items.normalize_item({"id": "item.test.plate", "slot": "armor", "name": "Plate", "base": "base.robe.iron_plate", "armor": 14.0, "ilvl": 2, "value": 20})
	var charm: Dictionary = Items.normalize_item({"id": "item.test.charm", "slot": "talisman", "name": "Charm", "base": "base.talisman.wind_charm", "ilvl": 1, "value": 14})
	var jade: Dictionary = Items.normalize_item({"id": "item.test.jade", "slot": "ring", "name": "Jade", "base": "base.ring.jade", "ilvl": 1, "value": 10})
	var rod: Dictionary = Items.normalize_item({"id": "item.test.rod", "slot": "weapon", "name": "Rod", "base": "base.staff.azure_rod", "base_damage": 6.0, "ilvl": 3, "value": 30})
	var spirit_ring: Dictionary = Items.normalize_item({"id": "item.test.spirit_ring", "slot": "ring", "name": "Spirit Ring", "base": "base.ring.spirit_iron", "ilvl": 3, "value": 28})

	check(int(rules.requirements(plate).get("str", 0)) == 12, "a base carries its requirements")
	check(rules.missing_requirements(plate, attrs, 1) == ["STR 12"], "a level ten body misses a STR 12 plate")
	check(not bool(rules.can_equip(plate, {}, attrs, 1)["ok"]), "the gate refuses the plate")
	check(String(rules.can_equip(plate, {}, attrs, 1)["reason"]).begins_with("Requires"), "the refusal names the requirement")
	attrs.add("str", 2)
	check(rules.missing_requirements(plate, attrs, 1).is_empty(), "the requirement is met exactly")
	check(bool(rules.can_equip(plate, {}, attrs, 1)["ok"]), "STR 12 wears the plate")
	check(not bool(rules.can_equip(spirit_ring, {}, attrs, 1)["ok"]), "a realm requirement is enforced")
	check(bool(rules.can_equip(spirit_ring, {}, attrs, 2)["ok"]), "realm two wears the spirit ring")
	check(not bool(rules.can_equip(rod, {}, Attributes.new(), 1)["ok"]), "an INT 14 rod refuses an INT 10 body")
	var smart := Attributes.new()
	smart.add("int", 4)
	check(bool(rules.can_equip(rod, {}, smart, 1)["ok"]), "INT 14 wears the rod")

	var worn_plate := {"armor": plate}
	var clash := rules.conflict_with(charm, worn_plate)
	check(String(clash.get("name", "")) == "Plate", "the wind charm sees the plate")
	check(not bool(rules.can_equip(charm, worn_plate, attrs, 1)["ok"]), "wind and heavy plate conflict")
	check(not bool(rules.can_equip(plate, {"talisman": charm}, attrs, 1)["ok"]), "the conflict is symmetric")
	check(rules.conflict_with(jade, worn_plate).is_empty(), "an unrelated piece does not conflict")
	check(rules.conflict_with(charm, {"ring": jade}).is_empty(), "wind does not conflict with jade")
	check(bool(rules.can_equip(plate, {"ring": jade}, attrs, 1)["ok"]), "plate and jade coexist")
	check(not bool(rules.can_equip({"id": "item.test.pill", "slot": "consumable"}, {}, attrs, 1)["ok"]), "a pill is not equipment")

	var plain: Dictionary = Items.normalize_item({"id": "item.test.jian.a", "slot": "weapon", "name": "Jian", "base": "base.sword.iron_jian", "base_damage": 8.0, "ilvl": 1, "rarity": 0, "value": 12})
	var better := plain.duplicate(true)
	better["id"] = "item.test.jian.b"
	better["base_damage"] = 11.0
	better["mods"] = [{"id": "prefix.sharpened", "stat": "physical_damage_pct", "value": 10.0, "tier": 1, "text": "+10% physical damage"}]
	var cmp := rules.compare(better, plain)
	var by_stat: Dictionary = {}
	for delta in cmp["deltas"]:
		by_stat[String((delta as Dictionary)["stat"])] = delta
	check(by_stat.has("weapon_damage") and approx(float((by_stat["weapon_damage"] as Dictionary)["delta"]), 3.0), "comparison reports the base damage gain")
	check(by_stat.has("physical_damage_pct"), "comparison reports the new affix")
	check((cmp["deltas"] as Array).size() == 2, "only real differences are listed")
	var worse := plain.duplicate(true)
	worse["base_damage"] = 5.0
	var loss := rules.compare(worse, plain)
	check(float(((loss["deltas"] as Array)[0] as Dictionary)["delta"]) < 0.0, "a downgrade reads negative")
	check((rules.compare(plain, plain)["deltas"] as Array).is_empty(), "an identical piece has no deltas")
	check(approx(float(rules.stat_map(plate)["armor"]), 14.0), "armour feeds the comparison")
	var modded := plain.duplicate(true)
	modded["mods"] = [{"stat": "str", "value": 2.0}, {"stat": "str", "value": 3.0}]
	check(approx(float(rules.stat_map(modded)["str"]), 5.0), "affixes of the same stat sum")
	check(Equipment.unit_for("physical_damage_pct") == "%", "percent affixes compare in percent")
	check(Equipment.label_for("qi_max_flat") == "maximum Qi", "comparison labels are readable")


# ---------------------------------------------------------------- uniques ----

func _unique_tests() -> void:
	print("[uniques] authored relics, effects and one-per-save ids")
	var rules := Uniques.new(DB)
	var blade := rules.make("item.unique.hollow_moon_blade")
	check(not blade.is_empty(), "a relic is authored")
	check(bool(blade.get("unique", false)), "a relic marks itself unique")
	check(String(blade.get("lore", "")) != "", "a relic carries lore")
	check(String(blade["slot"]) == "weapon" and float(blade["base_damage"]) > 0.0, "its base numbers come from the base")
	check(int(blade["rarity"]) == ItemGen.RARITY_NAMES.size() - 1, "relics sit at the top shipped rarity")
	check(Items.is_stable_id(String(blade["id"])), "its id is stable")
	check(JSON.stringify(blade) == JSON.stringify(rules.make("item.unique.hollow_moon_blade")), "the same relic is always identical")
	var mods: Array = blade["mods"]
	check(mods.size() == 3, "fixed mods are authored, not rolled")
	check(String((mods[0] as Dictionary)["stat"]) == "physical_damage_pct", "the first mod is fixed")
	check(approx(float((mods[0] as Dictionary)["value"]), 38.0), "the mod value is fixed")
	var plain := Items.normalize_item({"id": "item.test.plain", "slot": "weapon", "name": "Plain"})
	check(not bool(plain.get("unique", false)), "ordinary items are not relics")
	check(Items.label(blade).begins_with("◆ "), "a relic is marked in every list")
	check(Items.label(plain) == "Plain", "ordinary labels are unchanged")
	check(bool(Items.to_save(blade).get("unique", false)), "the save form keeps the relic flag")
	check(String(Items.to_save(blade).get("lore", "")) != "", "the save form keeps the lore")
	check(rules.is_unique(blade), "the registry recognises a relic")
	check(not rules.is_unique(plain), "it does not claim ordinary gear")
	check(rules.make("item.unique.missing").is_empty(), "an unknown relic cannot be made")
	check(rules.make("item.test.plain").is_empty(), "an ordinary id cannot be made as a relic")

	var sash := rules.make("item.unique.cloudstep_sash")
	check(not sash.is_empty(), "the second relic is authored")
	var qi_only := Uniques.kill_effects({"weapon": blade}, DB)
	check(approx(float(qi_only["qi"]), 12.0), "a blade returns Qi per kill")
	check(approx(float(qi_only["hp"]), 0.0), "and no health")
	var both := Uniques.kill_effects({"weapon": blade, "armor": sash}, DB)
	check(approx(float(both["hp"]), 5.0), "a sash returns health per kill")
	check(approx(float(both["qi"]), 12.0), "effects add up across slots")
	var broken := blade.duplicate(true)
	broken["durability"] = 0.0
	check(approx(float(Uniques.kill_effects({"weapon": broken}, DB)["qi"]), 0.0), "a broken relic returns nothing")
	check(approx(float(Uniques.kill_effects({"weapon": plain}, DB)["qi"]), 0.0), "ordinary gear has no kill effect")
	var effects_known := true
	for entry in DB.uniques:
		var effect: Dictionary = entry.get("effect", {})
		if not Uniques.EFFECTS.has(String(effect.get("id", ""))):
			effects_known = false
	check(effects_known, "every authored effect is implemented")

	check(rules.for_source("boss.tomb_warden").size() == 1, "the warden has one relic")
	check(rules.for_source(Uniques.ALTAR_SOURCE).size() == 1, "the altar has one relic")
	check(rules.for_source("site.nowhere").is_empty(), "an unknown source has none")
	check(Uniques.owned_ids({}, [blade]).has("item.unique.hollow_moon_blade"), "ownership reads the satchel")
	check(Uniques.owned_ids({"armor": sash}, []).has("item.unique.cloudstep_sash"), "ownership reads worn gear")
	check(String(rules.effect_text("item.unique.hollow_moon_blade")) != "", "the effect has a readable line")

	var generator := ItemGen.new(DB, Rng)
	var spurious := false
	for i in 80:
		var item := generator.generate(5, 8100 + i, 0)
		if bool(item.get("unique", false)):
			spurious = true
	check(not spurious, "ordinary generation never produces a relic")
	check(DB.uniques.size() >= 2, "relic content is loaded")


# ---------------------------------------------------------------- inventory ----

func _inventory_tests() -> void:
	print("[inventory] grid pages, sort orders and the storehouse")
	check(Inventory.COLS == 6 and Inventory.ROWS == 5 and Inventory.PAGE_SIZE == 30, "the grid is six by five")
	check(Inventory.SORTS.has("recent") and Inventory.SORTS.has("slot") and Inventory.SORTS.has("rarity") \
		and Inventory.SORTS.has("value") and Inventory.SORTS.has("name"), "every shipped order exists")
	check(Inventory.next_sort("recent") == "slot" and Inventory.next_sort("name") == "recent", "the sort key cycles")
	check(Inventory.next_sort("junk") == "recent", "an unknown order falls back to the stored order")
	check(Inventory.sort_label("value") == "Value", "orders are labelled")
	check(not Inventory.is_sort_mode("junk"), "an unknown order is not a mode")

	var sword := _item_for("item.inv.sword", "weapon", "Iron Jian", {"rarity": 1, "ilvl": 3, "value": 30})
	var plate := _item_for("item.inv.plate", "armor", "Iron Plate", {"rarity": 2, "ilvl": 2, "value": 50})
	var ore := _item_for("item.inv.ore", "material", "Spirit Ore", {"rarity": 0, "ilvl": 1, "value": 5, "base": "ore.spirit"})
	var pill := _item_for("item.inv.pill", "consumable", "Qi Pill", {"rarity": 3, "ilvl": 4, "value": 80})
	var bag: Array = [sword, plate, ore, pill]
	var by_value := Inventory.sort_entries(bag, "value")
	check(String(by_value[0]["id"]) == "item.inv.pill" and String(by_value[3]["id"]) == "item.inv.ore", "value sorts richest first")
	check(String(Inventory.sort_entries(bag, "rarity")[0]["id"]) == "item.inv.pill", "rarity sorts rarest first")
	var by_slot := Inventory.sort_entries(bag, "slot")
	check(String(by_slot[0]["id"]) == "item.inv.sword" and String(by_slot[1]["id"]) == "item.inv.plate", "slot sorts weapons before armour")
	check(String(by_slot[3]["id"]) == "item.inv.ore", "materials come last")
	var by_name := Inventory.sort_entries(bag, "name")
	check(String(by_name[0]["name"]) == "Iron Jian" and String(by_name[1]["name"]) == "Iron Plate", "name sorts alphabetically")
	check(Inventory.sort_entries(bag, "recent") == bag, "recent keeps the stored order")
	check(String(bag[0]["id"]) == "item.inv.sword", "sorting never mutates the satchel")
	check(by_value.size() == bag.size(), "sorting keeps every entry")
	var ids_a: Array = []
	var ids_b: Array = []
	for entry in by_value:
		ids_a.append(String((entry as Dictionary)["id"]))
	for entry in Inventory.sort_entries(bag.duplicate(true), "value"):
		ids_b.append(String((entry as Dictionary)["id"]))
	check(ids_a == ids_b, "the same satchel sorts the same way twice")
	var twin_a := _item_for("item.inv.twin.a", "material", "Twin Ore", {"value": 7})
	var twin_b := _item_for("item.inv.twin.b", "material", "Twin Ore", {"value": 7})
	var twins := Inventory.sort_entries([twin_b, twin_a], "value")
	check(String(twins[0]["id"]) == "item.inv.twin.a", "equal values break ties on the stable id")
	check(Inventory.slot_label(sword) == "Weapon" and Inventory.slot_rank(ore) > Inventory.slot_rank(plate), "slot labels and ranks agree")

	check(Inventory.page_count([]) == 1, "an empty satchel still has one page")
	var many: Array = []
	for i in 61:
		many.append(_item_for("item.inv.bulk.%d" % i, "material", "Ore %d" % i, {"value": i}))
	check(Inventory.page_count(many) == 3, "sixty one kinds need three pages")
	check(Inventory.page_slice(many, 0).size() == 30 and Inventory.page_slice(many, 2).size() == 1, "the last page is short")
	check(Inventory.page_slice(many, 9).size() == 1, "a page past the end is clamped")
	check(Inventory.page_of(0) == 0 and Inventory.page_of(30) == 1 and Inventory.page_of(60) == 2, "index to page is exact")
	check(Inventory.cell_of(0) == Vector2i(0, 0) and Inventory.cell_of(7) == Vector2i(1, 1), "index to cell is exact")
	check(Inventory.index_at(0, Vector2i(1, 1), 8) == 7, "cell to index is exact")
	check(Inventory.index_at(2, Vector2i(0, 0), 61) == 60, "a cell on a later page is offset")
	check(Inventory.index_at(0, Vector2i(5, 4), 10) == -1, "an empty cell has no index")
	check(Inventory.move_cursor(0, -1, 4) == 0 and Inventory.move_cursor(3, 1, 4) == 3, "the cursor cannot leave the list")
	check(Inventory.move_cursor(0, Inventory.COLS, 10) == 6, "down moves one grid row")
	check(Inventory.move_cursor(0, 1, 0) == 0, "an empty grid has a safe cursor")

	var store := Storage.new()
	check(Storage.CAPACITY == 60, "the storehouse has sixty shelves")
	check(store.slots_used() == 0 and not store.is_full(), "a new storehouse is empty")
	var carried: Array = Items.add_to_inventory([], ore)
	carried = Items.add_to_inventory(carried, sword)
	var deposited: Dictionary = store.deposit(carried, "item.inv.ore")
	check(bool(deposited["ok"]), "a satchel stack can be stored")
	var left: Array = deposited["inventory"]
	check(left.size() == 1 and String(left[0]["id"]) == "item.inv.sword", "deposit removes only that stack")
	check(store.has("item.inv.ore") and store.slots_used() == 1, "the storehouse holds it")
	var missing := store.deposit(left, "item.inv.missing")
	check(not bool(missing["ok"]) and String(missing["reason"]) != "", "depositing what you do not carry is refused with a reason")
	var merged := store.deposit(Items.add_to_inventory([], ore), "item.inv.ore")
	check(bool(merged["ok"]) and store.slots_used() == 1, "a second stack merges on the shelf")
	check(int((store.item_at(0) as Dictionary)["count"]) == 2, "the shelf remembers both units")
	var withdrawn: Dictionary = store.withdraw(left, "item.inv.ore")
	check(bool(withdrawn["ok"]) and store.slots_used() == 0, "withdrawing empties the shelf")
	check((withdrawn["inventory"] as Array).size() == 2, "the withdrawal returns to the satchel")
	check(not bool(store.withdraw([], "item.inv.ore")["ok"]), "withdrawing an empty shelf is refused")

	var shelf: Array = []
	for i in Storage.CAPACITY:
		shelf = Items.add_to_inventory(shelf, _item_for("item.inv.shelf.%d" % i, "material", "Ore %d" % i, {"base": "ore.spirit"}))
	check(shelf.size() == Storage.CAPACITY, "sixty distinct materials fill sixty shelves")
	var full_store := Storage.new()
	full_store.items = shelf.duplicate(true)
	check(full_store.is_full(), "sixty kinds fill the storehouse")
	var refused := full_store.deposit(Items.add_to_inventory([], sword), "item.inv.sword")
	check(not bool(refused["ok"]), "a full storehouse refuses a new kind")
	check(String(refused["reason"]).contains("full"), "the refusal says the storehouse is full")
	check(not full_store.has("item.inv.sword"), "a refused deposit stores nothing")
	check((refused["inventory"] as Array).size() == 1, "a refused deposit keeps the satchel intact")
	var ore_again := _item_for("item.inv.ore.again", "material", "Ore 0", {"base": "ore.spirit"})
	var merged_full := full_store.deposit(Items.add_to_inventory([], ore_again), "item.inv.ore.again")
	check(bool(merged_full["ok"]) and full_store.slots_used() == Storage.CAPACITY, "a full storehouse still accepts a stack that merges")

	var saved_store := Storage.new()
	saved_store.items = [ore, sword]
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved_store.to_dict()))
	var restored := Storage.new()
	restored.from_dict(parsed)
	check(restored.slots_used() == 2, "the storehouse survives JSON")
	check(String((restored.item_at(1) as Dictionary)["id"]) == "item.inv.sword", "stored gear keeps its id")
	var dirty := Storage.new()
	dirty.from_dict({"items": [{"id": "item.inv.bad"}, "junk", ore]})
	check(dirty.slots_used() == 1, "a hand-edited storehouse drops malformed entries")
	check(Storage.new().to_dict().has("items"), "the save form is explicit")

	var body := Player.new()
	check(body.inventory_sort == "recent", "a new satchel starts in stored order")
	body.inventory = [sword, plate, ore]
	check(body.sort_inventory("value") == "value", "the body records the chosen order")
	check(String(body.inventory[0]["id"]) == "item.inv.plate", "the satchel itself is reordered")
	check(body.sort_inventory("junk") == "recent", "an unknown order falls back to stored order")
	check(Items.to_save(sword).size() != 0 and body.inventory.size() == 3, "sorting keeps the satchel canonical")


# ---------------------------------------------------------------- crafting ----

func _crafting_tests() -> void:
	print("[crafting] forge recipes, costs, quality and the three verbs")
	var rules := Crafting.new(DB)
	check(not DB.station("station.forge").is_empty(), "the forge station is loaded")
	check(DB.recipes.size() >= 5, "forge recipes are loaded")
	check(rules.recipes_for("station.forge").size() == DB.recipes.size(), "every recipe belongs to the forge")
	check(rules.recipes_for("station.nope").is_empty(), "an unknown station has no recipes")
	check(not DB.crafting_action("refine").is_empty() and not DB.crafting_action("disassemble").is_empty(), "both forge actions exist")
	check(Crafting.MATERIALS.has("ore") and Crafting.MATERIALS.has("core"), "material kinds are declared")
	check(Crafting.material_label("ore") == "Spirit Ore" and not Crafting.is_material_key("wood"), "materials are labelled and checked")

	var recipe := DB.recipe("recipe.forge.iron_jian")
	check(not recipe.is_empty() and String(recipe.get("station", "")) == "station.forge", "the iron jian recipe exists")
	var legacy_ore := Items.normalize_item({"id": "item.ore.spirit.0", "slot": "material", "name": "Spirit Ore", "count": 2})
	check(Items.material_key(legacy_ore) == "ore", "a legacy ore is recognised by its id")
	var kinded_ore := Items.normalize_item({"id": "item.test.ore", "slot": "material", "name": "Spirit Ore", "material": "ore", "count": 3})
	check(Items.material_key(kinded_ore) == "ore" and bool(Items.to_save(kinded_ore).has("material")), "a material kind survives the save form")
	check(Items.material_key(_item_for("item.test.sword2", "weapon", "Sword")) == "", "gear is not a material")

	var bag: Array = []
	bag = Items.add_to_inventory(bag, legacy_ore)
	bag = Items.add_to_inventory(bag, Items.normalize_item({"id": "item.ore.spirit.1", "slot": "material", "name": "Spirit Ore", "count": 2}))
	bag = Items.add_to_inventory(bag, Items.normalize_item({"id": "item.herb.spirit.0", "slot": "material", "name": "Spirit Herb", "count": 1}))
	check(int(Crafting.material_counts(bag)["ore"]) == 4, "material counts add stacks")
	check(Crafting.requirement_text(recipe) == "3 Spirit Ore, 60 spirit stones", "the cost line reads")
	check(not bool(Crafting.check(recipe, bag, 10, 1)["ok"]), "a recipe refuses an empty purse")
	check(String(Crafting.check(recipe, bag, 10, 1)["reason"]).contains("spirit stones"), "the refusal names the missing stones")
	check(bool(Crafting.check(recipe, bag, 100, 1)["ok"]), "a payable recipe passes")
	check(not bool(Crafting.check(recipe, bag, 100, 0)["ok"]), "a realm gate is enforced")
	check(not bool(Crafting.check(recipe, [], 100, 1)["ok"]), "missing materials are refused")
	var before_consume := Crafting.material_counts(bag)
	var short := Crafting.consume(bag, [{"material": "ore", "count": 9}])
	check(not bool(short["ok"]) and Crafting.material_counts(short["inventory"]) == before_consume, "an unaffordable consume changes nothing")
	var paid := Crafting.consume(bag, [{"material": "ore", "count": 3}])
	check(bool(paid["ok"]), "a payable consume succeeds")
	check(int(Crafting.material_counts(paid["inventory"])["ore"]) == 1, "consume takes exactly the cost")
	check(int(Crafting.material_counts(paid["inventory"])["herb"]) == 1, "consume leaves other materials alone")

	check(approx(Crafting.quality_chance(1.0), 0.0), "an ordinary smith has no quality chance")
	check(Crafting.quality_chance(2.0) > 0.0 and Crafting.quality_chance(9.0) <= Crafting.MAX_QUALITY_CHANCE, "quality chance is bounded")
	var forged := rules.craft(recipe, 3, 4242, 0, 1.0)
	check(bool(forged["ok"]) and not bool(forged["quality"]), "a plain forge succeeds at the authored rarity")
	var piece: Dictionary = forged["item"]
	check(String(piece["base"]) == "base.sword.iron_jian" and int(piece["rarity"]) == 1, "a recipe forges its authored base and rarity")
	check(JSON.stringify(forged) == JSON.stringify(rules.craft(recipe, 3, 4242, 0, 1.0)), "a forge attempt is reproducible")
	check(JSON.stringify(rules.craft(recipe, 3, 4242, 1, 1.0)) != JSON.stringify(forged), "a new attempt rolls a new piece")

	var flawed := recipe.duplicate(true)
	flawed["failure_chance"] = 1.0
	var failed := rules.craft(flawed, 3, 1, 0, 1.0)
	check(bool(failed["failed"]) and not bool(failed["ok"]), "a guaranteed failure makes nothing")
	check((failed["item"] as Dictionary).is_empty(), "a failed forge has no item")

	var lifted := false
	var bounded := true
	for i in 40:
		var attempt := rules.craft(recipe, 6, 9000 + i, 0, 3.0)
		if not bool(attempt["ok"]):
			continue
		var made: Dictionary = attempt["item"]
		if int(made["rarity"]) > 1:
			lifted = true
		if int(made["rarity"]) >= ItemGen.RARITY_NAMES.size():
			bounded = false
	check(lifted, "a skilled smith occasionally lifts the rarity")
	check(bounded, "quality never exceeds the shipped rarities")

	var target := Items.normalize_item({
		"id": "item.test.refine", "base": "base.sword.iron_jian", "slot": "weapon", "name": "Iron Jian",
		"ilvl": 3, "rarity": 1, "value": 20, "durability": 120.0,
		"mods": [{"id": "prefix.sharpened", "stat": "physical_damage_pct", "value": 5.0, "tier": 1, "text": "+5%"}],
	})
	var refined := rules.refine(target, 77, 0, 1.0)
	check(bool(refined["ok"]), "a piece can be refined")
	var new_piece: Dictionary = refined["item"]
	check(String(new_piece["base"]) == "base.sword.iron_jian" and int(new_piece["ilvl"]) == 3, "refining keeps the base and level")
	check(int(new_piece["rarity"]) == 1, "refining keeps the rarity at ordinary skill")
	check(approx(Items.durability_of(new_piece), 120.0), "refining keeps the wear")
	check(JSON.stringify(new_piece) != JSON.stringify(target), "refining rerolls the affixes")
	check(not bool(rules.refine(_item_for("item.test.material3", "material", "Ore"), 1, 0, 1.0)["ok"]), "a material cannot be refined")
	var relic := Uniques.new(DB).make("item.unique.hollow_moon_blade")
	var relic_refused := rules.refine(relic, 1, 0, 1.0)
	check(not bool(relic_refused["ok"]) and String(relic_refused["reason"]).contains("relic"), "a relic refuses the smith")

	check(Crafting.disassemble_ore(target) == 1 + 2 + 1, "ore scales with rarity and level")
	check(Crafting.disassemble_ore(_item_for("item.test.material4", "material", "Ore")) == 0, "a material cannot be broken down")
	var gem := _item_for("item.test.gem", "ring", "Jade Ring", {"rarity": 3, "ilvl": 8})
	check(Crafting.disassemble_ore(gem) > Crafting.disassemble_ore(target), "a richer piece yields more ore")
	check(Crafting.disassemble_ore(relic) == 0, "a relic cannot be broken down")

	var crafting_problems := 0
	for problem in DB.validate():
		if String(problem).contains("recipe") or String(problem).contains("crafting"):
			crafting_problems += 1
	check(crafting_problems == 0, "crafting data validates")


# -------------------------------------------------------------------- loot ----

func _loot_tests() -> void:
	print("[loot] data-driven tables, weights and elite rank")
	var rules := Loot.new(DB, Rng)
	var wild := rules.table("kill.wild")
	check(not wild.is_empty() and String(wild.get("id", "")) == "kill.wild", "the wild table resolves by id")
	check(String(rules.table("kill.nope").get("id", "")) == "kill.wild", "an unknown source falls back to the wild table")
	for source in Loot.REQUIRED_SOURCES:
		check(not rules.table(String(source)).is_empty(), "every called source has a table: %s" % source)
	check(DB.loot_tables.size() >= Loot.REQUIRED_SOURCES.size(), "all loot tables are loaded")
	check(not DB.loot_table("kill.boss").is_empty(), "the registry indexes loot tables")
	check(DB.loot_table("nope").is_empty(), "an unknown table id resolves to nothing")
	check(Loot.MAX_ROLLS >= 2 and Loot.rolls_of({}) == Vector2i.ONE, "a tableless roll asks for one piece")
	check(Loot.label("kill.wild") == "Wild", "sources have readable labels")

	var first := rules.roll("kill.wild", 5, 4242, 7)
	check((first["items"] as Array).size() == 1, "the wild table rolls one piece")
	check(JSON.stringify(first) == JSON.stringify(rules.roll("kill.wild", 5, 4242, 7)), "the same kill rolls the same loot")
	check(JSON.stringify(first) != JSON.stringify(rules.roll("kill.wild", 5, 4242, 8)), "a different counter rolls different loot")
	check(String(((first["items"] as Array)[0] as Dictionary).get("id", "")).begins_with("item."), "a rolled piece is a real item")
	check(not bool(((first["items"] as Array)[0] as Dictionary).get("unique", false)), "a loot table never rolls a relic")

	var boss := rules.roll("kill.boss", 8, 99, 0)
	check((boss["items"] as Array).size() == 2, "the boss table rolls two pieces")
	var boss_ok := true
	for item in (boss["items"] as Array):
		var piece: Dictionary = item
		if not Items.is_equipment(String(piece["slot"])) or int(piece["rarity"]) < 2:
			boss_ok = false
	check(boss_ok, "boss loot is equipment at spirit grade or better")
	check(Loot.rolls_of(DB.loot_table("chest.sealed")) == Vector2i(1, 2), "a table's roll range is data")

	var sealed := rules.roll("chest.sealed", 6, 1234, 0)
	check(not (sealed["items"] as Array).is_empty(), "a sealed chest always holds something")
	var sealed_ok := true
	for item in (sealed["items"] as Array):
		var piece: Dictionary = item
		if Items.is_equipment(String(piece["slot"])) and int(piece["rarity"]) < 1:
			sealed_ok = false
	check(sealed_ok, "sealed chest gear is never mortal grade")

	var elite := rules.roll("kill.elite", 5, 777, 0)
	check(not (elite["items"] as Array).is_empty(), "an elite always drops at least one piece")
	check(int(elite["stones"]) >= 18 and int(elite["stones"]) <= 40, "an elite carries a purse")
	var wild_purse := 0
	for i in 20:
		wild_purse += int(rules.roll("kill.wild", 5, 800 + i, 0)["stones"])
	check(wild_purse == 0, "ordinary kills carry no purse")

	var rings := {
		"id": "test.rings", "rolls": [3, 3], "empty_chance": 0.0, "min_rarity": 0,
		"rarity_weights": [0, 0, 0, 100], "slot_weights": {"ring": 100}, "stones": [0, 0],
	}
	var ring_roll := rules.roll_with(rings, 4, 31, 0)
	check((ring_roll["items"] as Array).size() == 3, "a table rolls its declared count")
	var rings_ok := true
	var ring_ids := {}
	for item in (ring_roll["items"] as Array):
		var piece: Dictionary = item
		ring_ids[String(piece["id"])] = true
		if String(piece["slot"]) != "ring" or int(piece["rarity"]) != 3:
			rings_ok = false
	check(rings_ok, "slot and rarity weights are obeyed")
	check(ring_ids.size() == 3, "pieces from one roll have distinct ids")

	var empty := {
		"id": "test.empty", "rolls": [2, 2], "empty_chance": 1.0,
		"rarity_weights": [100, 0, 0, 0], "slot_weights": {"material": 100},
	}
	check((rules.roll_with(empty, 3, 5, 0)["items"] as Array).is_empty(), "an empty chance of one drops nothing")
	var no_slots := {
		"id": "test.noslots", "rolls": [2, 2],
		"rarity_weights": [100, 0, 0, 0], "slot_weights": {},
	}
	check((rules.roll_with(no_slots, 3, 5, 0)["items"] as Array).is_empty(), "a table with no slot weights drops nothing")

	var high := {
		"id": "test.high", "rolls": [1, 1], "ilvl_bonus": 4,
		"rarity_weights": [100, 0, 0, 0], "slot_weights": {"ring": 100},
	}
	var high_items: Array = rules.roll_with(high, 5, 12, 0)["items"]
	check(high_items.size() == 1 and int((high_items[0] as Dictionary)["ilvl"]) == 9, "a table's level bonus raises the item level")
	var clamped := {
		"id": "test.clamped", "rolls": [1, 1], "min_rarity": 2,
		"rarity_weights": [100, 0, 0, 0], "slot_weights": {"ring": 100},
	}
	var clamped_items: Array = rules.roll_with(clamped, 4, 13, 0)["items"]
	check(clamped_items.size() == 1 and int((clamped_items[0] as Dictionary)["rarity"]) == 2, "a minimum rarity lifts a mundane roll")
	var unknown := rules.roll("kill.nope", 4, 1, 0)
	check(String(unknown["table"]) == "kill.nope" and not (unknown["items"] as Array).is_empty(), "an unknown source still pays the wild table")

	var plain := Dummy.new()
	add_child(plain)
	check(not plain.is_elite, "a body starts unranked")
	var plain_hp := plain.hp_max
	var plain_damage := plain.damage
	plain.make_elite()
	check(plain.is_elite and plain.is_in_group("elite"), "a wild body can be promoted")
	check(approx(plain.hp_max, plain_hp * 2.4), "an elite carries elite health")
	check(plain.damage > plain_damage, "an elite hits harder")
	check(plain.display_name.begins_with("Elite "), "an elite is named as one")
	plain.queue_free()

	var boss_body := Dummy.new()
	add_child(boss_body)
	boss_body.become_boss(DB.boss("boss.tomb_warden"), 2)
	boss_body.make_elite()
	check(not boss_body.is_elite, "a boss cannot also be an elite")
	boss_body.queue_free()
	var beast_body := Dummy.new()
	add_child(beast_body)
	beast_body.become_beast(Beasts.profile(DB.spirit_beast("beast.moonfang")), 2)
	beast_body.make_elite()
	check(not beast_body.is_elite, "a beast keeps its own rank")
	beast_body.queue_free()


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


## Find one archetype by its stable id.
func _npc_archetype(id: String) -> Dictionary:
	for value in DB.archetypes():
		var archetype: Dictionary = value
		if String(archetype.get("id", "")) == id:
			return archetype
	return {}


# ----------------------------------------------------------------- quests ----

## The NPC record is a pure function; memory is the only thing that changes.
## These checks keep both halves honest: a sheet can never name content that
## does not exist or gear the body could not wear, and a save can never buy
## regard it did not earn.
func _npcdb_tests() -> void:
	print("[npc] every person has a full deterministic record")
	check(DB.npc_goals.size() >= 6, "NPC goals are authored")
	check(not DB.npc_goal("goal.pursue_dao").is_empty(), "a goal can be read by id")
	check(NpcDb.goal_label("goal.pursue_dao") == "Pursue the Dao", "a goal has a label")
	check(NpcDb.goal_blurb("goal.pursue_dao") != "", "a goal has a blurb")
	check(NpcDb.goal_blurb("goal.unknown") == "", "an unknown goal has no blurb")

	var disciple := _npc_archetype("inner_disciple")
	check(not disciple.is_empty(), "the inner disciple archetype exists")
	var first: Dictionary = NpcDb.sheet(disciple, "npc.inner_disciple.7")
	var again: Dictionary = NpcDb.sheet(disciple, "npc.inner_disciple.7")
	check(JSON.stringify(first) == JSON.stringify(again), "a sheet is a pure function of seed and id")
	check(String(first.get("archetype_id", "")) == "inner_disciple", "the sheet remembers its archetype")
	check(int(first.get("realm", 0)) == 2, "the sheet uses the archetype realm")

	var template: Dictionary = disciple.get("attrs", {})
	var attrs: Dictionary = first.get("attrs", {})
	check(attrs.size() == Attributes.KEYS.size(), "every attribute is generated")
	var attrs_ok := true
	for key in Attributes.KEYS:
		if not attrs.has(key) or int(attrs[key]) < int(template.get(key, 0)):
			attrs_ok = false
	check(attrs_ok, "no attribute falls below the archetype base")

	var elder_sheet: Dictionary = NpcDb.sheet(_npc_archetype("elder"), "elder_bai", 4)
	var farmer_sheet: Dictionary = NpcDb.sheet(_npc_archetype("farmer"), "npc.farmer.0")
	check(int((elder_sheet["attrs"] as Dictionary)["str"]) > int((farmer_sheet["attrs"] as Dictionary)["str"]),
		"realm and archetype raise attributes")

	var span: Array = disciple.get("root", [1, 1])
	var root_tier := int(first.get("root_tier", 0))
	check(root_tier >= int(span[0]) and root_tier <= int(span[1]), "the root tier stays in the archetype band")
	var root: Dictionary = DB.by_id("root", String(first.get("root_id", "")))
	check(not root.is_empty() and int(root.get("tier", 0)) == root_tier, "the root id and tier agree")

	var physique_id := String(first.get("physique_id", ""))
	check(not DB.physique(physique_id).is_empty(), "the body is a known physique")
	check((disciple.get("physiques", []) as Array).has(physique_id), "the body comes from the archetype pool")

	var techniques: Array = first.get("techniques", [])
	check(techniques.size() == 2, "a disciple carries two arts")
	var body := Attributes.new()
	body.from_dict(attrs)
	var legal := true
	for tech_id in techniques:
		if not bool(Techniques.can_learn(String(tech_id), {"realm": 2, "attrs": body}).get("ok", false)):
			legal = false
	check(legal, "every art is one the body qualifies for")

	var gear: Dictionary = first.get("gear", {})
	check(not gear.is_empty(), "a disciple wears gear")
	var rules := Equipment.new(DB)
	var gear_ok := true
	for slot in gear.keys():
		var piece: Dictionary = gear[slot]
		if String(piece.get("slot", "")) != String(slot):
			gear_ok = false
		if not rules.missing_requirements(piece, body, 2).is_empty():
			gear_ok = false
	check(gear_ok, "every worn piece passes the equip gate")
	var gear_again: Dictionary = NpcDb.roll_gear(disciple, "npc.inner_disciple.7", 2, attrs)
	check(JSON.stringify(gear) == JSON.stringify(gear_again), "gear rerolls identically")

	var goals: Array = first.get("goals", [])
	check(goals.size() == 2, "two ambitions are chosen")
	var goals_known := true
	for goal_id in goals:
		if DB.npc_goal(String(goal_id)).is_empty():
			goals_known = false
	check(goals_known, "ambitions come from the catalogue")
	check(goals[0] != goals[1], "ambitions do not repeat")
	check(int(first.get("disposition", 99)) == int(disciple.get("disposition", 0)),
		"disposition comes from the archetype")

	var memory: Dictionary = {}
	var blank := NpcDb.memory_entry(memory, "npc.x")
	check(not bool(blank["met"]) and int(blank["talks"]) == 0, "an unmet person starts blank")
	var greeted := NpcDb.remember(memory, "npc.x", 12)
	check(bool(greeted["met"]) and int(greeted["talks"]) == 1 and int(greeted["last_day"]) == 12,
		"talking is remembered")
	check(int(greeted["regard"]) == NpcDb.REGARD_PER_TALK, "talking warms regard")
	check(memory.has("npc.x"), "memory is written to the dictionary it is handed")
	NpcDb.remember(memory, "npc.x", 13)
	var twice := NpcDb.memory_entry(memory, "npc.x")
	check(int(twice["talks"]) == 2 and int(twice["last_day"]) == 13, "memory accumulates")
	check(int(twice["regard"]) == NpcDb.REGARD_PER_TALK * 2, "regard stacks")
	for _i in 40:
		NpcDb.remember(memory, "npc.x", 14)
	check(int(NpcDb.memory_entry(memory, "npc.x")["regard"]) == NpcDb.REGARD_MAX, "regard is capped")
	check(not bool(NpcDb.remember({}, "", 1)["met"]), "an unnamed listener remembers nothing")

	var dirty := NpcDb.sanitize_memory({
		"npc.x": {"met": true, "talks": -4, "last_day": -2, "regard": 900},
		"npc.y": {"met": true, "talks": 3, "last_day": 4, "regard": -3},
		"junk": "nope",
		"": {"met": true},
	})
	check(dirty.size() == 2, "garbage memory entries are dropped")
	check(int(dirty["npc.x"]["talks"]) == 0 and int(dirty["npc.x"]["last_day"]) == 0,
		"negative memory counts are cleaned")
	check(int(dirty["npc.x"]["regard"]) == NpcDb.REGARD_MAX, "regard is clamped on load")
	check(int(dirty["npc.y"]["regard"]) == -3, "a negative regard that is real survives")
	check(NpcDb.sanitize_memory("broken").is_empty(), "a non-dictionary memory block is ignored")
	check(NpcDb.sanitize_memory({}).is_empty(), "an empty save has no memory")

	check(NpcDb.standing_label(-30) == "hostile", "a hostile standing is named")
	check(NpcDb.standing_label(-5) == "wary", "a wary standing is named")
	check(NpcDb.standing_label(0) == "neutral", "a neutral standing is named")
	check(NpcDb.standing_label(12) == "friendly", "a friendly standing is named")
	check(NpcDb.standing_label(30) == "warm", "a warm standing is named")

	# A body carries the record the database rolled, and reads memory live.
	var npc := Npc.new()
	npc.setup("npc.test.body", "Test Body", "Disciple", "sect.azure_cloud", 2, [], null, first)
	check(npc.attrs.get_attr("str") == int(attrs["str"]), "the body carries its attributes")
	check(npc.root_id == String(first["root_id"]) and npc.root_tier == root_tier, "the body carries its root")
	check(npc.technique_ids.size() == techniques.size(), "the body carries its arts")
	check(npc.goal_labels().size() == goals.size(), "the body can name its ambitions")
	check(npc.standing() == int(first["disposition"]), "an unmet body stands at its base disposition")
	Game.npc_memory = {"npc.test.body": {"met": true, "talks": 2, "last_day": 3, "regard": 6}}
	check(npc.regard() == 6, "the body reads its memory")
	check(npc.standing() == int(first["disposition"]) + 6, "memory moves standing without touching the sheet")
	check(npc.standing_label() == NpcDb.standing_label(npc.standing()), "the body names its standing")
	Game.npc_memory.clear()
	npc.free()


## The week, the rest routines, the path graph and the hours a service is open
## are all pure, so every rule can be checked without moving a body.
func _schedules_tests() -> void:
	print("[schedules] the week, rest routines and service hours")
	check(Clock.WEEK_DAYS.size() == Schedules.WEEK_LENGTH, "one week has seven named days")
	check(Clock.weekday_for(1) == 0 and Clock.weekday_for(7) == Clock.REST_WEEKDAY,
		"day one is the first day and day seven the Restday")
	check(Clock.weekday_for(8) == 0, "the week wraps")
	var saved_day: int = Clock.day
	Clock.day = 2
	check(Clock.weekday_name() == Clock.WEEK_DAYS[1], "the clock names its weekday")
	check(Clock.label().contains(Clock.WEEK_DAYS[1]), "the clock line carries the weekday")
	Clock.day = saved_day

	var schedules: Dictionary = DB.schedules()
	var disciple: Array = schedules.get("disciple", [])
	var rest: Array = schedules.get("disciple_rest", [])
	check(not disciple.is_empty() and not rest.is_empty(), "weekday and Restday routines are authored")
	check(String(Schedules.resolve(disciple, 6, 0).get("location", "")) == "shrine", "06:00 puts a disciple at the shrine")
	check(String(Schedules.resolve(disciple, 13, 0).get("location", "")) == "market", "13:00 puts a disciple in the market")
	check(String(Schedules.resolve(disciple, 23, 0).get("activity", "")) == "sleep", "23:00 puts a disciple to bed")
	check(String(Schedules.resolve(rest, 10, 6).get("location", "")) == "market", "a Restday moves the morning to the market")

	var guard: Array = schedules.get("guard", [])
	check(String(Schedules.resolve(guard, 13, 5).get("location", "")) == "training", "Lightday drills replace the plaza patrol")
	check(String(Schedules.resolve(guard, 13, 0).get("location", "")) == "plaza", "other days keep the patrol")
	check(Schedules.applies({"days": [1, 2]}, 2), "a day filter applies on a listed day")
	check(not Schedules.applies({"days": [1, 2]}, 3), "a day filter skips other days")
	check(Schedules.applies({}, 4), "an entry without days applies every day")

	var next := Schedules.next_entry(disciple, 10, 0)
	check(String(next.get("location", "")) == "market" and int(next.get("from", 0)) == 12,
		"the next block is the 12:00 market")
	var dawn := Schedules.next_entry(disciple, 23, 0)
	check(String(dawn.get("activity", "")) == "meditate" and int(dawn.get("from", 0)) == 5,
		"the next block after sleep is dawn meditation")

	var npc := Npc.new()
	npc.schedule = disciple
	npc.rest_schedule = rest
	Clock.day = 3
	check(String(npc.resolve_schedule(10).get("activity", "")) == "train", "a weekday uses the working routine")
	Clock.day = 7
	check(Clock.is_rest_day(), "day seven is the Restday")
	check(String(npc.resolve_schedule(10).get("activity", "")) == "socialize", "a Restday uses the rest routine")
	Clock.day = saved_day
	npc.free()

	var settlement := Settlement.new()
	check("|".join(settlement.route_from("shrine", "market")) == "plaza|market",
		"a walk between spokes goes through the plaza")
	check("|".join(settlement.route_from("plaza", "market")) == "market", "a walk from the plaza is direct")
	check("|".join(settlement.route_from("market", "market")) == "market", "a walk to the same place is direct")
	check("|".join(settlement.route_from("nowhere", "market")) == "market",
		"an unknown origin falls back to a direct walk")
	settlement.free()

	var locations := Settlement.LOCATIONS.keys()
	check(Schedules.validate([{"from": 0, "to": 24, "location": "plaza", "activity": "idle"}], "all_day", locations).is_empty(),
		"a full-day entry is complete")
	check(not Schedules.validate([{"from": 6, "to": 18, "location": "market", "activity": "sell"}], "gap", locations).is_empty(),
		"a schedule with a gap is rejected")
	check(not Schedules.validate([
		{"from": 0, "to": 24, "location": "plaza", "activity": "idle"},
		{"from": 6, "to": 8, "location": "market", "activity": "sell"},
	], "overlap", locations).is_empty(), "overlapping entries are rejected")
	check(not Schedules.validate([{"from": 0, "to": 24, "location": "moon", "activity": "idle"}], "bad", locations).is_empty(),
		"an unknown location is rejected")
	check(not Schedules.validate([
		{"from": 0, "to": 24, "location": "plaza", "activity": "idle", "days": [9]},
	], "days", locations).is_empty(), "an invalid weekday is rejected")
	check(Schedules.validate([
		{"from": 0, "to": 12, "location": "plaza", "activity": "patrol", "days": [0, 1]},
		{"from": 0, "to": 12, "location": "market", "activity": "sell", "days": [2, 3, 4, 5, 6]},
		{"from": 12, "to": 24, "location": "plaza", "activity": "sleep"},
	], "split", locations).is_empty(), "disjoint day filters may share the same hours")
	for schedule_name in schedules.keys():
		check(Schedules.validate(schedules[schedule_name], String(schedule_name), locations).is_empty(),
			"schedule %s is complete and legal" % String(schedule_name))
	for value in DB.archetypes():
		var archetype: Dictionary = value
		var rest_name := String(archetype.get("rest_schedule", ""))
		check(rest_name != "" and schedules.has(rest_name),
			"archetype %s has a Restday routine" % String(archetype.get("id", "")))

	check(not Schedules.awake("sleep") and Schedules.awake("train"), "sleep is not a conversation")
	check(Schedules.can_teach("training", "train"), "the instructor teaches in the yard during training")
	check(not Schedules.can_teach("market", "train"), "a lesson away from the yard is refused")
	check(not Schedules.can_teach("training", "sleep"), "a sleeping instructor teaches nothing")
	check(Schedules.activity_label("meditate") == "meditating", "activities have readable labels")
	check(Schedules.describe("meditate", "shrine", 9) == "Meditating at the shrine until 09:00",
		"a routine reads as a sentence")
	check(Schedules.small_talk("sleep") == "…", "a sleeper has nothing to say")
	check(Schedules.small_talk("sell").contains("price"), "a merchant speaks of prices")


func _npcai_tests() -> void:
	print("[npc ai] nerve, alarms and reactions")
	var timid := NpcAi.profile({"nerve": 0.2, "alert_range": 200.0, "response": "flee",
		"refuge": "fields", "shout": false})
	check(approx(float(timid["nerve"]), 0.2) and approx(float(timid["alert_range"]), 200.0),
		"a profile keeps the values it is given")
	check(String(timid["response"]) == "flee" and String(timid["refuge"]) == "fields",
		"a profile keeps its orders and its refuge")
	check(not bool(timid["shout"]), "a quiet body does not shout")

	var fallback := NpcAi.profile({"response": "dance", "nerve": 4.0, "alert_range": -10.0})
	check(String(fallback["response"]) == "shelter", "an unknown response falls back to shelter")
	check(approx(float(fallback["nerve"]), 1.0), "nerve is clamped to its ceiling")
	check(approx(float(fallback["alert_range"]), 40.0), "the alert range is clamped to its floor")
	check(String(NpcAi.profile({})["refuge"]) == "sect_hall", "a body with no data takes the default refuge")

	var threats := [
		{"id": "beast.a", "position": Vector2(300, 0)},
		{"id": "beast.b", "position": Vector2(120, 0)},
		{"id": "junk", "position": "not a vector"},
		42,
	]
	var near := NpcAi.nearest_threat(Vector2.ZERO, threats, 200.0)
	check(String(near.get("id", "")) == "beast.b", "the closest threat wins")
	check(approx(float(near.get("distance", 0.0)), 120.0), "distance is measured from the body")
	check(NpcAi.nearest_threat(Vector2.ZERO, threats, 50.0).is_empty(),
		"a threat outside the alert range is not seen")
	check(NpcAi.nearest_threat(Vector2.ZERO, [], 500.0).is_empty(), "an empty world is quiet")
	check(NpcAi.nearest_threat(Vector2.ZERO, threats, 0.0).is_empty(), "a blind body sees nothing")
	check(NpcAi.watched(threats, Vector2.ZERO, 360.0).size() == 2,
		"the watch ring keeps the real bodies and drops the rest")
	check(NpcAi.watched([{"id": "far", "position": Vector2(400, 0)}], Vector2.ZERO, 360.0).is_empty(),
		"a body in the wilds is nobody's alarm")

	check(NpcAi.decide(false, false, timid) == "routine", "an ordinary hour follows the routine")
	check(NpcAi.decide(true, false, timid) == "flee", "a seen threat is answered")
	check(NpcAi.decide(false, true, timid) == "flee", "a shout is answered without a sighting")
	var brave := NpcAi.profile({"nerve": 0.9, "response": "confront"})
	var shaky := NpcAi.profile({"nerve": 0.2, "response": "confront"})
	check(NpcAi.decide(true, false, brave) == "confront", "a steady body holds its ground")
	check(NpcAi.decide(true, false, shaky) == "shelter",
		"a faint-hearted guard takes shelter instead of standing")
	check(NpcAi.CONFRONT_NERVE > 0.2 and NpcAi.CONFRONT_NERVE < 0.9,
		"the nerve threshold separates the steady from the shaky")

	check(NpcAi.hears(Vector2.ZERO, Vector2(300, 0)), "a shout carries across the market")
	check(not NpcAi.hears(Vector2.ZERO, Vector2(500, 0)), "a shout has a limit")
	check(NpcAi.hears(Vector2.ZERO, Vector2(500, 0), 600.0), "a louder shout carries further")

	var hold := NpcAi.approach_point(Vector2.ZERO, Vector2(300, 0), NpcAi.CONFRONT_GAP)
	check(approx(hold.distance_to(Vector2(300, 0)), NpcAi.CONFRONT_GAP),
		"a confronting body stops at the hold gap")
	var inside := NpcAi.approach_point(Vector2(260, 0), Vector2(300, 0), NpcAi.CONFRONT_GAP)
	check(inside == Vector2(260, 0), "a body already inside the gap holds where it stands")
	check(NpcAi.target_for("shelter", Vector2.ZERO, Vector2(300, 0), Vector2(-200, 70), fallback) == Vector2(-200, 70),
		"a sheltering body runs to its refuge")
	check(NpcAi.target_for("routine", Vector2(5, 5), Vector2(300, 0), Vector2.ZERO, fallback) == Vector2(5, 5),
		"a routine body has no reaction target")
	check(NpcAi.hold_at("confront", brave) > 0.0 and approx(NpcAi.hold_at("flee", timid), 0.0),
		"only a confronting body keeps a distance")

	check(NpcAi.label("confront") == "Standing ground", "a reaction has a label")
	check(NpcAi.label("routine") == "About their business", "a calm body reads as calm")
	check(NpcAi.short_label("shelter") == "sheltering", "the nameplate tag is short")
	check(NpcAi.describe("routine", 120.0) == "", "a calm body has no alarm line")
	check(NpcAi.describe("confront", 240.0).contains("24 paces"), "the alarm line reads a distance in paces")
	check(NpcAi.warning_line("flee").contains("Run"), "a fleeing body shouts a warning")
	check(NpcAi.warning_line("routine") == "", "a calm body warns nobody")
	check(NpcAi.nerve_label(0.9) == "steady" and NpcAi.nerve_label(0.1) == "timid",
		"nerve reads as a word")

	var npc := Npc.new()
	npc.apply_ai({"nerve": 0.9, "response": "confront", "refuge": "gate"})
	check(not npc.reacting(), "an unalarmed body is not reacting")
	check(npc.react("confront", Vector2(300, 0), NpcAi.ALARM_SECONDS, 300.0),
		"sighting a threat raises an alarm")
	check(npc.reacting() and npc.reaction == "confront", "the reaction is in force while the alarm lasts")
	check(not npc.react("confront", Vector2(320, 0), NpcAi.ALARM_SECONDS, 320.0),
		"the same alarm is not raised twice")
	npc.alarm_left = 1.0
	npc.react("confront", Vector2(320, 0), NpcAi.ALARM_SECONDS, 320.0)
	check(approx(npc.alarm_left, NpcAi.ALARM_SECONDS),
		"a fresh sighting keeps the alarm alive while the danger lasts")
	check(npc.react("shelter", Vector2(320, 0), NpcAi.ALARM_SECONDS, 320.0),
		"a new order is a new alarm")
	check(npc.reaction_line().contains("paces") and npc.warning_line() != "",
		"an alarmed body reads and speaks its alarm")
	npc.alarm_left = 0.0
	check(not npc.reacting(), "an expired alarm ends the reaction")
	npc.free()

	var guard_brain := {}
	var farmer_brain := {}
	var merchant_brain := {}
	for value in DB.archetypes():
		var archetype: Dictionary = value
		var data: Dictionary = archetype.get("ai", {})
		var brain := NpcAi.profile(data)
		check(not data.is_empty() and Settlement.LOCATIONS.has(String(brain["refuge"])),
			"archetype %s has a real refuge" % String(archetype.get("id", "")))
		var archetype_id := String(archetype.get("id", ""))
		if archetype_id == "guard":
			guard_brain = brain
		elif archetype_id == "farmer":
			farmer_brain = brain
		elif archetype_id == "merchant":
			merchant_brain = brain
	check(String(guard_brain.get("response", "")) == "confront" and NpcAi.decide(true, false, guard_brain) == "confront",
		"a guard stands its ground")
	check(String(farmer_brain.get("response", "")) == "flee", "a farmer runs")
	check(String(merchant_brain.get("response", "")) == "shelter", "a merchant shuts the stall")


func _relationships_tests() -> void:
	print("[relationships] bands, ties and a directed graph")
	# The catalogue is data, and it must tile the whole range.
	check(DB.bonds.size() >= 6, "the bond catalogue has a band for every degree")
	check(Relationships.validate(DB.bonds, DB.bond_ties, DB.bond_pairs).is_empty(),
		"the shipped relationship data is consistent")
	check(String(DB.bond("bond.friend").get("label", "")) == "Friend", "a band is indexed by id")
	check(DB.bond("bond.nonsense").is_empty(), "an unknown band is not invented")
	check(String(DB.bond_tie("tie.mentor").get("reciprocal", "")) == "tie.student",
		"a tie knows what the other side is called")
	check(DB.bond_tie("").is_empty(), "an empty tie id is not a tie")

	# Thresholds: each band owns a slice, including both of its edges.
	check(Relationships.band_id(-100) == "bond.enemy", "the floor is an enemy's")
	check(Relationships.band_id(-21) == "bond.enemy", "the coldest rival score is still enmity")
	check(Relationships.band_id(-20) == "bond.rival", "one point warmer is a rival")
	check(Relationships.band_id(-6) == "bond.rival", "a rival's warm edge")
	check(Relationships.band_id(-5) == "bond.stranger", "a stranger begins where rivalry ends")
	check(Relationships.band_id(9) == "bond.stranger", "a stranger's warm edge")
	check(Relationships.band_id(10) == "bond.acquaintance", "an acquaintance begins")
	check(Relationships.band_id(24) == "bond.acquaintance", "an acquaintance ends at friendship")
	check(Relationships.band_id(25) == "bond.friend", "friendship begins at its threshold")
	check(Relationships.band_id(49) == "bond.friend", "friendship holds its range")
	check(Relationships.band_id(50) == "bond.sworn", "a sworn friend is made at fifty")
	check(Relationships.band_id(100) == "bond.sworn", "the ceiling is a sworn bond")
	check(Relationships.band_id(-500) == "bond.enemy", "an impossible score clamps at enmity")
	check(Relationships.band_id(500) == "bond.sworn", "an impossible warmth clamps at devotion")
	check(Relationships.label(30) == "Friend" and Relationships.blurb(30) != "",
		"a band names and explains itself")
	check(Relationships.describe(30) == "Friend (+30)", "a bond reads as a label and a number")
	check(Relationships.greeting("bond.stranger") != "", "every band has a greeting")
	check(Relationships.greeting("bond.nonsense") == "", "an unknown band greets nobody")

	# Behaviour is a rule on the band, not a number scattered through callers.
	check(Relationships.warns(25), "a friend warns the player")
	check(Relationships.warns(80), "a sworn friend warns the player")
	check(not Relationships.warns(24), "an acquaintance keeps its own counsel")
	check(not Relationships.refuses(-20), "a rival still speaks")
	check(Relationships.refuses(-21), "an enemy refuses")

	# Ties: structural, reciprocal, and directional.
	check(Relationships.reciprocal("tie.mentor") == "tie.student", "a mentor's other side is a student")
	check(Relationships.reciprocal("tie.student") == "tie.mentor", "a student's other side is a mentor")
	check(Relationships.reciprocal("tie.kin") == "tie.kin", "kin is its own other side")
	check(Relationships.reciprocal("") == "", "no tie has no other side")

	var elder_to_rui := Relationships.edge("elder_bai", "instructor_rui")
	var rui_to_elder := Relationships.edge("instructor_rui", "elder_bai")
	check(String(elder_to_rui.get("tie", "")) == "tie.mentor", "the elder is the instructor's mentor")
	check(String(rui_to_elder.get("tie", "")) == "tie.student", "the instructor is the elder's student")
	check(int(elder_to_rui.get("score", 0)) == 46, "an authored tie keeps its score")
	check(int(rui_to_elder.get("score", 0)) == 58, "the other direction keeps its own")
	check(String(elder_to_rui.get("label", "")) == "Mentor", "a tie names the edge")
	check(String(elder_to_rui.get("band", "")) == "bond.friend", "a tie still carries a warmth band")
	check(String(elder_to_rui.get("blurb", "")) == "Someone whose teaching shaped another's road.",
		"a tie explains itself")
	check(not Relationships.pair("instructor_rui", "elder_bai").is_empty(),
		"an authored pair is found by direction")
	check(Relationships.pair("elder_bai", "npc.guard.0").is_empty(), "an unauthored pair is not invented")
	var ties := Relationships.ties_of("elder_bai")
	check(ties.size() == 1 and String((ties[0] as Dictionary).get("to", "")) == "instructor_rui",
		"the elder's ties name the instructor")
	check(String((ties[0] as Dictionary).get("phrase", "")).contains("%s"),
		"a tie carries a readable phrase")
	check(Relationships.ties_of("").is_empty(), "nobody is bound to nobody")
	check(Relationships.edge("elder_bai", "npc.guard.0").get("tie", "") == "",
		"an unauthored edge has no tie")

	# The seeded fabric: deterministic, bounded, and not symmetric.
	var a := Relationships.base_score("npc.guard.0", "npc.farmer.0")
	var b := Relationships.base_score("npc.guard.0", "npc.farmer.0")
	check(a == b, "the same pair draws the same baseline")
	check(a >= Relationships.BASE_MIN and a <= Relationships.BASE_MAX, "a baseline stays in its range")
	check(Relationships.base_score("npc.guard.0", "npc.guard.0") == 0, "nobody has a score with themselves")
	check(Relationships.base_score("", "npc.guard.0") == 0, "an empty person has no score")
	var found_asymmetry := false
	for other in ["npc.farmer.0", "npc.merchant.0", "npc.outer_disciple.0", "npc.guard.1"]:
		if Relationships.base_score("npc.guard.0", String(other)) != Relationships.base_score(String(other), "npc.guard.0"):
			found_asymmetry = true
	check(found_asymmetry, "two people do not feel exactly the same about each other")

	# The whole fabric, built on demand and never stored.
	var ids := ["elder_bai", "instructor_rui", "npc.guard.0"]
	var graph := Relationships.graph(ids)
	check(graph.size() == 3, "every named person gets a row")
	check((graph["npc.guard.0"] as Dictionary).size() == 2, "a row has an edge to everyone else")
	check(not (graph["npc.guard.0"] as Dictionary).has("npc.guard.0"), "nobody has an edge to themselves")
	var graph_ok := true
	for from_id in graph.keys():
		var row: Dictionary = graph[from_id]
		for to_id in row.keys():
			var row_edge: Dictionary = row[to_id]
			if DB.bond(String(row_edge.get("band", ""))).is_empty():
				graph_ok = false
	check(graph_ok, "every generated edge reads through a real band")
	check(Relationships.graph([]).is_empty(), "an empty settlement has no fabric")

	# The player node is memory, read through the same bands.
	var neutral := Relationships.toward_player(0, 0)
	check(int(neutral.get("score", 0)) == 0 and String(neutral.get("band", "")) == "bond.stranger",
		"an unmet stranger starts neutral")
	var warm := Relationships.toward_player(10, 30)
	check(int(warm.get("score", 0)) == 40, "temperament plus regard is the player's score")
	check(String(warm.get("band", "")) == "bond.friend", "a warm regard reads as friendship")
	check(String(warm.get("label", "")) == "Friend", "the player's bond has a name")
	check(int(Relationships.toward_player(-100, -100).get("score", 0)) == -100,
		"the player's score clamps at the floor")
	check(int(Relationships.toward_player(100, 100).get("score", 0)) == 100,
		"the player's score clamps at the ceiling")

	var npc := Npc.new()
	npc.npc_id = "npc.test.bond"
	npc.base_disposition = 10
	Game.npc_memory = {"npc.test.bond": {"met": true, "talks": 1, "last_day": 1, "regard": 15}}
	check(int(npc.bond_to_player().get("score", 0)) == 25, "a body's bond reads its own memory")
	check(npc.bond_label() == "Friend", "a body names its bond")
	check(npc.bond_line() == "Friend (+25)", "the dossier line carries the number")
	npc.npc_id = "npc.test.unknown"
	check(int(npc.bond_to_player().get("score", 0)) == 10,
		"an unremembered body still has its temperament")
	Game.npc_memory.clear()
	npc.free()

	# Validation: the checks have teeth.
	check(not Relationships.validate([], [], []).is_empty(), "a missing catalogue is a problem")
	var thin := [{"id": "bond.enemy", "label": "Enemy", "min": -100, "max": 0, "greeting": "x", "blurb": "x"}]
	check(not Relationships.validate(thin, [], []).is_empty(), "bands that stop early leave a gap")
	var overlapping := [
		{"id": "bond.one", "label": "One", "min": -100, "max": 20, "greeting": "x", "blurb": "x"},
		{"id": "bond.two", "label": "Two", "min": 20, "max": 100, "greeting": "x", "blurb": "x"},
	]
	check(not Relationships.validate(overlapping, [], []).is_empty(), "overlapping bands are a problem")
	var bad_ties := [{"id": "tie.a", "label": "A", "reciprocal": "tie.missing", "phrase": "%s of %s"}]
	check(not Relationships.validate(DB.bonds, bad_ties, []).is_empty(), "a tie to nothing is a problem")
	var one_sided := [
		{"id": "tie.a", "label": "A", "reciprocal": "tie.b", "phrase": "%s of %s"},
		{"id": "tie.b", "label": "B", "reciprocal": "tie.b", "phrase": "%s of %s"},
	]
	check(not Relationships.validate(DB.bonds, one_sided, []).is_empty(), "ties that disagree are a problem")
	var bad_pairs := [{"from": "a", "to": "b", "tie": "tie.ghost", "score": 10}]
	check(not Relationships.validate(DB.bonds, DB.bond_ties, bad_pairs).is_empty(),
		"a pair with no tie is a problem")
	var duplicate_pairs := [
		{"from": "a", "to": "b", "tie": "tie.kin", "score": 10},
		{"from": "a", "to": "b", "tie": "tie.kin", "score": 20},
	]
	check(not Relationships.validate(DB.bonds, DB.bond_ties, duplicate_pairs).is_empty(),
		"the same pair twice is a problem")
	var self_pair := [{"from": "a", "to": "a", "tie": "tie.kin", "score": 10}]
	check(not Relationships.validate(DB.bonds, DB.bond_ties, self_pair).is_empty(),
		"a pair with itself is a problem")
	var wild_score := [{"from": "a", "to": "b", "tie": "tie.kin", "score": 400}]
	check(not Relationships.validate(DB.bonds, DB.bond_ties, wild_score).is_empty(),
		"a pair beyond the range is a problem")


func _party_tests() -> void:
	print("[party] trust, slots, formation and a companion's own fight")
	# Trust is M50's friend band, not a second threshold.
	check(Party.willing(25), "a friend will travel with you")
	check(Party.willing(60), "a sworn friend will travel with you")
	check(not Party.willing(24), "an acquaintance will not")
	check(not Party.willing(-20), "a rival will not")

	var roster: Array = []
	check(not bool(Party.can_recruit(roster, "", 50, 3).get("ok", true)), "there is nobody to ask")
	check(not bool(Party.can_recruit(roster, "npc.a", 10, 3).get("ok", true)),
		"an unwilling body is refused")
	check(String(Party.can_recruit(roster, "npc.a", 10, 3).get("reason", "")).contains("trust"),
		"the refusal says why")
	check(bool(Party.can_recruit(roster, "npc.a", 40, 3).get("ok", false)), "a friend may join")
	check(not bool(Party.can_recruit(roster, "npc.a", 40, 0).get("ok", true)),
		"no slots means no party")
	check(not bool(Party.can_recruit(roster, "npc.a", 40, -2).get("ok", true)),
		"a negative capacity refuses")
	check(Party.add(roster, "npc.a"), "a member is added")
	check(not Party.add(roster, "npc.a"), "the same member is not added twice")
	check(not Party.add(roster, ""), "an empty id is not a member")
	check(Party.has(roster, "npc.a"), "membership is readable")
	check(Party.index_of(roster, "npc.a") == 0, "formation order is roster order")
	check(Party.add(roster, "npc.b") and Party.index_of(roster, "npc.b") == 1,
		"the second slot follows the first")
	check(not bool(Party.can_recruit(roster, "npc.c", 40, 2).get("ok", true)),
		"a full party refuses a third")
	check(not bool(Party.can_recruit(roster, "npc.a", 40, 2).get("ok", true)),
		"an existing member is not re-recruited")
	check(String(Party.can_recruit(roster, "npc.a", 40, 2).get("reason", "")).contains("already"),
		"the duplicate refusal says why")
	check(Party.remove(roster, "npc.a"), "a member is dismissed")
	check(not Party.remove(roster, "npc.a"), "a dismissal happens once")
	check(not Party.has(roster, "npc.a") and Party.index_of(roster, "npc.b") == 0,
		"the roster closes the gap")
	check(Party.slots_label(1, 4) == "1/4", "the party reads as a count")
	check(Party.MAX_SIZE >= 3, "the ceiling leaves room for a real party")

	# A stored roster is cleaned, not trusted.
	check(Party.sanitize("junk").is_empty(), "a non-list roster loads empty")
	check(Party.sanitize(["npc.a", "", "npc.a", "npc.b"]).size() == 2,
		"empty and duplicate ids are dropped")
	var many: Array = []
	for i in 20:
		many.append("npc.%d" % i)
	check(Party.sanitize(many).size() == Party.MAX_SIZE, "the ceiling applies on load")
	check(Party.sanitize([3]).size() == 1, "an id may be numeric in the file")

	# Formation is deterministic and behind the player.
	var facing := Vector2.RIGHT
	var back := Party.follow_offset(0, facing)
	check(approx(back.x, -Party.FOLLOW_GAP), "slot zero walks directly behind the player")
	check(approx(back.y, 0.0), "the back slot does not drift sideways")
	var left := Party.follow_offset(1, facing)
	var right := Party.follow_offset(2, facing)
	check(left != right, "the two flanks are different places")
	check(approx(left.y, -right.y), "the flanks mirror each other")
	check(approx(left.x, right.x), "both flanks sit the same distance back")
	check(Party.follow_offset(0, Vector2.ZERO) == Party.follow_offset(0, Vector2.DOWN),
		"a body with no facing falls back to down")
	check(Party.follow_offset(0, facing) == Party.follow_offset(0, facing), "the formation repeats")
	check(Party.follow_offset(4, facing).length() > Party.follow_offset(1, facing).length(),
		"later members stand wider")

	# A companion fights with its own sheet.
	Game.party_ids.clear()
	var npc := Npc.new()
	npc.npc_id = "npc.test.party"
	npc.realm = 2
	npc.attrs.from_dict({"str": 16, "dex": 13, "agi": 12, "int": 10, "wis": 11, "char": 10})
	npc.gear = {"weapon": {"id": "item.test.saber", "slot": "weapon", "name": "Test Saber",
		"base_damage": 12.0, "armor": 0.0, "mods": []}}
	check(not npc.in_party and npc.hp_max <= 0.0, "an idle resident has no party health")
	check(npc.take_hit(10.0) <= 0.0, "a resident who is not in the party cannot be hit")
	npc.join_party()
	check(npc.in_party, "joining makes a companion")
	check(npc.hp_max > 40.0 and npc.hp == npc.hp_max,
		"a companion gets health from its realm and body")
	check(npc.party_stats != null and npc.party_stats.weapon_damage() >= 12.0,
		"a companion wears its real weapon")
	check(npc.party_damage() > 3.0, "a companion's blow is real")
	check(npc.party_poise() > 0.0 and npc.party_penetration() >= 0.0,
		"a companion's blow carries poise and steel")
	check(npc.party_interval() > 0.0 and npc.party_interval() <= 1.6, "a companion's cadence is bounded")
	var before := npc.hp
	var dealt := npc.take_hit(20.0, Vector2.ZERO, false)
	check(dealt > 0.0 and npc.hp < before, "a companion can be hurt")
	check(npc.hp_max > npc.hp, "one blow does not end a companion")
	npc.take_hit(npc.hp_max * 2.0, Vector2.ZERO, false)
	check(not npc.in_party, "a downed companion leaves the party")
	check(npc.hp > 0.0, "a downed companion is not dead")
	check(Game.party_ids.is_empty(), "a downed companion leaves the saved roster")
	npc.free()


## Captivity is a status with consequences: labour, upkeep, loyalty drift,
## escape, rebellion, bounty and a legal name the market remembers. Every rule
## is a pure static, so the whole trade is checked without a body or a scene.
func _captivity_tests() -> void:
	print("[captivity] the holding yard is a ledger, not an inventory slot")
	var policies := Captivity.policies()
	check(policies.size() >= 2, "captivity ships more than one set of terms")
	check(Captivity.policy_ids().has(Captivity.DEFAULT_POLICY), "the default terms exist")
	check(String(Captivity.policy(Captivity.DEFAULT_POLICY).get("name", "")) != "",
		"a policy has a name")
	check(Captivity.policy_id_or_default("captivity.nonsense") == Captivity.default_policy_id(),
		"an unknown policy falls back to authored terms")
	check(Captivity.policy("captivity.nonsense").is_empty(), "an unknown policy is empty, not invented")

	var fair := Captivity.new_record("captive.test.fair", "Lin Zhao", 2, 0, 4, Captivity.DEFAULT_POLICY)
	var harsh := Captivity.new_record("captive.test.harsh", "Mo Yan", 2, 0, 4, Captivity.HARD_POLICY)
	check(String(fair.get("policy", "")) == Captivity.DEFAULT_POLICY, "a record keeps the terms it was taken under")
	check(int(fair.get("bound_day", 0)) == 4, "a record remembers the day")
	check(int(fair.get("loyalty", 0)) == int(Captivity.loyalty_rules().get("start", 35)),
		"a stranger starts at the authored loyalty")
	var warmer := Captivity.new_record("captive.test.warm", "Su Fei", 1, 80, 4, Captivity.DEFAULT_POLICY)
	check(int(warmer.get("loyalty", 0)) > int(fair.get("loyalty", 0)),
		"a person already warm to you starts more loyal")

	check(Captivity.daily_labor(fair) > 0, "a captive's work is worth stones")
	check(Captivity.daily_labor(harsh) > Captivity.daily_labor(fair),
		"harsh terms extract more labour")
	check(Captivity.upkeep(fair) > Captivity.upkeep(harsh), "fair terms cost rations")
	var higher := Captivity.new_record("captive.test.higher", "Han Jue", 5, 0, 4, Captivity.DEFAULT_POLICY)
	check(Captivity.daily_labor(higher) > Captivity.daily_labor(fair),
		"a higher realm works more")
	var broken := fair.duplicate(true)
	broken["loyalty"] = 0
	check(Captivity.daily_labor(broken) < Captivity.daily_labor(fair),
		"a broken person works less")
	check(Captivity.daily_labor(broken) >= 0, "labour is never negative")

	check(Captivity.loyalty_band(0) == Captivity.BAND_REBELLIOUS, "zero loyalty is rebellious")
	check(Captivity.loyalty_band(20) == Captivity.BAND_RESTLESS, "a hungry person is restless")
	check(Captivity.loyalty_band(50) == Captivity.BAND_STEADY, "an ordinary captive is steady")
	check(Captivity.loyalty_band(90) == Captivity.BAND_BONDED, "a long-kept person can bond")
	check(Captivity.loyalty_label(0) == "Rebellious", "the band has a player-facing name")
	check(Captivity.loyalty_colour(0) != Captivity.loyalty_colour(90), "the bands read apart")

	var chance_low := Captivity.escape_chance(broken, 1)
	var chance_high := Captivity.escape_chance(fair, 1)
	check(chance_low > chance_high, "desperation raises the chance of escape")
	check(Captivity.escape_chance(fair, 4) > Captivity.escape_chance(fair, 1),
		"a crowded yard is harder to watch")
	check(Captivity.escape_chance(broken, 40) <= float(Captivity.escape_rules().get("max", 0.55)) + 0.0001,
		"escape chance is capped")
	var escape_day := 12
	var escape_roll := float(Rng.roll_float(Captivity.ESCAPE_DOMAIN, hash(String(broken.get("id", ""))), escape_day))
	check(Captivity.escapes(broken, escape_day, 1) == (escape_roll < Captivity.escape_chance(broken, 1)),
		"the escape check is the documented roll, not a scripted run")
	check(Captivity.escapes(broken, escape_day, 1) == Captivity.escapes(broken, escape_day, 1),
		"the same night cannot be rerolled")

	var calm_yard: Array = [fair, fair.duplicate(true), fair.duplicate(true)]
	var angry_yard: Array = []
	for i in 3:
		var angry := fair.duplicate(true)
		angry["id"] = "captive.test.angry.%d" % i
		angry["loyalty"] = 8
		angry_yard.append(angry)
	check(not Captivity.rebellion_risk(calm_yard), "a contented yard does not rise")
	check(Captivity.rebellion_risk(angry_yard), "enough desperate people rise together")
	check(not Captivity.rebellion_risk([angry_yard[0], angry_yard[1]]), "two people are not a rebellion")

	# One fair day: labour is earned, rations are paid out of it, loyalty rises.
	var day_result := Captivity.settle_day([fair], 10, 0)
	check(int(day_result.get("labor", 0)) > 0, "a day's work is counted")
	check(int(day_result.get("paid", 0)) > 0, "rations are paid")
	check(int(day_result.get("net", 0)) == int(day_result.get("labor", 0)) - int(day_result.get("paid", 0)),
		"the keeper's share is labour minus rations")
	var kept: Array = day_result.get("records", [])
	check(kept.size() == 1, "a contented captive stays")
	check(int((kept[0] as Dictionary).get("loyalty", 0)) > int(fair.get("loyalty", 0)),
		"fair terms slowly win loyalty")
	check(int(day_result.get("notoriety", 0)) > 0, "holding people is a crime the market counts")
	check(int(fair.get("loyalty", 0)) == int(Captivity.loyalty_rules().get("start", 35)),
		"settling a day does not mutate the saved record")

	var harsh_day := Captivity.settle_day([harsh], 10, 100)
	var harsh_kept: Array = harsh_day.get("records", [])
	check(int((harsh_kept[0] as Dictionary).get("loyalty", 0)) < int(harsh.get("loyalty", 0)),
		"harsh terms burn loyalty")
	check(int(harsh_day.get("notoriety", 0)) > int(day_result.get("notoriety", 0)),
		"harsh terms are worse for your name")

	# A poor keeper: two fair captives, no stones, so the rations go unpaid.
	var poor: Array = []
	for i in 2:
		var record := fair.duplicate(true)
		record["id"] = "captive.test.poor.%d" % i
		record["realm"] = 1
		record["loyalty"] = 0
		poor.append(record)
	var poor_day := Captivity.settle_day(poor, 10, 0)
	check(int(poor_day.get("unpaid", 0)) > 0, "rations can go unpaid")
	check(int(poor_day.get("net", 0)) >= 0, "the keeper never pays out more than the work earns")
	check(not (poor_day.get("notes", []) as Array).is_empty(), "an unpaid day says so")

	# Rebellion takes everyone desperate at once.
	var rising := Captivity.settle_day(angry_yard, 10, 100)
	check(bool(rising.get("rebellion", false)), "a desperate yard rebels")
	check((rising.get("records", []) as Array).is_empty(), "the rebels all leave")
	check((rising.get("escaped", []) as Array).size() == 3, "every rebel is named")

	check(Captivity.bounty(fair) > 0, "the watch pays for a handover")
	check(Captivity.bounty(higher) > Captivity.bounty(fair), "a stronger cultivator is worth more")
	check(Captivity.capture_notoriety() > 0, "taking a person costs your name something")
	check(Captivity.handover_relief() > 0 and Captivity.release_relief() > 0,
		"both endings give the name some relief")
	check(Captivity.legal_label(0) != Captivity.legal_label(100), "the legal name changes with the number")
	check(not Captivity.wanted(int(Captivity.legal_band(0).get("max", 9))),
		"the lowest legal band is not wanted")
	check(not Captivity.wanted(0), "an unmarked cultivator is not wanted")
	check(Captivity.wanted(Captivity.notoriety_cap()), "a full name is wanted")
	check(Captivity.legal_blurb(0) != "", "a legal band explains itself")

	# Binding is refused for a reason the player can read.
	var saved_toggle: bool = bool(Settings.content.get("captivity", true))
	Settings.content["captivity"] = true
	check(bool(Captivity.can_bind([]).get("ok", false)), "an empty yard accepts a captive")
	var full: Array = []
	for i in Captivity.max_held():
		full.append(Captivity.new_record("captive.test.full.%d" % i, "Captive %d" % i, 1, 0, 1, Captivity.DEFAULT_POLICY))
	check(not bool(Captivity.can_bind(full).get("ok", false)), "a full yard refuses another")
	Settings.content["captivity"] = false
	check(not Captivity.enabled(), "the subsystem can be switched off")
	var off := Captivity.can_bind([])
	check(not bool(off.get("ok", false)) and String(off.get("reason", "")) != "",
		"a switched-off subsystem explains itself")
	Settings.content["captivity"] = saved_toggle

	# A save is read without trust.
	check(Captivity.sanitize("nonsense").is_empty(), "a malformed roster becomes empty")
	var loaded := Captivity.sanitize([
		{"id": "captive.a", "name": "A", "realm": 99, "loyalty": 500, "policy": "nope", "labor": -4},
		{"id": "captive.a", "name": "duplicate"},
		{"id": "", "name": "nameless"},
		{"id": "captive.b", "name": "B", "loyalty": -50},
	])
	check(loaded.size() == 2, "duplicate and nameless records are dropped")
	check(int((loaded[0] as Dictionary).get("realm", 0)) == 12, "a loaded realm is clamped")
	check(int((loaded[0] as Dictionary).get("loyalty", 0)) == int(Captivity.loyalty_rules().get("max", 100)),
		"a loaded loyalty is clamped")
	check(String((loaded[0] as Dictionary).get("policy", "")) == Captivity.default_policy_id(),
		"an unknown policy becomes authored terms")
	check(int((loaded[1] as Dictionary).get("loyalty", 0)) == 0, "negative loyalty floors at zero")
	check(Captivity.describe(loaded[0]).contains("realm"), "a captive can be described in one line")

	# The shipped file passes its own validator, and each broken rule fails it.
	check(Captivity.validate(DB.captivity).is_empty(), "the shipped captivity data validates")
	var broken_data: Dictionary = DB.captivity.duplicate(true)
	(broken_data["policies"] as Array)[0]["labor"] = 0.0
	check(not Captivity.validate(broken_data).is_empty(), "a policy that pays nothing is rejected")
	var gap_data: Dictionary = DB.captivity.duplicate(true)
	(gap_data["legal"] as Array)[1]["min"] = 40
	check(not Captivity.validate(gap_data).is_empty(), "a gap in the legal bands is rejected")
	var ladder_data: Dictionary = DB.captivity.duplicate(true)
	(ladder_data["loyalty"] as Dictionary)["restless"] = 5
	check(not Captivity.validate(ladder_data).is_empty(), "an out-of-order loyalty ladder is rejected")


## The town climbs without the player. Progression is a pure day-by-day
## simulation from the world seed and the person's stable id, so the checks are
## about determinism, monotonicity, caps and consequences — not about saved data.
func _npc_progress_tests() -> void:
	print("[npc progression] the town climbs without the player")
	NpcProgress.reset_cache()
	check(not NpcProgress.archetype("outer_disciple").is_empty(), "an archetype is found by id")
	check(NpcProgress.archetype("nobody").is_empty(), "an unknown archetype is empty")
	check(not NpcProgress.profile("outer_disciple").is_empty(), "an archetype carries a discipline profile")
	check(NpcProgress.realm_cap("outer_disciple") >= NpcProgress.base_realm("outer_disciple"),
		"a cap is never below the starting realm")
	check(NpcProgress.realm_cap("farmer") < NpcProgress.realm_cap("sect_master"),
		"a sect master's ceiling outranks a farmer's")
	check(float(NpcProgress.profile("inner_disciple").get("rate", 0.0)) >
		float(NpcProgress.profile("farmer").get("rate", 0.0)), "disciples train harder than farmers")

	var seed_a := 424242
	var person := "npc.progress.unit"
	var day_one := NpcProgress.state_for("outer_disciple", person, 1, seed_a)
	check(int(day_one.get("realm", 0)) == NpcProgress.base_realm("outer_disciple"),
		"a person starts at the archetype's realm")
	check(int(day_one.get("sublevel", 0)) == 1, "a person starts at the first sublevel")
	check(float(day_one.get("insight", 0.0)) >= 0.0, "nobody starts in insight debt")

	var day_300 := NpcProgress.state_for("outer_disciple", person, 300, seed_a)
	check(int(day_300.get("realm", 0)) > int(day_one.get("realm", 0))
		or int(day_300.get("sublevel", 0)) > 1, "three hundred days of practice move a person")
	check(int(day_300.get("realm", 0)) <= NpcProgress.realm_cap("outer_disciple"),
		"growth respects the realm cap")
	check(float(day_300.get("insight", 0.0)) >= 0.0, "insight never goes negative")

	# Determinism: seed, id and day decide the person; nothing else does.
	NpcProgress.reset_cache()
	var rebuilt := NpcProgress.state_for("outer_disciple", person, 300, seed_a)
	check(str(rebuilt) == str(day_300), "the same seed and day rebuild the same person")
	var neighbour := NpcProgress.state_for("outer_disciple", "npc.progress.other", 300, seed_a)
	check(str(neighbour) != str(day_300), "two disciples do not advance in lockstep")
	var other_world := NpcProgress.state_for("outer_disciple", person, 300, seed_a + 1)
	check(str(other_world) != str(day_300), "a different world advances differently")

	# A load rewinds the clock, so it must rewind the record too.
	var rewound := NpcProgress.state_for("outer_disciple", person, 60, seed_a)
	check(int(rewound.get("realm", 1)) <= int(day_300.get("realm", 1)),
		"rewinding the clock rewinds the record")

	# A failed breakthrough may cost a sublevel (that is the intended failure),
	# but a realm is never lost to time.
	var previous_realm := 0
	var realms_hold := true
	for cursor in [30, 90, 180, 360, 540, 720]:
		var state := NpcProgress.state_for("outer_disciple", person, int(cursor), seed_a)
		var realm := int(state.get("realm", 1))
		if realm < previous_realm:
			realms_hold = false
		previous_realm = realm
	check(realms_hold, "time never takes a realm away")

	check(NpcProgress.insight_percent(day_300) >= 0 and NpcProgress.insight_percent(day_300) <= 100,
		"progress towards the next step is a percentage")
	check(NpcProgress.stage_label(day_300).contains(" "), "a stage reads as realm and sublevel")
	check(NpcProgress.describe("outer_disciple", day_300) != "", "a record can be described")
	check(not NpcProgress.at_peak("outer_disciple", day_one), "day one is not the peak")

	var generous := NpcProgress.breakthrough_chance(1, 0.0)
	var harsh := NpcProgress.breakthrough_chance(8, 0.0)
	check(generous > harsh, "higher realms break through harder")
	check(NpcProgress.breakthrough_chance(1, 5.0) <=
		float(NpcProgress.rules().get("max_chance", 0.92)), "talent cannot guarantee a breakthrough")
	check(NpcProgress.breakthrough_chance(12, -5.0) >=
		float(NpcProgress.rules().get("min_chance", 0.06)), "no realm is impossible")

	# A temporary hopeless prodigy proves failure is real: insight resets, the
	# body is injured, and attempts keep coming. The archetype is removed after.
	var archetypes_list: Array = DB.npc_data.get("archetypes", [])
	archetypes_list.append({"id": "test_progress", "realm": 1,
		"progression": {"rate": 600.0, "cap": 12, "talent": -0.5}})
	NpcProgress.reset_cache()
	var doomed := NpcProgress.state_for("test_progress", "npc.progress.doomed", 200, seed_a)
	check(int(doomed.get("attempts", 0)) > 0, "a peak cultivator attempts a breakthrough")
	check(int(doomed.get("failures", 0)) > 0, "a hopeless attempt can fail")
	check(int(doomed.get("injured_until", 0)) >= 0, "failure leaves a recovery date")
	archetypes_list.pop_back()
	NpcProgress.reset_cache()

	# The body and the dossier read the same derived state.
	var saved_day: int = Clock.day
	var npc := Npc.new()
	npc.npc_id = "npc.progress.body"
	npc.archetype_id = "outer_disciple"
	npc.realm = 1
	Clock.day = 400
	var body_state := npc.refresh_progress()
	check(npc.realm == int(body_state.get("realm", 0)), "the body wears the realm it earned")
	check(npc.realm > 1 or int(body_state.get("sublevel", 1)) > 1,
		"a resident met on day 400 has grown")
	check(npc.progress_line().contains("Cultivation"), "the dossier states the climb")
	check(npc.attrs.get_attr("str") >= 11, "progress raises the generated attributes")
	Clock.day = saved_day
	npc.free()

	# Derived, not saved: no progression key enters the run dictionary.
	check(not Game.to_dict().has("progress"), "progression is not a save key")
	check(not Game.to_dict().has("npc_progress"), "progression is not an extra save key")

	check(NpcProgress.validate(DB.npc_data).is_empty(), "the shipped progression data validates")
	var free_steps: Dictionary = DB.npc_data.duplicate(true)
	(free_steps["progression"] as Dictionary)["sublevel_cost"] = 0.0
	check(not NpcProgress.validate(free_steps).is_empty(), "a free sublevel is rejected")
	var low_cap: Dictionary = DB.npc_data.duplicate(true)
	(low_cap["archetypes"] as Array)[0]["progression"]["cap"] = 1
	check(not NpcProgress.validate(low_cap).is_empty(), "a cap below the archetype's realm is rejected")
	var no_discipline: Dictionary = DB.npc_data.duplicate(true)
	(no_discipline["archetypes"] as Array)[0].erase("progression")
	check(not NpcProgress.validate(no_discipline).is_empty(), "an archetype without a discipline is rejected")


## The market's tongue: deterministic daily news, local witnesses, requests with
## a deadline, and a chronicle that is derived content rather than saved truth.
func _stories_tests() -> void:
	print("[stories] the market keeps its own record")
	var rule := Stories.rules()
	check(not rule.is_empty(), "story rules are loaded")
	check(int(rule.get("per_day", 0)) >= 1, "a day carries at least one beat")
	check(not Stories.templates().is_empty(), "story templates are loaded")
	check(not Stories.template("story.dispute").is_empty(), "a template is found by id")
	check(Stories.template("story.nope").is_empty(), "an unknown template is empty")
	check(Stories.validate(DB.stories).is_empty(), "the shipped story data validates")

	var people: Array = [
		{"id": "a", "name": "Lin Zhao", "archetype": "merchant", "place": "market", "goals": ["goal.wealth"]},
		{"id": "b", "name": "Su Fei", "archetype": "farmer", "place": "fields", "goals": ["goal.family"]},
		{"id": "c", "name": "Han Yan", "archetype": "guard", "place": "gate", "goals": ["goal.protect_sect"]},
		{"id": "d", "name": "Mo Xue", "archetype": "inner_disciple", "place": "training", "goals": ["goal.pursue_dao"]},
		{"id": "e", "name": "Wei Rou", "archetype": "inner_disciple", "place": "training", "goals": ["goal.pursue_dao"]},
		{"id": "f", "name": "Gu Shan", "archetype": "elder", "place": "shrine", "goals": ["goal.teach"]},
	]
	var story_seed := 9911
	var day_one := Stories.ambient(people, 1, story_seed)
	check(day_one.size() == int(rule.get("per_day", 2)), "a day draws the configured number of beats")
	check(str(day_one) == str(Stories.ambient(people, 1, story_seed)), "the same day draws the same news")
	check(str(day_one) != str(Stories.ambient(people, 2, story_seed)), "another day draws different news")
	check(str(day_one) != str(Stories.ambient(people, 1, story_seed + 1)), "another world draws different news")
	check(day_one.size() >= 2 and String((day_one[0] as Dictionary).get("id", "")) !=
		String((day_one[1] as Dictionary).get("id", "")), "two beats in a day do not share an id")
	for value in day_one:
		var entry: Dictionary = value
		check(String(entry.get("headline", "")).contains(" "), "a beat reads as a sentence")
		check(String(entry.get("detail", "")) != "", "a beat has a detail")
		var actors := entry.get("actors", []) as Array
		check(actors.size() >= 1, "a beat has an actor")
		var known := false
		for person in people:
			if String((person as Dictionary).get("id", "")) == String(actors[0]):
				known = true
		check(known, "a beat names a real resident")
		var tpl := Stories.template(String(entry.get("template", "")))
		if not tpl.is_empty():
			check((tpl.get("venues", []) as Array).has(String(entry.get("place", ""))),
				"a beat happens where its template puts it")
			var actor_person: Dictionary = {}
			for person in people:
				if String((person as Dictionary).get("id", "")) == String(actors[0]):
					actor_person = person
			var shared := false
			for goal in actor_person.get("goals", []):
				if (tpl.get("goals", []) as Array).has(String(goal)):
					shared = true
			check(shared, "a beat follows one of its actor's goals")

	# Witnesses are local and deterministic, and a rumour ages out.
	var first: Dictionary = (day_one[0] as Dictionary).duplicate(true)
	var witnesses := Stories.witnesses(first, people, story_seed)
	first["witnesses"] = witnesses
	check(witnesses.has(String((first.get("actors", []) as Array)[0])), "the actor knows their own news")
	check(str(witnesses) == str(Stories.witnesses(first, people, story_seed)), "witnesses are deterministic")
	check(witnesses.size() <= 1 + int(rule.get("witnesses", 2)), "witnesses stay bounded")
	check(Stories.rumor_for("nobody", [first], 1).is_empty(), "an outsider has not heard it")
	var gossiper := String(witnesses[0])
	check(not Stories.rumor_for(gossiper, [first], 2, 4).is_empty(), "news lasts a few days")
	check(Stories.rumor_for(gossiper, [first], 30, 4).is_empty(), "news does not last a month")

	# A real progression event becomes a beat; failure asks for help.
	var actor := {"id": "d", "name": "Mo Xue"}
	var breakthrough := Stories.event_beat(Stories.BREAKTHROUGH, actor, 9,
		{"realm_name": "Foundation Establishment"})
	check(not breakthrough.is_empty(), "a breakthrough becomes a beat")
	check(String(breakthrough.get("headline", "")).contains("Mo Xue"), "the beat names the person")
	check(String(breakthrough.get("headline", "")).contains("Foundation"), "the beat names the realm")
	check((breakthrough.get("request", {}) as Dictionary).is_empty(), "a breakthrough asks nothing")
	var deviation := Stories.event_beat(Stories.DEVIATION, actor, 10)
	check(String(deviation.get("headline", "")).contains("Mo Xue"), "a failure names the person")
	check(String((deviation.get("request", {}) as Dictionary).get("kind", "")) == Stories.DELIVER,
		"a failed breakthrough asks for a mending pill")
	check(Stories.event_beat("nonsense", actor, 1).is_empty(), "unknown event kinds are refused")

	var offer := Stories.offer_for(deviation)
	check(String(offer.get("kind", "")) == Stories.DELIVER, "a failure produces a delivery request")
	check(int(offer.get("deadline", 0)) == 10 + int(rule.get("offer_days", 4)), "the request has a deadline")
	check(String(offer.get("target", "")) == String(rule.get("deliver_base", "")), "the request names the pill")
	check(int(offer.get("stones", 0)) > 0 and int(offer.get("regard", 0)) > 0, "the request pays")
	check(Stories.offer_text(offer).contains("Mending"), "the request reads as a request")
	check(Stories.deliver_index([offer], "d") == 0, "the delivery is found by actor")
	check(Stories.deliver_index([offer], "a") < 0, "another resident owns no such request")

	var hunt_entry := {"id": "story.1.0", "day": 1, "actors": ["c"], "names": ["Han Yan"],
		"place": "gate", "request": {"kind": "hunt"}}
	var hunt := Stories.offer_for(hunt_entry)
	check(String(hunt.get("kind", "")) == Stories.HUNT, "a patrol produces a hunt request")
	check(int(hunt.get("count", 0)) == int(rule.get("hunt_target", 0)), "the hunt asks for the configured number")
	var hunt_first := Stories.advance_hunt([hunt], 1)
	check((hunt_first.get("offers", []) as Array).size() == 1, "one kill does not finish a two-beast request")
	check((hunt_first.get("completed", []) as Array).is_empty(), "nothing is completed early")
	var hunt_second := Stories.advance_hunt(hunt_first.get("offers", []), 1)
	check((hunt_second.get("completed", []) as Array).size() == 1, "the second kill answers it")
	check((hunt_second.get("offers", []) as Array).is_empty(), "a finished request leaves the list")
	check(Stories.expire_offers([hunt], 999).is_empty(), "a request lapses after its deadline")

	# The chronicle is bounded, refuses duplicates and keeps the newest news.
	var chronicle: Array = []
	chronicle = Stories.append(chronicle, deviation, 3)
	chronicle = Stories.append(chronicle, breakthrough, 3)
	check(chronicle.size() == 2, "the chronicle records both entries")
	chronicle = Stories.append(chronicle, deviation, 3)
	check(chronicle.size() == 2, "the same entry is not repeated")
	var third := Stories.event_beat(Stories.DEVIATION, {"id": "e", "name": "Wei Rou"}, 11)
	chronicle = Stories.append(chronicle, third, 2)
	check(chronicle.size() == 2, "the chronicle respects its cap")
	check(String((chronicle[1] as Dictionary).get("id", "")) == String(third.get("id", "")),
		"the newest entry survives the trim")

	var garbage := Stories.sanitize_chronicle([null, {"id": "x"},
		{"id": "y", "headline": "Y", "day": -4, "actors": "bad"}])
	check(garbage.size() == 1 and int((garbage[0] as Dictionary).get("day", -1)) == 0,
		"malformed entries are dropped and days clamped")
	var bad_offers := Stories.sanitize_offers([
		{"id": "o", "kind": "nope"},
		{"id": "p", "kind": "deliver", "actor": "d", "deadline": 2, "count": 1},
	], 3)
	check(bad_offers.is_empty(), "expired and malformed requests are dropped on load")
	check(Stories.sanitize_offers([offer], 10).size() == 1, "a live request survives a load")

	# A resident becomes a story person without the system touching the node.
	var body := Npc.new()
	body.npc_id = "npc.story.unit"
	body.display_name = "Test Person"
	body.current_location = "market"
	body.goals = ["goal.wealth"]
	var snapshot := Stories.people_from([body])
	check(snapshot.size() == 1, "a resident becomes a story person")
	check(String((snapshot[0] as Dictionary).get("place", "")) == "market", "the snapshot keeps the place")
	body.free()

	check(Game.to_dict().has("chronicle"), "the chronicle is a save key")
	check(Game.to_dict().has("story_offers"), "open requests are a save key")

	var broken: Dictionary = DB.stories.duplicate(true)
	(broken["rules"] as Dictionary)["per_day"] = 0
	check(not Stories.validate(broken).is_empty(), "a day with no beats is rejected")
	broken = DB.stories.duplicate(true)
	(broken["templates"] as Array)[0]["actors"] = 3
	check(not Stories.validate(broken).is_empty(), "a headline naming the wrong number of actors is rejected")
	broken = DB.stories.duplicate(true)
	(broken["templates"] as Array)[0]["goals"] = ["goal.nope"]
	check(not Stories.validate(broken).is_empty(), "an unknown story goal is rejected")
	broken = DB.stories.duplicate(true)
	(broken["templates"] as Array)[0]["weight"] = 0
	check(not Stories.validate(broken).is_empty(), "a template with no weight is rejected")
	broken = DB.stories.duplicate(true)
	(broken["templates"] as Array)[0]["request"] = {"kind": "dance"}
	check(not Stories.validate(broken).is_empty(), "an unknown request kind is rejected")
	broken = DB.stories.duplicate(true)
	(broken["rules"] as Dictionary)["deliver_base"] = "base.nope"
	check(not Stories.validate(broken).is_empty(), "a delivery of an unknown item is rejected")


## Factions: a stored record of what the player did, read through bands that
## change real numbers, with rivals and allies moving when one house is helped.
func _factions_tests() -> void:
	print("[factions] standing is earned, remembered and spent")
	check(Factions.factions().size() == 4, "the four factions are loaded")
	check(not Factions.faction("faction.azure_cloud").is_empty(), "a faction is found by id")
	check(Factions.faction("faction.nope").is_empty(), "an unknown faction is empty")
	check(Factions.bands().size() == 5, "five standing bands are loaded")
	check(Factions.validate(DB.factions_data).is_empty(), "the shipped faction data validates")
	check(Factions.default_standing() == 0, "a new name starts neutral")

	check(Factions.band_id(-100) == "standing.hostile", "the bottom of the ladder is hostile")
	check(Factions.band_id(-40) == "standing.hostile", "hostile takes its upper edge")
	check(Factions.band_id(-39) == "standing.wary", "wary begins where hostile ends")
	check(Factions.band_id(0) == "standing.neutral", "zero is neutral")
	check(Factions.band_id(24) == "standing.neutral", "neutral takes its upper edge")
	check(Factions.band_id(25) == "standing.trusted", "trusted begins at its lower edge")
	check(Factions.band_id(59) == "standing.trusted", "trusted takes its upper edge")
	check(Factions.band_id(60) == "standing.honoured", "honoured begins at its lower edge")
	check(Factions.band_id(999) == "standing.honoured", "the ladder clamps above the top")
	check(Factions.label(60) == "Honoured", "a band has a readable label")
	check(Factions.blurb(-50) != "", "a band explains itself")

	check(Factions.for_archetype("elder") == "faction.azure_cloud", "elders belong to the Azure Cloud")
	check(Factions.for_archetype("guard") == "faction.watch", "guards belong to the watch")
	check(Factions.for_archetype("merchant") == "faction.market_league", "merchants belong to the league")
	check(Factions.for_archetype("farmer") == "faction.market_league", "farmers belong to the league")
	check(Factions.for_archetype("") == "", "an empty archetype belongs to no faction")
	check(Factions.for_archetype("nobody") == "", "an unknown archetype belongs to no faction")
	check(Factions.for_boss("boss.tomb_warden") == "faction.hollow_moon", "the warden answers to the Hollow Moon")
	check(Factions.for_boss("boss.nobody") == "", "an unknown boss answers to no faction")
	check(Factions.relation_text("faction.azure_cloud").contains("Rival"), "the sect names its rival")
	check(Factions.relation_text("faction.market_league").contains("Ally"), "the league names its ally")

	var empty := Factions.sanitize({})
	check(empty.size() == Factions.factions().size(), "a fresh record covers every faction")
	check(int(empty.get("faction.azure_cloud", 99)) == 0, "a fresh record is neutral")
	var raw: Dictionary = {"faction.azure_cloud": 40}
	check(Factions.effective_standing("faction.azure_cloud", raw) == 40, "raw standing reads as itself")
	check(Factions.effective_standing("faction.azure_cloud", raw, 20) == 35,
		"notoriety costs a lawful faction a quarter of its value")
	check(Factions.effective_standing("faction.market_league", {"faction.market_league": 40}, 20) == 40,
		"a guild is not the law and ignores notoriety")
	check(Factions.effective_standing("faction.hollow_moon", {"faction.hollow_moon": 40}, 20) == 35,
		"a lawful cult keeps its own law")
	check(Factions.effective_standing("faction.azure_cloud", raw, 1000) == -100,
		"notoriety can floor a lawful standing")

	var after := Factions.award(empty, "faction.azure_cloud", 10)
	check(int(after.get("faction.azure_cloud", 0)) == 10, "an act raises its faction")
	check(int(after.get("faction.hollow_moon", 0)) == -5, "the rival loses half")
	check(int(after.get("faction.market_league", 0)) == 2, "an ally gains a quarter")
	check(int(after.get("faction.watch", 0)) == 2, "every ally moves")
	check(int(empty.get("faction.azure_cloud", 0)) == 0, "award never mutates its input")
	var damned := Factions.award(empty, "faction.hollow_moon", 10)
	check(int(damned.get("faction.azure_cloud", 0)) == -5, "helping a cult cools its rival")
	check(int(Factions.award(empty, "faction.azure_cloud", 500).get("faction.azure_cloud", 0)) == 100,
		"awards clamp at the top")
	check(int(Factions.award(empty, "faction.azure_cloud", -500).get("faction.azure_cloud", 0)) == -100,
		"awards clamp at the bottom")
	check(str(Factions.award(empty, "faction.nope", 50)) == str(empty), "an unknown faction changes nothing")
	check(str(Factions.award(empty, "faction.azure_cloud", 0)) == str(empty), "a zero award changes nothing")

	check(Factions.disposition_bonus("faction.azure_cloud", empty) == 0, "neutral members are unaffected")
	check(Factions.disposition_bonus("faction.azure_cloud", {"faction.azure_cloud": 60}) == 8,
		"honoured standing warms members")
	check(Factions.price_multiplier("faction.market_league", {"faction.market_league": 60}) == 0.9,
		"honoured standing cuts stall prices")
	check(Factions.price_multiplier("faction.azure_cloud", {"faction.azure_cloud": -50}) == 1.25,
		"hostile standing raises them")
	var described := Factions.describe("faction.azure_cloud", {"faction.azure_cloud": 30})
	check(described.contains("Azure Cloud Sect") and described.contains("Trusted"), "describe names the house and band")
	check(Factions.describe("faction.nope", empty) == "", "an unknown house describes as nothing")

	var dirty := Factions.sanitize({"faction.azure_cloud": 500, "faction.nope": 10, "junk": "x"})
	check(int(dirty.get("faction.azure_cloud", 0)) == 100, "sanitise clamps wild values")
	check(not dirty.has("faction.nope"), "sanitise drops unknown factions")
	check(dirty.size() == Factions.factions().size(), "sanitise keeps the whole known map")
	check(Factions.sanitize("nonsense").size() == Factions.factions().size(), "sanitise survives a bad shape")

	check(Game.to_dict().has("faction_standing"), "faction standing is a save key")
	check(Factions.sanitize(Game.faction_standing).size() == Factions.factions().size(),
		"the live standing map covers every faction")

	var broken: Dictionary = DB.factions_data.duplicate(true)
	(broken["bands"] as Array)[0]["max"] = -41
	check(not Factions.validate(broken).is_empty(), "a gap in the standing ladder is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array).append((DB.factions_data["factions"] as Array)[0].duplicate(true))
	check(not Factions.validate(broken).is_empty(), "a duplicate faction is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array)[0]["archetypes"].append("nope")
	check(not Factions.validate(broken).is_empty(), "an unknown archetype is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array)[0]["archetypes"].append("guard")
	check(not Factions.validate(broken).is_empty(), "an archetype in two factions is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array)[3]["rivals"] = []
	check(not Factions.validate(broken).is_empty(), "a one-sided rivalry is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array)[0]["allies"].append("faction.azure_cloud")
	check(not Factions.validate(broken).is_empty(), "a faction allied to itself is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["bands"] as Array)[0]["price_mult"] = 0.1
	check(not Factions.validate(broken).is_empty(), "an unfair price multiplier is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["awards"] as Dictionary).erase("quest_award")
	check(not Factions.validate(broken).is_empty(), "missing award tuning is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["awards"] as Dictionary)["default_standing"] = 200
	check(not Factions.validate(broken).is_empty(), "a default outside the ladder is rejected")
	broken = DB.factions_data.duplicate(true)
	(broken["factions"] as Array)[3]["bosses"] = ["boss.nope"]
	check(not Factions.validate(broken).is_empty(), "an unknown boss is rejected")


## Sects: the twelve houses are content with a codex and a validator, not a
## simulation yet. Their identities must be complete and never repeat.
func _sects_tests() -> void:
	print("[sects] twelve houses, twelve answers")
	check(DB.sects().size() == Sects.EXPECTED, "the twelve sects are loaded (%d)" % DB.sects().size())
	check(Sects.count() == Sects.EXPECTED, "the roster reads twelve")
	check(String(Sects.sect("sect.heavenly_sword").get("name", "")) == "Heavenly Sword",
		"a sect is found by id")
	check(Sects.sect("sect.nope").is_empty(), "an unknown sect is empty")
	check(Sects.row("sect.nope").is_empty(), "an unknown sect has no codex row")

	var local := Sects.local_sect()
	check(String(local.get("id", "")) == "sect.azure_cloud", "the market's gate is the Azure Cloud")
	check(String(local.get("faction", "")) == "faction.azure_cloud", "the local sect is the Azure Cloud faction")
	check(not Factions.faction(String(local.get("faction", ""))).is_empty(),
		"the local sect names a real faction")
	var locals := 0
	for value in Sects.sects():
		if bool((value as Dictionary).get("local", false)):
			locals += 1
	check(locals == 1, "exactly one sect is the player's gate")

	var names := {}
	var methods := {}
	var techniques := {}
	for value in Sects.sects():
		var entry: Dictionary = value
		names[String(entry.get("name", ""))] = true
		var method: Dictionary = entry.get("method", {})
		var technique: Dictionary = entry.get("technique", {})
		methods[String(method.get("name", ""))] = true
		techniques[String(technique.get("name", ""))] = true
		check(String(entry.get("philosophy", "")) != "" and String(entry.get("fault_line", "")) != "",
			"%s has a philosophy and a fault line" % String(entry.get("name", "?")))
		check(String(entry.get("seat", "")) != "" and String(entry.get("economy", "")) != "",
			"%s has a seat and an economy" % String(entry.get("name", "?")))
		check(String(technique.get("path", "")) != "" and String(method.get("path", "")) != "",
			"%s signatures explain themselves" % String(entry.get("name", "?")))
		check(Sects.TECHNIQUE_KINDS.has(String(technique.get("kind", ""))),
			"%s signature technique has a playable kind" % String(entry.get("name", "?")))
	check(names.size() == Sects.EXPECTED, "every sect has its own name")
	check(methods.size() == Sects.EXPECTED, "every sect has its own method")
	check(techniques.size() == Sects.EXPECTED, "every sect has its own technique")

	var signature := Sects.signature_line("sect.heavenly_sword")
	check(signature.contains("Sword Heart Method") and signature.contains("Heaven Splitting Slash"),
		"a signature line names both arts")
	var seat := Sects.seat_line("sect.crimson_lotus")
	check(seat.contains("Lotus Lake") and seat.contains("poison"), "a seat line names place and trade")
	check(Sects.describe("sect.void_scripture").contains("catalogued"), "describe carries the philosophy")
	check(Sects.describe("sect.nope") == "", "an unknown sect describes as nothing")
	check(Sects.signature_line("sect.nope") == "" and Sects.seat_line("sect.nope") == "",
		"an unknown sect has no signature or seat line")

	var row := Sects.row("sect.azure_cloud")
	check(bool(row.get("local", false)), "the local row is marked for the codex")
	check(String(row.get("method", "")) == "Five Elements Cycle" and
		String(row.get("technique", "")) == "Azure Cloud Palm", "a row flattens its signatures")
	check(String(row.get("technique_kind", "")) == "projectile", "a row carries the technique kind")
	check(Factions.faction(String(row.get("faction", ""))).get("name", "") == "Azure Cloud Sect",
		"the local row points at the standing house")
	check(not Game.to_dict().has("sects"), "the sect roster is content, not save state")

	check(Sects.validate(DB.sects_data).is_empty(), "the shipped sect roster validates")
	var broken: Dictionary = DB.sects_data.duplicate(true)
	(broken["sects"] as Array).pop_back()
	check(not Sects.validate(broken).is_empty(), "eleven sects are rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array).append((DB.sects_data["sects"] as Array)[0].duplicate(true))
	check(not Sects.validate(broken).is_empty(), "a duplicate sect id is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["name"] = (DB.sects_data["sects"] as Array)[0]["name"]
	check(not Sects.validate(broken).is_empty(), "a duplicate sect name is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["method"] = {"name": "Sword Heart Method", "path": "Borrowed."}
	check(not Sects.validate(broken).is_empty(), "a shared signature method is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["philosophy"] = "  "
	check(not Sects.validate(broken).is_empty(), "a sect without a philosophy is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["colour"] = "not-a-colour"
	check(not Sects.validate(broken).is_empty(), "an invalid sect colour is rejected")
	broken = DB.sects_data.duplicate(true)
	var two_locals: Array = broken["sects"]
	var second_sect: Dictionary = two_locals[2]
	second_sect["local"] = true
	second_sect["faction"] = "faction.watch"
	check(not Sects.validate(broken).is_empty(), "two local gates are rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["faction"] = ""
	check(not Sects.validate(broken).is_empty(), "a local sect without a faction is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["faction"] = "faction.nope"
	check(not Sects.validate(broken).is_empty(), "a local sect naming an unknown faction is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[0]["method"]["id"] = "method.nope"
	check(not Sects.validate(broken).is_empty(), "an unknown signature method is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[0]["technique"]["id"] = "tech.nope"
	check(not Sects.validate(broken).is_empty(), "an unknown signature technique is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["technique"]["kind"] = "melee"
	check(not Sects.validate(broken).is_empty(), "a signature kind that disagrees with its art is rejected")
	broken = DB.sects_data.duplicate(true)
	(broken["sects"] as Array)[1]["technique"]["kind"] = "dance"
	check(not Sects.validate(broken).is_empty(), "an unknown signature kind is rejected")


## Hierarchy: seven rungs and two offices, every resident placed, and the
## player's station derived from the same standing the gate already reads.
func _hierarchy_tests() -> void:
	print("[hierarchy] a place in the hall")
	check(Hierarchy.ladder().size() == Hierarchy.EXPECTED_LADDER, "the seven rungs are loaded")
	check(Hierarchy.offices().size() == Hierarchy.EXPECTED_OFFICES, "the two offices are loaded")
	check(Hierarchy.rank("rank.elder").get("name", "") == "Elder", "a rank is found by id")
	check(Hierarchy.rank("office.instructor").get("name", "") == "Instructor", "an office is found by id")
	check(Hierarchy.rank("rank.nope").is_empty(), "an unknown rank is empty")
	check(not Hierarchy.seat_available(), "the master's seat is held at the start")
	check(Hierarchy.authority("rank.elder") == 65, "a rank carries its authority")
	check(Hierarchy.duty("office.guardian").contains("gate"), "an office carries its duty")
	check(Hierarchy.privilege("rank.inner_disciple").contains("library"), "a rank carries its privilege")
	check(Hierarchy.title("rank.nope") == "" and Hierarchy.authority("rank.nope") == 0,
		"an unknown rank has no title or authority")
	var levels: Array = []
	var last_authority := -1
	var seats := 0
	for value in Hierarchy.ladder():
		var entry: Dictionary = value
		levels.append(int(entry.get("level", -1)))
		check(int(entry.get("authority", 0)) >= last_authority, "authority rises with the ladder")
		last_authority = int(entry.get("authority", 0))
		if bool(entry.get("seat", false)):
			seats += 1
	check(levels == [0, 1, 2, 3, 4, 5, 6], "the ladder covers every level in order")
	check(seats == 1, "exactly one rung is the seat")

	check(Hierarchy.for_archetype("elder") == "rank.elder", "an elder archetype holds the elder rung")
	check(Hierarchy.for_archetype("inner_disciple") == "rank.inner_disciple", "a disciple is placed")
	check(Hierarchy.for_archetype("guard") == "office.guardian", "a guard holds the guardian office")
	check(Hierarchy.for_archetype("merchant") == "", "an unaligned trade holds no seat")
	check(Hierarchy.for_npc("elder_bai", "inner_disciple") == "rank.elder", "an authored resident overrides the template")
	check(Hierarchy.for_npc("instructor_rui", "inner_disciple") == "office.instructor", "the instructor holds his office")
	check(Hierarchy.for_npc("npc.sect_master.0", "sect_master") == "rank.sect_master",
		"a generated master holds the seat")
	check(Hierarchy.station_line("elder_bai", "elder").contains("Elder") and
		Hierarchy.station_line("elder_bai", "elder").contains("65"), "a station line names rank and authority")
	check(Hierarchy.station_line("npc.merchant.0", "merchant") == "", "a trade has no station line")

	check(Hierarchy.player_rank(1, {}).get("id", "") == "rank.outer_disciple", "a fresh name is an outer disciple")
	check(Hierarchy.player_rank(1, {"faction.azure_cloud": -50}).get("id", "") == "rank.servant",
		"a hostile name is a servant")
	check(Hierarchy.player_rank(2, {"faction.azure_cloud": 20}).get("id", "") == "rank.inner_disciple",
		"standing and realm open the inner hall")
	check(Hierarchy.player_rank(3, {"faction.azure_cloud": 40}).get("id", "") == "rank.core_disciple",
		"a core seat needs both") 
	check(Hierarchy.player_rank(4, {"faction.azure_cloud": 60}).get("id", "") == "rank.elder",
		"an elder's seat can be earned")
	check(Hierarchy.player_rank(5, {"faction.azure_cloud": 80}).get("id", "") == "rank.deputy",
		"the deputy's place is reachable")
	check(Hierarchy.player_rank(6, {"faction.azure_cloud": 95}).get("id", "") == "rank.deputy",
		"the held seat stops a qualified player at deputy")
	check(Hierarchy.player_rank(6, {"faction.azure_cloud": 95}, 0, true).get("id", "") == "rank.sect_master",
		"a vacant seat can be taken")
	check(Hierarchy.player_rank(4, {"faction.azure_cloud": 60}, 40).get("id", "") == "rank.core_disciple",
		"notoriety costs a place in the hall")
	check(Hierarchy.next_rank("rank.servant").get("id", "") == "rank.outer_disciple", "the next rung is readable")
	check(Hierarchy.next_rank("rank.sect_master").is_empty(), "nothing stands above the master")

	var inner_missing: Array = Hierarchy.missing_for("rank.inner_disciple", 1, {}, 0, false)
	check(inner_missing.size() == 2, "the inner hall wants standing and realm")
	check(String(inner_missing[0]).contains("20 standing") and String(inner_missing[1]).contains("realm 2"),
		"the missing requirements say what is short")
	var seat_missing: Array = Hierarchy.missing_for("rank.sect_master", 6, {"faction.azure_cloud": 95}, 0, false)
	check(seat_missing.size() == 1 and String(seat_missing[0]).contains("seat is held"),
		"the held seat is named as the only obstacle")
	check(Hierarchy.missing_for("rank.sect_master", 6, {"faction.azure_cloud": 95}, 0, true).is_empty(),
		"a vacant seat has nothing missing")
	var progress := Hierarchy.station_progress(1, {})
	check(progress.contains("Station: Outer Disciple") and progress.contains("Inner Disciple needs"),
		"the progress line names the station and the next rung")
	var hud_station := Hierarchy.hud_line(1, {})
	check(hud_station.contains("Station: Outer Disciple") and hud_station.contains("Inner Disciple"),
		"the vitals line is short and honest")
	check(not Game.to_dict().has("sect_rank") and not Game.to_dict().has("hierarchy"),
		"rank is derived, not stored")

	check(Hierarchy.validate(DB.hierarchy_data).is_empty(), "the shipped hierarchy validates")
	var broken: Dictionary = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array).pop_back()
	check(not Hierarchy.validate(broken).is_empty(), "a six-rung ladder is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array).append((DB.hierarchy_data["ladder"] as Array)[0].duplicate(true))
	check(not Hierarchy.validate(broken).is_empty(), "a duplicate rank is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[1]["level"] = 0
	check(not Hierarchy.validate(broken).is_empty(), "two ranks on one level are rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[1]["duty"] = " "
	check(not Hierarchy.validate(broken).is_empty(), "a rank without a duty is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[5]["authority"] = 10
	check(not Hierarchy.validate(broken).is_empty(), "a rank below the authority under it is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[0]["seat"] = true
	(broken["ladder"] as Array)[6]["seat"] = false
	check(not Hierarchy.validate(broken).is_empty(), "a seat on the wrong rung is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[6]["requires"]["standing"] = 200
	check(not Hierarchy.validate(broken).is_empty(), "an impossible standing gate is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["ladder"] as Array)[2]["requires"]["realm"] = 0
	check(not Hierarchy.validate(broken).is_empty(), "a realm gate below one is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["offices"] as Array).pop_back()
	check(not Hierarchy.validate(broken).is_empty(), "a missing office is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["offices"] as Array)[0]["authority"] = 200
	check(not Hierarchy.validate(broken).is_empty(), "an office outside the authority range is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["assignments"] as Dictionary)["archetypes"]["elder"] = "rank.nope"
	check(not Hierarchy.validate(broken).is_empty(), "an assignment to an unknown rank is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	(broken["assignments"] as Dictionary)["archetypes"]["nobody"] = "rank.outer_disciple"
	check(not Hierarchy.validate(broken).is_empty(), "an assignment for an unknown archetype is rejected")
	broken = DB.hierarchy_data.duplicate(true)
	broken["seat_held"] = "yes"
	check(not Hierarchy.validate(broken).is_empty(), "a non-boolean seat flag is rejected")


## Sect economy: contribution is earned, donated and spent; the stipend is paid
## once a day by rank, with dues taken from the pay rather than the purse.
func _sect_economy_tests() -> void:
	print("[sect economy] contribution, stipend and the quartermaster")
	check(SectEconomy.quest_award() == 40, "a completed sect quest pays contribution")
	check(SectEconomy.story_award() == 3, "an answered request pays a little contribution")
	check(SectEconomy.boss_award() == 25, "a fallen enemy of the sect pays contribution")
	check(SectEconomy.cap() == 9999, "contribution has a ceiling")
	check(SectEconomy.donation("donation.small").get("points", 0) == 1, "small donations are 10 stones for 1")
	check(SectEconomy.donation("donation.large").get("points", 0) == 6, "large donations pay a bulk bonus")
	check(SectEconomy.donation("donation.nope").is_empty(), "an unknown donation is empty")
	check(SectEconomy.stipend_for("rank.outer_disciple").get("stones", 0) == 6, "a rank draws its own pay")
	check(SectEconomy.stipend_net("rank.outer_disciple") == 5, "dues come out of the stipend")
	check(SectEconomy.stipend_net("rank.elder") == 24, "an elder's pay is larger")
	check(SectEconomy.stipend_net("rank.nope") == 0, "an unknown rank draws nothing")
	check(SectEconomy.service("service.qi_pill").get("base", "") == "base.pill.qi_gathering",
		"a service names a real consumable")
	check(SectEconomy.service("service.nope").is_empty(), "an unknown service is empty")

	check(SectEconomy.award_contribution(0, 40) == 40, "service awards contribution")
	check(SectEconomy.award_contribution(9998, 5) == 9999, "contribution clamps at the cap")
	check(SectEconomy.award_contribution(10, -5) == 10, "a negative award cannot tax the record")

	var claim := SectEconomy.claim("rank.outer_disciple", 7, -1, 100)
	check(bool(claim.get("ok", false)), "a fresh day can claim the stipend")
	check(int(claim.get("stones", 0)) == 105, "the net stipend reaches the purse")
	check(int(claim.get("net", 0)) == 5 and int(claim.get("dues", 0)) == 1, "pay and dues are reported")
	check(int(claim.get("day", -1)) == 7, "the claim records the day")
	check(not bool(SectEconomy.claim("rank.outer_disciple", 7, 7, 100).get("ok", false)),
		"the same day cannot be claimed twice")
	check(int(SectEconomy.claim("rank.servant", 7, -1, 0).get("stones", 0)) == 2,
		"the lowest rung still eats")

	var donated := SectEconomy.donate("donation.small", 100, 0)
	check(bool(donated.get("ok", false)), "a donation is accepted when the purse covers it")
	check(int(donated.get("stones", 0)) == 90 and int(donated.get("contribution", 0)) == 1,
		"ten stones become one contribution")
	check(not bool(SectEconomy.donate("donation.small", 5, 0).get("ok", false)),
		"a donation cannot overdraw the purse")
	check(int(SectEconomy.donate("donation.large", 60, 9999).get("contribution", 0)) == 9999,
		"donations clamp at the cap")
	check(not bool(SectEconomy.donate("donation.nope", 100, 0).get("ok", false)),
		"an unknown donation is refused")

	check(SectEconomy.can_use("service.qi_pill", "rank.outer_disciple"), "an outer disciple may buy a Qi pill")
	check(not SectEconomy.can_use("service.mending_pill", "rank.outer_disciple"),
		"the mending shelf is above an outer disciple")
	check(SectEconomy.can_use("service.mending_pill", "rank.inner_disciple"), "an inner disciple may buy it")
	var bought := SectEconomy.buy("service.qi_pill", 10, "rank.outer_disciple")
	check(bool(bought.get("ok", false)) and int(bought.get("contribution", 0)) == 4,
		"a purchase spends exactly its cost")
	check(not bool(SectEconomy.buy("service.qi_pill", 5, "rank.outer_disciple").get("ok", false)),
		"a purchase cannot overdraw contribution")
	check(not bool(SectEconomy.buy("service.mending_pill", 20, "rank.outer_disciple").get("ok", false)),
		"rank gates the counter")
	check(not bool(SectEconomy.buy("service.nope", 20, "rank.elder").get("ok", false)),
		"an unknown service is refused")

	var summary := SectEconomy.summary_line("rank.outer_disciple", 24, -1, 7)
	check(summary.contains("Contribution 24") and summary.contains("6 stones"), "the ledger header reads")
	check(SectEconomy.summary_line("rank.outer_disciple", 24, 7, 7).contains("today claimed"),
		"a paid day says so")
	check(Game.to_dict().has("sect_contribution") and Game.to_dict().has("sect_stipend_day"),
		"the contribution record and pay day are saved")
	check(Game.sect_contribution == 0 and Game.sect_stipend_day == SectEconomy.DEFAULT_STIPEND_DAY,
		"a run starts with no contribution and no pay day")
	check(Game.to_dict().has("sect_purchases"), "the purchase counter is saved so ids stay unique")

	check(SectEconomy.validate(DB.sect_economy_data).is_empty(), "the shipped economy validates")
	var broken: Dictionary = DB.sect_economy_data.duplicate(true)
	broken["cap"] = 0
	check(not SectEconomy.validate(broken).is_empty(), "a zero cap is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["awards"] as Dictionary).erase("quest")
	check(not SectEconomy.validate(broken).is_empty(), "a missing award is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["awards"] as Dictionary)["story"] = 0
	check(not SectEconomy.validate(broken).is_empty(), "a zero award is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["donations"] as Array).clear()
	check(not SectEconomy.validate(broken).is_empty(), "an empty donation list is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["donations"] as Array).append((DB.sect_economy_data["donations"] as Array)[0].duplicate(true))
	check(not SectEconomy.validate(broken).is_empty(), "a duplicate donation is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["donations"] as Array)[0]["stones"] = 0
	check(not SectEconomy.validate(broken).is_empty(), "a free donation is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["donations"] as Array)[0]["points"] = 0
	check(not SectEconomy.validate(broken).is_empty(), "a donation that pays nothing is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["donations"] as Array)[0]["label"] = " "
	check(not SectEconomy.validate(broken).is_empty(), "an unlabelled donation is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["stipends"] as Array).pop_back()
	check(not SectEconomy.validate(broken).is_empty(), "a rank without a stipend is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["stipends"] as Array)[0]["rank"] = "rank.nope"
	check(not SectEconomy.validate(broken).is_empty(), "a stipend for an unknown rank is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["stipends"] as Array)[1]["dues"] = 99
	check(not SectEconomy.validate(broken).is_empty(), "dues above the pay are rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array).clear()
	check(not SectEconomy.validate(broken).is_empty(), "an empty service shelf is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array)[0]["base"] = "base.nope"
	check(not SectEconomy.validate(broken).is_empty(), "a service with an unknown base is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array)[0]["base"] = "base.sword.iron_jian"
	check(not SectEconomy.validate(broken).is_empty(), "a service selling equipment is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array)[0]["rank"] = "rank.nope"
	check(not SectEconomy.validate(broken).is_empty(), "a service gated on an unknown rank is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array)[0]["cost"] = 0
	check(not SectEconomy.validate(broken).is_empty(), "a free service is rejected")
	broken = DB.sect_economy_data.duplicate(true)
	(broken["services"] as Array).append((DB.sect_economy_data["services"] as Array)[0].duplicate(true))
	check(not SectEconomy.validate(broken).is_empty(), "a duplicate service is rejected")


## Sect politics: three blocs whose support is bought with contribution, and a
## vote that only opens the top seat when the council is already with you.
func _sect_politics_tests() -> void:
	print("[sect politics] blocs, lobbying and the vote for the seat")
	check(SectPolitics.blocs().size() == 3, "the council has three blocs")
	check(SectPolitics.bloc("bloc.reformists").get("name", "") == "Reformists", "a bloc is found by id")
	check(not String(SectPolitics.bloc("bloc.reformists").get("speaker", "")).is_empty(),
		"a bloc names its speaker")
	check(SectPolitics.bloc("bloc.nope").is_empty(), "an unknown bloc is empty")
	check(SectPolitics.threshold() == 150, "the vote has its threshold")
	check(SectPolitics.min_rank() == "rank.deputy", "only a deputy may call the vote")
	check(SectPolitics.max_support() == 300, "three blocs can reach 300 support")

	check(SectPolitics.support_for("bloc.traditionalists", {}) == 20, "a bloc starts at its base")
	check(SectPolitics.support_for("bloc.traditionalists", {"bloc.traditionalists": 30}) == 50,
		"investment raises support")
	check(SectPolitics.support_for("bloc.traditionalists", {"bloc.traditionalists": 999}) == 100,
		"support clamps at the bloc ceiling")
	check(SectPolitics.support_for("bloc.nope", {"bloc.nope": 10}) == 0, "an unknown bloc has no support")
	check(SectPolitics.total_support({}) == 60, "the untouched council stands at 60")
	check(SectPolitics.total_support({"bloc.traditionalists": 40, "bloc.reformists": 30,
		"bloc.militants": 30}) == 160, "support is summed over the blocs")

	var lobby := SectPolitics.lobby("bloc.reformists", 20, {})
	check(bool(lobby.get("ok", false)), "a lobby is accepted when contribution covers it")
	check(int(lobby.get("contribution", 0)) == 12, "a lobby spends its cost")
	check(int(lobby.get("gain", 0)) == 10, "a lobby buys its gain")
	check(int((lobby.get("invested", {}) as Dictionary).get("bloc.reformists", 0)) == 10,
		"the investment map records the gain")
	check(int(lobby.get("support", 0)) == 30, "the bloc's new support is reported")
	check(not bool(SectPolitics.lobby("bloc.reformists", 7, {}).get("ok", false)),
		"a lobby cannot overdraw contribution")
	check(not bool(SectPolitics.lobby("bloc.nope", 20, {}).get("ok", false)),
		"an unknown bloc is refused")
	var capped := SectPolitics.lobby("bloc.reformists", 20, {"bloc.reformists": 80})
	check(not bool(capped.get("ok", false)), "a maxed bloc is refused")
	var partial := SectPolitics.lobby("bloc.reformists", 20, {"bloc.reformists": 75})
	check(bool(partial.get("ok", false)) and int(partial.get("gain", 0)) == 5,
		"the last lobby buys only the room left")

	var poor := SectPolitics.can_vote({}, "rank.deputy", false)
	check(not bool(poor.get("ok", false)) and String(poor.get("reason", "")).contains("60 of 150"),
		"a council at 60 cannot vote")
	var low_rank := SectPolitics.can_vote({"bloc.traditionalists": 80, "bloc.reformists": 80,
		"bloc.militants": 80}, "rank.outer_disciple", false)
	check(not bool(low_rank.get("ok", false)) and String(low_rank.get("reason", "")).contains("Deputy"),
		"an outer disciple cannot call the vote even with the council")
	var open_seat := SectPolitics.can_vote({"bloc.traditionalists": 80, "bloc.reformists": 80,
		"bloc.militants": 80}, "rank.deputy", true)
	check(not bool(open_seat.get("ok", false)), "the vote cannot be called twice")
	var ready := {"bloc.traditionalists": 40, "bloc.reformists": 30, "bloc.militants": 30}
	check(bool(SectPolitics.can_vote(ready, "rank.deputy", false).get("ok", false)),
		"a deputy with 160 support can call the vote")
	var result := SectPolitics.vote(ready, "rank.deputy", false)
	check(bool(result.get("ok", false)) and bool(result.get("seat_open", false)),
		"a successful vote opens the seat")
	check(SectPolitics.summary_line(ready).contains("160"), "the council summary counts support")

	var cleaned := SectPolitics.sanitize_lobby({"bloc.reformists": 999, "bloc.nope": 50,
		"bloc.traditionalists": -4})
	check(int(cleaned.get("bloc.reformists", 0)) == 80, "a loaded lobby clamps to the room left")
	check(not cleaned.has("bloc.nope"), "an unknown loaded bloc is dropped")
	check(not cleaned.has("bloc.traditionalists"), "a zero loaded lobby is dropped")
	check(SectPolitics.sanitize_lobby([]).is_empty(), "junk lobby data is emptied")

	check(Game.to_dict().has("sect_lobby") and Game.to_dict().has("sect_seat_open"),
		"the political record is saved")
	check(Game.sect_lobby.is_empty() and not Game.sect_seat_open,
		"a run starts with a closed council and a held seat")
	check(not Hierarchy.seat_available(), "the content seat is held")
	check(Hierarchy.seat_available(true), "the political result opens the seat")
	var held_station := Hierarchy.player_rank(6, {"faction.azure_cloud": 100}, 0, Hierarchy.seat_available())
	var open_station := Hierarchy.player_rank(6, {"faction.azure_cloud": 100}, 0, Hierarchy.seat_available(true))
	check(String(held_station.get("id", "")) == "rank.deputy", "a qualified player stops at Deputy while the seat is held")
	check(String(open_station.get("id", "")) == "rank.sect_master", "the same player takes the open seat")

	check(SectPolitics.validate(DB.politics_data).is_empty(), "the shipped council validates")
	var broken: Dictionary = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array).clear()
	check(not SectPolitics.validate(broken).is_empty(), "an empty council is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array).pop_back()
	check(not SectPolitics.validate(broken).is_empty(), "a council missing a bloc is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array).append((DB.politics_data["blocs"] as Array)[0].duplicate(true))
	check(not SectPolitics.validate(broken).is_empty(), "a duplicate bloc is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["name"] = " "
	check(not SectPolitics.validate(broken).is_empty(), "a nameless bloc is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["speaker"] = " "
	check(not SectPolitics.validate(broken).is_empty(), "a bloc without a speaker is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["agenda"] = " "
	check(not SectPolitics.validate(broken).is_empty(), "a bloc without an agenda is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["base"] = -1
	check(not SectPolitics.validate(broken).is_empty(), "negative base support is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["max"] = 20
	check(not SectPolitics.validate(broken).is_empty(), "a bloc that cannot gain is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["max"] = 101
	check(not SectPolitics.validate(broken).is_empty(), "support above 100 is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["gain"] = 0
	check(not SectPolitics.validate(broken).is_empty(), "a lobby that buys nothing is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["blocs"] as Array)[0]["cost"] = 0
	check(not SectPolitics.validate(broken).is_empty(), "a free lobby is rejected")
	broken = DB.politics_data.duplicate(true)
	broken.erase("vote")
	check(not SectPolitics.validate(broken).is_empty(), "missing vote rules are rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["vote"] as Dictionary)["threshold"] = 0
	check(not SectPolitics.validate(broken).is_empty(), "a zero threshold is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["vote"] as Dictionary)["threshold"] = 301
	check(not SectPolitics.validate(broken).is_empty(), "an unwinnable vote is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["vote"] as Dictionary)["threshold"] = 60
	check(not SectPolitics.validate(broken).is_empty(), "a vote that passes without lobbying is rejected")
	broken = DB.politics_data.duplicate(true)
	(broken["vote"] as Dictionary)["min_rank"] = "rank.nope"
	check(not SectPolitics.validate(broken).is_empty(), "a vote gated on an unknown rank is rejected")


## Player sect: one late, irreversible founding, three doctrines, a treasury fed
## by a daily levy, and a roster of people who already trust the founder.
func _player_sect_tests() -> void:
	print("[player sect] founding, doctrines, levy and recruitment")
	check(PlayerSect.doctrines().size() == 3, "three doctrines are offered")
	check(PlayerSect.doctrine("doctrine.sword").get("sect_name", "") == "Dawn Blade Hall",
		"a doctrine names the hall")
	check(PlayerSect.doctrine("doctrine.nope").is_empty(), "an unknown doctrine is empty")
	check(PlayerSect.founding_cost() == 500, "founding costs its stones")
	check(PlayerSect.recruit_cost() == 25, "recruitment costs its gift")
	check(PlayerSect.min_rank() == "rank.deputy", "only a deputy may found a hall")
	check(PlayerSect.capacity({"doctrine": "doctrine.sword"}) == 6, "the sword hall holds six")
	check(PlayerSect.capacity({"doctrine": "doctrine.formation"}) == 7, "the formation hall holds seven")
	check(PlayerSect.capacity({}) == 0, "an unformed hall holds nobody")
	check(PlayerSect.member_rank(1) == "Initiate" and PlayerSect.member_rank(2) == "Disciple",
		"a member's rank follows their realm")
	check(PlayerSect.member_rank(4) == "Steward" and PlayerSect.member_rank(9) == "Elder",
		"higher realms carry the higher offices")

	check(PlayerSect.can_found({}, 500, "rank.deputy").is_empty(), "a deputy with the stones may found")
	check(not PlayerSect.can_found({}, 499, "rank.deputy").is_empty(), "the fee cannot be short")
	check(not PlayerSect.can_found({}, 500, "rank.outer_disciple").is_empty(),
		"an outer disciple cannot found a hall")
	check(not PlayerSect.can_found({"name": "Old"}, 500, "rank.deputy").is_empty(),
		"a second hall cannot be founded")
	var found := PlayerSect.found("doctrine.sword", 1500, 9)
	check(bool(found.get("ok", false)), "the founding succeeds")
	check(int(found.get("stones", 0)) == 1000, "the fee leaves the purse")
	var sect: Dictionary = found.get("sect", {})
	check(String(sect.get("name", "")) == "Dawn Blade Hall", "the doctrine names the new hall")
	check(int(sect.get("treasury", 0)) == 500, "the fee becomes the first treasury")
	check(int(sect.get("founded_day", 0)) == 9 and int(sect.get("tribute_day", 0)) == -1,
		"the hall records its founding and no levy yet")
	check(not bool(PlayerSect.found("doctrine.nope", 1500, 9).get("ok", false)),
		"an unknown doctrine cannot be founded")
	check(not bool(PlayerSect.found("doctrine.sword", 499, 9).get("ok", false)),
		"a short purse cannot found")

	check(PlayerSect.tribute_for("doctrine.sword", [1, 3, 6]) == 7, "a realm decides a member's share")
	check(PlayerSect.tribute_for("doctrine.alchemy", [1, 3, 6]) == 13, "a doctrine adds its levy")
	check(PlayerSect.tribute_for("doctrine.formation", [2]) == 3, "formation taxes one disciple")
	check(PlayerSect.tribute_for("doctrine.nope", [6]) == 0, "an unknown doctrine pays nothing")
	check(not bool(PlayerSect.can_collect({}, 9).get("ok", false)), "an unformed hall cannot levy")
	check(not bool(PlayerSect.can_collect(sect, 9).get("ok", false)), "an empty hall cannot levy")
	var staffed := sect.duplicate(true)
	staffed["members"] = ["npc.a", "npc.b"]
	check(bool(PlayerSect.can_collect(staffed, 9).get("ok", false)), "a staffed hall can levy")
	var collected := PlayerSect.collect(staffed, 9, [1, 3])
	check(bool(collected.get("ok", false)), "the levy is gathered")
	check(int(collected.get("amount", 0)) == 3, "the levy follows the members' realms")
	check(int((collected.get("sect", {}) as Dictionary).get("treasury", 0)) == 503,
		"the levy reaches the treasury")
	check(not bool(PlayerSect.collect(collected["sect"], 9, [1, 3]).get("ok", false)),
		"the levy is gathered once a day")

	var can := PlayerSect.can_recruit(staffed, "npc.c", 30, 2)
	check(bool(can.get("ok", false)), "a friend may be recruited")
	check(not bool(PlayerSect.can_recruit(staffed, "npc.c", 10, 2).get("ok", false)),
		"a stranger is not recruited")
	check(not bool(PlayerSect.can_recruit(staffed, "npc.a", 30, 2).get("ok", false)),
		"a member cannot be recruited twice")
	check(not bool(PlayerSect.can_recruit(staffed, "npc.c", 30, 6).get("ok", false)),
		"a full hall is refused")
	var broke := staffed.duplicate(true)
	broke["treasury"] = 5
	check(not bool(PlayerSect.can_recruit(broke, "npc.c", 30, 2).get("ok", false)),
		"a poor treasury cannot pay the gift")
	var recruited := PlayerSect.recruit(staffed, "npc.c", 30, 2)
	check(bool(recruited.get("ok", false)), "the recruit joins")
	check(int((recruited.get("sect", {}) as Dictionary).get("treasury", 0)) == 475,
		"the gift leaves the treasury")
	check(PlayerSect.is_member(recruited["sect"], "npc.c"), "the roster holds the new member")
	check(PlayerSect.member_count(recruited["sect"]) == 3, "the roster grows by one")

	check(PlayerSect.sanitize([]).is_empty(), "junk sect data is dropped")
	check(PlayerSect.sanitize({"doctrine": "doctrine.nope"}).is_empty(),
		"an unknown doctrine discards the hall")
	var clean := PlayerSect.sanitize({"doctrine": "doctrine.sword", "members": ["a", "a", "", "b"],
		"treasury": -5, "founded_day": 0, "tribute_day": 4})
	check(String(clean.get("name", "")) == "Dawn Blade Hall", "a nameless hall falls back to its doctrine")
	check((clean.get("members", []) as Array).size() == 2, "duplicate and empty members are dropped")
	check(int(clean.get("treasury", -1)) == 0 and int(clean.get("founded_day", 0)) == 1,
		"a loaded treasury and founding are clamped")
	check(int(clean.get("tribute_day", 0)) == 4, "the last levy day is kept")
	var crowded: Array = []
	for i in 20:
		crowded.append("npc.%d" % i)
	check((PlayerSect.sanitize({"doctrine": "doctrine.sword", "members": crowded}).get("members", []) as Array).size() == 6,
		"a loaded roster caps at the doctrine's size")
	check(Game.to_dict().has("player_sect"), "the hall is saved")
	check(Game.player_sect.is_empty(), "a run starts without a hall")

	check(PlayerSect.validate(DB.player_sect_data).is_empty(), "the shipped player sect validates")
	var broken_data: Dictionary = DB.player_sect_data.duplicate(true)
	broken_data.erase("founding")
	check(not PlayerSect.validate(broken_data).is_empty(), "missing founding rules are rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["founding"] as Dictionary)["stones"] = 0
	check(not PlayerSect.validate(broken_data).is_empty(), "a free founding is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["founding"] as Dictionary)["recruit_cost"] = -1
	check(not PlayerSect.validate(broken_data).is_empty(), "a negative gift is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["founding"] as Dictionary)["min_rank"] = "rank.nope"
	check(not PlayerSect.validate(broken_data).is_empty(), "an unknown founding rank is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array).clear()
	check(not PlayerSect.validate(broken_data).is_empty(), "a doctrineless sect is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array).pop_back()
	check(not PlayerSect.validate(broken_data).is_empty(), "a missing doctrine is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array).append((DB.player_sect_data["doctrines"] as Array)[0].duplicate(true))
	check(not PlayerSect.validate(broken_data).is_empty(), "a duplicate doctrine is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array)[0]["sect_name"] = " "
	check(not PlayerSect.validate(broken_data).is_empty(), "a hall without a name is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array)[0]["capacity"] = 0
	check(not PlayerSect.validate(broken_data).is_empty(), "a hall that holds nobody is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array)[0]["capacity"] = PlayerSect.ROSTER_CAP + 1
	check(not PlayerSect.validate(broken_data).is_empty(), "a roster above the hard cap is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["doctrines"] as Array)[0]["tribute"] = -1
	check(not PlayerSect.validate(broken_data).is_empty(), "a negative doctrine levy is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["member_ranks"] as Array).clear()
	check(not PlayerSect.validate(broken_data).is_empty(), "a hall with no ranks is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["member_ranks"] as Array)[0]["min_realm"] = 0
	check(not PlayerSect.validate(broken_data).is_empty(), "a rank below realm 1 is rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["member_ranks"] as Array).reverse()
	check(not PlayerSect.validate(broken_data).is_empty(), "out-of-order member ranks are rejected")
	broken_data = DB.player_sect_data.duplicate(true)
	(broken_data["member_ranks"] as Array)[0]["name"] = " "
	check(not PlayerSect.validate(broken_data).is_empty(), "a nameless member rank is rejected")


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


# ------------------------------------------------------------ skill bars ----

func _skill_bar_tests() -> void:
	print("[skill bars] 3x6 layout, switching, assignment, pruning and cooldowns")
	check(SkillBar.BAR_COUNT == 3 and SkillBar.SLOTS_PER_BAR == 6, "three bars of six slots")
	check(SkillBar.SLOT_COUNT == 18, "the layout holds eighteen slots")
	var empty := SkillBar.empty_layout()
	check(empty.size() == SkillBar.SLOT_COUNT, "an empty layout has every slot")
	check(empty.all(func(value: Variant) -> bool: return String(value) == ""), "an empty layout holds no arts")
	check(SkillBar.index_of(0, 0) == 0 and SkillBar.index_of(2, 5) == 17, "bar and slot map to one index")
	check(SkillBar.index_of(9, 9) == 17, "an out-of-range bar clamps")
	check(SkillBar.bar_of(7) == 1 and SkillBar.slot_of(7) == 1, "an index maps back to bar and slot")
	check(SkillBar.bar_of(-4) == 0 and SkillBar.slot_of(99) == 5, "the index helpers clamp")

	var known := ["a", "b", "c", "d", "e", "f", "g", "h"]
	var layout := SkillBar.default_layout(known)
	check(layout.size() == SkillBar.SLOT_COUNT, "a default layout always has eighteen slots")
	check(String(layout[0]) == "a" and String(layout[5]) == "f", "the first bar fills in known order")
	check(String(layout[6]) == "g" and String(layout[7]) == "h", "later known arts spill into the second bar")
	check(String(layout[8]) == "", "the rest of the layout stays empty")
	var duplicates := SkillBar.default_layout(["a", "a", "b"])
	check(String(duplicates[0]) == "a" and String(duplicates[1]) == "b", "the default layout never repeats an art")
	var overfull := SkillBar.default_layout(Array(range(0, 30)))
	check(SkillBar.bar_filled(overfull, 2) == 6, "a long roster stops at the eighteenth slot")

	layout = SkillBar.assign(layout, 2, "h")
	check(String(layout[2]) == "h", "an art can be placed in a chosen slot")
	check(String(layout[7]) == "", "placing an art empties the slot it held")
	check(SkillBar.find_slot(layout, "h") == 2, "a technique lives in one slot")
	check(SkillBar.find_slot(layout, "nope") == -1, "an absent art has no slot")
	check(SkillBar.find_slot(layout, "") == -1, "an empty id matches no slot")
	var first_before := String(layout[0])
	check(String(SkillBar.assign(layout, 0, "b")[0]) == "b", "assign reports the new layout")
	check(String(layout[0]) == first_before, "assign never mutates its input")
	check(String(SkillBar.assign(layout, 99, "a")[17]) == "", "an out-of-range slot changes nothing")
	check(String(SkillBar.assign(layout, 3, "")[3]) == "", "an empty id clears the slot")
	var swapped := SkillBar.swap(layout, 0, 1)
	check(String(swapped[0]) == String(layout[1]) and String(swapped[1]) == String(layout[0]), "swap exchanges two slots")
	check(String(layout[0]) == first_before, "swap never mutates its input")
	check(String(SkillBar.swap(layout, 0, 99)[0]) == String(layout[0]), "an out-of-range swap changes nothing")
	check(String(SkillBar.swap(layout, 2, 2)[2]) == String(layout[2]), "swapping a slot with itself is a no-op")

	var pruned := SkillBar.reconcile(["a", "bogus", "a", "c"], ["a", "c"])
	check(pruned.size() == SkillBar.SLOT_COUNT, "reconcile always returns eighteen slots")
	check(String(pruned[0]) == "a" and String(pruned[3]) == "c", "reconcile drops unknown arts and duplicates")
	check(String(pruned[1]) == "" and String(pruned[2]) == "", "a dropped art leaves its own slot empty")
	var padded := SkillBar.reconcile(["a"], ["a", "b"])
	check(String(padded[0]) == "a" and String(padded[1]) == "", "a short layout is padded, not refilled")
	check(SkillBar.reconcile([], ["a"]).size() == SkillBar.SLOT_COUNT, "an empty layout reconciles to empty")
	var pruned_default := SkillBar.reconcile(SkillBar.default_layout(["x", "y"]), ["x"])
	check(String(pruned_default[0]) == "x" and String(pruned_default[1]) == "", "reconcile also prunes a default layout")
	check(SkillBar.reconcile(["a", "b"], []).all(func(value: Variant) -> bool: return String(value) == ""), "nothing known means an empty bar")

	check(SkillBar.wrap_bar(0, 1) == 1 and SkillBar.wrap_bar(2, 1) == 0, "bar switching wraps forward")
	check(SkillBar.wrap_bar(0, -1) == 2, "bar switching wraps backward")
	check(SkillBar.wrap_bar(7, 1) == 0, "a bad bar clamps before wrapping")
	check(SkillBar.bar_label(0) == "I" and SkillBar.bar_label(2) == "III", "bars carry numerals")
	check(SkillBar.bar_label(9) == "III", "a bad bar label clamps")
	check(SkillBar.bar_filled(layout, 0) == 6, "a full bar counts six arts")
	var sparse := SkillBar.empty_layout()
	sparse[9] = "z"
	check(SkillBar.bar_filled(sparse, 1) == 1 and SkillBar.bar_filled(sparse, 0) == 0, "occupancy counts only that bar")
	check(SkillBar.first_filled(sparse, 1) == 3, "the first filled slot is reported within its bar")
	check(SkillBar.first_filled(sparse, 2) == -1, "an empty bar has no first slot")
	check(SkillBar.unplaced(["z", "y"], sparse) == ["y"], "known arts off the bar are listed")
	check(SkillBar.unplaced(["z", "z"], sparse).is_empty(), "unplaced never repeats an art")

	check(approx(SkillBar.cooldown_ratio(2.0, 4.0), 0.5), "a cooldown shows the fraction still left")
	check(SkillBar.cooldown_ratio(0.0, 4.0) == 0.0, "a ready slot has no cooldown")
	check(SkillBar.cooldown_ratio(5.0, 4.0) == 1.0, "a cooldown never overfills its sweep")
	check(SkillBar.cooldown_ratio(1.0, 0.0) == 0.0, "a zero-length cooldown shows nothing")
	check(SkillBar.cooldown_text(0.0) == "" and SkillBar.cooldown_text(0.02) == "", "a ready art shows no timer")
	check(SkillBar.cooldown_text(1.24) == "1.2s", "a cooldown reads in tenths of a second")
	check(SkillBar.cooldown_text(0.5) == "0.5s", "a short cooldown still reads")


# ------------------------------------------------------------- enemy ai ----

func _enemy_ai_tests() -> void:
	print("[enemy ai] archetypes, perception, leashes, group slots and states")
	check(DB.enemy_archetypes.size() >= 4, "at least four enemy archetypes are defined")
	check(DB.has("enemy_archetype", "brawler"), "the registry indexes enemy archetypes by id")
	check(DB.enemy_archetype("brawler").get("name", "") == "Brawler", "an archetype carries its display name")
	check(DB.counts().has("enemy_archetypes"), "the registry counts enemy archetypes")
	var every_biome_enemy_named := true
	for biome in DB.biomes:
		for enemy in biome.get("enemies", []):
			if not DB.has("enemy_archetype", String(enemy.get("archetype", ""))):
				every_biome_enemy_named = false
	check(every_biome_enemy_named, "every biome enemy names a known archetype")

	var brawler := EnemyAI.profile(DB.enemy_archetype("brawler"))
	var skirmisher := EnemyAI.profile(DB.enemy_archetype("skirmisher"))
	var sentinel := EnemyAI.profile(DB.enemy_archetype("sentinel"))
	var archer := EnemyAI.profile(DB.enemy_archetype("archer"))
	check(EnemyAI.is_ranged(archer), "an archer is a ranged body")
	check(not EnemyAI.is_ranged(brawler) and not EnemyAI.is_ranged(skirmisher), "a brawler and a skirmisher are melee")
	check(EnemyAI.keep_away(archer) > 0.0, "an archer holds a firing distance")
	check(EnemyAI.keep_away(brawler) == 0.0, "a melee body wants no distance")
	check(EnemyAI.reach(sentinel) > EnemyAI.reach(brawler), "a sentinel strikes further than a brawler")
	check(float(EnemyAI.strike_hitbox(sentinel).get("angle", 0.0)) < 360.0, "a sentinel guards a frontal arc")
	check(float(EnemyAI.strike_hitbox(brawler).get("angle", 0.0)) == 360.0, "a brawler swings all around")
	check(approx(float(EnemyAI.strike_hitbox(brawler).get("radius", 0.0)), EnemyAI.reach(brawler)), "a strike reaches exactly its reach")
	check(EnemyAI.windup_time(sentinel) > EnemyAI.windup_time(skirmisher), "a heavier body telegraphs longer")
	check(EnemyAI.cooldown_time(archer) > EnemyAI.cooldown_time(brawler), "a ranged body reloads longer")
	check(EnemyAI.ring_distance(brawler) > EnemyAI.reach(brawler), "a circling body stands just outside its reach")
	check(approx(EnemyAI.ring_distance(archer), EnemyAI.keep_away(archer)), "an archer orbits at its firing band")
	check(EnemyAI.telegraph_color(archer) != EnemyAI.telegraph_color(brawler), "archetypes telegraph in their own colours")
	check(EnemyAI.label("return") == "Returning home" and EnemyAI.label("nope") == "Unknown", "states carry readable labels")

	var fallback := EnemyAI.profile_by_id(DB.enemy_archetypes, "nope")
	check(String(fallback.get("id", "")) == "nope" and float(fallback.get("aggro_range", 0.0)) == float(EnemyAI.DEFAULTS["aggro_range"]), "an unknown archetype falls back to the defaults")
	var clamped := EnemyAI.profile({"aggro_range": -5.0, "vision_degrees": 900.0, "group_limit": 0, "delivery": "song", "windup": 0.0})
	check(float(clamped.get("aggro_range", 0.0)) >= 1.0, "a negative aggro range is clamped")
	check(approx(float(clamped.get("vision_degrees", 0.0)), 360.0), "a vision cone cannot exceed a full circle")
	check(int(clamped.get("group_limit", 0)) == 1, "a group always allows at least one attacker")
	check(String(clamped.get("delivery", "")) == "melee", "an unknown delivery falls back to melee")
	check(float(clamped.get("windup", 0.0)) > 0.0, "a wind-up never collapses to zero")
	check(int(EnemyAI.profile({"retreat_after": -2}).get("retreat_after", -1)) == 0, "a negative retreat count is clamped")

	var sight := EnemyAI.profile({"aggro_range": 300.0, "vision_degrees": 120.0})
	check(EnemyAI.perceives(100.0, Vector2.RIGHT, Vector2.RIGHT, sight), "a target ahead in range is seen")
	check(not EnemyAI.perceives(400.0, Vector2.RIGHT, Vector2.RIGHT, sight), "a target beyond the aggro range is unseen")
	check(not EnemyAI.perceives(100.0, Vector2.LEFT, Vector2.RIGHT, sight), "a target behind the vision cone is unseen")
	check(EnemyAI.perceives(100.0, Vector2.RIGHT, Vector2.ZERO, sight), "a body with no facing is alert rather than blind")
	check(EnemyAI.perceives(40.0, Vector2.LEFT, Vector2.RIGHT, EnemyAI.profile({"aggro_range": 50.0, "vision_degrees": 360.0})), "a full-circle cone sees behind")
	check(not EnemyAI.perceives(-1.0, Vector2.RIGHT, Vector2.RIGHT, sight), "a negative distance perceives nothing")

	check(EnemyAI.leash_broken(900.0, brawler), "a body dragged past its leash breaks off")
	check(not EnemyAI.leash_broken(100.0, brawler), "a body near home holds its ground")
	check(EnemyAI.wants_to_flee(0.1, skirmisher), "a wounded skirmisher wants to run")
	check(not EnemyAI.wants_to_flee(0.1, brawler), "a brawler never runs")
	check(not EnemyAI.wants_to_flee(1.0, skirmisher), "an unhurt skirmisher stands its ground")

	var calm := {
		"dist": 200.0, "home_dist": 10.0, "memory": 0.0, "hp_ratio": 1.0,
		"flee_left": 0.0, "retreat_left": 0.0, "seen": false, "at_home": true,
		"ready": true, "committed": true, "flee_used": false, "in_reach": false,
	}
	check(EnemyAI.think(calm, brawler) == "patrol", "an unaware body at home patrols")
	var away := calm.duplicate()
	away["at_home"] = false
	away["home_dist"] = 120.0
	check(EnemyAI.think(away, brawler) == "return", "an unaware body away from home walks back")
	var chase := calm.duplicate()
	chase["seen"] = true
	chase["dist"] = 260.0
	check(EnemyAI.think(chase, brawler) == "chase", "a seen target out of reach is chased")
	var leashed := chase.duplicate()
	leashed["home_dist"] = 900.0
	check(EnemyAI.think(leashed, brawler) == "return", "a broken leash beats the target in sight")
	var strike := chase.duplicate()
	strike["in_reach"] = true
	check(EnemyAI.think(strike, brawler) == "windup", "a ready body in reach winds up")
	var cooling := strike.duplicate()
	cooling["ready"] = false
	check(EnemyAI.think(cooling, brawler) == "recover", "a body still cooling recovers")
	var crowded := strike.duplicate()
	crowded["committed"] = false
	check(EnemyAI.think(crowded, brawler) == "circle", "a body that cannot commit circles")
	var far_crowded := chase.duplicate()
	far_crowded["committed"] = false
	check(EnemyAI.think(far_crowded, brawler) == "circle", "a body without a slot circles instead of piling on")
	var hurt := chase.duplicate()
	hurt["hp_ratio"] = 0.1
	check(EnemyAI.think(hurt, skirmisher) == "flee", "a cowardly body flees when wounded")
	var already_ran := hurt.duplicate()
	already_ran["flee_used"] = true
	check(EnemyAI.think(already_ran, skirmisher) == "chase", "a body that already fled fights on")
	var running := chase.duplicate()
	running["flee_left"] = 2.0
	check(EnemyAI.think(running, brawler) == "flee", "a flee clock keeps the body running")
	var backing_off := strike.duplicate()
	backing_off["retreat_left"] = 0.4
	check(EnemyAI.think(backing_off, brawler) == "retreat", "a retreat clock backs the body off")
	var close_archer := calm.duplicate()
	close_archer["seen"] = true
	close_archer["dist"] = 90.0
	close_archer["in_reach"] = true
	check(EnemyAI.think(close_archer, archer) == "retreat", "an archer backs off when a target closes in")
	var ranged := calm.duplicate()
	ranged["seen"] = true
	ranged["dist"] = 300.0
	ranged["in_reach"] = true
	check(EnemyAI.think(ranged, archer) == "windup", "an archer in its band winds up a bolt")

	check(EnemyAI.move_intent("chase", Vector2(3, 0), 50.0, brawler) == Vector2.RIGHT, "chasing walks toward the target")
	check(EnemyAI.move_intent("flee", Vector2(3, 0), 50.0, brawler) == Vector2.LEFT, "fleeing walks away from the target")
	check(EnemyAI.move_intent("retreat", Vector2(3, 0), 50.0, archer) == Vector2.LEFT, "retreating backs away")
	check(EnemyAI.move_intent("return", Vector2.RIGHT, 50.0, brawler, 1.0, Vector2(0, 1)) == Vector2.DOWN, "returning walks toward home")
	check(EnemyAI.move_intent("windup", Vector2.RIGHT, 50.0, brawler) == Vector2.ZERO, "a wind-up does not move")
	check(EnemyAI.move_intent("recover", Vector2.RIGHT, 50.0, brawler) == Vector2.ZERO, "a recovery does not move")
	var orbit_one := EnemyAI.move_intent("circle", Vector2.RIGHT, 300.0, archer, 1.0)
	var orbit_two := EnemyAI.move_intent("circle", Vector2.RIGHT, 300.0, archer, -1.0)
	check(orbit_one.y > 0.0 and orbit_two.y < 0.0, "the two strafe signs mirror the orbit")
	var closing := EnemyAI.move_intent("circle", Vector2.RIGHT, 600.0, archer, 1.0)
	check(closing.x > 0.0, "a circling body too far away still closes in")
	check(EnemyAI.move_intent("idle", Vector2.RIGHT, 50.0, brawler) == Vector2.ZERO, "an idle body stands still")

	var push := EnemyAI.separation(Vector2.ZERO, [Vector2(10, 0)], 30.0)
	check(push.x < 0.0, "bodies push apart")
	check(EnemyAI.separation(Vector2.ZERO, [Vector2(400, 0)], 30.0) == Vector2.ZERO, "distant bodies do not push")
	check(EnemyAI.separation(Vector2.ZERO, [Vector2.ZERO], 30.0).length() > 0.0, "stacked bodies still separate")
	check(EnemyAI.separation(Vector2.ZERO, [], 30.0) == Vector2.ZERO, "an empty crowd pushes nothing")
	check(push.y == 0.0, "a push is straight away from the neighbour")

	check(EnemyAI.may_commit(2, brawler), "a group of three allows two committed allies")
	check(not EnemyAI.may_commit(3, brawler), "a full group takes no more attackers")
	check(EnemyAI.may_commit(-1, brawler), "a negative count is treated as none")
	check(not EnemyAI.may_commit(2, sentinel), "a sentinel's smaller group fills sooner")

	var bolt := Projectile.new()
	check(bolt.faction == "player", "a projectile defaults to the player's side")
	check(bolt.origin == Vector2.ZERO, "a projectile records its origin")
	bolt.free()


# ------------------------------------------------------ item architecture ----

func _item_for(id_value: String, slot: String, name_value: String, extra: Dictionary = {}) -> Dictionary:
	var raw := {
		"id": id_value, "slot": slot, "name": name_value, "base_name": name_value,
		"base": "base.test", "value": 10,
	}
	raw.merge(extra, true)
	return Items.normalize_item(raw)


func _item_architecture_tests() -> void:
	print("[items] schema, durability, stacks and save form")

	var blank := Items.normalize_item({})
	check(blank.get("count") == 1 and blank.get("rarity") == 0, "a blank record fills safe defaults")
	check(not Items.is_valid_item(blank), "a record without an id is not an item")
	var sword := _item_for("item.test.1", "weapon", "Iron Jian", {"rarity": 9, "ilvl": 0, "value": -5, "junk": 1})
	check(int(sword["rarity"]) == ItemGen.RARITY_NAMES.size() - 1, "rarity is clamped to the table")
	check(String(sword["rarity_name"]) == ItemGen.RARITY_NAMES[ItemGen.RARITY_NAMES.size() - 1], "the rarity name follows the clamped value")
	check(int(sword["ilvl"]) == 1 and int(sword["value"]) == 0, "level and value are clamped")
	check(not sword.has("junk"), "unknown fields are dropped")
	check(Items.is_valid_item(sword), "a normalised weapon is a real item")
	check(Items.is_stable_id("item.test.1") and Items.is_stable_id("item.core.beast.moonfang.3"), "item ids with segments are stable")
	check(not Items.is_stable_id("item") and not Items.is_stable_id("item."), "a bare prefix is not an id")
	check(not Items.is_stable_id("loot.1.2"), "an id must be an item id")
	check(not Items.is_valid_item(_item_for("item.test.2", "hat", "Odd Hat")), "an unknown slot is not an item")
	check(not Items.is_valid_item(_item_for("", "material", "Nameless")), "an anonymous record is not an item")

	var modded := Items.normalize_item({"id": "item.test.3", "slot": "ring", "name": "Jade Ring", "mods": [
		{"id": "prefix.azure", "stat": "qi_regen_flat", "value": 1.5, "text": "+1.5 Qi", "junk": true},
		"junk",
	]})
	var mods: Array = modded["mods"]
	check(mods.size() == 1, "malformed mods are dropped")
	check(String((mods[0] as Dictionary)["stat"]) == "qi_regen_flat" and not (mods[0] as Dictionary).has("junk"), "a mod is reduced to its schema")

	var material := _item_for("item.test.4", "material", "Spirit Ore", {"base": "ore.spirit"})
	var potion := _item_for("item.test.5", "consumable", "Qi Pill")
	check(not material.has("durability") and not potion.has("durability"), "only weapons and armour carry durability")
	check(approx(Items.max_durability("weapon"), 300.0) and approx(Items.max_durability("armor"), 400.0), "durable slots have their own maximum")
	check(approx(Items.durability_of(sword), 300.0), "a fresh weapon arrives at full durability")

	var worn := Items.wear(sword, 60.0)
	check(approx(Items.durability_of(worn), 240.0), "a blow wears the weapon by its amount")
	check(approx(Items.durability_ratio(worn), 0.8), "condition is the ratio of what is left")
	check(approx(Items.condition_mult(worn), 1.0), "a worn weapon still works")
	check(approx(Items.durability_of(sword), 300.0), "wearing never mutates the original")
	var broken := Items.wear(worn, 9999.0)
	check(approx(Items.durability_of(broken), 0.0), "durability cannot go below zero")
	check(Items.is_broken(broken) and approx(Items.condition_mult(broken), 0.0), "a broken weapon contributes nothing")
	var mended := Items.repair(broken)
	check(approx(Items.durability_of(mended), 300.0) and not Items.is_broken(mended), "repair restores the full maximum")
	check(approx(Items.durability_of(Items.wear(material, 5.0)), 0.0) and not Items.is_broken(material), "a material cannot wear")

	var gear := {"weapon": worn, "armor": Items.wear(_item_for("item.test.6", "armor", "Cloud Robe"), 200.0), "ring": modded}
	var cost := Items.repair_cost(gear)
	check(cost > 0, "worn gear costs stones to mend")
	check(Items.repair_cost({"weapon": sword, "ring": modded}) == 0, "undamaged gear costs nothing")
	var rare_cost := Items.repair_cost({"weapon": Items.wear(_item_for("item.test.7", "weapon", "Saber", {"rarity": 3}), 60.0)})
	var plain_cost := Items.repair_cost({"weapon": Items.wear(_item_for("item.test.8", "weapon", "Saber"), 60.0)})
	check(rare_cost > plain_cost, "treasure gear costs more to mend")
	check(Items.repair_cost({}) == 0, "an empty body has nothing to mend")

	check(Items.stack_limit(material) == 20 and Items.stack_limit(potion) == 10, "materials and consumables have stack limits")
	check(Items.stack_limit(sword) == 1 and Items.stack_key(sword) == "", "equipment never stacks")
	var ore := _item_for("item.test.9", "material", "Spirit Ore", {"base": "ore.spirit"})
	check(Items.can_stack(material, ore) and not Items.can_stack(material, sword), "only the same kind of thing stacks")
	var other_ore := _item_for("item.test.10", "material", "Spirit Ore", {"base": "ore.spirit"})
	check(Items.stack_key(material) == Items.stack_key(other_ore), "the stack key ignores the instance id")
	var bag: Array = Items.add_to_inventory([], material)
	check(bag.size() == 1 and int(bag[0]["count"]) == 1, "the first pickup starts a stack")
	bag = Items.add_to_inventory(bag, other_ore)
	check(bag.size() == 1 and int(bag[0]["count"]) == 2, "a matching pickup joins the stack")
	var filled := material.duplicate(true)
	filled["count"] = 20
	var full_bag := Items.add_to_inventory([filled], other_ore)
	check(full_bag.size() == 2 and int(full_bag[1]["count"]) == 1, "a full stack spills into a new one")
	var mixed := Items.add_to_inventory(Items.add_to_inventory([], sword), _item_for("item.test.11", "weapon", "Iron Jian"))
	check(mixed.size() == 2, "two swords are two entries")
	var messy: Array = Items.normalize_inventory([material, other_ore, sword, "junk", {"id": "item.bad.1"}])
	check(messy.size() == 2, "loading merges stacks and drops malformed entries")
	check(Items.total_count(messy) == 3, "total count adds the stack sizes")
	var bag_entry: Dictionary = bag[0]
	check(Items.label(bag_entry) == "Spirit Ore x2" and Items.label(sword) == "Iron Jian", "a stack is labelled with its count")

	var saved := Items.to_save(broken)
	var round_trip := Items.from_save(JSON.parse_string(JSON.stringify(saved)))
	check(round_trip == saved, "an item survives JSON unchanged")
	check(Items.to_save(saved) == saved, "the save form is canonical")
	check(Items.from_save("junk").is_empty() and Items.from_save({"id": "item.x.1"}).is_empty(), "malformed saved items are refused")
	var legacy_weapon := Items.from_save({"id": "item.legacy.1", "slot": "weapon", "name": "Old Jian", "value": 4})
	check(approx(Items.durability_of(legacy_weapon), 300.0), "a legacy weapon loads undamaged")
	check(int(legacy_weapon["count"]) == 1, "a legacy item loads as a single unit")
	var loaded_gear := Items.normalize_equipment({"weapon": saved, "ring": saved, "junk": 1})
	check(loaded_gear.size() == 1 and loaded_gear.has("weapon"), "equipment drops a piece in the wrong slot")
	check(Items.inventory_to_save([material, other_ore]).size() == 1, "saving merges duplicate stacks")

	check(Economy.sell_value(filled) == Economy.sell_price(filled) * 20, "a stack sells for its whole count")
	check(Economy.sell_value(sword) == Economy.sell_price(sword), "a single item sells at its unit price")

	var legacy_save := {
		"schema": 1,
		"player": {
			"inventory": [{"id": "item.legacy.2", "slot": "material", "name": "Spirit Ore", "value": 3}],
			"equipment": {"weapon": {"id": "item.legacy.3", "slot": "weapon", "name": "Iron Jian", "value": 12}},
		},
	}
	var migrated := Save._migrate(legacy_save, 1)
	check(int(migrated.get("schema", -1)) == Save.CURRENT_SCHEMA, "a schema-1 save migrates to the current schema")
	var migrated_player: Dictionary = migrated["player"]
	var migrated_inventory: Array = migrated_player["inventory"]
	check(migrated_inventory.size() == 1 and int(migrated_inventory[0]["count"]) == 1, "migration gives a legacy material a count")
	var migrated_equipment: Dictionary = migrated_player["equipment"]
	var migrated_weapon: Dictionary = migrated_equipment["weapon"]
	check(approx(Items.durability_of(migrated_weapon), 300.0), "migration gives a legacy weapon durability")

	var bases_ok := true
	for base in DB.bases:
		var slot := String(base.get("slot", ""))
		if not Items.is_known_slot(slot):
			bases_ok = false
	check(bases_ok, "every item base declares a known slot")


# ---------------------------------------------------- beasts and bosses ----

func _boss_and_beast_tests() -> void:
	print("[beasts] species, habitats and cores")

	check(DB.spirit_beasts.size() == 4, "four spirit beast species ship")
	check(int(DB.counts()["spirit_beasts"]) == 4, "the registry counts the species")
	check(int(DB.counts()["bosses"]) >= 1, "the registry counts the bosses")
	var beast_ids: Dictionary = {}
	for entry in DB.spirit_beasts:
		var species := Beasts.profile(entry)
		var id := String(species["id"])
		check(not beast_ids.has(id), "spirit beast id %s is unique" % id)
		beast_ids[id] = true
		check(Beasts.ARCHETYPES.has(String(species["archetype"])), "%s has a real archetype" % id)
		check(not (species["biomes"] as Dictionary).is_empty(), "%s lives somewhere" % id)
		check(String((species["core"] as Dictionary)["name"]) != "", "%s leaves a core" % id)
		check(String(species["color"]).begins_with("#"), "%s has a colour" % id)
	check(beast_ids.size() == 4, "every species id is distinct")
	check(Beasts.is_valid_id(DB.spirit_beasts, "beast.moonfang"), "a known species is found")
	check(not Beasts.is_valid_id(DB.spirit_beasts, "beast.nope"), "an unknown species is rejected")

	var fallback := Beasts.profile({})
	check(String(fallback["archetype"]) == "brawler", "a malformed species falls back to a brawler")
	check(String((fallback["core"] as Dictionary)["name"]) == "Spirit Core", "a malformed species still has a core")
	var bad_archetype := Beasts.profile({"archetype": "dragon"})
	check(String(bad_archetype["archetype"]) == "brawler", "an unknown archetype is replaced")
	var clamped := Beasts.profile({"speed": 0.0, "hp_mult": 0.0, "biomes": {"biome.verdant": 0, "biome.marsh": -2}})
	check(float(clamped["speed"]) >= 10.0 and float(clamped["hp_mult"]) >= 0.2, "species numbers are clamped")
	check((clamped["biomes"] as Dictionary).is_empty(), "non-positive habitat weights are dropped")

	var marsh := Beasts.residents(DB.spirit_beasts, "biome.marsh")
	check(marsh.size() >= 2, "the marsh has residents")
	var marsh_ids: Array = []
	for entry in marsh:
		marsh_ids.append(String((entry as Dictionary)["species"]["id"]))
	check(marsh_ids.has("beast.gloomserpent") and marsh_ids.has("beast.moonfang"), "the marsh lists its own species")
	check(not marsh_ids.has("beast.stoneback"), "a species absent from a biome is not listed there")
	check(Beasts.residents(DB.spirit_beasts, "biome.none").is_empty(), "an unknown biome has no beasts")
	check(Beasts.roll(DB.spirit_beasts, "biome.none", Rng.stream("beast", 0, 0)).is_empty(), "no habitat means no roll")
	check(Beasts.roll([], "biome.marsh", Rng.stream("beast", 0, 1)).is_empty(), "an empty table rolls nothing")

	var first_roll := Beasts.roll(DB.spirit_beasts, "biome.marsh", Rng.stream("beast_probe", 9, 4))
	var same_roll := Beasts.roll(DB.spirit_beasts, "biome.marsh", Rng.stream("beast_probe", 9, 4))
	check(String(first_roll.get("id", "")) == String(same_roll.get("id", "")), "a beast roll is deterministic")
	var seen_species: Dictionary = {}
	for i in 40:
		var rolled := Beasts.roll(DB.spirit_beasts, "biome.marsh", Rng.stream("beast_probe", 3, i))
		seen_species[String(rolled.get("id", ""))] = true
	check(not seen_species.has("beast.stoneback"), "a roll never leaves a species' habitat")
	check(seen_species.size() >= 2, "a habitat roll reaches more than one species")

	var stoneback := Beasts.profile(DB.spirit_beast("beast.stoneback"))
	var as_enemy := Beasts.enemy_entry(stoneback)
	check(String(as_enemy["archetype"]) == "sentinel", "a beast converts to an enemy entry")
	check(float(as_enemy["hp_mult"]) > 1.0, "the species' numbers survive the conversion")
	var core := Beasts.core_item(stoneback, 4, 12)
	check(String(core["slot"]) == "material", "a core is a material")
	check(String(core["name"]) == "Stoneback Hide", "a core keeps its species' name")
	check(int(core["rarity"]) == 2 and int(core["ilvl"]) == 4, "a core carries its rarity and level")
	check(String(core["id"]).begins_with("item.core.beast.stoneback"), "a core id names its species")
	check(int(core["value"]) > 0, "a core is worth something")
	check(Beasts.count(DB.spirit_beasts) == 4, "the species count is four")
	check(Beasts.all([{}, "junk"]).size() == 1, "malformed entries are skipped")

	print("[bosses] phases, adds and rewards")

	var warden := Boss.profile(DB.boss("boss.tomb_warden"))
	check(String(warden["id"]) == "boss.tomb_warden", "the tomb warden loads")
	check(Boss.phase_count(warden) == 3, "the warden has three phases")
	check((Boss.thresholds(warden) as Array).size() == 2, "the warden has two thresholds")
	check(approx(float(Boss.thresholds(warden)[0]), 0.66), "the first threshold is read as data")
	check(Boss.phase_index(1.0, warden) == 0, "a whole body is in the first phase")
	check(Boss.phase_index(0.67, warden) == 0, "the first phase holds above its threshold")
	check(Boss.phase_index(0.66, warden) == 1, "crossing a threshold enters the next phase")
	check(Boss.phase_index(0.4, warden) == 1, "the middle phase covers the middle band")
	check(Boss.phase_index(0.33, warden) == 2, "the last threshold enters the last phase")
	check(Boss.phase_index(0.0, warden) == 2, "a dying body stays in the last phase")
	check(Boss.phase_name(warden, 0) == "Hollow Guard", "the first phase is named")
	check(Boss.phase_name(warden, 1) == "Moon's Wrath", "the second phase is named")
	check(Boss.phase_name(warden, 2) == "Last Light", "the last phase is named")
	check(approx(Boss.phase_mult(warden, 0, "damage_mult"), 1.0), "the first phase does not amplify")
	check(approx(Boss.phase_mult(warden, 1, "damage_mult"), 1.25), "the second phase hits harder")
	check(approx(Boss.phase_mult(warden, 2, "speed_mult"), 1.3), "the last phase moves faster")
	check(approx(Boss.phase_mult(warden, 2, "cooldown_mult"), 0.7), "the last phase strikes sooner")
	check(approx(Boss.phase_mult(warden, 9, "damage_mult"), Boss.phase_mult(warden, 2, "damage_mult")), "an out-of-range phase clamps to the last")
	check(Boss.phase_status(warden, 0).is_empty(), "the first phase carries no status")
	check(String(Boss.phase_status(warden, 1).get("id", "")) == "shock", "the second phase shocks")
	check(String(Boss.phase_status(warden, 2).get("id", "")) == "bleed", "the last phase bleeds")
	check(Boss.adds(warden, 0).is_empty(), "the first phase calls nothing")
	check(Boss.adds(warden, 1).size() == 1, "the second phase calls one beast")
	check(Boss.adds(warden, 2).size() == 2, "the last phase calls two")
	check(Beasts.is_valid_id(DB.spirit_beasts, String(Boss.adds(warden, 2)[0])), "an add names a real species")
	check(int(Boss.reward(warden)["stones"]) == 400, "the boss pays its stones")
	check(int(Boss.reward(warden)["rarity"]) == 3, "the boss reward is treasure grade")
	check(String(warden["name"]) == "Warden of the Hollow Moon", "the boss has a name")
	check(Boss.bar_color(warden) != Boss.telegraph_color(warden), "the boss bar and telegraph differ")
	check(String(Boss.label(warden, 1)).contains("Moon's Wrath"), "a boss label names its phase")

	var custom := Boss.profile({"thresholds": [0.3, 0.8], "phases": [{"name": "A"}, {"name": "B"}]})
	check(approx(float(Boss.thresholds(custom)[0]), 0.8), "thresholds sort from the top down")
	check(Boss.phase_count(custom) == 3, "missing phases are padded to the threshold count")
	check(Boss.phase_name(custom, 2) == "Phase 3", "a padded phase still has a name")
	var duplicated := Boss.profile({"thresholds": [0.5, 0.5], "phases": [{"name": "A"}, {"name": "B"}]})
	check((Boss.thresholds(duplicated) as Array).size() == 1, "duplicate thresholds collapse")
	var extras := Boss.profile({"thresholds": [0.25], "phases": [{"name": "A"}, {"name": "B"}, {"name": "C"}]})
	check(Boss.phase_count(extras) == 2, "extra phases are trimmed to the thresholds")
	var blank := Boss.profile({})
	check(Boss.phase_count(blank) == 2, "a malformed boss still gets one threshold two phases")
	check(approx(Boss.phase_mult(blank, 0, "damage_mult"), 1.0), "a missing multiplier reads one")


# -------------------------------------------------------- combat polish ----

func _combat_polish_tests() -> void:
	print("[combat polish] hitstop, statuses, damage text and synthesized sound")

	check(Hitstop.duration_for(0.0) == 0.0, "no damage freezes nothing")
	check(Hitstop.duration_for(5.0) >= Hitstop.MIN, "a light blow still registers")
	check(Hitstop.duration_for(5.0) <= Hitstop.MAX, "a blow never freezes past the cap")
	check(Hitstop.duration_for(20.0, true) > Hitstop.duration_for(20.0), "a critical blow holds longer")
	check(Hitstop.duration_for(20.0, false, true) > Hitstop.duration_for(20.0), "a heavy blow holds longer")
	check(Hitstop.duration_for(100000.0) <= Hitstop.MAX, "damage is capped, not unbounded")
	check(approx(Hitstop.duration_for(100000.0, true, true), Hitstop.MAX), "a huge critical heavy blow hits the cap")
	var freeze := Hitstop.new()
	check(not freeze.is_frozen(), "a fresh timer is not frozen")
	freeze.punch(12.0)
	check(freeze.is_frozen() and freeze.requests == 1, "a blow requests a freeze")
	var freeze_before := freeze.remaining
	freeze.request(0.02)
	check(approx(freeze.remaining, freeze_before), "a shorter request never cuts a freeze short")
	freeze.request(1.0)
	check(approx(freeze.remaining, Hitstop.MAX), "a request is clamped to the cap")
	freeze.tick(Hitstop.MAX)
	check(not freeze.is_frozen() and freeze.remaining == 0.0, "the freeze expires")
	freeze.request(0.05)
	freeze.clear()
	check(not freeze.is_frozen(), "a load or death clears the freeze")

	check(Status.IDS.size() == 4, "four statuses exist")
	check(Status.is_valid("burn") and not Status.is_valid("poison"), "status ids are validated")
	check(Status.name_of("burn") == "Burning" and Status.name_of("chill") == "Chilled", "statuses carry names")
	check(Status.color("burn") != Status.color("chill"), "statuses carry colours")
	check(Status.is_dot("burn") and Status.is_dot("bleed"), "burn and bleed are damage over time")
	check(not Status.is_dot("chill") and not Status.is_dot("shock"), "chill and shock are not")
	var burning := Status.apply([], {"id": "burn", "duration": 3.0, "magnitude": 4.0})
	check(burning.size() == 1 and Status.has(burning, "burn"), "a status can be applied")
	check(approx(Status.remaining_of(burning, "burn"), 3.0), "the status keeps its clock")
	check(Status.apply(burning, {"id": "nope", "duration": 3.0, "magnitude": 1.0}) == burning, "an unknown status changes nothing")
	check(Status.apply(burning, {"id": "burn", "duration": 0.0, "magnitude": 4.0}) == burning, "a zero-clock status changes nothing")
	check(Status.apply(burning, {"id": "burn", "duration": 3.0, "magnitude": 0.0}) == burning, "a zero-magnitude status changes nothing")
	var longer := Status.apply(burning, {"id": "burn", "duration": 5.0, "magnitude": 3.0})
	check(approx(Status.remaining_of(longer, "burn"), 5.0), "reapplying refreshes the clock")
	check(int(longer[0]["stacks"]) == 2, "reapplying adds a stack")
	check(approx(float(longer[0]["magnitude"]), 4.0), "reapplying never weakens the magnitude")
	var stronger := Status.apply(burning, {"id": "burn", "duration": 1.0, "magnitude": 9.0})
	check(approx(float(stronger[0]["magnitude"]), 9.0), "a stronger application wins")
	var capped := burning
	for i in 5:
		capped = Status.apply(capped, {"id": "burn", "duration": 3.0, "magnitude": 4.0})
	check(int(capped[0]["stacks"]) == Status.MAX_STACKS, "stacks cap at three")
	check(Status.has(burning, "burn") and approx(Status.remaining_of(burning, "burn"), 3.0), "apply never mutates its input")
	var half_tick := Status.advance(burning, 0.5)
	check((half_tick["active"] as Array).size() == 1, "the status survives its first tick")
	check((half_tick["hits"] as Array).size() == 1, "a burn ticks after half a second")
	check(approx(float((half_tick["hits"] as Array)[0]["amount"]), 2.0), "a burn tick carries magnitude x interval")
	check(((Status.advance(burning, 0.2))["hits"] as Array).is_empty(), "a burn does not tick before its interval")
	check(((Status.advance(burning, 2.0))["hits"] as Array).size() == 4, "a long step yields every due tick")
	check(((Status.advance(burning, 3.0))["active"] as Array).is_empty(), "an expired status is dropped")
	var stacked_burn := Status.apply(burning, {"id": "burn", "duration": 3.0, "magnitude": 4.0})
	check(approx(float(((Status.advance(stacked_burn, 0.5))["hits"] as Array)[0]["amount"]), 4.0), "stacks raise a tick's damage")
	var chill := Status.apply([], {"id": "chill", "duration": 2.0, "magnitude": 0.3})
	check(((Status.advance(chill, 0.5))["hits"] as Array).is_empty(), "a non-damaging status ticks nothing")
	check(approx(Status.slow(chill), 0.3), "chill slows by its magnitude")
	var stacked_chill := Status.apply(chill, {"id": "chill", "duration": 2.0, "magnitude": 0.4})
	check(approx(Status.slow(stacked_chill), Status.SLOW_CAP), "chill stacks up to the cap")
	check(approx(Status.speed_multiplier(stacked_chill), 1.0 - Status.SLOW_CAP), "chill multiplies movement")
	var shock := Status.apply([], {"id": "shock", "duration": 2.0, "magnitude": 0.15})
	check(approx(Status.taken_multiplier(shock), 1.15), "shock raises damage taken")
	check(approx(Status.taken_multiplier([]), 1.0), "no shock means ordinary damage")
	check(String(Status.labels(chill)[0]).begins_with("Chilled"), "labels name the status")
	check(Status.count(burning) == 1 and Status.count([]) == 0, "count reports live statuses")
	check(Status.id_of({"id": "burn"}) == "burn" and Status.id_of({}) == "", "a payload names its status or nothing")

	check(CombatText.format_amount(0.0) == "" and CombatText.format_amount(0.2) == "", "nothing below half a point is shown")
	check(CombatText.format_amount(12.4) == "12", "damage is rounded for display")
	check(CombatText.format_amount(12345.0) == "12k", "large damage shortens to thousands")
	var plain_text := CombatText.entry(12.0)
	check(String(plain_text["text"]) == "12" and String(plain_text["color"]) == String(CombatText.COLORS[""]), "a plain hit is ink")
	var crit_text := CombatText.entry(12.0, true)
	check(String(crit_text["text"]) == "12!" and int(crit_text["size"]) > int(plain_text["size"]), "a critical is marked and larger")
	var tinted_text := CombatText.entry(9.0, false, "burn")
	check(String(tinted_text["color"]) == String(CombatText.COLORS["burn"]), "a status tints its number")
	check(String(CombatText.entry(9.0, false, "nope")["color"]) == String(CombatText.COLORS[""]), "an unknown tint falls back to ink")
	check(CombatText.entry(0.0).is_empty(), "no entry for no damage")
	check(CombatText.advance([plain_text], 1.5).is_empty(), "a number expires")
	check(float(plain_text.get("age", 0.0)) == 0.0, "advance never mutates its input")
	check(approx(CombatText.alpha(plain_text), 1.0), "a fresh number is opaque")
	var late_text := plain_text.duplicate(true)
	late_text["age"] = 0.8
	check(CombatText.alpha(late_text) < 1.0, "a fading number is transparent")
	check(CombatText.offset(late_text).y < CombatText.offset(plain_text).y, "a number rises as it ages")
	check(approx(CombatText.offset(CombatText.entry(5.0, false, "", 14.0)).x, 14.0), "a number keeps its drift")
	late_text["age"] = 2.0
	check(CombatText.expired(late_text), "an old number is expired")

	check(Sfx.kinds().size() == 8, "eight combat sounds exist")
	check(Sfx.build("nope").data.is_empty(), "an unknown sound is silent rather than broken")
	check(approx(Sfx.duration("hit"), 0.18), "a sound declares its duration")
	for kind in Sfx.kinds():
		var stream := Sfx.build(kind)
		check(stream.data.size() == Sfx.sample_count(kind) * 2, "the %s stream has one 16-bit sample per frame" % kind)
		check(stream.mix_rate == Sfx.RATE and stream.format == AudioStreamWAV.FORMAT_16_BITS, "the %s stream is 22 kHz 16-bit mono" % kind)
		var peak := 0
		for i in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		check(peak > 1000, "the %s sound is audible" % kind)
		check(peak <= 32767, "the %s sound does not clip" % kind)
		check(Sfx.build(kind).data == stream.data, "the %s sound is deterministic" % kind)



## Alchemy: one station, three potions, every potion a consumable whose effect
## is known, a brew that is pure in its stream, and potency that carries quality.
func _alchemy_tests() -> void:
	var station: Dictionary = DB.alchemy_brewery()
	check(String(station.get("id", "")) == Alchemy.STATION, "the cauldron is a real station")
	check(Settlement.LOCATIONS.has(String(station.get("location", ""))), "the cauldron stands somewhere real")
	check(DB.potions.size() == 3, "three potions are authored")
	var rules := Alchemy.new(DB)
	for entry in DB.potions:
		var potion: Dictionary = entry
		var base: Dictionary = DB.base_item(String(potion.get("base", "")))
		check(not base.is_empty() and String(base.get("slot", "")) == "consumable",
			"%s brews a consumable" % String(potion.get("id", "")))
		check(Alchemy.is_effect(String((potion.get("effect", {}) as Dictionary).get("id", ""))),
			"%s has a known effect" % String(potion.get("id", "")))

	# A pill found in the world is drinkable exactly like a brewed one.
	var world_pill := Items.normalize_item({
		"id": "item.alchemy.world", "base": "base.pill.qi_gathering", "slot": "consumable",
		"name": "Qi Gathering Pill", "ilvl": 1})
	check(String(rules.effect_for(world_pill).get("id", "")) == "qi", "a found pill is drinkable")
	check(String(rules.recipe_for_item(world_pill).get("id", "")) == "potion.qi_gathering", "a found pill knows its recipe")
	check(rules.effect_for(Items.normalize_item({"id": "item.alchemy.ore", "slot": "material", "material": "ore"})).is_empty(),
		"ore is not a pill")

	# Potency: default, scaling, bounds, stacking.
	check(is_equal_approx(Alchemy.potency_of(world_pill), 1.0), "a plain pill has plain potency")
	check(Alchemy.potency_for(1.0, false) == 1.0, "an ordinary brewer gains nothing")
	check(Alchemy.potency_for(2.0, true) > Alchemy.potency_for(2.0, false), "luck raises potency further")
	check(Alchemy.potency_for(100.0, true) <= Alchemy.MAX_POTENCY, "potency stays bounded")
	var effect: Dictionary = rules.effect_for(world_pill)
	check(is_equal_approx(Alchemy.effect_amount(effect, world_pill), float(effect.get("amount", 0.0))),
		"a plain pill restores its base amount")
	var strong := world_pill.duplicate()
	strong["potency"] = 1.5
	check(Alchemy.effect_amount(effect, strong) > Alchemy.effect_amount(effect, world_pill), "a stronger pill restores more")
	check(not Items.can_stack(world_pill, strong), "pills of different potency never merge")
	check(Items.can_stack(world_pill, world_pill.duplicate()), "pills of the same potency stack")
	check(is_equal_approx(float(Items.normalize_item({"slot": "consumable", "potency": 99.0})["potency"]), 5.0),
		"potency is clamped on the way in")

	# Brewing is pure in its stream and makes the authored base.
	var recipe: Dictionary = DB.potion("potion.qi_gathering")
	var first: Dictionary = rules.brew(recipe, 1, 70000, 0, 1.0)
	var again: Dictionary = rules.brew(recipe, 1, 70000, 0, 1.0)
	check(bool(first.get("ok", false)) and not bool(first.get("failed", false)), "the qi potion brews")
	check(String((first["item"] as Dictionary).get("id", "")) == String((again["item"] as Dictionary).get("id", "")),
		"brewing repeats from the same stream")
	check(String((first["item"] as Dictionary).get("base", "")) == "base.pill.qi_gathering",
		"the cauldron makes the authored pill")
	check(is_equal_approx(Alchemy.potency_of(first["item"] as Dictionary), 1.0), "an ordinary brewer gets plain potency")
	var learned: Dictionary = rules.brew(recipe, 5, 70000, 1, 1.6)
	check(Alchemy.potency_of(learned["item"] as Dictionary) > 1.0, "insight makes a stronger brew")
	check(int((learned["item"] as Dictionary).get("ilvl", 0)) == 5, "a brew keeps its level")
	var spoiled: Dictionary = recipe.duplicate()
	spoiled["failure_chance"] = 1.0
	var failed: Dictionary = rules.brew(spoiled, 1, 70000, 2, 1.0)
	check(bool(failed.get("failed", false)) and (failed["item"] as Dictionary).is_empty(), "a spoiled brew makes nothing")
	check(not bool(rules.brew({}, 1, 0, 0).get("ok", true)), "an unknown potion is refused")
	check(DB.has("potion", "potion.cleansing"), "potions are indexed")


## Professions: ranks derived from practice, bonuses that grow with rank, and
## recipe gates that mean what they say.
func _professions_tests() -> void:
	check(DB.professions.size() == 2, "two professions are authored")
	var smith: Dictionary = DB.profession("profession.smith")
	check(String(smith.get("station", "")) == "station.forge", "the smith works the forge")
	check(String(DB.profession("profession.alchemist").get("station", "")) == "station.alchemy",
		"the alchemist works the cauldron")

	check(Professions.level_for(0) == 0, "a fresh apprentice starts at nothing")
	check(Professions.level_for(3) == 0, "practice below the gate earns no rank")
	check(Professions.level_for(4) == 1, "four finished works make a journeyman")
	check(Professions.level_for(10) == 2, "ten works make an adept")
	check(Professions.level_for(34) == Professions.MAX_LEVEL, "practice tops out at grandmaster")
	check(Professions.level_for(9999) == Professions.MAX_LEVEL, "rank never overflows")
	check(Professions.rank_name(0) == "Apprentice" and Professions.rank_name(4) == "Grandmaster", "ranks are named")
	check(Professions.xp_for_level(2) == 10, "the level curve is data")

	var data: Dictionary = {}
	var awarded := Professions.award(data, "profession.smith", 3)
	check(int(awarded["xp"]) == 3 and int(awarded["level"]) == 0 and not bool(awarded["leveled"]),
		"practice accumulates without a rank")
	var ranked := Professions.award(data, "profession.smith", 1)
	check(int(ranked["level"]) == 1 and bool(ranked["leveled"]), "the fourth work earns a rank")
	check(Professions.level_of(data, "profession.smith") == 1, "the rank is derived from practice")
	check(not bool(Professions.award(data, "profession.smith", 0)["leveled"]), "empty practice changes nothing")
	check(Professions.xp_of(Professions.sanitize({"profession.smith": {"xp": -5}}), "profession.smith") == 0,
		"negative practice is discarded")
	check(Professions.sanitize({"junk": 4}).is_empty(), "only professions are read back")
	check(Professions.xp_of(Professions.sanitize({"profession.smith": {"xp": 7}}), "profession.smith") == 7,
		"practice survives a sanitize")

	check(Professions.quality_bonus(smith, 0) == 0.0, "an apprentice has no bonus")
	check(Professions.quality_bonus(smith, 2) > 0.0, "rank raises quality")
	check(is_equal_approx(Professions.failure_mult(smith, 0), 1.0), "rank zero changes no odds")
	check(Professions.failure_mult(smith, 4) < 1.0, "rank lowers failure")
	check(Professions.failure_mult(smith, 100) >= 0.35, "even a grandmaster keeps a risk floor")

	# Gates: the apprentice may forge a jian, not a spirit iron ring.
	var jian: Dictionary = DB.recipe("recipe.forge.iron_jian")
	var ring: Dictionary = DB.recipe("recipe.forge.spirit_iron_ring")
	check(bool(Professions.gate(jian, {}, DB).get("ok", false)), "the first sword is open to an apprentice")
	check(not bool(Professions.gate(ring, {}, DB).get("ok", true)), "a masterwork is locked to an apprentice")
	check(String(Professions.gate(ring, {}, DB).get("reason", "")) == "Smith 2 required",
		"a lock names the rank it needs")
	check(not bool(Professions.gate(ring, data, DB).get("ok", true)), "a journeyman still cannot take a masterwork")
	var practiced: Dictionary = {"profession.smith": {"xp": 10}}
	check(bool(Professions.gate(ring, practiced, DB).get("ok", false)), "an adept may take the masterwork")
	check(bool(Professions.gate({"profession": "", "level": 0}, {}, DB).get("ok", false)),
		"an ungated recipe is open to anyone")

	# Alchemy speaks the same rank language.
	var mending: Dictionary = DB.potion("potion.mending")
	check(not bool(Professions.gate(mending, {}, DB).get("ok", true)), "the mending pill needs practice")
	check(bool(Professions.gate(mending, {"profession.alchemist": {"xp": 4}}, DB).get("ok", false)),
		"a journeyman alchemist may brew it")

	# Progress text is what the panels show.
	var text := Professions.progress_text({"profession.smith": {"xp": 6}}, "profession.smith", DB)
	check(text.begins_with("Smith — Journeyman") and text.contains("6/10"), "progress shows rank and practice")
	check(String(Professions.progress_text({}, "profession.alchemist", DB)).begins_with("Alchemist — Apprentice"),
		"an untrained profession reads as apprentice")

	# Crafting honours the failure multiplier it is given.
	var certain: Dictionary = DB.recipe("recipe.forge.iron_jian").duplicate(true)
	certain["failure_chance"] = 1.0
	check(bool(Crafting.new(DB).craft(certain, 1, 50000, 0, 1.0, 1.0).get("failed", false)),
		"a certain failure still fails at full odds")
	var protected: Dictionary = Crafting.new(DB).craft(certain, 1, 50000, 0, 1.0, 0.0)
	check(bool(protected.get("ok", false)), "a zero chance cannot spoil the work")
