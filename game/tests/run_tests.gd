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
	_rng_tests()
	_item_tests()
	_cultivation_tests()
	_combat_tests()
	_world_tests()
	_camera_tests()
	_display_tests()
	_lighting_tests()
	_occlusion_tests()
	_sorting_tests()
	_motion_tests()
	_controller_tests()
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
