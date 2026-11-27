class_name DebugActions
extends RefCounted
## Every gameplay verb the debug menu can run, as one catalogue.
##
## Each action is `{group, id, label, run}` where `run` is a Callable returning a
## one-line result for the panel's status bar. Keeping them data (rather than a
## switch inside the panel) is what lets a headless check assert the catalogue is
## complete, unique and runnable without opening a window.
##
## Actions reach the game through the same entry points play uses — `Player`,
## `Game`, `Clock`, and the host's own handlers. It is a shortcut, not a second
## rules layer, so anything that works here would work in play.

const GROUPS: Array[String] = [
	"clock", "player", "cultivation", "combat", "npcs", "world", "economy", "save", "ui", "debug",
]


static func build(main: Node) -> Array:
	var out: Array = []

	# ---------------------------------------------------------------- clock ----
	_add(out, "clock", "clock.hour", "Advance one hour", func() -> String:
		Clock.advance(1.0)
		return _clock_line())
	_add(out, "clock", "clock.day", "Advance one day", func() -> String:
		Clock.advance(24.0)
		return _clock_line())
	_add(out, "clock", "clock.dawn", "Set the hour to 06:00", func() -> String:
		Clock.hour = 6.0
		return _clock_line())
	_add(out, "clock", "clock.night", "Set the hour to 21:00", func() -> String:
		Clock.hour = 21.0
		return _clock_line())

	# --------------------------------------------------------------- player ----
	_add(out, "player", "player.heal", "Fill health", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		player.hp = player.hp_max
		return "hp %.0f/%.0f" % [player.hp, player.hp_max])
	_add(out, "player", "player.hurt", "Halve health", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		player.hp = maxf(1.0, player.hp_max * 0.5)
		return "hp %.0f/%.0f" % [player.hp, player.hp_max])
	_add(out, "player", "player.qi", "Fill Qi", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		player.cultivation.qi = player.cultivation.qi_max(player.stats)
		return "qi %.0f" % player.cultivation.qi)
	_add(out, "player", "player.stones", "Add 1,000 spirit stones", func() -> String:
		Game.spirit_stones += 1000
		return "stones %d" % Game.spirit_stones)
	_add(out, "player", "player.karma", "Add 10 karma", func() -> String:
		Game.karma += 10
		return "karma %d" % Game.karma)
	_add(out, "player", "player.notoriety", "Add 10 notoriety", func() -> String:
		Game.notoriety = clampi(Game.notoriety + 10, 0, Captivity.notoriety_cap())
		return "notoriety %d" % Game.notoriety)
	_add(out, "player", "player.age", "Age the body ten years", func() -> String:
		Game.born_day -= int(round(10.0 * Aging.DAYS_PER_YEAR))
		return "age %.1f" % Aging.age_for(Game.born_day, Clock.day))

	# ---------------------------------------------------------- cultivation ----
	_add(out, "cultivation", "cultivation.breakthrough", "Attempt a breakthrough", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		var result: Dictionary = player.attempt_breakthrough()
		var reason := String(result.get("reason", ""))
		if reason != "":
			return "refused: %s" % reason
		return "realm %d" % player.cultivation.realm)
	_add(out, "cultivation", "cultivation.technique", "Learn a technique", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		if not player.learn_technique("tech.sword.azure_cleave"):
			return "already known"
		return "techniques %d" % player.technique_ids.size())
	_add(out, "cultivation", "cultivation.comprehension", "Gain 30 comprehension", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		var learned: bool = player.gain_comprehension(30.0)
		return "epiphany" if learned else "comprehension +30")
	_add(out, "cultivation", "cultivation.physique", "Inherit a sword-bone body", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		if not player.inherit_physique("physique.sword_bone"):
			return "not an upgrade"
		return Physiques.name_of(player.physique_id))
	_add(out, "cultivation", "cultivation.passive", "Grant Iron Bone", func() -> String:
		var player := _player(main)
		if player == null:
			return "no run"
		if not player.add_passive("passive.iron_bone"):
			return "already known"
		return "passives %d" % player.active_passives().size())

	# --------------------------------------------------------------- combat ----
	_add(out, "combat", "combat.spawn", "Spawn a wild spirit beast", func() -> String:
		if main == null:
			return "no run"
		main._spawn_wild_dummy()
		return "spawned near the player")
	_add(out, "combat", "combat.kill", "Count a kill", func() -> String:
		Game.kills += 1
		return "kills %d" % Game.kills)
	_add(out, "combat", "combat.tribulation", "Force a tribulation", func() -> String:
		if main == null:
			return "no run"
		if main.tribulation_arena != null:
			return "already facing heaven"
		main._start_tribulation()
		return "the arena opened")

	# ----------------------------------------------------------------- npcs ----
	_add(out, "npcs", "npcs.recruit", "Recruit the nearest person", func() -> String:
		if main == null:
			return "no run"
		main._toggle_party()
		return "party %d" % Game.party_ids.size())
	_add(out, "npcs", "npcs.bond", "Make the nearest person a friend", func() -> String:
		if main == null:
			return "no run"
		var npc: Variant = main.nearest_npc()
		if npc == null:
			return "nobody near"
		Game.npc_memory[npc.npc_id] = {
			"met": true, "talks": 8, "last_day": Clock.day, "regard": 30,
		}
		return "%s is a friend" % npc.display_name)
	_add(out, "npcs", "npcs.forget", "Clear NPC memory", func() -> String:
		var count: int = Game.npc_memory.size()
		Game.npc_memory.clear()
		return "forgot %d people" % count)

	# ---------------------------------------------------------------- world ----
	_add(out, "world", "world.weather", "Reroll the weather", func() -> String:
		Weather.refresh(true)
		return Weather.label())
	_add(out, "world", "world.travel", "Fast travel to the first route", func() -> String:
		if main == null:
			return "no run"
		if main.travel_destinations().is_empty():
			return "no routes known"
		main._travel_to(0)
		return "travelled")
	_add(out, "world", "world.resync", "Rebuild the streamed province", func() -> String:
		if main == null:
			return "no run"
		main.chunks.resync(_player(main).global_position)
		return "chunks %d" % int(main.chunks.streamed_chunks))
	_add(out, "world", "world.realm", "Enter a hidden realm", func() -> String:
		if main == null:
			return "no run"
		if main.realm_instance != null:
			return "already inside"
		main._enter_realm()
		return "entered" if main.realm_instance != null else "no site known")
	_add(out, "world", "world.inheritance", "Claim the altar you stand at", func() -> String:
		if main == null:
			return "no run"
		if main.realm_instance == null:
			return "not in a hidden realm"
		main._claim_inheritance()
		return "the altar answered" if not main.inheritance_trial.is_empty() else "no offer")

	# -------------------------------------------------------------- economy ----
	_add(out, "economy", "economy.contribution", "Add 50 sect contribution", func() -> String:
		Game.sect_contribution += 50
		return "contribution %d" % Game.sect_contribution)

	# ----------------------------------------------------------------- save ----
	_add(out, "save", "save.write", "Save slot 1", func() -> String:
		if main == null:
			return "no run"
		main._save(1)
		return "saved slot 1")
	_add(out, "save", "save.read", "Load slot 1", func() -> String:
		if main == null:
			return "no run"
		main._load_game(1)
		return "loaded slot 1")

	# ------------------------------------------------------------------- ui ----
	_add_ui(out, main, "ui.character", "Open the character sheet", "_open_character")
	_add_ui(out, main, "ui.shop", "Open the shop", "_open_shop")
	_add_ui(out, main, "ui.storage", "Open the storehouse", "_open_storage")
	_add_ui(out, main, "ui.forge", "Open the forge", "_open_forge")
	_add_ui(out, main, "ui.alchemy", "Open alchemy", "_open_alchemy")
	_add_ui(out, main, "ui.settings", "Open settings", "toggle_settings")
	_add_ui(out, main, "ui.travel", "Open fast travel", "_open_travel")
	_add_ui(out, main, "ui.map", "Open the province map", "toggle_map")
	_add_ui(out, main, "ui.bars", "Open the skill bars", "toggle_bars")
	_add_ui(out, main, "ui.gear", "Open equipment", "toggle_gear")
	_add_ui(out, main, "ui.chronicle", "Open the market chronicle", "toggle_chronicle")
	_add_ui(out, main, "ui.factions", "Open faction standings", "toggle_factions")
	_add_ui(out, main, "ui.sects", "Open the sect codex", "toggle_sects")
	_add_ui(out, main, "ui.hierarchy", "Open the hall hierarchy", "toggle_hierarchy")
	_add_ui(out, main, "ui.ledger", "Open the sect ledger", "toggle_sect_ledger")
	_add_ui(out, main, "ui.council", "Open the council", "toggle_council")
	_add_ui(out, main, "ui.player_sect", "Open your own sect", "toggle_player_sect")
	_add_ui(out, main, "ui.storylines", "Open sect storylines", "toggle_storylines")
	_add_ui(out, main, "ui.narrative", "Open the narrative archive", "toggle_narrative")
	_add_ui(out, main, "ui.endgame", "Open the ending page", "toggle_endgame")
	_add_ui(out, main, "ui.captives", "Open the holding yard", "toggle_captives")

	# ---------------------------------------------------------------- debug ----
	_add(out, "debug", "debug.selftest", "Run the in-game self-check", func() -> String:
		return self_check(main))

	return out


## Read-only invariants that should hold in any live run. Not the test suites: a
## quick answer to "is this build sane right now", recorded in the log so a report
## carries it.
static func self_check(main: Node) -> String:
	var stats := {"total": 0, "failed": []}
	var player := _player(main)
	_expect(stats, player != null, "a player exists")
	_expect(stats, DB.techniques.size() > 0, "techniques loaded")
	_expect(stats, DB.realms.size() > 0, "realms loaded")
	_expect(stats, Clock.day >= 1, "the calendar is past day zero")
	_expect(stats, Log.entries.size() > 0, "the log has entries")
	if player != null:
		_expect(stats, player.hp > 0.0 and player.hp <= player.hp_max, "health is in range")
		_expect(stats, player.cultivation.qi >= 0.0, "qi is not negative")
		_expect(stats, player.cultivation.realm >= 1 and player.cultivation.realm <= Realms.count(),
			"the realm is on the ladder")
		_expect(stats, player.global_position.is_finite(), "the body has a position")
	if main != null:
		var npcs: Variant = main.get("npcs")
		_expect(stats, typeof(npcs) == TYPE_ARRAY and (npcs as Array).size() > 0, "the town exists")
	var failed: Array = stats["failed"]
	var line := "%d/%d checks pass" % [int(stats["total"]) - failed.size(), int(stats["total"])]
	if not failed.is_empty():
		line += " · failed: %s" % ", ".join(failed)
	Log.info("debug", "self-check: " + line)
	return line


static func _expect(stats: Dictionary, condition: bool, label: String) -> void:
	stats["total"] = int(stats["total"]) + 1
	if not condition:
		(stats["failed"] as Array).append(label)


static func _add(out: Array, group: String, id: String, label: String, run: Callable) -> void:
	out.append({"group": group, "id": id, "label": label, "run": run})


## UI actions are the host's own toggles. A missing handler is reported as an
## action that cannot run, rather than crashing the panel.
static func _add_ui(out: Array, main: Node, id: String, label: String, method: String) -> void:
	_add(out, "ui", id, label, func() -> String:
		if main == null or not main.has_method(method):
			return "no handler for %s" % method
		main.call(method)
		return "%s opened" % label.to_lower())


static func _player(main: Node) -> Node:
	if main == null:
		return null
	var player: Variant = main.get("player")
	return player if player is Node else null


static func _clock_line() -> String:
	return "Day %d, %02d:%02d" % [Clock.day, int(Clock.hour), int(fmod(Clock.hour, 1.0) * 60.0)]
