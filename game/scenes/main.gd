extends Node2D
## Scene root.
##
## Owns the run: the province streamer, the settlement and its scheduled NPCs,
## the Azure Cloud questline state, the hidden realm transition, loot, and
## save/load. The player node owns only the player.

const SPAWN := Vector2(5632, 5632)
const FORMATION_POINTS := 6
const WILD_DUMMY_TARGET := 4
const RESPAWN_INTERVAL := 8.0
## Share of wild spawns that are spirit beasts rather than humanoid cultivators.
const BEAST_SHARE := 0.45
## Share of wild humanoids that turn up as elites. Drawn from its own stream, so
## tuning the share cannot reshuffle the spawns themselves.
const ELITE_SHARE := 0.12

var phase := "creation"  # creation | play | realm
## Character creation is two screens: formation points, then identity.
var creation_stage := 0
var player: Player
var hud: Hud
## Floating damage numbers live in the world layer so they sit over bodies.
var damage_numbers: DamageNumbers
## Combat sound. Streams are synthesized; the pool is played from bus signals.
var combat_audio: CombatAudio
var chunks: ChunkManager
var settlement: Settlement
var npcs: Array = []
var elder: Npc
## Y-sorted layer: props, buildings, NPCs, the player and enemies all share it
## so draw order follows world Y instead of node creation order.
var world: Node2D
var camera_rig: CameraRig
var lighting: WorldLighting
## Continent geography, derived from the seed and never saved.
var continent: Dictionary = {}
var world_map: WorldMap
## Settlement services: the merchant's stock and the shop overlay.
var merchant := Merchant.new()
var shop_panel: ShopPanel
var shop_open := false
var _shop_mode := "buy"
var _sell_base := 0
## Navigation: known destinations, the travel overlay and the current waypoint.
var travel_panel: TravelPanel
var travel_open := false
var travel_index := 0
## Skill bar arrangement overlay. It freezes play like the map, so a drag can
## never be mistaken for an attack.
var skill_bar_panel: SkillBarPanel
var bars_open := false
## Gear overlay: worn slots, satchel candidates and a stat-by-stat comparison.
## It freezes play, so choosing a ring is never mistaken for a swing.
var gear_open := false
var gear_index := 0
## Storehouse screen: the satchel and the settlement's shelves, with the cursor
## on one side. It freezes play for the same reason the satchel does.
var storage := Storage.new()
var storage_open := false
var storage_side := 0
var storage_index := 0
## Forge screen: recipes, refinement and breaking gear down. Three modes, one
## cursor, frozen play so a swing never falls on the anvil.
var crafting: Crafting
var forge_open := false
var forge_mode := 0
var forge_index := 0
const FORGE_MODES: Array[String] = ["forge", "refine", "disassemble"]
## Alchemy: one cauldron, one list of potions, frozen play for the same reason.
var alchemy: Alchemy
var alchemy_open := false
var alchemy_index := 0
var waypoint_name := ""
var waypoint_position := Vector2.ZERO
## Discovered sites, recorded with a position so they stay travel destinations
## after their chunk unloads.
var travel_sites: Dictionary = {}
## Off-screen simulation: NPCs sleep beyond this distance, and changes they lived
## through wait in a short report shown when the player is back in the settlement.
const NPC_SIM_RADIUS := 1500.0
## How often the settlement looks for trouble. A quarter second is well under a
## frame of walking, and it keeps a crowd of residents off the enemy list.
const NPC_ALERT_TICK := 0.25
## How far a resident who likes the player will call a warning to them, and how
## long before the same town warns them again. Friendship is not a siren.
const WARN_RADIUS := 420.0
const WARN_COOLDOWN := 20.0
var _npc_seen: Dictionary = {}
var _alert_timer := 0.0
var _warn_timer := 0.0
## Stable id → the display name it was spawned with, so authored ties can be
## named the way the player sees them.
var _npc_names: Dictionary = {}
## Captivity ledger: a frozen, row-selected screen of the holding yard.
var captives_open := false
var captive_index := 0
## Last world day settled for the holding yard. A jump in days (inn, travel, a
## loaded clock) is paid a day at a time instead of skipped.
var _captive_day := 0
## Last world day the town's cultivation was re-derived for. Progression is a
## pure function of the day, so this only avoids repeating the refresh.
var _progress_day := 0
## Last world day the chronicle was brought up to. Skipped days still get their
## small news, a day at a time.
var _story_day := 0
## The chronicle screen: the market's recent news and the requests it carries.
var chronicle_open := false
## The faction screen: who stands where with whom, and what that buys.
var factions_open := false
## The sect codex: twelve houses, their seats, economies, fault lines and arts.
var sects_open := false
## The sect hierarchy: the ladder, who holds each rung, and where the player stands.
var hierarchy_open := false
## The sect ledger: stipend, donations and the quartermaster's shelf.
var sect_ledger_open := false
var sect_ledger_index := 0
## The council: three blocs, their support, and the vote on the master's seat.
var council_open := false
var council_index := 0
## The player's own hall: founding, roster and the daily levy.
var player_sect_open := false
var player_sect_index := 0
var _away_notes: Array = []
var _wilds_recovered := 0
var interactables: Array = []
var ground_items: Array = []
var quests: QuestLog
var realm_instance: HiddenRealm = null
## The active playable tribulation, if any. Never saved: a load abandons it.
var tribulation_arena: TribulationArena = null
var realm_seed := 0
var realm_cleared := false
## Legacy tomb flag. Per-site claims live in `inheritances_taken`.
var inheritance_taken := false
var inheritances_taken: Dictionary = {}
## The altar trial in progress: site, offered entry, time left and echo bodies.
var inheritance_trial: Dictionary = {}
var inheritance_trial_nodes: Array = []
## The overworld rifts are only visible once their site is discovered.
var realm_portals: Dictionary = {}
var realm_portal_positions: Dictionary = {}
## The default portal is kept as a named handle for tests and older code paths.
var realm_portal: Interactable = null
var active_realm_id := ""
var active_realm_seed := 0
var _realm_access_day := -1
## One rumor per day is enough; the flag is session state, not a save key.
var _realm_rumor_day := -1
## Bosses already killed this save, by stable id. The tomb's warden is only
## spawned when its id is absent, which is what makes a cleared tomb stay clear.
var bosses_slain: Dictionary = {}
var portal_position := Vector2.ZERO
var used_interactables: Array = []
## Per-chunk state the seed cannot reproduce: harvested resources and their day.
var world_delta := WorldDelta.new()

var _allocation_spent := 0
var _allocation_history: Array = []
var _root_rng: RandomNumberGenerator
var _name_rng: RandomNumberGenerator
var _used_names: Dictionary = {}
var _spawn_timer := 0.0
var _help_visible := true
var _hazard_accum := 0.0
var _npc_index := 0
var _root_rolls := 0
var _physique_rolls := 0


func _ready() -> void:
	Game.new_run()
	crafting = Crafting.new(DB)
	alchemy = Alchemy.new(DB)
	continent = Continent.generate(Game.world_seed)
	DisplayPolicy.apply(get_window())
	get_window().size_changed.connect(_on_window_resized)
	_root_rng = Rng.stream("root_roll", 0)
	_name_rng = Rng.stream("npc_names", 0)
	quests = QuestLog.new()
	_build_world()
	_spawn_player()
	_build_hud()
	_build_feedback()
	Bus.enemy_died.connect(_on_enemy_died)
	Bus.elite_died.connect(_on_elite_died)
	Bus.beast_slain.connect(_on_beast_slain)
	Bus.boss_phase_changed.connect(_on_boss_phase_changed)
	Bus.boss_defeated.connect(_on_boss_defeated)
	Bus.tribulation_finished.connect(_on_tribulation_finished)
	Weather.changed.connect(_on_weather_changed)
	Bus.toast.emit("A new path opens. Assign your attributes, then press ENTER.")


# ---------------------------------------------------------------- world ----

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	lighting = WorldLighting.new()
	lighting.name = "Lighting"
	add_child(lighting)

	# Ground layers sort below everything by z_index; the Y-sort only orders
	# things that stand on the ground.
	chunks = ChunkManager.new()
	chunks.name = "Province"
	chunks.z_index = -20
	world.add_child(chunks)
	# Payloads generate on worker threads; nodes are still built here.
	chunks.threaded = true
	chunks.delta = world_delta
	chunks.biome_defs = DB.biome_table()
	chunks.set_resource_parent(world)
	chunks.on_resource_spawned = func(node: Interactable) -> void: interactables.append(node)
	chunks.on_resource_freed = func(node: Interactable) -> void: interactables.erase(node)
	chunks.regrown.connect(_on_wilds_regrown)
	chunks.configure(Game.world_seed)
	chunks.set_prop_parent(world)
	chunks.stream_around(SPAWN)
	# The first frame must show ground, not a hole: wait for the initial ring.
	chunks.settle()

	settlement = Settlement.new()
	settlement.name = "AzureCloudMarket"
	settlement.position = SPAWN
	settlement.z_index = -15
	world.add_child(settlement)
	settlement.build_buildings(world)

	_spawn_npcs()
	_spawn_interactables()


func _spawn_player() -> void:
	player = Player.new()
	player.position = SPAWN + Vector2(0, 60)
	world.add_child(player)
	player.display_name = _random_name()
	player.cultivation.root_tier = _roll_root()
	player.cultivation.purity_bonus = _roll_purity()
	player.cultivation.identified = false
	player.physique_id = Physiques.roll(_physique_rolls)
	player.spawn_point = player.position

	camera_rig = CameraRig.new()
	camera_rig.name = "Camera"
	camera_rig.set_bounds(ChunkManager.world_bounds())
	player.add_child(camera_rig)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = Hud.new()
	hud.host = self
	layer.add_child(hud)
	world_map = WorldMap.new()
	layer.add_child(world_map)
	world_map.setup(continent, Continent.region_for_world_position(player.global_position), _realm_map_marks())
	shop_panel = ShopPanel.new()
	layer.add_child(shop_panel)
	travel_panel = TravelPanel.new()
	layer.add_child(travel_panel)
	skill_bar_panel = SkillBarPanel.new()
	layer.add_child(skill_bar_panel)


## Combat feedback nodes. Both listen on the bus, so no combat code knows they
## exist and either can be removed without changing a rule.
func _build_feedback() -> void:
	damage_numbers = DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	world.add_child(damage_numbers)
	combat_audio = CombatAudio.new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)


func _spawn_npcs() -> void:
	_npc_names.clear()
	var schedules: Dictionary = DB.schedules()
	elder = _make_npc("elder_bai", "Elder Bai Qing", "Elder", "sect.azure_cloud",
		4, schedules.get("elder", []), Vector2(-30, 40), "elder")
	_make_npc("instructor_rui", "Instructor Rui", "Sword Instructor", "sect.azure_cloud",
		3, schedules.get("disciple", []), Vector2(64, 120), "inner_disciple")

	var plan := [
		["sect_master", 1],
		["inner_disciple", 5],
		["outer_disciple", 6],
		["merchant", 2],
		["guard", 2],
		["farmer", 2],
	]
	for entry in plan:
		var archetype := _archetype(String(entry[0]))
		if archetype.is_empty():
			continue
		var count := int(entry[1])
		for i in count:
			var offset := Vector2(_name_rng.randf_range(-140.0, 140.0), _name_rng.randf_range(-100.0, 160.0))
			_make_npc(
				"npc.%s.%d" % [String(entry[0]), _npc_index],
				_random_name(),
				String(archetype.get("role", "Wanderer")),
				String(archetype.get("sect", "")),
				int(archetype.get("realm", 1)),
				schedules.get(String(archetype.get("schedule", "disciple")), []),
				offset,
				String(entry[0])
			)
	_sync_party()


func _archetype(id: String) -> Dictionary:
	for archetype in DB.archetypes():
		if String(archetype.get("id", "")) == id:
			return archetype
	return {}


## One generated record per body: the archetype names the pools, NpcDb rolls the
## person, and the node carries the result. `archetype_id` is kept explicit so
## an authored character can outrank or differ from its template.
func _make_npc(id: String, display: String, role: String, sect: String, realm: int,
		schedule: Array, offset: Vector2, archetype_id: String = "") -> Npc:
	var archetype := _archetype(archetype_id)
	if archetype.is_empty():
		archetype = _archetype("outer_disciple")
	var npc := Npc.new()
	npc.name = "Npc_" + id
	var sheet := NpcDb.sheet(archetype, id, realm)
	npc.setup(id, display, role, sect, realm, schedule, settlement, sheet)
	npc.rest_schedule = DB.schedules().get(String(archetype.get("rest_schedule", "")), [])
	npc.apply_ai(archetype.get("ai", {}))
	world.add_child(npc)
	npc.global_position = settlement.position_for("plaza") + offset
	npcs.append(npc)
	_npc_names[id] = display
	_npc_index += 1
	return npc


## A stable id as the player would say it. Unknown ids fall back to words, so a
## tie to a resident who is not spawned still reads.
func person_name(id: String) -> String:
	if id == Relationships.PLAYER_ID:
		return "you"
	if _npc_names.has(id):
		return String(_npc_names[id])
	return id.replace("_", " ").capitalize()


## The authored ties of one resident, named through the people actually spawned.
func npc_tie_line(npc: Npc) -> String:
	if npc == null:
		return ""
	var parts: Array[String] = []
	for value in Relationships.ties_of(npc.npc_id):
		var entry: Dictionary = value
		parts.append(String(entry.get("phrase", "Linked to %s")) % person_name(String(entry.get("to", ""))))
	if parts.is_empty():
		return ""
	return "Bonds: " + ", ".join(parts)


func _random_name() -> String:
	var surnames: Array = DB.npc_data.get("surnames", ["Bai"])
	var given: Array = DB.npc_data.get("given", ["Qing"])
	for attempt in 60:
		var surname := String(surnames[_name_rng.randi_range(0, surnames.size() - 1)])
		var personal := String(given[_name_rng.randi_range(0, given.size() - 1)])
		var full := "%s %s" % [surname, personal]
		if not _used_names.has(full):
			_used_names[full] = true
			return full
	return "Wanderer %d" % _used_names.size()


func _spawn_interactables() -> void:
	var shrine := Interactable.new()
	shrine.setup(Interactable.Kind.SHRINE, "shrine.azure", "Azure Cloud Shrine — attune")
	shrine.position = settlement.position_for("shrine")
	world.add_child(shrine)
	interactables.append(shrine)

	# The scorched circle where a peak cultivator banks preparations. Placed
	# beside the shrine so the two tribulation-facing services sit together.
	var tribulation_ground := Interactable.new()
	tribulation_ground.setup_tribulation("tribulation.ground", "Tribulation ground")
	tribulation_ground.position = settlement.position_for("shrine") + Vector2(72, 18)
	world.add_child(tribulation_ground)
	interactables.append(tribulation_ground)

	for i in 3:
		var herb := Interactable.new()
		herb.setup(Interactable.Kind.HERB, "herb.%d" % i, "Spirit Herb")
		herb.position = settlement.position_for("herb_garden") + Vector2(-40.0 + float(i) * 40.0, 0.0)
		world.add_child(herb)
		interactables.append(herb)

	for site in RealmAccess.sites():
		var site_id := String(site.get("id", ""))
		var portal_pos := RealmAccess.world_position(site, SPAWN)
		var portal := Interactable.new()
		portal.setup(Interactable.Kind.PORTAL, site_id, RealmAccess.portal_label(site, Clock.day))
		portal.position = portal_pos
		portal.visible = realm_known(site_id)
		world.add_child(portal)
		interactables.append(portal)
		realm_portals[site_id] = portal
		realm_portal_positions[site_id] = portal_pos
		if site_id == RealmAccess.default_id():
			realm_portal = portal
			portal_position = portal_pos
		var family := HiddenRealms.family(String(site.get("family", "")))
		lighting.add_light(world, portal_pos, Color(String(family.get("light_color", "#b48cff"))), 260.0, 1.0)

	# Night lighting: the shrine and the rifts stay readable after dusk.
	lighting.add_light(world, shrine.position, Color("#ffd9a0"), 220.0, 0.9)

	# A door for every building, at the doorway the building draws.
	for spec in Settlement.BUILDINGS:
		var location := String(spec["location"])
		var building := settlement.building_for(location)
		if building == null:
			continue
		var door := Interactable.new()
		door.setup_door("door.%s" % location, "%s door" % location.capitalize(), building)
		door.position = building.global_position + Vector2(0, (spec["size"] as Vector2).y * 0.5 + 8.0)
		world.add_child(door)
		interactables.append(door)

	# Containers: one-shot loot, deterministic from their stable id.
	var crate_spots := [
		["crate.market.0", "Market crate", "market", Vector2(-58, 44)],
		["crate.tavern.0", "Tavern crate", "tavern", Vector2(52, 48)],
		["crate.dorms.0", "Dormitory chest", "dorms", Vector2(0, 54)],
	]
	for spot in crate_spots:
		var crate := Interactable.new()
		crate.setup_container(String(spot[0]), String(spot[1]), hash(String(spot[0])))
		crate.position = settlement.position_for(String(spot[2])) + (spot[3] as Vector2)
		world.add_child(crate)
		interactables.append(crate)

	# The storehouse: a second container with a limit, kept by the market so a
	# heavy satchel is a walk away rather than a permanent loss.
	var storehouse := Interactable.new()
	storehouse.setup(Interactable.Kind.STORAGE, "storage.market", "Storehouse — deposit or withdraw")
	storehouse.position = settlement.position_for("market") + Vector2(46, 62)
	world.add_child(storehouse)
	interactables.append(storehouse)

	# The forge: recipes, refining and breaking gear down, at the smithy door.
	var forge := Interactable.new()
	forge.setup(Interactable.Kind.FORGE, "forge.azure", "Azure Forge — craft or refine")
	forge.position = settlement.position_for("forge") + Vector2(0, 62)
	world.add_child(forge)
	interactables.append(forge)

	# The cauldron: herbs and cores in, pills out, beside the herb garden.
	var cauldron := Interactable.new()
	cauldron.setup(Interactable.Kind.ALCHEMY, "alchemy.cauldron", "Herb-Garden Cauldron — brew")
	cauldron.position = settlement.position_for("herb_garden") + Vector2(0, 56)
	world.add_child(cauldron)
	interactables.append(cauldron)

	# A manual teaches a technique that is otherwise hidden from character start.
	var manual := Interactable.new()
	manual.setup_manual("manual.crimson_moon", "Forbidden manual — Crimson Moon Devour", "tech.blood.crimson_moon")
	manual.position = settlement.position_for("sect_hall") + Vector2(-46, 12)
	world.add_child(manual)
	interactables.append(manual)

	# Meridian hall: opens the next channel the body can bear, for Qi and stones.
	var meridian_hall := Interactable.new()
	meridian_hall.setup_meridian_hall("meridian.hall", "Meridian hall")
	meridian_hall.position = settlement.position_for("shrine") + Vector2(-72, 36)
	world.add_child(meridian_hall)
	interactables.append(meridian_hall)

	# Method stele: reshapes your circulation for a price, gated on requirements.
	var method_stele := Interactable.new()
	method_stele.setup_method("method.stele", "Method stele")
	method_stele.position = settlement.position_for("shrine") + Vector2(112, -26)
	world.add_child(method_stele)
	interactables.append(method_stele)

	# A disciple practising a technique nobody wrote down: watch and learn.
	var demonstration := Interactable.new()
	demonstration.setup_demonstration("training.falling_petal", "Practising disciple — Falling Petal Cut",
		"tech.sword.falling_petal")
	demonstration.position = settlement.position_for("plaza") + Vector2(-58, 148)
	world.add_child(demonstration)
	interactables.append(demonstration)

	# Passive manuals: voluntary learning, gated by what the body can use.
	var manual_specs := [
		["manual.jade_skin", "Body-Refining Manual — Jade Skin", "passive.jade_skin", Vector2(40, 54)],
		["manual.battle_trance", "Blood-Refining Manual — Battle Trance", "passive.battle_trance", Vector2(86, 40)],
		["manual.flowing_water", "Water-Step Manual — Flowing Water", "passive.flowing_water", Vector2(-18, 88)],
	]
	for spec in manual_specs:
		var passive_manual := Interactable.new()
		passive_manual.setup_passive_manual(String(spec[0]), String(spec[1]), String(spec[2]))
		passive_manual.position = settlement.position_for("shrine") + (spec[3] as Vector2)
		world.add_child(passive_manual)
		interactables.append(passive_manual)

	# Examination: scenery that rewards looking, repeatable and inconsumable.
	var stele := Interactable.new()
	stele.setup_examine("stele.azure", "Azure Cloud stele",
		"The stele reads: the sect was founded on a promise to teach the rootless. The lower names are worn away.")
	stele.position = settlement.position_for("shrine") + Vector2(64, 18)
	world.add_child(stele)
	interactables.append(stele)

	# Root appraisal and evolution, beside the shrine that reads meridians.
	var pavilion := Interactable.new()
	pavilion.setup(Interactable.Kind.ROOT, "root.pavilion", "Root-Reading Pavilion — appraise or evolve")
	pavilion.position = settlement.position_for("shrine") + Vector2(-84, 62)
	world.add_child(pavilion)
	interactables.append(pavilion)

	var board := Interactable.new()
	board.setup_examine("board.market", "Market notice board",
		"Notices: a bounty on marsh boars, a lost jade comb, and a warning not to enter the eastern rift.")
	board.position = settlement.position_for("market") + Vector2(-96, -18)
	world.add_child(board)
	interactables.append(board)

	# Settlement services: a merchant stall and an inn counter.
	var stall := Interactable.new()
	stall.setup(Interactable.Kind.SHOP, "shop.market", "Merchant stall — trade")
	stall.position = settlement.position_for("market") + Vector2(74, 42)
	world.add_child(stall)
	interactables.append(stall)

	var inn := Interactable.new()
	inn.setup(Interactable.Kind.INN, "inn.tavern", "Inn counter — rest")
	inn.position = settlement.position_for("tavern") + Vector2(-74, 46)
	world.add_child(inn)
	interactables.append(inn)


func _roll_purity() -> float:
	_root_rolls += 1
	return Roots.roll_purity_bonus(_root_rolls)


func _roll_root() -> int:
	var weights: Array = []
	for root in DB.roots:
		weights.append(int(root.get("weight", 1)))
	var index: int = int(Rng.pick_weighted(weights, _root_rng))
	if index < 0:
		return 3
	return int(DB.roots[index].get("tier", 3))


# ----------------------------------------------------------- creation ----

func allocation_remaining() -> int:
	return FORMATION_POINTS - _allocation_spent


func allocate_attribute(key: String) -> bool:
	if phase != "creation" or allocation_remaining() <= 0:
		return false
	if not Attributes.KEYS.has(key):
		return false
	player.attrs.add(key, 1)
	_allocation_spent += 1
	_allocation_history.append(key)
	player.rebuild_stats()
	player.hp = player.hp_max
	Bus.player_stats_changed.emit()
	return true


func refund_attribute() -> bool:
	if phase != "creation" or _allocation_history.is_empty():
		return false
	var key: String = _allocation_history.pop_back()
	player.attrs.add(key, -1)
	_allocation_spent -= 1
	player.rebuild_stats()
	player.hp = player.hp_max
	Bus.player_stats_changed.emit()
	return true


func _begin_run() -> void:
	_apply_origin()
	Game.born_day = Clock.day
	_captive_day = Clock.day
	_progress_day = Clock.day
	_story_day = Clock.day
	_realm_access_day = -1
	_realm_rumor_day = -1
	Game.dead = false
	Game.age_warning_stage = 0
	_run_ended = false
	player.set_physics_process(true)
	player.set_process(true)
	phase = "play"
	player.rebuild_stats()
	player.hp = player.hp_max
	player.spawn_point = settlement.position_for("plaza")
	_sync_realm_portal()
	Bus.toast.emit("Azure Cloud Market. Elder Bai waits by the sect hall.")


# --------------------------------------------------------------- aging ----

var _run_ended := false


## Aging is read from the calendar each frame rather than ticked by a signal, so
## fast travel, inn rest and any direct day jump all count in full.
func _check_aging() -> void:
	if player == null or Game.dead or String(phase) != "play":
		return
	var lifespan := player.stats.lifespan_years()
	var age := Game.age_years()
	var stage := Aging.stage(age, lifespan)
	var rank := Aging.stage_rank(stage)
	if rank > Game.age_warning_stage:
		Game.age_warning_stage = rank
		var warning := Aging.warning_for(stage)
		if warning != "":
			Bus.toast.emit(warning)
			Bus.player_stats_changed.emit()
	if Aging.is_dead(age, lifespan):
		_end_run()


## The body has outlived its years: the run ends and the end screen takes over.
## Idempotent, because both the frame check and a loaded dead save may call it.
func _end_run() -> void:
	if _run_ended:
		return
	_run_ended = true
	phase = "ended"
	Game.dead = true
	Game.running = false
	if player != null:
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process(false)
	if tribulation_arena != null:
		tribulation_arena.queue_free()
		tribulation_arena = null
	Bus.cultivation_changed.emit()
	Bus.player_stats_changed.emit()
	Bus.toast.emit("Your years are spent. The dao releases you.")


func creation_origins() -> Array:
	return DB.origins


func selected_origin() -> Dictionary:
	var origin: Dictionary = DB.origin(Game.origin_id)
	if origin.is_empty() and not DB.origins.is_empty():
		return DB.origins[0]
	return origin


## Starting circumstances: a purse, a starting method and at most one passive.
## Applied once when the run begins; a loaded save already contains the result.
func _apply_origin() -> void:
	var origin: Dictionary = DB.origin(Game.origin_id)
	if origin.is_empty():
		return
	var fx := Origin.effects(origin)
	Game.spirit_stones += int(fx["stones"])
	var method_id := String(fx["method_id"])
	if method_id != "" and DB.has("method", method_id):
		player.cultivation.method_id = method_id
	var passive := String(fx["passive"])
	if passive != "":
		player.add_passive(passive)
	Bus.toast.emit("Origin — %s. %s" % [String(fx["name"]), String(fx["condition"])])


# --------------------------------------------------------------- loop ----

func _process(delta: float) -> void:
	if player == null:
		return
	if String(phase) == "ended":
		return
	_check_aging()
	if String(phase) == "ended":
		return
	_check_captivity()
	_check_sect_autonomy()
	_check_npc_progress()
	_check_stories()
	_check_realm_access()
	# Regional Qi density is derived from where the body stands, never saved.
	if realm_instance != null:
		Game.biome_density = 1.0
	else:
		Game.biome_density = Biome.qi_density(
			DB.biome(Biome.for_chunk(chunks.world_to_chunk(player.global_position), Game.world_seed)))
	# The continent map is a reading screen: it freezes play instead of letting
	# the player walk blind behind an opaque overlay.
	if (world_map != null and world_map.visible) or shop_open or travel_open or bars_open or gear_open \
			or alchemy_open or captives_open or chronicle_open or factions_open or sects_open or hierarchy_open \
			or sect_ledger_open or council_open or player_sect_open:
		return

	_tick_inheritance_trial(delta)
	_simulate_npcs()
	_direct_npcs(delta)
	_flush_away_report()

	if Travel.has_arrived(player.global_position, waypoint_position):
		Bus.toast.emit("You have reached %s." % waypoint_name)
		waypoint_name = ""
		waypoint_position = Vector2.ZERO

	# The province is hidden inside a realm: streaming there would load chunks
	# for tomb coordinates and spawn props under the tomb floor.
	chunks.today = Clock.day
	if realm_instance == null:
		chunks.stream_around(player.global_position)
	if phase == "creation":
		return

	var limit := ChunkManager.CHUNK_SIZE * ChunkManager.PROVINCE_CHUNKS - 40.0
	player.global_position = Vector2(
		clampf(player.global_position.x, 40.0, limit),
		clampf(player.global_position.y, 40.0, limit)
	)

	if phase == "realm":
		if realm_instance != null:
			var dps := realm_instance.hazard_dps_at(player.global_position)
			if dps > 0.0:
				_hazard_accum += dps * delta
				if _hazard_accum >= 5.0:
					# Floor hazards are not dodgeable: evasion is for attacks.
					player.take_hit(_hazard_accum, player.global_position, false)
					_hazard_accum = 0.0
		return

	for i in SkillBar.SLOTS_PER_BAR:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			_select_bar_slot(i)
	if Input.is_action_just_pressed("bar_next"):
		_switch_bar(1)
	elif Input.is_action_just_pressed("bar_prev"):
		_switch_bar(-1)
	# The bar draws six slots; Q walks the whole known list so an art learned
	# later is never stranded off the bar.
	if Input.is_action_just_pressed("cycle_bar"):
		var cycled := player.cycle_technique()
		if cycled != "":
			Bus.toast.emit("Technique: %s (%s)." % [cycled, TechniqueCombat.kind_label(player.current_technique_kind())])
		Bus.cultivation_changed.emit()

	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("party_toggle"):
		_toggle_party()
	if Input.is_action_just_pressed("bind_captive"):
		_bind_captive()
	if Input.is_action_just_pressed("open_captives"):
		toggle_captives()
	if Input.is_action_just_pressed("open_chronicle"):
		toggle_chronicle()
	if Input.is_action_just_pressed("open_factions"):
		toggle_factions()
	if Input.is_action_just_pressed("open_sects"):
		toggle_sects()
	if Input.is_action_just_pressed("open_hierarchy"):
		toggle_hierarchy()
	if Input.is_action_just_pressed("open_ledger"):
		toggle_sect_ledger()
	if Input.is_action_just_pressed("open_council"):
		toggle_council()
	if Input.is_action_just_pressed("open_player_sect"):
		toggle_player_sect()

	_spawn_timer += delta
	if _spawn_timer >= RESPAWN_INTERVAL:
		_spawn_timer = 0.0
		if _wild_dummy_count() < WILD_DUMMY_TARGET:
			_spawn_wild_dummy()


func _wild_dummy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


func _spawn_wild_dummy() -> void:
	var r: RandomNumberGenerator = Rng.stream("wild_dummy", Game.kills + 1, _wild_dummy_count())
	var angle := r.randf_range(0.0, TAU)
	var distance := r.randf_range(420.0, 760.0)
	var spawn := settlement.position_for("plaza") + Vector2(cos(angle), sin(angle)) * distance
	var dummy := Dummy.new()
	dummy.ilvl = maxi(1, player.cultivation.realm)
	dummy.position = spawn
	world.add_child(dummy)
	# The biome at the spawn point decides which creature turns up, not a global table.
	var biome: Dictionary = DB.biome(Biome.for_chunk(chunks.world_to_chunk(spawn), Game.world_seed))
	# Two streams: whether a beast turns up is decided by its own stream, so the
	# weighted species roll below cannot shift when the share is tuned.
	var share: RandomNumberGenerator = Rng.stream("wild_beast", Game.kills + 1, _wild_dummy_count())
	var elite_share: RandomNumberGenerator = Rng.stream("wild_elite", Game.kills + 1, _wild_dummy_count())
	var species := Beasts.roll(DB.spirit_beasts, String(biome.get("id", "")), r)
	if not species.is_empty() and share.randf() < BEAST_SHARE:
		dummy.become_beast(species, player.cultivation.realm)
	else:
		var enemy := Biome.pick_enemy(biome, r)
		dummy.apply_biome_enemy(enemy, player.cultivation.realm)
		# Rank is decided after the species roll so a beast never becomes an
		# elite: beasts report on their own death channel and keep their core.
		if elite_share.randf() < ELITE_SHARE:
			dummy.make_elite()


func current_biome_name() -> String:
	if player == null:
		return ""
	var id := Biome.for_chunk(chunks.world_to_chunk(player.global_position), Game.world_seed)
	return String(DB.biome(id).get("name", "Wilds"))


func _on_window_resized() -> void:
	DisplayPolicy.apply(get_window())


# --------------------------------------------------------------- services ----

func _open_shop() -> void:
	if shop_panel == null or player == null:
		return
	if Captivity.wanted(Game.notoriety):
		Bus.toast.emit("The merchant will not deal with a wanted slaver.")
		return
	merchant.refresh(DB, Rng, Clock.day)
	shop_open = true
	player.set_physics_process(false)
	player.set_process(false)
	_show_shop("buy")


func _close_shop() -> void:
	shop_open = false
	if shop_panel != null:
		shop_panel.hide_panel()
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func _show_shop(mode: String) -> void:
	if shop_panel == null or player == null:
		return
	_shop_mode = mode
	var rows: Array = []
	if mode == "buy":
		for item in merchant.stock:
			rows.append({
				"name": String(item.get("name", "?")),
				"price": _shop_price(item),
				"color": ItemGen.RARITY_COLORS[int(item.get("rarity", 0))],
			})
		_sell_base = 0
	else:
		_sell_base = maxi(0, player.inventory.size() - 6)
		for i in range(_sell_base, player.inventory.size()):
			var item: Dictionary = player.inventory[i]
			rows.append({
				"name": Items.label(item),
				"price": Economy.sell_value(item),
				"color": ItemGen.RARITY_COLORS[int(item.get("rarity", 0))],
			})
	shop_panel.setup(mode, "Azure Cloud Market — Merchant", rows, Game.spirit_stones)


## A trusted name buys cheaper at the stall. Selling stays on the one value
## curve, so standing can never be turned into a money loop.
func _shop_price(item: Dictionary) -> int:
	var mult := Factions.price_multiplier("faction.market_league", Game.faction_standing, Game.notoriety)
	return maxi(1, int(ceil(float(Economy.buy_price(item)) * mult)))


func _buy_index(index: int) -> void:
	if index < 0 or index >= merchant.stock.size():
		return
	var item: Dictionary = merchant.stock[index]
	var price := _shop_price(item)
	if not Economy.can_afford(Game.spirit_stones, price):
		Bus.toast.emit("Not enough spirit stones: %d needed." % price)
		return
	Game.spirit_stones -= price
	merchant.take(index)
	player.pick_up(item)
	Bus.toast.emit("Bought %s for %d spirit stones." % [String(item.get("name", "item")), price])
	_show_shop("buy")


func _sell_index(index: int) -> void:
	if index < 0 or index >= player.inventory.size():
		return
	var item: Dictionary = player.inventory[index]
	# A stack is sold whole, so the price is the whole stack's.
	var price := Economy.sell_value(item)
	player.inventory.remove_at(index)
	# Selling worn gear must not leave the stat pipeline holding a ghost.
	var slot := String(item.get("slot", ""))
	var worn: Dictionary = player.equipment.get(slot, {})
	if not worn.is_empty() and String(worn.get("id", "")) == String(item.get("id", "")):
		player.equipment.erase(slot)
		player.rebuild_stats()
	Game.spirit_stones += price
	Bus.player_stats_changed.emit()
	Bus.toast.emit("Sold %s for %d spirit stones." % [Items.label(item), price])
	_show_shop("sell")


## The inn restores the body and, if the purse allows, mends worn gear too. A
## rest the player cannot afford is refused whole: no partial healing.
func _rest_at_inn() -> void:
	var cost := Economy.rest_cost()
	if not Economy.can_afford(Game.spirit_stones, cost):
		Bus.toast.emit("A night at the inn costs %d spirit stones. You have %d." % [cost, Game.spirit_stones])
		return
	var repair := Items.repair_cost(player.equipment)
	var mend := repair > 0 and Economy.can_afford(Game.spirit_stones - cost, repair)
	Game.spirit_stones -= cost
	if mend:
		Game.spirit_stones -= repair
		player.repair_gear()
	player.hp = player.hp_max
	cultivation_restore()
	Clock.advance(8.0)
	Bus.player_stats_changed.emit()
	var message := "You sleep for eight hours and wake restored. (-%d stones)" % cost
	if mend:
		message += " The innkeeper mends your gear. (-%d stones)" % repair
	Bus.toast.emit(message)


# ------------------------------------------------------------------ gear ----

## Equipped pieces are excluded: re-wearing what is already on is noise.
func gear_candidates() -> Array:
	var out: Array = []
	if player == null:
		return out
	for entry in player.inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		var slot := String(item.get("slot", ""))
		if not Items.is_equipment(slot):
			continue
		var worn: Dictionary = player.equipment.get(slot, {})
		if not worn.is_empty() and String(worn.get("id", "")) == String(item.get("id", "")):
			continue
		out.append(item)
	return out


## Comparison plus the equip gate, computed once per panel redraw.
func gear_compare(item: Dictionary) -> Dictionary:
	var rules := Equipment.new(DB)
	var slot := String(item.get("slot", ""))
	var worn: Dictionary = player.equipment.get(slot, {})
	var out := rules.compare(item, worn)
	out["check"] = rules.can_equip(item, player.equipment, player.attrs, player.cultivation.realm)
	return out


func toggle_gear() -> void:
	if player == null or phase == "creation" or String(phase) == "ended":
		return
	if gear_open:
		close_gear()
		return
	if bars_open or travel_open or shop_open or storage_open or forge_open or alchemy_open or (world_map != null and world_map.visible):
		return
	gear_open = true
	gear_index = 0
	player.set_physics_process(false)
	player.set_process(false)


func close_gear() -> void:
	gear_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## The grid's order is the satchel's order: sorting rewrites the array once, so
## no list can show an index that no longer points at the item it did.
func inventory_rows() -> Array:
	if player == null:
		return []
	return player.inventory


func cycle_inventory_sort() -> void:
	if player == null:
		return
	var mode := player.sort_inventory(Inventory.next_sort(player.inventory_sort))
	Bus.toast.emit("Satchel sorted by %s." % Inventory.sort_label(mode))


# ---------------------------------------------------------------- storage ----

## The screen lists both containers; the cursor only ever sits on one of them.
func storage_rows(side: int) -> Array:
	if player == null:
		return []
	return player.inventory if side == 0 else storage.items


func storage_selected() -> Dictionary:
	var rows: Array = storage_rows(storage_side)
	if storage_index < 0 or storage_index >= rows.size():
		return {}
	return rows[storage_index] as Dictionary


## Moves the selected stack whole to the other container. There is no partial
## move: a half-stack would only trade one untidy shelf for two.
func storage_move() -> void:
	if player == null:
		return
	var chosen := storage_selected()
	if chosen.is_empty():
		Bus.toast.emit("Nothing selected.")
		return
	var item_id := String(chosen.get("id", ""))
	var moved: Dictionary = storage.deposit(player.inventory, item_id) if storage_side == 0 \
		else storage.withdraw(player.inventory, item_id)
	if not bool(moved.get("ok", false)):
		Bus.toast.emit("Cannot move %s — %s." % [String(chosen.get("name", "item")), String(moved.get("reason", "refused"))])
		return
	var bag: Array = moved.get("inventory", [])
	player.inventory = bag
	storage_index = clampi(storage_index, 0, maxi(0, storage_rows(storage_side).size() - 1))
	var verb := "Stored" if storage_side == 0 else "Withdrew"
	Bus.toast.emit("%s %s." % [verb, Items.label(chosen)])
	Bus.player_stats_changed.emit()


func _open_storage() -> void:
	if player == null or phase == "creation" or String(phase) == "ended":
		return
	if gear_open or forge_open or alchemy_open or bars_open or travel_open or shop_open or (world_map != null and world_map.visible):
		return
	storage_open = true
	storage_side = 0
	storage_index = 0
	player.set_physics_process(false)
	player.set_process(false)


func close_storage() -> void:
	storage_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


# ------------------------------------------------------------------ forge ----

## Recipes in forge mode, gear in the other two: the same cursor, a different
## list, so the panel never needs a second selection model.
func forge_rows() -> Array:
	if FORGE_MODES[forge_mode] == "forge":
		return crafting.recipes_for("station.forge") if crafting != null else []
	return gear_candidates()


func forge_selected() -> Dictionary:
	var rows: Array = forge_rows()
	if forge_index < 0 or forge_index >= rows.size():
		return {}
	return rows[forge_index] as Dictionary


## The cost of the current mode, or {} in forge mode where each recipe carries
## its own price.
func forge_cost(mode_index: int) -> Dictionary:
	if crafting == null:
		return {}
	match FORGE_MODES[mode_index]:
		"refine":
			return crafting.action("refine")
		"disassemble":
			return crafting.action("disassemble")
		_:
			return {}


func forge_act() -> void:
	if player == null or crafting == null:
		return
	var chosen := forge_selected()
	if chosen.is_empty():
		return
	match FORGE_MODES[forge_mode]:
		"forge":
			_forge_make(chosen)
		"refine":
			_forge_refine(chosen)
		_:
			_forge_disassemble(chosen)


func _spend_craft(cost: Dictionary) -> void:
	var paid := Crafting.consume(player.inventory, cost.get("materials", []))
	if bool(paid.get("ok", false)):
		player.inventory = paid.get("inventory", player.inventory)
	Game.spirit_stones = maxi(0, Game.spirit_stones - int(cost.get("stones", 0)))
	Bus.player_stats_changed.emit()


func _forge_make(recipe: Dictionary) -> void:
	var gate := Professions.gate(recipe, Game.professions, DB)
	if not bool(gate.get("ok", false)):
		Bus.toast.emit("The forge refuses: %s." % String(gate.get("reason", "your rank is too low")))
		return
	var check := Crafting.check(recipe, player.inventory, Game.spirit_stones, player.cultivation.realm)
	if not bool(check.get("ok", false)):
		Bus.toast.emit("The forge refuses: %s." % String(check.get("reason", "not enough")))
		return
	var output: Dictionary = recipe.get("output", {})
	var base: Dictionary = DB.base_item(String(output.get("base", "")))
	var ilvl := maxi(int(base.get("ilvl", 1)), player.cultivation.realm)
	# Every attempt advances the counter, failures included: a retry must roll a
	# new stream or a failed recipe would fail forever.
	var attempt := Game.crafts_made
	Game.crafts_made += 1
	var smith: Dictionary = DB.profession("profession.smith")
	var rank := Professions.level_of(Game.professions, "profession.smith")
	var quality := player.stats.crafting_quality_mult() + Professions.quality_bonus(smith, rank)
	var result := crafting.craft(
		recipe, ilvl, 50000 + attempt, 0, quality, Professions.failure_mult(smith, rank))
	if not bool(result.get("ok", false)) and not bool(result.get("failed", false)):
		Bus.toast.emit(String(result.get("reason", "the forge cannot make that")).capitalize() + ".")
		return
	_spend_craft(recipe)
	if bool(result.get("failed", false)):
		Bus.toast.emit("The forge fails; the materials are lost.")
		return
	var item: Dictionary = result["item"]
	player.pick_up(item)
	var flourish := " (exceptional work)" if bool(result.get("quality", false)) else ""
	Bus.toast.emit("Forged %s%s." % [String(item.get("name", "a piece")), flourish])
	var practice := Professions.award(Game.professions, "profession.smith")
	if bool(practice.get("leveled", false)):
		Bus.toast.emit("Smith rank: %s." % Professions.rank_name(int(practice.get("level", 0))))


func _forge_refine(item: Dictionary) -> void:
	var rules: Dictionary = crafting.action("refine")
	var check := Crafting.check(rules, player.inventory, Game.spirit_stones, player.cultivation.realm)
	if not bool(check.get("ok", false)):
		Bus.toast.emit("Refining needs %s." % String(check.get("reason", "more materials")))
		return
	var attempt := Game.crafts_made
	Game.crafts_made += 1
	var smith: Dictionary = DB.profession("profession.smith")
	var rank := Professions.level_of(Game.professions, "profession.smith")
	var quality := player.stats.crafting_quality_mult() + Professions.quality_bonus(smith, rank)
	var result := crafting.refine(
		item, 60000 + attempt, 0, quality, Professions.failure_mult(smith, rank))
	if not bool(result.get("ok", false)) and not bool(result.get("failed", false)):
		Bus.toast.emit(String(result.get("reason", "the piece refuses the hammer")).capitalize() + ".")
		return
	_spend_craft(rules)
	if bool(result.get("failed", false)):
		Bus.toast.emit("The refine fails; the piece is unchanged.")
		return
	var refined: Dictionary = result["item"]
	for i in player.inventory.size():
		if String((player.inventory[i] as Dictionary).get("id", "")) == String(item.get("id", "")):
			player.inventory[i] = refined
			break
	var flourish := " (exceptional work)" if bool(result.get("quality", false)) else ""
	Bus.toast.emit("Refined %s%s." % [String(refined.get("name", "a piece")), flourish])
	var practice := Professions.award(Game.professions, "profession.smith")
	if bool(practice.get("leveled", false)):
		Bus.toast.emit("Smith rank: %s." % Professions.rank_name(int(practice.get("level", 0))))


func _forge_disassemble(item: Dictionary) -> void:
	var ore := Crafting.disassemble_ore(item)
	if ore <= 0:
		Bus.toast.emit("That cannot be broken down.")
		return
	for i in player.inventory.size():
		if String((player.inventory[i] as Dictionary).get("id", "")) == String(item.get("id", "")):
			player.inventory.remove_at(i)
			break
	player.inventory = Items.add_to_inventory(player.inventory, _make_ore(ore))
	forge_index = clampi(forge_index, 0, maxi(0, forge_rows().size() - 1))
	Bus.player_stats_changed.emit()
	Bus.toast.emit("Broken down into %d Spirit Ore." % ore)


func _open_forge() -> void:
	if player == null or phase == "creation" or String(phase) == "ended":
		return
	if gear_open or storage_open or alchemy_open or bars_open or travel_open or shop_open or (world_map != null and world_map.visible):
		return
	forge_open = true
	forge_mode = 0
	forge_index = 0
	player.set_physics_process(false)
	player.set_process(false)


func close_forge() -> void:
	forge_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


# ---------------------------------------------------------------- alchemy ----

func alchemy_rows() -> Array:
	return alchemy.recipes() if alchemy != null else []


func alchemy_selected() -> Dictionary:
	var rows: Array = alchemy_rows()
	if alchemy_index < 0 or alchemy_index >= rows.size():
		return {}
	return rows[alchemy_index] as Dictionary


func alchemy_act() -> void:
	_brew(alchemy_selected())


## Brewing shares the forge's attempt counter and its spend path: a failed brew
## costs its herbs, and the next try must roll a fresh stream.
func _brew(recipe: Dictionary) -> void:
	if player == null or alchemy == null or recipe.is_empty():
		return
	var gate := Professions.gate(recipe, Game.professions, DB)
	if not bool(gate.get("ok", false)):
		Bus.toast.emit("The cauldron refuses: %s." % String(gate.get("reason", "your rank is too low")))
		return
	var check := Crafting.check(recipe, player.inventory, Game.spirit_stones, player.cultivation.realm)
	if not bool(check.get("ok", false)):
		Bus.toast.emit("The cauldron refuses: %s." % String(check.get("reason", "not enough")))
		return
	var base: Dictionary = DB.base_item(String(recipe.get("base", "")))
	var ilvl := maxi(int(base.get("ilvl", 1)), player.cultivation.realm)
	var attempt := Game.crafts_made
	Game.crafts_made += 1
	var alchemist: Dictionary = DB.profession("profession.alchemist")
	var rank := Professions.level_of(Game.professions, "profession.alchemist")
	var quality := player.stats.crafting_quality_mult() + Professions.quality_bonus(alchemist, rank)
	var result := alchemy.brew(
		recipe, ilvl, 70000 + attempt, 0, quality, Professions.failure_mult(alchemist, rank))
	if not bool(result.get("ok", false)) and not bool(result.get("failed", false)):
		Bus.toast.emit(String(result.get("reason", "the cauldron cannot make that")).capitalize() + ".")
		return
	_spend_craft(recipe)
	if bool(result.get("failed", false)):
		Bus.toast.emit("The brew spoils; the herbs are lost.")
		return
	var pill: Dictionary = result["item"]
	player.pick_up(pill)
	var flourish := " (exceptional brew)" if bool(result.get("quality", false)) else ""
	Bus.toast.emit("Brewed %s at potency x%.2f%s." % [String(pill.get("name", "a pill")), Alchemy.potency_of(pill), flourish])
	var practice := Professions.award(Game.professions, "profession.alchemist")
	if bool(practice.get("leveled", false)):
		Bus.toast.emit("Alchemist rank: %s." % Professions.rank_name(int(practice.get("level", 0))))


func _open_alchemy() -> void:
	if player == null or phase == "creation" or String(phase) == "ended":
		return
	if gear_open or storage_open or forge_open or bars_open or travel_open or shop_open or (world_map != null and world_map.visible):
		return
	alchemy_open = true
	alchemy_index = 0
	player.set_physics_process(false)
	player.set_process(false)


func close_alchemy() -> void:
	alchemy_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## Drinks the selected satchel stack. The pill is spent even at full health or
## Qi: a cultivator who swallows one at the wrong moment has still swallowed it.
func use_selected_item() -> void:
	if player == null or alchemy == null:
		return
	var rows: Array = inventory_rows()
	if gear_index < 0 or gear_index >= rows.size():
		return
	var item: Dictionary = rows[gear_index]
	if String(item.get("slot", "")) != "consumable":
		Bus.toast.emit("%s is not a pill." % String(item.get("name", "item")))
		return
	var effect: Dictionary = alchemy.effect_for(item)
	if effect.is_empty():
		Bus.toast.emit("%s has no effect you know how to draw out." % String(item.get("name", "item")))
		return
	var amount := Alchemy.effect_amount(effect, item)
	var effect_id := String(effect.get("id", ""))
	match effect_id:
		"qi":
			player.cultivation.qi = minf(player.cultivation.qi_max(player.stats), player.cultivation.qi + amount)
		"heal":
			player.heal(amount)
		"cleanse":
			player.cultivation.cleanse(amount)
	var item_id := String(item.get("id", ""))
	for i in player.inventory.size():
		var entry: Dictionary = player.inventory[i]
		if String(entry.get("id", "")) != item_id:
			continue
		var left := int(entry.get("count", 1)) - 1
		if left <= 0:
			player.inventory.remove_at(i)
		else:
			entry["count"] = left
			player.inventory[i] = entry
		break
	gear_index = clampi(gear_index, 0, maxi(0, inventory_rows().size() - 1))
	var label := String(Alchemy.EFFECT_LABELS.get(effect_id, effect_id))
	var line := ("purged %.0f contamination" % amount) if effect_id == "cleanse" \
		else ("restored %.0f %s" % [amount, label])
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()
	Bus.toast.emit("Used %s — %s." % [Items.label(item), line])


# ---------------------------------------------------------- simulation ----

## Sleeps every NPC the player cannot see and wakes the ones nearby. Waking snaps
## an NPC to the schedule that passed while it slept, and any change in activity
## is remembered for the return report.
func _simulate_npcs() -> void:
	var in_realm := realm_instance != null
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var node := npc as Npc
		# A companion is always simulated and never goes to bed: it is with you.
		if node.in_party:
			if not node.simulated:
				node.simulated = true
				node.set_physics_process(true)
			continue
		var near := not in_realm and node.global_position.distance_to(player.global_position) <= NPC_SIM_RADIUS
		if near:
			if not node.simulated:
				var before := String(_npc_seen.get(node.npc_id, ""))
				node.wake()
				if before != "" and before != node.current_activity:
					_away_notes.append("%s was %s while you were away, and is now %s." % [node.display_name, before, node.current_activity])
					if _away_notes.size() > 6:
						_away_notes.pop_front()
				_npc_seen[node.npc_id] = node.current_activity
		elif node.simulated:
			_npc_seen[node.npc_id] = node.current_activity
			node.sleep()


## The settlement's watch. Hostile bodies inside the market ring are filtered
## once, then every waking resident decides for itself: notice one, hear a
## neighbour's shout, or carry on. A new alarm is shouted once, never per frame.
## Threats in the wilds are not the town's business until they walk in.
func _direct_npcs(delta: float) -> void:
	_warn_timer = maxf(0.0, _warn_timer - delta)
	_alert_timer -= delta
	if _alert_timer > 0.0 or npcs.is_empty() or realm_instance != null:
		return
	_alert_timer = NPC_ALERT_TICK
	var center: Vector2 = settlement.position_for("plaza")
	var bodies: Array = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var body := node as Dummy
		# Only a hostile body is a threat. A training dummy and a sparring
		# partner are furniture with a health bar.
		if body == null or body.state == "dead" or not body.aggressive:
			continue
		bodies.append({"id": String(body.name), "position": body.global_position})
	var threats: Array = NpcAi.watched(bodies, center)

	var shouted: Array = []
	for value in npcs:
		if not is_instance_valid(value):
			continue
		var npc := value as Npc
		# A sleeping body is behind a door: it neither sees nor answers an alarm.
		# A companion is following the player, not the town's duty roster.
		if npc == null or not npc.simulated or not npc.is_awake() or npc.in_party:
			continue
		var radius := float(npc.ai.get("alert_range", 260.0))
		var threat: Dictionary = NpcAi.nearest_threat(npc.global_position, threats, radius)
		var kind := NpcAi.decide(not threat.is_empty(), npc.reacting(), npc.ai)
		if kind == "routine":
			continue
		var at: Vector2 = npc.threat_position
		var distance := npc.threat_distance
		if not threat.is_empty():
			at = threat["position"]
			distance = float(threat["distance"])
		if npc.react(kind, at, NpcAi.ALARM_SECONDS, distance):
			shouted.append(npc)

	for value in shouted:
		var crier := value as Npc
		if not bool(crier.ai.get("shout", true)):
			continue
		for other in npcs:
			if not is_instance_valid(other) or other == crier:
				continue
			var listener := other as Npc
			if listener == null or not listener.simulated or not listener.is_awake() or listener.in_party:
				continue
			if not NpcAi.hears(crier.global_position, listener.global_position):
				continue
			# The listener keeps its own distance to the trouble: a shout carries the
			# warning, not the crier's eyesight.
			var heard_at: Vector2 = crier.threat_position
			listener.react(NpcAi.decide(false, true, listener.ai), heard_at,
				NpcAi.ALARM_SECONDS, listener.global_position.distance_to(heard_at))

	# A resident who thinks well of the player does not let them walk into it
	# blind. One voice, once per crisis.
	if not shouted.is_empty() and _warn_timer <= 0.0:
		_warn_player()


## Friendship made audible: the warmest resident within earshot calls out. Both
## conditions are required, so a friend across the province says nothing.
func _warn_player() -> void:
	var best: Npc = null
	var best_score := -101
	for value in npcs:
		if not is_instance_valid(value):
			continue
		var npc := value as Npc
		if npc == null or not npc.simulated or not npc.is_awake():
			continue
		if npc.global_position.distance_to(player.global_position) > WARN_RADIUS:
			continue
		var score := int(npc.bond_to_player().get("score", 0))
		if not Relationships.warns(score) or score <= best_score:
			continue
		best = npc
		best_score = score
	if best == null:
		return
	_warn_timer = WARN_COOLDOWN
	Bus.toast.emit("%s (%s): \"Stay close — something hostile is in the market.\"" % [
		best.display_name, best.role])


func _flush_away_report() -> void:
	if _wilds_recovered > 0 and realm_instance == null:
		Bus.toast.emit("The wilds recover while you were away (%d)." % _wilds_recovered)
		_wilds_recovered = 0
	if _away_notes.is_empty() or phase != "play":
		return
	if player.global_position.distance_to(settlement.position_for("plaza")) > 600.0:
		return
	var shown := mini(3, _away_notes.size())
	for i in shown:
		Bus.toast.emit(String(_away_notes[i]))
	if _away_notes.size() > shown:
		Bus.toast.emit("...and %d more changes while you were away." % (_away_notes.size() - shown))
	_away_notes.clear()


func _on_wilds_regrown(count: int) -> void:
	_wilds_recovered += count


# --------------------------------------------------------------- travel ----

func _travel_landmarks() -> Array:
	var rows: Array = [
		{"id": "landmark.plaza", "name": "Azure Cloud plaza", "position": settlement.position_for("plaza")},
		{"id": "landmark.shrine", "name": "Azure Cloud shrine", "position": settlement.position_for("shrine")},
		{"id": "landmark.tavern", "name": "Tavern inn", "position": settlement.position_for("tavern")},
	]
	for site in RealmAccess.sites():
		var site_id := String(site.get("id", ""))
		if not realm_known(site_id):
			continue
		var at: Vector2 = realm_portal_positions.get(site_id, portal_position)
		rows.append({
			"id": site_id,
			"name": RealmAccess.travel_label(site, Clock.day),
			"position": at,
		})
	return rows


func travel_destinations() -> Array:
	return Travel.destinations(_travel_landmarks(), travel_sites, Travel.MAX_ROWS)


func _open_travel() -> void:
	if travel_panel == null or player == null:
		return
	if realm_instance != null:
		Bus.toast.emit("No route can be charted inside a hidden realm.")
		return
	travel_index = 0
	travel_open = true
	player.set_physics_process(false)
	player.set_process(false)
	_show_travel()


func _close_travel() -> void:
	travel_open = false
	if travel_panel != null:
		travel_panel.hide_panel()
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func _show_travel() -> void:
	if travel_panel == null or player == null:
		return
	var destinations := travel_destinations()
	if travel_index >= destinations.size():
		travel_index = maxi(0, destinations.size() - 1)
	var rows: Array = []
	for destination in destinations:
		var target: Vector2 = destination["position"]
		var distance := target.distance_to(player.global_position)
		rows.append({
			"name": String(destination["name"]),
			"detail": "%s · %.1f h" % [Travel.distance_label(distance), Travel.hours_for(distance)],
			"color": "#9fe0c0" if waypoint_name == String(destination["name"]) else "#e6eef2",
		})
	travel_panel.setup(rows, travel_index)


func _travel_to(index: int) -> void:
	var destinations := travel_destinations()
	if index < 0 or index >= destinations.size():
		return
	if not Travel.can_travel(true, realm_instance != null, false):
		return
	var destination: Dictionary = destinations[index]
	var target: Vector2 = destination["position"]
	var hours := Travel.hours_for(target.distance_to(player.global_position))
	player.global_position = target + Vector2(0, 44)
	player.spawn_point = player.global_position
	Clock.advance(hours)
	chunks.today = Clock.day
	chunks.stream_around(player.global_position)
	chunks.settle()
	camera_rig.reset_smoothing()
	waypoint_name = ""
	waypoint_position = Vector2.ZERO
	_close_travel()
	Bus.toast.emit("Travelled to %s (%.1f hours)." % [String(destination["name"]), hours])


func _set_waypoint(index: int) -> void:
	var destinations := travel_destinations()
	if index < 0 or index >= destinations.size():
		return
	var destination: Dictionary = destinations[index]
	waypoint_name = String(destination["name"])
	waypoint_position = destination["position"]
	_close_travel()
	Bus.toast.emit("Waypoint set: %s." % waypoint_name)


## 1-6 on the active bar. An empty slot says so instead of silently doing
## nothing, and points at the arrangement panel.
func _select_bar_slot(slot: int) -> bool:
	if player == null:
		return false
	if not player.select_bar_slot(slot):
		Bus.toast.emit("Bar %s, slot %d is empty. (B arranges the bars)" % [
			SkillBar.bar_label(player.active_bar), slot + 1])
		return false
	Bus.cultivation_changed.emit()
	return true


func _switch_bar(step: int) -> int:
	if player == null:
		return 0
	var bar := player.cycle_bar(step)
	Bus.toast.emit("Skill bar %s." % SkillBar.bar_label(bar))
	Bus.cultivation_changed.emit()
	return bar


func toggle_bars() -> void:
	if bars_open:
		_close_bars()
		return
	if player == null or phase == "creation" or String(phase) == "ended":
		return
	# The overlays are mutually exclusive: one screen at a time owns the mouse.
	if shop_open or travel_open:
		return
	if world_map != null and world_map.visible:
		toggle_map()
	bars_open = true
	if skill_bar_panel != null:
		skill_bar_panel.open(player)
	player.set_physics_process(false)
	player.set_process(false)


func _close_bars() -> void:
	if not bars_open:
		return
	bars_open = false
	if skill_bar_panel != null:
		skill_bar_panel.close()
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func toggle_map() -> void:
	if world_map == null or player == null or phase == "creation":
		return
	world_map.toggle()
	if world_map.visible:
		world_map.setup(continent, Continent.region_for_world_position(player.global_position), _realm_map_marks())
	# Freeze both loops, so an open map is not a blind walk.
	player.set_physics_process(not world_map.visible)
	player.set_process(not world_map.visible)


func _unhandled_input(event: InputEvent) -> void:
	# Muting is a reading preference, not a game action: it works on every screen.
	if event.is_action_pressed("mute_audio"):
		_toggle_audio()
		return
	if String(phase) == "ended":
		if event.is_action_pressed("accept"):
			get_tree().reload_current_scene()
		return
	if phase == "creation":
		if event.is_action_pressed("accept"):
			if creation_stage == 0:
				creation_stage = 1
			else:
				_begin_run()
			return
		if event.is_action_pressed("undo_point"):
			if creation_stage == 1:
				creation_stage = 0
			else:
				refund_attribute()
			return
		if event.is_action_pressed("reroll"):
			player.cultivation.root_tier = _roll_root()
			player.cultivation.purity_bonus = _roll_purity()
			player.cultivation.identified = false
			player.rebuild_stats()
			Bus.cultivation_changed.emit()
			Bus.toast.emit("Your root shifts.")
			return
		if event.is_action_pressed("creation_origin"):
			Game.origin_id = Origin.next(DB.origins, Game.origin_id, 1)
			return
		if event.is_action_pressed("creation_robe"):
			player.appearance.cycle("robe")
			return
		if event.is_action_pressed("creation_hair"):
			player.appearance.cycle("hair")
			return
		if event.is_action_pressed("creation_skin"):
			player.appearance.cycle("skin")
			return
		if event.is_action_pressed("creation_presentation"):
			player.appearance.cycle("presentation")
			return
		if event.is_action_pressed("creation_physique"):
			_physique_rolls += 1
			player.physique_id = Physiques.roll(_physique_rolls)
			player.rebuild_stats()
			Bus.player_stats_changed.emit()
			Bus.toast.emit("Your body reshapes — %s." % Physiques.name_of(player.physique_id))
			return
		if creation_stage == 0:
			for i in Attributes.KEYS.size():
				if event.is_action_pressed("skill_%d" % (i + 1)):
					allocate_attribute(Attributes.KEYS[i])
					return
		return

	if factions_open:
		if event.is_action_pressed("open_factions") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_factions()
		return

	if sects_open:
		if event.is_action_pressed("open_sects") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_sects()
		return

	if hierarchy_open:
		if event.is_action_pressed("open_hierarchy") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_hierarchy()
		return

	if sect_ledger_open:
		if event.is_action_pressed("open_ledger") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_sect_ledger()
			return
		if event.is_action_pressed("ui_down"):
			sect_ledger_index = mini(sect_ledger_index + 1, maxi(0, sect_ledger_rows().size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			sect_ledger_index = maxi(0, sect_ledger_index - 1)
			return
		if event.is_action_pressed("accept"):
			_sect_ledger_activate(sect_ledger_index)
			return
		return

	if council_open:
		if event.is_action_pressed("open_council") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_council()
			return
		if event.is_action_pressed("ui_down"):
			council_index = mini(council_index + 1, maxi(0, council_rows().size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			council_index = maxi(0, council_index - 1)
			return
		if event.is_action_pressed("accept"):
			_council_activate(council_index)
			return
		return

	if player_sect_open:
		if event.is_action_pressed("open_player_sect") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_player_sect()
			return
		if event.is_action_pressed("ui_down"):
			player_sect_index = mini(player_sect_index + 1, maxi(0, player_sect_rows().size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			player_sect_index = maxi(0, player_sect_index - 1)
			return
		if event.is_action_pressed("accept"):
			_player_sect_activate(player_sect_index)
			return
		return

	if chronicle_open:
		if event.is_action_pressed("open_chronicle") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_chronicle()
		return

	if captives_open:
		if event.is_action_pressed("open_captives") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_captives()
			return
		if event.is_action_pressed("ui_down"):
			captive_index = mini(captive_index + 1, maxi(0, Game.captives.size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			captive_index = maxi(0, captive_index - 1)
			return
		if event.is_action_pressed("accept"):
			_hand_over_captive(captive_index)
			return
		if event.is_action_pressed("use_item"):
			_release_captive(captive_index)
			return
		if event.is_action_pressed("shop_mode"):
			_cycle_captive_policy()
			return
		return

	if bars_open:
		if event.is_action_pressed("open_bars") or event.is_action_pressed("interact") \
				or event.is_action_pressed("ui_cancel"):
			_close_bars()
		return

	if travel_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_close_travel()
			return
		if event.is_action_pressed("accept"):
			_travel_to(travel_index)
			return
		if event.is_action_pressed("travel_waypoint"):
			_set_waypoint(travel_index)
			return
		for i in 6:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				travel_index = i
				_show_travel()
				return
		return

	if alchemy_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close_alchemy()
			return
		var potion_list: Array = alchemy_rows()
		if event.is_action_pressed("ui_down"):
			alchemy_index = mini(alchemy_index + 1, maxi(0, potion_list.size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			alchemy_index = maxi(0, alchemy_index - 1)
			return
		if event.is_action_pressed("accept"):
			alchemy_act()
			return
		return

	if forge_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close_forge()
			return
		if event.is_action_pressed("shop_mode"):
			forge_mode = (forge_mode + 1) % FORGE_MODES.size()
			forge_index = 0
			return
		var forge_list := forge_rows()
		if event.is_action_pressed("ui_down"):
			forge_index = mini(forge_index + 1, maxi(0, forge_list.size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			forge_index = maxi(0, forge_index - 1)
			return
		if event.is_action_pressed("accept"):
			forge_act()
			return
		return

	if storage_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") \
				or event.is_action_pressed("open_inventory"):
			close_storage()
			return
		if event.is_action_pressed("shop_mode") or event.is_action_pressed("ui_left") \
				or event.is_action_pressed("ui_right"):
			storage_side = 1 - storage_side
			storage_index = 0
			return
		var storage_list := storage_rows(storage_side)
		if event.is_action_pressed("ui_down"):
			storage_index = mini(storage_index + 1, maxi(0, storage_list.size() - 1))
			return
		if event.is_action_pressed("ui_up"):
			storage_index = maxi(0, storage_index - 1)
			return
		if event.is_action_pressed("accept"):
			storage_move()
			return
		return

	if gear_open:
		if event.is_action_pressed("open_inventory") or event.is_action_pressed("ui_cancel") \
				or event.is_action_pressed("interact"):
			close_gear()
			return
		var rows: Array = inventory_rows()
		if event.is_action_pressed("sort_inventory"):
			cycle_inventory_sort()
			gear_index = 0
			return
		if event.is_action_pressed("use_item"):
			use_selected_item()
			return
		if event.is_action_pressed("ui_down"):
			gear_index = Inventory.move_cursor(gear_index, Inventory.COLS, rows.size())
			return
		if event.is_action_pressed("ui_up"):
			gear_index = Inventory.move_cursor(gear_index, -Inventory.COLS, rows.size())
			return
		if event.is_action_pressed("ui_right"):
			gear_index = Inventory.move_cursor(gear_index, 1, rows.size())
			return
		if event.is_action_pressed("ui_left"):
			gear_index = Inventory.move_cursor(gear_index, -1, rows.size())
			return
		if event.is_action_pressed("accept") and not rows.is_empty():
			gear_index = clampi(gear_index, 0, rows.size() - 1)
			var wanted: Dictionary = rows[gear_index]
			if not Items.is_equipment(String(wanted.get("slot", ""))):
				Bus.toast.emit("%s is not something you can wear." % String(wanted.get("name", "item")))
				return
			var result := player.equip(wanted)
			if bool(result.get("ok", false)):
				Bus.toast.emit("Worn: %s." % String(wanted.get("name", "item")))
			else:
				Bus.toast.emit("Cannot wear %s — %s" % [String(wanted.get("name", "item")), String(result.get("reason", "refused"))])
			gear_index = clampi(gear_index, 0, maxi(0, inventory_rows().size() - 1))
			return
		return

	if event.is_action_pressed("open_inventory"):
		toggle_gear()
		return

	if event.is_action_pressed("open_travel"):
		_open_travel()
		return

	if event.is_action_pressed("open_bars"):
		toggle_bars()
		return

	if shop_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_close_shop()
			return
		if event.is_action_pressed("shop_mode"):
			_show_shop("sell" if _shop_mode == "buy" else "buy")
			return
		for i in 6:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				if _shop_mode == "buy":
					_buy_index(i)
				else:
					_sell_index(_sell_base + i)
				return
		return

	if event.is_action_pressed("quick_save"):
		_save(1)
	elif event.is_action_pressed("map"):
		toggle_map()
	elif event.is_action_pressed("quick_load"):
		_load_game(1)
	elif event.is_action_pressed("toggle_help"):
		_help_visible = not _help_visible
		Bus.help_toggled.emit(_help_visible)
	elif event.is_action_pressed("breakthrough"):
		_face_tribulation()


# ----------------------------------------------------------- interaction ----

func _active_interactables() -> Array:
	if realm_instance != null:
		return realm_instance.interactables
	return interactables


## The dossier follows the nearest person within conversational distance.
func nearest_npc() -> Npc:
	if player == null or realm_instance != null or String(phase) == "ended":
		return null
	var best: Npc = null
	var best_dist := 150.0
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc == null:
			continue
		var dist: float = npc.global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	return best


## P: ask the nearest person to travel with you, or send a companion home. The
## rules live in `Party`; this only turns the answer into a line of speech.
func _toggle_party() -> void:
	if player == null or String(phase) != "play" or realm_instance != null:
		return
	var npc := nearest_npc()
	if npc == null:
		Bus.toast.emit("There is nobody close enough to ask.")
		return
	if npc.in_party:
		_dismiss_party_member(npc)
		return
	var bond: Dictionary = npc.bond_to_player()
	var verdict := Party.can_recruit(Game.party_ids, npc.npc_id,
		int(bond.get("score", 0)), player.stats.party_slots())
	if not bool(verdict.get("ok", false)):
		Bus.toast.emit("%s %s" % [npc.display_name, String(verdict.get("reason", ""))])
		return
	Party.add(Game.party_ids, npc.npc_id)
	npc.join_party()
	Bus.toast.emit("%s joins you. (%s)" % [npc.display_name,
		Party.slots_label(Game.party_ids.size(), player.stats.party_slots())])


func _dismiss_party_member(npc: Npc) -> void:
	if npc == null or not npc.in_party:
		return
	Party.remove(Game.party_ids, npc.npc_id)
	npc.leave_party()
	Bus.toast.emit("%s returns to the %s." % [
		npc.display_name, npc.current_location.replace("_", " ")])


## Aligns the spawned bodies with the saved roster. Membership is the only party
## state a save carries, so this is the whole load path.
func _sync_party() -> void:
	for index in Game.party_ids.size():
		var npc := _npc_by_id(String(Game.party_ids[index]))
		if npc == null:
			continue
		if not npc.in_party:
			npc.join_party()
		if player != null and npc.global_position.distance_to(player.global_position) > 900.0:
			npc.global_position = player.global_position + Party.follow_offset(index, Vector2.DOWN)
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var resident := node as Npc
		if resident != null and resident.in_party and not Game.party_ids.has(resident.npc_id):
			resident.leave_party()


func _npc_by_id(id: String) -> Npc:
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc != null and npc.npc_id == id:
			return npc
	return null


## The travelling party in roster order, for the HUD.
func party_members() -> Array:
	var out: Array = []
	for id in Game.party_ids:
		var npc := _npc_by_id(String(id))
		if npc != null and npc.in_party:
			out.append(npc)
	return out


# ---------------------------------------------------------- npc progression ----


## Re-derives every resident's cultivation for the current day. Bodies whose
## realm changed rebuild their sheet, which is why a disciple met on day 1 is
## visibly not the cultivator met on day 300.
func _refresh_npc_progress_all() -> void:
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc != null:
			_npc_progress_for(npc)


func _npc_progress_for(npc: Npc) -> Dictionary:
	if npc == null:
		return {}
	return npc.refresh_progress()


## The town climbs while the player is elsewhere. Only a realm breakthrough and
## a failed attempt are worth a line: sublevels happen too often to announce.
func _check_npc_progress() -> void:
	if String(phase) != "play":
		return
	if _progress_day == 0:
		_progress_day = Clock.day
		return
	if Clock.day == _progress_day:
		return
	_progress_day = Clock.day
	var lines: Array[String] = []
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc == null:
			continue
		var state := _npc_progress_for(npc)
		if int(state.get("last_event_day", 0)) != Clock.day:
			continue
		match String(state.get("last_event", "")):
			"breakthrough":
				lines.append("%s breaks through to %s." % [npc.display_name, Realms.name_of(npc.realm)])
			"deviation":
				lines.append("%s fails a breakthrough and withdraws to recover." % npc.display_name)
	for i in mini(lines.size(), 3):
		Bus.toast.emit(lines[i])
	if lines.size() > 3:
		Bus.toast.emit("%d more of the market advanced today." % (lines.size() - 3))
	if not lines.is_empty():
		Bus.player_stats_changed.emit()


# ----------------------------------------------------------------- stories ----


## The market keeps talking. On every day the calendar turns, real progression
## events become entries, the day's small beats are drawn from the residents'
## goals and routines, and each entry finds its witnesses and any request it
## carries. Skipped days (rest, travel) are walked one at a time, so the town is
## never silent just because the player slept through it.
func _check_stories() -> void:
	if String(phase) != "play":
		return
	if _story_day == 0:
		_story_day = Clock.day
		return
	if Clock.day <= _story_day:
		return
	var people := Stories.people_from(npcs)
	var rule := Stories.rules()
	var cap := int(rule.get("chronicle_cap", 40))
	var offer_cap := int(rule.get("offer_cap", 4))
	var visited := 0
	var announced := 0
	while _story_day < Clock.day and visited < 60:
		_story_day += 1
		visited += 1
		var entries: Array = []
		# The day being lived: real progression events, at most two.
		if _story_day == Clock.day:
			var events := 0
			for node in npcs:
				if events >= 2 or not is_instance_valid(node):
					continue
				var npc := node as Npc
				if npc == null:
					continue
				var state := npc.progress
				if int(state.get("last_event_day", 0)) != _story_day:
					continue
				var beat := Stories.event_beat(String(state.get("last_event", "")),
					{"id": npc.npc_id, "name": npc.display_name}, _story_day,
					{"realm_name": Realms.name_of(npc.realm), "place": npc.current_location})
				if beat.is_empty():
					continue
				entries.append(beat)
				events += 1
		entries.append_array(Stories.ambient(people, _story_day, Game.world_seed))
		for value in entries:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			entry["witnesses"] = Stories.witnesses(entry, people, Game.world_seed)
			Game.chronicle = Stories.append(Game.chronicle, entry, cap)
			var offer := Stories.offer_for(entry, rule)
			if not offer.is_empty() and Game.story_offers.size() < offer_cap \
					and not _has_story_offer(String(offer.get("id", ""))):
				Game.story_offers.append(offer)
				if _story_near(entry):
					Bus.toast.emit("A request: " + Stories.offer_text(offer))
			elif _story_day == Clock.day and String(entry.get("kind", "")) != Stories.BREAKTHROUGH \
					and String(entry.get("kind", "")) != Stories.DEVIATION \
					and announced < 2 and _story_near(entry):
				Bus.toast.emit("Word travels: " + String(entry.get("headline", "")))
				announced += 1
	Game.story_offers = Stories.expire_offers(Game.story_offers, Clock.day)


## Whether the player is close enough to hear about an entry: a known face, or
## someone standing within earshot.
func _story_near(entry: Dictionary) -> bool:
	var actors: Variant = entry.get("actors", [])
	if typeof(actors) != TYPE_ARRAY:
		return false
	for value in actors:
		var id := String(value)
		if Game.npc_memory.has(id):
			return true
		var npc := _story_npc(id)
		if npc != null and player != null and npc.global_position.distance_to(player.global_position) <= 520.0:
			return true
	return false


func _story_npc(id: String) -> Npc:
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc != null and npc.npc_id == id:
			return npc
	return null


func _has_story_offer(id: String) -> bool:
	for value in Game.story_offers:
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return true
	return false


## What a person adds to a greeting: their own request first, then the newest
## thing they have heard. Empty for someone with neither.
func _story_suffix(npc: Npc) -> String:
	if npc == null:
		return ""
	var index := Stories.offer_index_for(Game.story_offers, npc.npc_id)
	if index >= 0:
		return " " + Stories.offer_text(Game.story_offers[index] as Dictionary)
	var rumor := Stories.rumor_for(npc.npc_id, Game.chronicle, Clock.day,
		int(Stories.rules().get("rumor_days", 4)))
	if rumor.is_empty():
		return ""
	return " \"%s\"" % String(rumor.get("headline", ""))


func _story_has_item(base_id: String) -> bool:
	if base_id == "" or player == null:
		return false
	for value in player.inventory:
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("base", "")) == base_id:
			return true
	return false


## Takes one unit of the requested base, preferring a whole stack, and returns
## whether anything changed hands.
func _story_consume_item(base_id: String) -> bool:
	if base_id == "" or player == null:
		return false
	for i in player.inventory.size():
		var item: Dictionary = player.inventory[i]
		if String(item.get("base", "")) != base_id:
			continue
		var left := int(item.get("count", 1)) - 1
		if left <= 0:
			player.inventory.remove_at(i)
		else:
			item["count"] = left
			player.inventory[i] = item
		return true
	return false


func _story_deliver(index: int, npc: Npc) -> void:
	if index < 0 or index >= Game.story_offers.size():
		return
	var offer: Dictionary = Game.story_offers[index]
	if not _story_consume_item(String(offer.get("target", ""))):
		return
	Game.story_offers = Stories.without(Game.story_offers, index)
	_story_reward(offer)
	Bus.toast.emit("%s takes the %s. (+%d stones, +%d regard)" % [
		npc.display_name, String(offer.get("target_name", "pill")),
		int(offer.get("stones", 0)), int(offer.get("regard", 0))])


## A kill answers the oldest hunt request only; a second request is answered by
## the next beast, so one hunt cannot settle the whole watch's work.
func _check_story_hunts() -> void:
	if Game.story_offers.is_empty():
		return
	var result := Stories.advance_hunt(Game.story_offers, Clock.day)
	Game.story_offers = result.get("offers", [])
	for value in result.get("completed", []):
		var offer: Dictionary = value
		_story_reward(offer)
		Bus.toast.emit("%s's request is answered. (+%d stones, +%d regard)" % [
			String(offer.get("actor_name", "Someone")), int(offer.get("stones", 0)),
			int(offer.get("regard", 0))])


## Rewards land where the rest of the run can see them: stones in the purse and
## regard in the same memory the next conversation reads.
func _story_reward(offer: Dictionary) -> void:
	Game.spirit_stones += maxi(0, int(offer.get("stones", 0)))
	# A request answered in the sect's name is service, whether or not the person
	# who asked belongs to a faction the player can name.
	Game.sect_contribution = SectEconomy.award_contribution(
		Game.sect_contribution, SectEconomy.story_award())
	var id := String(offer.get("actor", ""))
	if id == "":
		return
	var record := NpcDb.memory_entry(Game.npc_memory, id)
	record["met"] = true
	record["regard"] = clampi(int(record.get("regard", 0)) + int(offer.get("regard", 0)),
		NpcDb.REGARD_MIN, NpcDb.REGARD_MAX)
	Game.npc_memory[id] = record
	# The person's faction notices the help, and its allies and rivals move a
	# little with it. A request answered is a small but real act of standing.
	var npc := _story_npc(id)
	var faction_id: String = npc.faction_id() if npc != null else ""
	if faction_id != "":
		Game.faction_standing = Factions.award(Game.faction_standing, faction_id, Factions.story_award())
		Bus.toast.emit("%s standing rises: %s" % [
			String(Factions.faction(faction_id).get("name", faction_id)),
			Factions.describe(faction_id, Game.faction_standing, Game.notoriety)])
	Bus.player_stats_changed.emit()


# --------------------------------------------------------------- chronicle ----


func toggle_chronicle() -> void:
	if chronicle_open:
		_close_chronicle()
	else:
		_open_chronicle()


func _open_chronicle() -> void:
	if player == null or String(phase) != "play":
		return
	chronicle_open = true
	player.set_physics_process(false)
	player.set_process(false)


func _close_chronicle() -> void:
	if not chronicle_open:
		return
	chronicle_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## Newest first, capped for the screen. The full list stays in `Game.chronicle`.
func chronicle_rows() -> Array:
	var out: Array = []
	for i in range(Game.chronicle.size() - 1, -1, -1):
		out.append(Game.chronicle[i])
		if out.size() >= 12:
			break
	return out


func story_offer_rows() -> Array:
	return Game.story_offers.duplicate(true)


# --------------------------------------------------------------- factions ----


func toggle_factions() -> void:
	if factions_open:
		_close_factions()
	else:
		_open_factions()


func _open_factions() -> void:
	if player == null or String(phase) != "play":
		return
	factions_open = true
	player.set_physics_process(false)
	player.set_process(false)


func _close_factions() -> void:
	if not factions_open:
		return
	factions_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## One row per faction, read through the same effective-standing rule the people
## use, so the screen cannot promise a welcome the guard will not give.
func faction_rows() -> Array:
	var out: Array = []
	for value in Factions.factions():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var standing := Factions.effective_standing(id, Game.faction_standing, Game.notoriety)
		var band := Factions.band_for(standing)
		out.append({
			"id": id,
			"name": String(entry.get("name", id)),
			"kind": String(entry.get("kind", "")),
			"colour": String(entry.get("colour", "#9aa0a6")),
			"motto": String(entry.get("motto", "")),
			"value": standing,
			"band": String(band.get("id", "")),
			"label": String(band.get("label", "")),
			"blurb": String(band.get("blurb", "")),
			"disposition": int(band.get("disposition", 0)),
			"price_mult": float(band.get("price_mult", 1.0)),
			"relations": Factions.relation_text(id),
			"lawful": bool(entry.get("lawful", false)),
		})
	return out


# ------------------------------------------------------------------ sects ----


func toggle_sects() -> void:
	if sects_open:
		_close_sects()
	else:
		_open_sects()


func _open_sects() -> void:
	if player == null or String(phase) != "play":
		return
	sects_open = true
	player.set_physics_process(false)
	player.set_process(false)


func _close_sects() -> void:
	if not sects_open:
		return
	sects_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## The codex is content, not state: one row per authored sect, with the local
## house marked so the screen can point at the gate the player actually uses.
func sect_rows() -> Array:
	var out: Array = []
	for value in Sects.sects():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := Sects.row(String((value as Dictionary).get("id", "")))
		if not row.is_empty():
			out.append(row)
	return out


# ------------------------------------------------------------- hierarchy ----


func toggle_hierarchy() -> void:
	if hierarchy_open:
		_close_hierarchy()
	else:
		_open_hierarchy()


func _open_hierarchy() -> void:
	if player == null or String(phase) != "play":
		return
	hierarchy_open = true
	player.set_physics_process(false)
	player.set_process(false)


func _close_hierarchy() -> void:
	if not hierarchy_open:
		return
	hierarchy_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## Every rung and office, with the residents who hold it and whether it is the
## player's own station. The scene supplies the occupancy because only it knows
## who is spawned; the ladder and eligibility stay in `Hierarchy`.
func hierarchy_rows() -> Array:
	var current := Hierarchy.player_rank(player.cultivation.realm, Game.faction_standing,
		Game.notoriety, Hierarchy.seat_available(Game.sect_seat_open))
	var current_id := String(current.get("id", ""))
	var out: Array = []
	for group in [Hierarchy.ladder(), Hierarchy.offices()]:
		for value in group:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			var holders: Array[String] = []
			for node in npcs:
				if not is_instance_valid(node):
					continue
				var person := node as Npc
				if person != null and person.rank_id() == id:
					holders.append(person.display_name)
			out.append({
				"id": id,
				"name": String(entry.get("name", id)),
				"level": int(entry.get("level", -1)),
				"authority": int(entry.get("authority", 0)),
				"duty": String(entry.get("duty", "")),
				"privilege": String(entry.get("privilege", "")),
				"requires": entry.get("requires", {}),
				"seat": bool(entry.get("seat", false)),
				"office": not entry.has("level"),
				"holders": holders,
				"you": id == current_id,
			})
	return out


# ----------------------------------------------------------- sect ledger ----


func toggle_sect_ledger() -> void:
	if sect_ledger_open:
		_close_sect_ledger()
	else:
		_open_sect_ledger()


func _open_sect_ledger() -> void:
	if player == null or String(phase) != "play":
		return
	sect_ledger_open = true
	sect_ledger_index = clampi(sect_ledger_index, 0, maxi(0, sect_ledger_rows().size() - 1))
	player.set_physics_process(false)
	player.set_process(false)


func _close_sect_ledger() -> void:
	if not sect_ledger_open:
		return
	sect_ledger_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


func _player_rank_id() -> String:
	if player == null:
		return "rank.servant"
	return String(Hierarchy.player_rank(player.cultivation.realm, Game.faction_standing,
		Game.notoriety, Hierarchy.seat_available(Game.sect_seat_open)).get("id", "rank.servant"))


## The ledger is one list of real transactions: today's stipend, the two
## donation rates, and the quartermaster's three shelves. A row that cannot be
## taken still appears, with the reason, so the cost is never a surprise.
func sect_ledger_rows() -> Array:
	var rank_id := _player_rank_id()
	var out: Array = []
	var claim := SectEconomy.claim(rank_id, Clock.day, Game.sect_stipend_day, Game.spirit_stones)
	var claim_detail := "%s · %d stones − %d dues = %d stones" % [
		Hierarchy.title(rank_id), SectEconomy.stipend_stones(rank_id),
		SectEconomy.stipend_dues(rank_id), SectEconomy.stipend_net(rank_id)]
	if not bool(claim.get("ok", false)):
		claim_detail = "Already paid today. Next stipend tomorrow."
	out.append({
		"kind": "stipend",
		"id": "stipend",
		"label": "Claim daily stipend",
		"detail": claim_detail,
		"enabled": bool(claim.get("ok", false)),
		"reason": String(claim.get("reason", "")),
	})
	for value in SectEconomy.donations():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var result := SectEconomy.donate(id, Game.spirit_stones, Game.sect_contribution)
		out.append({
			"kind": "donation",
			"id": id,
			"label": String(entry.get("label", id)),
			"detail": "%d stones → +%d contribution" % [int(entry.get("stones", 0)), int(entry.get("points", 0))],
			"enabled": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
	for value in SectEconomy.services():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var result := SectEconomy.buy(id, Game.sect_contribution, rank_id)
		var required := String(entry.get("rank", ""))
		out.append({
			"kind": "service",
			"id": id,
			"label": String(entry.get("name", id)),
			"detail": "%d contribution · needs %s" % [int(entry.get("cost", 0)), Hierarchy.title(required)],
			"enabled": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
	return out


func _sect_ledger_activate(index: int) -> void:
	var rows := sect_ledger_rows()
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	if not bool(row.get("enabled", false)):
		var reason := String(row.get("reason", ""))
		if reason == "":
			Bus.toast.emit("The ledger refuses.")
		else:
			Bus.toast.emit("The ledger refuses: %s." % reason)
		return
	match String(row.get("kind", "")):
		"stipend":
			_sect_claim_stipend(row)
		"donation":
			_sect_donate(row)
		"service":
			_sect_buy_service(row)


func _sect_claim_stipend(row: Dictionary) -> void:
	var result := SectEconomy.claim(_player_rank_id(), Clock.day, Game.sect_stipend_day, Game.spirit_stones)
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The ledger refuses: %s." % String(result.get("reason", "")))
		return
	Game.spirit_stones = int(result.get("stones", Game.spirit_stones))
	Game.sect_stipend_day = int(result.get("day", Clock.day))
	Bus.toast.emit("Sect stipend: +%d stones (%d pay, %d dues)." % [
		int(result.get("net", 0)), int(result.get("stipend", 0)), int(result.get("dues", 0))])
	Bus.player_stats_changed.emit()


func _sect_donate(row: Dictionary) -> void:
	var result := SectEconomy.donate(String(row.get("id", "")), Game.spirit_stones, Game.sect_contribution)
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The ledger refuses: %s." % String(result.get("reason", "")))
		return
	Game.spirit_stones = int(result.get("stones", Game.spirit_stones))
	Game.sect_contribution = int(result.get("contribution", Game.sect_contribution))
	Bus.toast.emit("Donated to the hall. Contribution +%d." % int(result.get("points", 0)))
	Bus.player_stats_changed.emit()


func _sect_buy_service(row: Dictionary) -> void:
	var entry := SectEconomy.service(String(row.get("id", "")))
	if entry.is_empty():
		return
	var result := SectEconomy.buy(String(row.get("id", "")), Game.sect_contribution, _player_rank_id())
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The ledger refuses: %s." % String(result.get("reason", "")))
		return
	var item := _sect_service_item(entry)
	if item.is_empty():
		Bus.toast.emit("The quartermaster has nothing on that shelf.")
		return
	Game.sect_contribution = int(result.get("contribution", Game.sect_contribution))
	Game.sect_purchases += 1
	player.inventory = Items.add_to_inventory(player.inventory, item)
	Bus.toast.emit("The quartermaster hands over %s. Contribution −%d." % [
		String(item.get("name", "a pill")), int(result.get("cost", 0))])
	Bus.player_stats_changed.emit()


# ----------------------------------------------------------- sect council ----


func toggle_council() -> void:
	if council_open:
		_close_council()
	else:
		_open_council()


func _open_council() -> void:
	if player == null or String(phase) != "play":
		return
	council_open = true
	council_index = clampi(council_index, 0, maxi(0, council_rows().size() - 1))
	player.set_physics_process(false)
	player.set_process(false)


func _close_council() -> void:
	if not council_open:
		return
	council_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## Three blocs plus the vote. Support is derived from the saved investment map;
## the row also states what one more lobby would cost and buy. The vote row is
## present even when it cannot be called, with the rank or support still missing.
func council_rows() -> Array:
	var rank_id := _player_rank_id()
	var out: Array = []
	for value in SectPolitics.blocs():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		var result := SectPolitics.lobby(id, Game.sect_contribution, Game.sect_lobby)
		out.append({
			"kind": "bloc",
			"id": id,
			"label": String(entry.get("name", id)),
			"speaker": String(entry.get("speaker", "")),
			"agenda": String(entry.get("agenda", "")),
			"support": SectPolitics.support_for(id, Game.sect_lobby),
			"max": SectPolitics.max_for(id),
			"cost": int(entry.get("cost", 0)),
			"gain": int(entry.get("gain", 0)),
			"enabled": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
	var check := SectPolitics.can_vote(Game.sect_lobby, rank_id, Game.sect_seat_open)
	out.append({
		"kind": "vote",
		"id": "vote",
		"label": "Call the council vote",
		"speaker": "The hall",
		"agenda": "Open the master's seat to a challenge." if not Game.sect_seat_open else "The master's seat stands open.",
		"support": SectPolitics.total_support(Game.sect_lobby),
		"max": SectPolitics.threshold(),
		"cost": 0,
		"gain": 0,
		"enabled": bool(check.get("ok", false)),
		"reason": String(check.get("reason", "")),
	})
	return out


func _council_activate(index: int) -> void:
	var rows := council_rows()
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	if not bool(row.get("enabled", false)):
		var reason := String(row.get("reason", ""))
		if reason == "":
			Bus.toast.emit("The council refuses.")
		else:
			Bus.toast.emit("The council refuses: %s." % reason)
		return
	if String(row.get("kind", "")) == "bloc":
		_council_lobby(row)
	elif String(row.get("kind", "")) == "vote":
		_council_vote()


func _council_lobby(row: Dictionary) -> void:
	var result := SectPolitics.lobby(String(row.get("id", "")), Game.sect_contribution, Game.sect_lobby)
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The council refuses: %s." % String(result.get("reason", "")))
		return
	Game.sect_contribution = int(result.get("contribution", Game.sect_contribution))
	Game.sect_lobby = (result.get("invested", {}) as Dictionary).duplicate(true)
	Bus.toast.emit("%s support +%d. %s" % [String(row.get("label", "The bloc")),
		int(result.get("gain", 0)), SectPolitics.summary_line(Game.sect_lobby)])
	Bus.player_stats_changed.emit()


func _council_vote() -> void:
	var result := SectPolitics.vote(Game.sect_lobby, _player_rank_id(), Game.sect_seat_open)
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The council refuses: %s." % String(result.get("reason", "")))
		return
	Game.sect_seat_open = true
	Bus.toast.emit("The council opens the master's seat. The ladder now ends at the chair.")
	var station := Hierarchy.player_rank(player.cultivation.realm, Game.faction_standing, Game.notoriety,
		Hierarchy.seat_available(Game.sect_seat_open))
	if String(station.get("id", "")) == "rank.sect_master":
		Bus.toast.emit("The hall rises: you are Sect Master.")
	Bus.player_stats_changed.emit()


# ---------------------------------------------------------- player sect ----


func toggle_player_sect() -> void:
	if player_sect_open:
		_close_player_sect()
	else:
		_open_player_sect()


func _open_player_sect() -> void:
	if player == null or String(phase) != "play":
		return
	player_sect_open = true
	player_sect_index = clampi(player_sect_index, 0, maxi(0, player_sect_rows().size() - 1))
	player.set_physics_process(false)
	player.set_process(false)


func _close_player_sect() -> void:
	if not player_sect_open:
		return
	player_sect_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## The real people standing in the hall. A member who is not currently spawned
## simply does not appear and does not pay a levy that day.
func player_sect_members() -> Array:
	var out: Array = []
	if Game.player_sect.is_empty():
		return out
	var roster: Variant = Game.player_sect.get("members", [])
	if typeof(roster) != TYPE_ARRAY:
		return out
	for value in (roster as Array):
		var npc := _npc_by_id(String(value))
		if npc == null:
			continue
		out.append({
			"id": npc.npc_id,
			"name": npc.display_name,
			"realm": npc.realm,
			"rank": PlayerSect.member_rank(npc.realm),
		})
	return out


## The strongest present member keeps the hall while the player is away. This is
## derived, not appointed: the same roster always produces the same steward.
func player_sect_steward() -> Dictionary:
	var best: Dictionary = {}
	for value in player_sect_members():
		var member: Dictionary = value
		if best.is_empty() or int(member.get("realm", 1)) > int(best.get("realm", 1)):
			best = member
	return best


## The hall runs itself one day at a time, including days skipped by rest or
## travel. A reload starts from the saved autonomy day, so it can never reroll a
## bad event; the same seed, hall and day always produce the same day.
func _check_sect_autonomy() -> void:
	if String(phase) != "play" or Game.player_sect.is_empty():
		return
	var last := int(Game.player_sect.get("autonomy_day", Clock.day))
	if Clock.day <= last:
		return
	var result := SectAutonomy.settle_days(Game.player_sect, _player_sect_realms(), last + 1,
		Clock.day, Game.world_seed)
	Game.player_sect = (result.get("sect", Game.player_sect) as Dictionary).duplicate(true)
	var days := int(result.get("days", 0))
	if days <= 0:
		return
	var lines: Array = result.get("lines", [])
	if lines.is_empty():
		return
	if days == 1:
		Bus.toast.emit(String(lines[0]))
	else:
		Bus.toast.emit("The hall ran %d days: +%d levy, −%d upkeep." % [days,
			int(result.get("income", 0)), int(result.get("upkeep", 0))])
	Bus.player_stats_changed.emit()


func _player_sect_realms() -> Array:
	var realms: Array = []
	for value in player_sect_members():
		realms.append(int((value as Dictionary).get("realm", 1)))
	return realms


## Before founding: three doctrines with the cost and station still required.
## After: the daily levy and every friend who trusts the player enough to join.
## The roster and candidate rows are both live reads of the town, not a cache.
func player_sect_rows() -> Array:
	var out: Array = []
	if Game.player_sect.is_empty():
		var missing := PlayerSect.can_found(Game.player_sect, Game.spirit_stones, _player_rank_id())
		var reason := ", ".join(missing)
		for value in PlayerSect.doctrines():
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = value
			out.append({
				"kind": "doctrine",
				"id": String(entry.get("id", "")),
				"label": String(entry.get("sect_name", entry.get("name", ""))),
				"detail": "%s · capacity %d · levy +%d" % [String(entry.get("name", "")),
					int(entry.get("capacity", 0)), int(entry.get("tribute", 0))],
				"blurb": String(entry.get("blurb", "")),
				"enabled": missing.is_empty(),
				"reason": reason,
			})
		return out

	var candidates := 0
	for node in npcs:
		if not is_instance_valid(node):
			continue
		var npc := node as Npc
		if npc == null or npc.npc_id == "":
			continue
		if PlayerSect.is_member(Game.player_sect, npc.npc_id):
			continue
		if Game.party_ids.has(npc.npc_id) or _is_captive_id(npc.npc_id):
			continue
		var bond := int(npc.bond_to_player().get("score", 0))
		if not Relationships.warns(bond):
			continue
		if candidates >= 7:
			break
		var result := PlayerSect.can_recruit(Game.player_sect, npc.npc_id, bond,
			PlayerSect.member_count(Game.player_sect))
		out.append({
			"kind": "recruit",
			"id": npc.npc_id,
			"label": "Recruit %s" % npc.display_name,
			"detail": "%s · %s · %s (+%d)" % [Realms.name_of(npc.realm), PlayerSect.member_rank(npc.realm),
				npc.bond_label(), bond],
			"blurb": "A %d-stone gift from the treasury." % PlayerSect.recruit_cost(),
			"enabled": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
		candidates += 1
	if candidates == 0:
		out.append({
			"kind": "info",
			"id": "info",
			"label": "No candidates",
			"detail": "No friend in the market trusts you far enough to leave their hall yet.",
			"blurb": "",
			"enabled": false,
			"reason": "",
		})
	return out


func _player_sect_activate(index: int) -> void:
	var rows := player_sect_rows()
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	var kind := String(row.get("kind", ""))
	if kind == "info":
		return
	if kind == "doctrine":
		_found_player_sect(String(row.get("id", "")))
		return
	if not bool(row.get("enabled", false)):
		var reason := String(row.get("reason", ""))
		if reason == "":
			Bus.toast.emit("The hall refuses.")
		else:
			Bus.toast.emit("The hall refuses: %s." % reason)
		return
	if kind == "recruit":
		_recruit_player_sect_member(String(row.get("id", "")))


func _is_captive_id(npc_id: String) -> bool:
	for value in Game.captives:
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == npc_id:
			return true
	return false


func _found_player_sect(doctrine_id: String) -> void:
	if not PlayerSect.can_found(Game.player_sect, Game.spirit_stones, _player_rank_id()).is_empty():
		Bus.toast.emit("You cannot found a hall yet.")
		return
	var result := PlayerSect.found(doctrine_id, Game.spirit_stones, Clock.day)
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The hall refuses: %s." % String(result.get("reason", "")))
		return
	Game.spirit_stones = int(result.get("stones", Game.spirit_stones))
	Game.player_sect = (result.get("sect", {}) as Dictionary).duplicate(true)
	player_sect_index = 0
	Bus.toast.emit("%s is founded. The hall is yours." % String(Game.player_sect.get("name", "Your sect")))
	Bus.player_stats_changed.emit()


func _recruit_player_sect_member(npc_id: String) -> void:
	var npc := _npc_by_id(npc_id)
	if npc == null:
		Bus.toast.emit("They are no longer here to ask.")
		return
	var result := PlayerSect.recruit(Game.player_sect, npc_id, int(npc.bond_to_player().get("score", 0)),
		PlayerSect.member_count(Game.player_sect))
	if not bool(result.get("ok", false)):
		Bus.toast.emit("The hall refuses: %s." % String(result.get("reason", "")))
		return
	Game.player_sect = (result.get("sect", {}) as Dictionary).duplicate(true)
	Bus.toast.emit("%s joins %s as %s." % [npc.display_name, String(Game.player_sect.get("name", "the hall")),
		PlayerSect.member_rank(npc.realm)])
	Bus.player_stats_changed.emit()


## A quartermaster pill is a real consumable from the same base table alchemy
## uses. The purchase counter keeps every issued id stable and unique.
func _sect_service_item(entry: Dictionary) -> Dictionary:
	var base_id := String(entry.get("base", ""))
	if base_id == "":
		return {}
	var item := ItemGen.new(DB, Rng).generate(
		1, hash("sect." + String(entry.get("id", ""))), Game.sect_purchases, 0, "consumable", base_id)
	if item.is_empty():
		return {}
	item["count"] = 1
	item["potency"] = 1.0
	return Items.normalize_item(item)


# --------------------------------------------------------------- captivity ----


## The nearest beaten body within binding reach. A subdued cultivator is not in
## the interactable list: taking a person is a decision, not a door.
func _beaten_body_near() -> Dummy:
	if player == null or realm_instance != null:
		return null
	var best: Dummy = null
	var best_dist := Captivity.bind_reach()
	for value in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(value):
			continue
		var body := value as Dummy
		if body == null or not (body.can_be_bound() or body.weakened()):
			continue
		var dist := body.global_position.distance_to(player.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = body
	return best


## H: bind the beaten cultivator at your feet. The body leaves the world alive:
## no kill, no loot, and a record in the yard that the market will remember.
func _bind_captive() -> void:
	if player == null or String(phase) != "play" or realm_instance != null:
		return
	var body := _beaten_body_near()
	if body == null:
		Bus.toast.emit("No beaten cultivator is close enough to bind.")
		return
	var verdict := Captivity.can_bind(Game.captives)
	if not bool(verdict.get("ok", false)):
		Bus.toast.emit(String(verdict.get("reason", "You cannot take another.")))
		return
	# Two deliberate steps: beat them down, then decide. The kill still exists as
	# the third option — strike a subdued body and it dies as any enemy would.
	if not body.can_be_bound():
		if not body.subdue():
			Bus.toast.emit("%s is still standing." % body.display_name)
			return
		Bus.toast.emit("%s drops to their knees. Press H to bind them, or strike to finish it." % body.display_name)
		return
	Game.captive_seq += 1
	var record := Captivity.new_record(
		"captive.%d.%d" % [Clock.day, Game.captive_seq],
		_random_name(),
		maxi(1, body.ilvl),
		0, Clock.day, Game.captive_policy)
	Game.captives.append(record)
	Game.notoriety = mini(Captivity.notoriety_cap(),
		Game.notoriety + Captivity.capture_notoriety())
	body.queue_free()
	Bus.toast.emit("%s is bound and sent to the holding yard. (%d/%d held)" % [
		String(record.get("name", "The cultivator")), Game.captives.size(), Captivity.max_held()])
	Bus.player_stats_changed.emit()


func toggle_captives() -> void:
	if captives_open:
		_close_captives()
		return
	_open_captives()


func _open_captives() -> void:
	if player == null or String(phase) != "play" or realm_instance != null:
		return
	if Game.captives.is_empty():
		Bus.toast.emit("The holding yard is empty. (H binds a beaten cultivator.)")
		return
	captives_open = true
	captive_index = clampi(captive_index, 0, Game.captives.size() - 1)
	player.set_physics_process(false)
	player.set_process(false)


func _close_captives() -> void:
	if not captives_open:
		return
	captives_open = false
	if player != null:
		player.set_physics_process(true)
		player.set_process(true)


## ENTER in the ledger: sell the person's sentence to the watch. The bounty is
## paid in stones and the market forgets a little of what it knew.
func _hand_over_captive(index: int) -> void:
	if index < 0 or index >= Game.captives.size():
		return
	var record: Dictionary = Game.captives[index]
	var paid := Captivity.bounty(record)
	Game.spirit_stones += paid
	Game.notoriety = maxi(0, Game.notoriety - Captivity.handover_relief())
	var name := String(record.get("name", "The captive"))
	Game.captives.remove_at(index)
	captive_index = clampi(captive_index, 0, maxi(0, Game.captives.size() - 1))
	Bus.toast.emit("%s is handed to the watch. You are paid %d stones. (%s)" % [
		name, paid, Captivity.legal_label(Game.notoriety)])
	Bus.player_stats_changed.emit()
	if Game.captives.is_empty():
		_close_captives()


## U in the ledger: unbind them. Cheaper than a handover, and the mercy is not
## free of consequence — the watch still remembers the yard existed.
func _release_captive(index: int) -> void:
	if index < 0 or index >= Game.captives.size():
		return
	var record: Dictionary = Game.captives[index]
	var name := String(record.get("name", "The captive"))
	Game.captives.remove_at(index)
	Game.notoriety = maxi(0, Game.notoriety - Captivity.release_relief())
	captive_index = clampi(captive_index, 0, maxi(0, Game.captives.size() - 1))
	Bus.toast.emit("%s is unbound and walks out of the yard." % name)
	if Game.captives.is_empty():
		_close_captives()


## TAB in the ledger: the terms apply to everyone held, because a yard with two
## rulebooks is a yard that cannot be reasoned about.
func _cycle_captive_policy() -> void:
	var ids := Captivity.policy_ids()
	if ids.is_empty():
		return
	var current := ids.find(Game.captive_policy)
	var next := String(ids[0]) if current < 0 else String(ids[(current + 1) % ids.size()])
	Game.captive_policy = next
	for value in Game.captives:
		if typeof(value) == TYPE_DICTIONARY:
			(value as Dictionary)["policy"] = next
	Bus.toast.emit("Terms: %s — %s" % [Captivity.policy_name(next), Captivity.policy_blurb(next)])


## A day with no keeper in it still passes: loyalty drifts, rations are paid,
## people run. Days jumped by rest or travel are settled one at a time.
func _check_captivity() -> void:
	if String(phase) != "play":
		return
	if _captive_day == 0:
		_captive_day = Clock.day
		return
	var guard := 0
	while _captive_day < Clock.day and guard < 60:
		_captive_day += 1
		guard += 1
		_settle_captive_day(_captive_day)
	if _captive_day < Clock.day:
		_captive_day = Clock.day


func _settle_captive_day(day: int) -> void:
	if not Captivity.enabled():
		return
	if Game.captives.is_empty():
		Game.notoriety = maxi(0, Game.notoriety - Captivity.notoriety_decay())
		return
	var result := Captivity.settle_day(Game.captives, day, Game.spirit_stones)
	var kept: Variant = result.get("records", [])
	Game.captives = (kept as Array).duplicate(true) if typeof(kept) == TYPE_ARRAY else []
	Game.spirit_stones = maxi(0, Game.spirit_stones + int(result.get("net", 0)))
	Game.notoriety = clampi(Game.notoriety + int(result.get("notoriety", 0)),
		0, Captivity.notoriety_cap())
	var escaped: Array = result.get("escaped", [])
	if bool(result.get("rebellion", false)):
		if player != null and player.hp_max > 0.0:
			player.hp = maxf(1.0, player.hp - player.hp_max * Captivity.rebellion_harm())
		Bus.toast.emit("The yard rebels! The desperate scatter, and you are struck in the scramble.")
	elif not escaped.is_empty():
		Bus.toast.emit("Captivity: %s slipped the guards in the night." % ", ".join(escaped))
	else:
		Bus.toast.emit("The yard yields %d stones; rations take %d." % [
			int(result.get("labor", 0)), int(result.get("paid", 0))])
	if Game.captives.is_empty():
		Bus.toast.emit("The holding yard stands empty.")
	Bus.player_stats_changed.emit()


## One row per captive for the ledger and the summary panel. Every number is
## asked of `Captivity`, so the screen cannot disagree with the day's settlement.
func captive_rows() -> Array:
	var out: Array = []
	for value in Game.captives:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = value
		var loyalty := Captivity.loyalty_of(record)
		out.append({
			"name": String(record.get("name", "?")),
			"realm": maxi(1, int(record.get("realm", 1))),
			"loyalty": loyalty,
			"band": Captivity.loyalty_label(loyalty),
			"colour": Captivity.loyalty_colour(loyalty),
			"labor": Captivity.daily_labor(record),
			"upkeep": Captivity.upkeep(record),
			"escape": Captivity.escape_chance(record, Game.captives.size()),
			"bounty": Captivity.bounty(record),
			"held": maxi(0, Clock.day - int(record.get("bound_day", Clock.day))),
		})
	return out


func _nearest_interactable() -> Node:
	var best: Node = null
	var best_dist := 96.0
	for npc in npcs:
		if realm_instance != null:
			break
		if not is_instance_valid(npc):
			continue
		var dist: float = (npc as Node2D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	for node in _active_interactables():
		if not is_instance_valid(node) or not node.can_interact():
			continue
		var dist: float = (node as Node2D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


func interaction_prompt() -> String:
	if player == null or phase == "creation":
		return ""
	# A beaten body is a decision, not furniture: it outranks the talk prompt.
	var beaten := _beaten_body_near()
	if beaten != null:
		if beaten.can_be_bound():
			return "H  Bind %s (beaten)  ·  L captives  (%d/%d held)" % [
				beaten.display_name, Game.captives.size(), Captivity.max_held()]
		var health := roundi(beaten.hp / maxf(1.0, beaten.hp_max) * 100.0)
		return "H  Subdue %s (%d%% health)  ·  L captives" % [beaten.display_name, health]
	var best := _nearest_interactable()
	if best == null:
		return ""
	if best is Npc:
		var npc := best as Npc
		var drowsy := "" if npc.is_awake() else "  — asleep"
		var hint := ""
		if npc.in_party:
			hint = "  ·  P dismiss"
		elif Party.willing(int(npc.bond_to_player().get("score", 0))):
			hint = "  ·  P recruit"
		return "E  Talk to %s (%s)%s%s" % [npc.display_name, npc.role, drowsy, hint]
	var interactable := best as Interactable
	if interactable.kind == Interactable.Kind.STORAGE:
		return "E  %s  (%d/%d kinds stored)" % [interactable.display_label(), storage.slots_used(), Storage.CAPACITY]
	return "E  %s" % interactable.display_label()


func _try_interact() -> void:
	var best := _nearest_interactable()
	if best == null:
		return
	if best is Npc:
		_talk(best as Npc)
	elif best is Interactable:
		_use_interactable(best as Interactable)


## Rui sells one cut to anyone who meets its requirements and can pay.
func _open_meridian() -> void:
	var next := Meridians.next_available(player.cultivation.meridians, player.cultivation.realm)
	if next.is_empty():
		Bus.toast.emit("The hall has nothing your realm can still open.")
		return
	var meridian_id := String(next.get("id", ""))
	var stones := Meridians.stone_cost(meridian_id)
	if Game.spirit_stones < stones:
		Bus.toast.emit("The hall asks %d stones for the %s." % [stones, String(next.get("name", meridian_id))])
		return
	var qi_cost := Meridians.qi_cost(meridian_id, player.cultivation.qi_max(player.stats))
	if player.cultivation.qi < qi_cost:
		Bus.toast.emit("You lack the Qi to force the %s open." % String(next.get("name", meridian_id)))
		return
	Game.spirit_stones -= stones
	player.cultivation.qi -= qi_cost
	if not player.cultivation.open_meridian(meridian_id):
		return
	player.rebuild_stats()
	Bus.toast.emit("Meridian opened: %s (+%s %s)." % [
		String(next.get("name", meridian_id)), String(next.get("stat", "")), str(next.get("value", 0))])
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()


## Bank one preparation for the next breakthrough. The attempt itself spends
## it, win or lose, so this is a decision rather than a permanent buff.
func _prepare_tribulation() -> void:
	if player.cultivation.preparation >= Cultivation.MAX_PREPARATION:
		Bus.toast.emit("Your body can hold no more preparation.")
		return
	if Game.spirit_stones < Cultivation.PREP_COST:
		Bus.toast.emit("Preparation costs %d stones." % Cultivation.PREP_COST)
		return
	Game.spirit_stones -= Cultivation.PREP_COST
	player.cultivation.prepare()
	Bus.toast.emit("Prepared for tribulation. (%d/%d)" % [player.cultivation.preparation, Cultivation.MAX_PREPARATION])
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()


## G at the peak starts the realm's playable tribulation; G anywhere else keeps
## the old immediate refusals and apex guard.
func _face_tribulation() -> void:
	if tribulation_arena != null:
		Bus.toast.emit("You are already standing in the tribulation.")
		return
	if not player.cultivation.is_peak() or player.cultivation.realm >= Realms.count():
		player.attempt_breakthrough()
		return
	if not player.cultivation.is_full(player.stats):
		Bus.toast.emit("Your Qi is not full. Heaven will not answer half a challenge.")
		return
	_start_tribulation()


func _start_tribulation() -> void:
	var type_id := player.cultivation.tribulation_id()
	var scale := player.cultivation.tribulation_with(Game.kills, Game.karma, player.method_state())
	var arena := TribulationArena.new()
	tribulation_arena = arena
	world.add_child(arena)
	var seed_value := Game.world_seed + player.cultivation.realm * 131 + player.cultivation.breakthrough_attempts
	arena.begin(player, type_id, scale, player.global_position, seed_value)
	Bus.toast.emit("%s. Survive every wave." % Tribulation.name_of(type_id))
	Bus.toast.emit("A perfect wave adds +4%% to the roll, up to +12%%.")


func _on_tribulation_finished(result: Dictionary) -> void:
	tribulation_arena = null
	var outcome := String(result.get("outcome", ""))
	if outcome == "survived":
		Bus.toast.emit("The tribulation passes: %d/%d waves, %d hit%s." % [
			int(result.get("waves_survived", 0)), int(result.get("waves_total", 0)),
			int(result.get("hits", 0)), "" if int(result.get("hits", 0)) == 1 else "s"])
		# Facing heaven and walking away is itself a lesson.
		player.gain_comprehension(20.0)
		player.attempt_breakthrough(float(result.get("composure", 0.0)))
	elif outcome == "broken":
		player.fail_breakthrough()
	else:
		Bus.toast.emit("The tribulation fades unresolved.")


func _cycle_method() -> void:
	var state := player.method_state()
	var next_id := Methods.next(player.cultivation.method_id, state)
	if next_id == "":
		Bus.toast.emit("The stele shows you nothing you qualify for.")
		return
	if next_id == player.cultivation.method_id:
		Bus.toast.emit("No other method answers you yet.")
		return
	if Game.spirit_stones < Methods.SWITCH_COST:
		Bus.toast.emit("The stele wants %d stones to reshape a meridian." % Methods.SWITCH_COST)
		return
	Game.spirit_stones -= Methods.SWITCH_COST
	player.cultivation.method_id = next_id
	var method: Dictionary = DB.by_id("method", next_id)
	Bus.toast.emit("The stele reshapes your circulation: %s." % String(method.get("name", next_id)))
	Bus.cultivation_changed.emit()


func _teach_technique() -> void:
	var tech_id := "tech.sword.falling_petal"
	var price := 180
	var tech: Dictionary = DB.technique(tech_id)
	if player.technique_ids.has(tech_id):
		Bus.toast.emit("Instructor Rui: \"You already carry that cut. Show it to me one day.\"")
		return
	var check := Techniques.can_learn(tech_id, player.technique_state())
	if not bool(check["ok"]):
		Bus.toast.emit("Instructor Rui: \"Come back when you are %s.\"" % String(check["reason"]))
		return
	if Game.spirit_stones < price:
		Bus.toast.emit("Instructor Rui: \"%d stones, and not one less.\"" % price)
		return
	var learned := player.try_learn_technique(tech_id)
	if not bool(learned["ok"]):
		Bus.toast.emit("Instructor Rui: \"%s.\"" % String(learned["reason"]))
		return
	Game.spirit_stones -= price
	Bus.toast.emit("Instructor Rui teaches %s. (-%d stones)" % [String(tech.get("name", tech_id)), price])
	Bus.cultivation_changed.emit()


func _talk(npc: Npc) -> void:
	if npc == null:
		return
	# A routine is not decoration: a sleeping body cannot be spoken to, and a
	# teacher away from the yard has no lesson to give.
	if not npc.is_awake():
		Bus.toast.emit("%s is asleep. The routine will bring them back." % npc.display_name)
		return
	# An alarmed body answers with the alarm, not with its trade, and the moment
	# is not a conversation worth remembering.
	if npc.reacting():
		Bus.toast.emit("%s: \"%s\"" % [npc.display_name, npc.warning_line()])
		return
	# The watch keeps its own ledger. A name bad enough closes the guard's mouth.
	if npc.role == "Guard" and Captivity.wanted(Game.notoriety):
		Bus.toast.emit("%s: \"The watch knows what you keep in that yard. Move along.\"" % npc.display_name)
		return
	# A person who has decided against you does not pretend otherwise, and the
	# moment is not a conversation worth remembering.
	var bond: Dictionary = npc.bond_to_player()
	if Relationships.refuses(int(bond.get("score", 0))):
		Bus.toast.emit("%s turns away. (%s)" % [npc.display_name, String(bond.get("label", "Enemy"))])
		return
	# Every real conversation is remembered: a merchant with nothing to sell still
	# remembers being spoken to.
	NpcDb.remember(Game.npc_memory, npc.npc_id, Clock.day)
	# Someone in the market has heard where the rift breathes. The first
	# conversation of a day can carry the rumor, even if the realm is already
	# known by then the call does nothing.
	_hear_realm_rumor(npc.display_name)
	# A request answered in person: the pill changes hands before the greeting.
	var story_index := Stories.deliver_index(Game.story_offers, npc.npc_id)
	if story_index >= 0 and _story_has_item(String((Game.story_offers[story_index] as Dictionary).get("target", ""))):
		_story_deliver(story_index, npc)
		return
	var story_suffix := _story_suffix(npc)
	if npc.npc_id == "instructor_rui":
		if not npc.teaches_here():
			Bus.toast.emit("Instructor Rui is %s at the %s. He teaches in the training yard from 08:00 to 12:00." % [
				Schedules.activity_label(npc.current_activity), npc.current_location.replace("_", " ")])
			return
		_teach_technique()
		return
	if npc.npc_id != "elder_bai":
		var line := "%s (%s): \"%s\"" % [
			npc.display_name, npc.role, Schedules.small_talk(npc.current_activity)]
		# The band colours the greeting: a friend's face is not a stranger's.
		var greeting := Relationships.greeting(String(bond.get("band", "")))
		if greeting != "":
			line += " " + greeting
		line += story_suffix
		Bus.toast.emit(line)
		return

	if quests.completed:
		Bus.toast.emit("Elder Bai: \"You are Azure Cloud now. Climb, and do not look down.\"" + story_suffix)
		return

	var advanced := quests.track("talk", "elder_bai")
	advanced = quests.track("return", "elder_bai") or advanced
	if quests.completed:
		_grant_reward()
	elif advanced:
		_toast_new_objective()
	else:
		Bus.toast.emit(("Elder Bai: \"%s\"" % quests.objective_text()) + story_suffix)


func _use_interactable(node: Interactable) -> void:
	match node.kind:
		Interactable.Kind.HERB:
			if node.used:
				return
			_mark_spent(node)
			var herb := _make_herb()
			player.inventory.append(herb)
			Bus.item_picked.emit(herb)
			var before := quests.step_index
			quests.track("collect", "spirit_herb", 1)
			Bus.toast.emit("Gathered a spirit herb.")
			if quests.step_index != before:
				_toast_new_objective()
		Interactable.Kind.SHRINE:
			var before := quests.step_index
			quests.track("channel", "shrine")
			if quests.step_index != before:
				_toast_new_objective()
			else:
				Bus.toast.emit("The shrine hums. Your meridians settle.")
			if player.cultivation.contamination > 0.0:
				if Game.spirit_stones >= Meridians.CLEANSE_COST:
					Game.spirit_stones -= Meridians.CLEANSE_COST
					player.cultivation.cleanse(Meridians.MAX_CONTAMINATION)
					Bus.toast.emit("The shrine burns the impurity from your channels. (-%d stones)" % Meridians.CLEANSE_COST)
				else:
					Bus.toast.emit("The shrine could purge you, for %d stones." % Meridians.CLEANSE_COST)
			cultivation_restore()
		Interactable.Kind.PORTAL:
			if node.id == "realm.exit":
				_exit_realm()
			else:
				_try_enter_realm(String(node.id))
		Interactable.Kind.CHEST:
			if node.used:
				return
			# A realm chest uses its family's table and tier, not a global default.
			var chest_table := "chest.sealed"
			var chest_ilvl := 6
			if realm_instance != null and is_instance_valid(realm_instance):
				chest_table = realm_instance.loot_table
				chest_ilvl = maxi(2, realm_instance.enemy_ilvl)
			_loot(node, chest_ilvl, "sealed chest", chest_table)
		Interactable.Kind.ALTAR:
			_claim_inheritance()
		Interactable.Kind.DOOR:
			node.open = not node.open
			if node.building != null:
				node.building.set_interior_open(node.open)
			Bus.toast.emit("%s %s." % [node.label, "opens" if node.open else "closes"])
		Interactable.Kind.CONTAINER:
			if node.used:
				return
			_loot(node, maxi(2, player.cultivation.realm + 1), node.label.to_lower(), "chest.common")
		Interactable.Kind.MANUAL:
			if node.used:
				return
			if node.manual_passive != "":
				var learned := player.try_learn_passive(node.manual_passive)
				if not bool(learned["ok"]):
					Bus.toast.emit("The manual will not open to you: %s required." % String(learned["reason"]))
					return
				node.used = true
				var passive: Dictionary = DB.passive(node.manual_passive)
				Bus.toast.emit("You study the manual. Passive learned: %s." % String(passive.get("name", node.manual_passive)))
				Bus.player_stats_changed.emit()
				return
			if player.learn_technique(node.manual_technique):
				node.used = true
				var tech: Dictionary = DB.technique(node.manual_technique)
				Bus.toast.emit("You study the manual. Technique learned: %s." % String(tech.get("name", node.manual_technique)))
				Bus.cultivation_changed.emit()
			else:
				Bus.toast.emit("You already know what this manual teaches.")
		Interactable.Kind.METHOD:
			_cycle_method()
		Interactable.Kind.MERIDIAN:
			_open_meridian()
		Interactable.Kind.TRIBULATION:
			_prepare_tribulation()
		Interactable.Kind.DEMONSTRATION:
			var watched := player.observe_technique(node.demo_technique)
			var demo: Dictionary = DB.technique(node.demo_technique)
			if bool(watched.get("learned", false)):
				Bus.toast.emit("You have watched the cut often enough. Technique learned: %s." % String(demo.get("name", node.demo_technique)))
				Bus.cultivation_changed.emit()
			elif bool(watched["ok"]):
				Bus.toast.emit("You watch the cut. Understanding %d%%." % roundi(float(watched["progress"]) * 100.0))
			elif String(watched["reason"]) == "already known":
				Bus.toast.emit("You already know the cut; there is nothing left to watch.")
			else:
				Bus.toast.emit("The disciple's cut is beyond you: %s required." % String(watched["reason"]))
		Interactable.Kind.EXAMINE:
			if node.id == "board.market":
				_hear_realm_rumor("The notice board")
			Bus.toast.emit(node.examine_text)
		Interactable.Kind.SHOP:
			_open_shop()
		Interactable.Kind.INN:
			_rest_at_inn()
		Interactable.Kind.STORAGE:
			_open_storage()
		Interactable.Kind.FORGE:
			_open_forge()
		Interactable.Kind.ALCHEMY:
			_open_alchemy()
		Interactable.Kind.RUIN:
			if node.used:
				return
			_loot(node, 5, "ruin cache", "chest.ruin")
			if Roots.marrow_found(node.chunk_coord, "ruin"):
				player.pick_up(_make_marrow())
				Bus.toast.emit("Among the rubble: a knot of root marrow.")
			_award_discovery(node, 40)
		Interactable.Kind.MINE:
			if node.used:
				return
			_mark_spent(node)
			player.pick_up(_make_ore())
			Bus.toast.emit("Mined spirit ore from the vein.")
			if Roots.marrow_found(node.chunk_coord, "mine"):
				player.pick_up(_make_marrow())
				Bus.toast.emit("A knot of root marrow comes loose from the rock.")
			_award_discovery(node, 25)
		Interactable.Kind.DEPOSIT:
			if node.used:
				return
			_mark_spent(node)
			Game.spirit_stones += 25
			Bus.player_stats_changed.emit()
			Bus.toast.emit("Gathered 25 spirit stones from the deposit.")
			_award_discovery(node, 15)
		Interactable.Kind.ROOT:
			_use_root_pavilion()


## Spends a node: streamed resources record a chunk delta with their own regrow
## window, unique world nodes go into the saved one-shot list.
func _mark_spent(node: Interactable) -> void:
	node.used = true
	if node.chunk_owned:
		world_delta.mark_spent(node.chunk_coord, node.id, Clock.day, node.regrow_days)
	elif not used_interactables.has(node.id):
		used_interactables.append(node.id)


## One-shot loot shared by chests, containers and ruins. The table decides how
## many pieces and how good; the node's stable id is the roll's key, so looting it
## again after a reload is impossible.
func _loot(node: Interactable, ilvl: int, verb: String, table_id: String = "chest.common") -> void:
	_mark_spent(node)
	var result := Loot.new(DB, Rng).roll(table_id, maxi(1, ilvl), hash(node.id), ground_items.size())
	var items: Array = result.get("items", [])
	if items.is_empty():
		Bus.toast.emit("The %s is empty." % verb)
		return
	var names: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i]
		ground_items.append({
			"x": node.global_position.x + float(i) * 10.0,
			"y": node.global_position.y + 30.0,
			"item": item,
		})
		Bus.item_dropped.emit(item, node.global_position)
		names.append(String(item.get("name", "?")))
	Bus.toast.emit("The %s holds %s." % [verb, ", ".join(names)])


func cultivation_restore() -> void:
	player.cultivation.qi = player.cultivation.qi_max(player.stats)
	Bus.cultivation_changed.emit()


## First visit to a site pays once, ever: `Game.discovered` is saved with the run.
func _award_discovery(node: Interactable, reward: int) -> void:
	if not Game.discover(node.id):
		return
	travel_sites[node.id] = {
		"name": node.label,
		"x": node.global_position.x,
		"y": node.global_position.y,
	}
	Game.spirit_stones += reward
	Bus.toast.emit("Discovery — %s (+%d spirit stones)." % [node.label, reward])


# ------------------------------------------------------------- roots ----

## Appraises an unread root, then evolves it one tier for marrow and stones.
## Repeatable: the pavilion is not consumed, and the prompt is honest about why a
## step is unavailable.
func _use_root_pavilion() -> void:
	if player == null:
		return
	var cultivation := player.cultivation
	if not cultivation.identified:
		if Game.spirit_stones < Roots.IDENTIFY_COST:
			Bus.toast.emit("Appraisal costs %d spirit stones. You have %d." % [Roots.IDENTIFY_COST, Game.spirit_stones])
			return
		Game.spirit_stones -= Roots.IDENTIFY_COST
		cultivation.identified = true
		var before := cultivation.qi_max(player.stats)
		player.rebuild_stats()
		cultivation.qi = minf(cultivation.qi, cultivation.qi_max(player.stats))
		Bus.player_stats_changed.emit()
		Bus.cultivation_changed.emit()
		Bus.toast.emit("The pavilion reads your root: %s. Qi capacity %d -> %d." % [
			Roots.describe(cultivation.root_data(), cultivation.effective_purity()),
			int(before), int(cultivation.qi_max(player.stats)),
		])
		return

	var tier := cultivation.root_tier
	var check := Roots.can_evolve(tier, _marrow_count(), Game.spirit_stones)
	if not bool(check["ok"]):
		match String(check["reason"]):
			"max_tier":
				Bus.toast.emit("Your root is already at the twelfth tier.")
			"no_marrow":
				Bus.toast.emit("Evolution needs Spirit Root Marrow. Mines and ruins sometimes hold it.")
			"no_stones":
				Bus.toast.emit("Evolution costs %d spirit stones. You have %d." % [int(check["cost"]), Game.spirit_stones])
		return
	_consume_marrow()
	Game.spirit_stones -= int(check["cost"])
	cultivation.root_tier = mini(Roots.MAX_TIER, tier + 1)
	player.rebuild_stats()
	cultivation.qi = minf(cultivation.qi, cultivation.qi_max(player.stats))
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()
	Bus.toast.emit("Your root evolves — %s." % Roots.describe(cultivation.root_data(), cultivation.effective_purity()))


func _make_marrow(count: int = 1) -> Dictionary:
	return {
		"id": "item.marrow.spirit.%d" % player.inventory.size(),
		"name": "Spirit Root Marrow",
		"base_name": "Spirit Root Marrow",
		"slot": "material",
		"material": "marrow",
		"ilvl": 3,
		"rarity": 2,
		"rarity_name": "Rare",
		"implicit": "Root evolution reagent",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 60,
		"count": maxi(1, count),
	}


func _marrow_count() -> int:
	var count := 0
	for item in player.inventory:
		if String(item.get("id", "")).begins_with("item.marrow"):
			count += 1
	return count


func _consume_marrow() -> void:
	for i in player.inventory.size():
		if String(player.inventory[i].get("id", "")).begins_with("item.marrow"):
			player.inventory.remove_at(i)
			return


func _make_ore(count: int = 1) -> Dictionary:
	return {
		"id": "item.ore.spirit.%d" % player.inventory.size(),
		"name": "Spirit Ore",
		"base_name": "Spirit Ore",
		"slot": "material",
		"material": "ore",
		"ilvl": 2,
		"rarity": 1,
		"rarity_name": "Refined",
		"implicit": "Forging ingredient",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 22,
		"count": maxi(1, count),
	}


func _make_herb(count: int = 1) -> Dictionary:
	return {
		"id": "item.herb.spirit.%d" % player.inventory.size(),
		"name": "Spirit Herb",
		"base_name": "Spirit Herb",
		"slot": "material",
		"material": "herb",
		"ilvl": 1,
		"rarity": 1,
		"rarity_name": "Refined",
		"implicit": "Alchemy ingredient",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": 12,
		"count": maxi(1, count),
	}


func _toast_new_objective() -> void:
	Bus.toast.emit("Quest — %s" % quests.objective_text())


func _grant_reward() -> void:
	if quests.rewarded:
		return
	quests.rewarded = true
	var reward: Dictionary = quests.quest.get("reward", {})
	var technique_id := String(reward.get("technique", ""))
	if player.learn_technique(technique_id):
		var tech: Dictionary = DB.technique(technique_id)
		Bus.toast.emit("Inherited technique: %s" % String(tech.get("name", technique_id)))
	var passive_id := String(reward.get("passive", ""))
	if player.add_passive(passive_id):
		var passive: Dictionary = DB.passive(passive_id)
		Bus.toast.emit("Passive awakened: %s" % String(passive.get("name", passive_id)))
	Game.spirit_stones += int(reward.get("spirit_stones", 0))
	# The sect keeps a record of who carried its invitation: a completed quest is
	# the largest single act of standing in the game.
	Game.faction_standing = Factions.award(Game.faction_standing, "faction.azure_cloud", Factions.quest_award())
	Game.sect_contribution = SectEconomy.award_contribution(Game.sect_contribution, SectEconomy.quest_award())
	Bus.toast.emit("Azure Cloud Sect remembers: %s (+%d contribution)" % [Factions.describe(
		"faction.azure_cloud", Game.faction_standing, Game.notoriety), SectEconomy.quest_award()])
	Bus.player_stats_changed.emit()


## The altar is guarded, not merely hidden. This is the whole gate: no claim
## while the warden stands, whatever the player has cleared elsewhere.
func _warden_blocks_altar() -> bool:
	if realm_instance == null or not is_instance_valid(realm_instance):
		return false
	return realm_instance.has_warden()


func _claim_inheritance() -> void:
	if _warden_blocks_altar():
		Bus.toast.emit("The warden still holds the altar. It must fall first.")
		return
	var site := _realm_site(active_realm_id)
	if site.is_empty():
		return
	var site_id := String(site.get("id", ""))
	if _inheritance_claimed(site_id):
		Bus.toast.emit("The altar is cold. Its legacy has already been claimed.")
		return
	if not inheritance_trial.is_empty():
		Bus.toast.emit("The altar is still deciding. %s" % inheritance_trial_line())
		return
	var offer := Inheritances.offer(String(site.get("family", "")), active_realm_seed, player.inheritance_state())
	var entry_value: Variant = offer.get("entry", {})
	var entry: Dictionary = entry_value if typeof(entry_value) == TYPE_DICTIONARY else {}
	if entry.is_empty():
		Bus.toast.emit("The altar refuses you: %s." % String(offer.get("reason", "your path does not resonate")))
		return
	_start_inheritance_trial(site, entry)


## Compatibility is checked before the trial starts, so an incompatible body is
## never sent into a fight it cannot win the right to lose.
func _start_inheritance_trial(site: Dictionary, entry: Dictionary) -> void:
	if realm_instance == null or player == null:
		return
	var family := HiddenRealms.family(String(site.get("family", "")))
	var tier := Inheritances.trial_tier(entry, int(family.get("enemy_ilvl", 2)))
	var trial := Inheritances.trial_of(entry)
	var base := realm_instance.altar_position()
	var roster: Array = realm_instance.enemy_roster
	if roster.is_empty():
		roster = ["sentinel", "skirmisher", "archer", "brawler"]
	for i in int(trial["guards"]):
		var angle := TAU * float(i) / float(int(trial["guards"]))
		var at := base + Vector2(cos(angle) * 150.0, sin(angle) * 120.0)
		var archetype := String(roster[i % roster.size()])
		var guard := realm_instance.spawn_trial_guard(archetype, at, tier, "Trial Echo")
		if guard != null:
			inheritance_trial_nodes.append(guard)
	if bool(trial["rival"]):
		var rival := realm_instance.spawn_trial_guard("brawler", base + Vector2(0, -150), tier + 1, "Rival Seeker", true)
		if rival != null:
			inheritance_trial_nodes.append(rival)
	inheritance_trial = {
		"site_id": String(site.get("id", "")),
		"entry": entry,
		"seconds": float(trial["seconds"]),
		"cleared": false,
	}
	Bus.toast.emit("The altar offers %s (%s). Trial: %s." % [
		String(entry.get("name", "an inheritance")),
		Inheritances.rarity_name(int(entry.get("rarity", 0))),
		Inheritances.trial_label(entry),
	])


## The trial ticks only while play is live. The timer is the pressure; killing
## every echo, including the rival, is the pass condition.
func _tick_inheritance_trial(delta: float) -> void:
	if inheritance_trial.is_empty() or bool(inheritance_trial.get("cleared", false)):
		return
	var left := float(inheritance_trial.get("seconds", 0.0)) - delta
	inheritance_trial["seconds"] = left
	if left <= 0.0:
		_fail_inheritance_trial()
		return
	if _alive_trial_guards() > 0:
		return
	inheritance_trial["cleared"] = true
	var site := _realm_site(String(inheritance_trial.get("site_id", "")))
	var entry_value: Variant = inheritance_trial.get("entry", {})
	var entry: Dictionary = entry_value if typeof(entry_value) == TYPE_DICTIONARY else {}
	_finish_inheritance(site, entry)


func _alive_trial_guards() -> int:
	var alive := 0
	for node in inheritance_trial_nodes:
		if not is_instance_valid(node):
			continue
		var body := node as Dummy
		if body != null and body.hp > 0.0:
			alive += 1
	return alive


func _fail_inheritance_trial() -> void:
	var entry_value: Variant = inheritance_trial.get("entry", {})
	var entry: Dictionary = entry_value if typeof(entry_value) == TYPE_DICTIONARY else {}
	_clear_inheritance_trial()
	Bus.toast.emit("The trial closes. %s returns to the altar." % String(entry.get("name", "The inheritance")))


func _clear_inheritance_trial() -> void:
	for node in inheritance_trial_nodes:
		if is_instance_valid(node):
			node.queue_free()
	inheritance_trial_nodes.clear()
	inheritance_trial = {}


## A one-line status the HUD can draw without knowing the trial's rules.
func inheritance_trial_line() -> String:
	if inheritance_trial.is_empty():
		return ""
	var entry_value: Variant = inheritance_trial.get("entry", {})
	var entry: Dictionary = entry_value if typeof(entry_value) == TYPE_DICTIONARY else {}
	var left := maxi(0, int(ceil(float(inheritance_trial.get("seconds", 0.0)))))
	var alive := _alive_trial_guards()
	return "INHERITANCE TRIAL — %s · %ds · %d %s remain" % [
		String(entry.get("name", "Legacy")), left, alive, "echo" if alive == 1 else "echoes"
	]


func _inheritance_claimed(site_id: String) -> bool:
	if site_id == "":
		return false
	if site_id == RealmAccess.default_id() and inheritance_taken:
		return true
	return inheritances_taken.has(site_id)


func _finish_inheritance(site: Dictionary, entry: Dictionary) -> void:
	if player == null or site.is_empty() or entry.is_empty():
		_clear_inheritance_trial()
		return
	var site_id := String(site.get("id", ""))
	if _inheritance_claimed(site_id):
		_clear_inheritance_trial()
		return
	var compatibility := Inheritances.check(entry, player.inheritance_state())
	if not bool(compatibility.get("ok", false)):
		_clear_inheritance_trial()
		Bus.toast.emit("The legacy slips away: %s." % String(compatibility.get("reason", "incompatible")))
		return
	var grants_value: Variant = entry.get("grants", {})
	var grants: Dictionary = grants_value if typeof(grants_value) == TYPE_DICTIONARY else {}
	var learned := player.learn_technique(String(grants.get("technique", "")))
	var gained := player.add_passive(String(grants.get("passive", "")))
	var inherited := false
	var physique := String(grants.get("physique", ""))
	if physique != "":
		inherited = player.inherit_physique(physique)
	_mark_inheritance_taken(site_id)
	if site_id == RealmAccess.default_id():
		realm_cleared = true
	if realm_instance != null and is_instance_valid(realm_instance):
		realm_instance.mark_cleared()
	_clear_inheritance_trial()
	var rarity := Inheritances.rarity_name(int(entry.get("rarity", 0)))
	Bus.toast.emit("Inheritance — %s (%s)." % [String(entry.get("name", "Legacy")), rarity])
	if learned:
		var tech := DB.technique(String(grants.get("technique", "")))
		Bus.toast.emit("Technique: %s." % String(tech.get("name", "a hidden art")))
	if gained:
		var passive := DB.passive(String(grants.get("passive", "")))
		Bus.toast.emit("Passive: %s." % String(passive.get("name", "a new constitution")))
	if inherited:
		Bus.toast.emit("Body: %s." % Physiques.name_of(player.physique_id))
	elif physique != "":
		Bus.toast.emit("The altar's body is no greater than the one you already carry.")
	var relic := String(entry.get("relic", ""))
	if relic != "":
		_grant_unique_item(relic)
	elif site_id == RealmAccess.default_id():
		_grant_unique(Uniques.ALTAR_SOURCE)
	# The altar has its own table, not a chest's: one assured piece above the
	# mundane, rolled from the realm seed so the same altar gives the same thing.
	var spoils := Loot.new(DB, Rng).roll(
		"inheritance.altar", maxi(1, player.cultivation.realm + 2 + int(entry.get("rarity", 0))),
		active_realm_seed + 91, ground_items.size())
	var items: Array = spoils.get("items", [])
	for item in items:
		player.pick_up(item as Dictionary)
	if not items.is_empty():
		Bus.toast.emit("Inheritance: %s." % String((items[0] as Dictionary).get("name", "a piece of the altar")))
	Bus.cultivation_changed.emit()


func _mark_inheritance_taken(site_id: String) -> void:
	if site_id == "":
		return
	inheritances_taken[site_id] = true
	if site_id == RealmAccess.default_id():
		inheritance_taken = true


# --------------------------------------------------------- hidden realm ----

func _set_overworld_active(active: bool) -> void:
	chunks.visible = active
	chunks.set_props_visible(active)
	settlement.visible = active
	settlement.set_buildings_visible(active)
	for npc in npcs:
		if is_instance_valid(npc):
			npc.visible = active
			npc.set_physics_process(active)
	for node in interactables:
		if is_instance_valid(node):
			# Discovery survives the overworld being hidden: an unknown rift must
			# not appear just because the player stepped out of a realm.
			var known := true
			if node.kind == Interactable.Kind.PORTAL and String(node.id).begins_with("realm."):
				known = realm_known(String(node.id))
			node.visible = active and known


## ------------------------------------------------------- realm access ----

func _realm_site(site_id: String = "") -> Dictionary:
	if site_id != "":
		return RealmAccess.site(site_id)
	return RealmAccess.default_site()


func realm_known(site_id: String = "") -> bool:
	var site := _realm_site(site_id)
	return not site.is_empty() and Game.discovered.has(String(site.get("id", "")))


func realm_window(site_id: String = "") -> Dictionary:
	var site := _realm_site(site_id)
	if site.is_empty():
		return {"open": false}
	return RealmAccess.window_for(site, Clock.day)


## Walking near a rift, hearing a rumor, or loading a pre-M63 save that had
## already entered the tomb all discover the same stable site id.
func _discover_realm(site_id: String = "", source: String = "approach", quiet: bool = false) -> bool:
	var site := _realm_site(site_id)
	if site.is_empty():
		return false
	if not Game.discover(String(site.get("id", ""))):
		return false
	_realm_access_day = Clock.day
	_sync_realm_portal()
	if quiet:
		return true
	if source == "rumor":
		Bus.toast.emit("Rumor — %s: \"%s\"" % [String(site.get("name", "Hidden realm")), RealmAccess.rumor_line(site)])
	else:
		Bus.toast.emit("Discovery — %s. %s" % [String(site.get("name", "Hidden realm")), RealmAccess.discovery_line(site)])
	return true


func _hear_realm_rumor(source: String) -> bool:
	if _realm_rumor_day == Clock.day:
		return false
	var target: Dictionary = {}
	for site in RealmAccess.sites():
		if not realm_known(String(site.get("id", ""))):
			target = site
			break
	if target.is_empty():
		return false
	if not _discover_realm(String(target.get("id", "")), "rumor"):
		return false
	_realm_rumor_day = Clock.day
	Log.info("scene", "%s revealed %s" % [source, String(target.get("name", "a hidden realm"))])
	return true


func _check_realm_access() -> void:
	if String(phase) != "play" or player == null:
		return
	for site in RealmAccess.sites():
		var site_id := String(site.get("id", ""))
		if realm_known(site_id):
			continue
		var at: Vector2 = realm_portal_positions.get(site_id, portal_position)
		if player.global_position.distance_to(at) <= RealmAccess.reveal_radius(site):
			_discover_realm(site_id, "approach")
	if _realm_access_day != Clock.day:
		_realm_access_day = Clock.day
		_sync_realm_portal()


## Keep every rift, label, travel row and map mark in step with the calendar.
## Discovery is saved; the opening itself is derived from the day.
func _sync_realm_portal() -> void:
	for site in RealmAccess.sites():
		var site_id := String(site.get("id", ""))
		var portal: Variant = realm_portals.get(site_id, null)
		if portal == null or not is_instance_valid(portal):
			continue
		var known := realm_known(site_id)
		portal.label = RealmAccess.portal_label(site, Clock.day)
		portal.visible = known and String(phase) == "play"


func _try_enter_realm(site_id: String = "") -> void:
	var site := _realm_site(site_id)
	var verdict := RealmAccess.access(site, Clock.day, realm_known(site_id))
	if not bool(verdict.get("ok", false)):
		Bus.toast.emit(String(verdict.get("reason", "The rift will not open.")))
		return
	_enter_realm(site_id)


func _realm_map_marks() -> Array:
	var marks: Array = []
	for site in RealmAccess.sites():
		var site_id := String(site.get("id", ""))
		if not realm_known(site_id):
			continue
		marks.append({
			"name": String(site.get("name", "Hidden realm")),
			"open": bool(realm_window(site_id).get("open", false)),
			"status": RealmAccess.status_line(site, Clock.day),
		})
	return marks


func _enter_realm(site_id: String = "") -> void:
	if realm_instance != null:
		return
	var site := _realm_site(site_id)
	if site.is_empty():
		return
	var id := String(site.get("id", ""))
	if id == RealmAccess.default_id():
		if realm_seed == 0:
			var roll := float(Rng.roll_float("realm_seed", Game.kills, 0))
			realm_seed = 100000 + int(roll * 900000.0)
		active_realm_seed = realm_seed
	else:
		active_realm_seed = RealmAccess.seed_for(site, Game.world_seed)
	active_realm_id = id
	portal_position = realm_portal_positions.get(id, portal_position)
	_set_overworld_active(false)
	realm_instance = HiddenRealm.new()
	realm_instance.name = "HiddenRealm"
	realm_instance.entity_parent = world
	world.add_child(realm_instance)
	realm_instance.generate(active_realm_seed, String(site.get("template", HiddenRealms.default_id())),
		String(site.get("family", "")), id)
	# A warden already killed in this save stays dead: the tomb remembers.
	var warden_dead := realm_instance.warden_id != "" and bosses_slain.has(realm_instance.warden_id)
	if warden_dead:
		realm_instance.clear_warden()
	realm_instance.spawn_warden = not warden_dead
	if _inheritance_claimed(id):
		realm_instance.mark_cleared()
	elif realm_cleared and id == RealmAccess.default_id():
		realm_instance.mark_cleared()
	player.global_position = realm_instance.entry_position() + Vector2(0, 60)
	player.spawn_point = player.global_position
	phase = "realm"
	camera_rig.set_bounds(realm_instance.world_bounds())
	camera_rig.reset_smoothing()
	var family := HiddenRealms.family(String(site.get("family", "")))
	lighting.add_light(realm_instance, realm_instance.altar_position(),
		Color(String(family.get("light_color", "#c9b6ff"))), 320.0, 1.0)
	Bus.toast.emit("The rift closes behind you. %s does not want you here." % realm_instance.realm_name)
	if realm_instance.has_warden():
		var ward: Dictionary = Boss.profile(DB.boss(realm_instance.warden_id))
		Bus.toast.emit(String(ward.get("intro", "Something old rises in the dark.")))


func _exit_realm() -> void:
	if realm_instance == null:
		return
	_clear_inheritance_trial()
	realm_instance.cleanup()
	realm_instance.queue_free()
	realm_instance = null
	_set_overworld_active(true)
	phase = "play"
	player.global_position = portal_position + Vector2(-80, 40)
	player.spawn_point = player.global_position
	camera_rig.set_bounds(ChunkManager.world_bounds())
	camera_rig.reset_smoothing()
	active_realm_id = ""
	_sync_realm_portal()
	Bus.toast.emit("You return to the Verdant Fringe.")


# ----------------------------------------------------------------- loot ----

func _try_pickup() -> void:
	var best_index := -1
	var best_dist := 70.0
	for i in ground_items.size():
		var entry: Dictionary = ground_items[i]
		var pos := Vector2(float(entry["x"]), float(entry["y"]))
		var dist := pos.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	if best_index < 0:
		return
	var picked: Dictionary = ground_items[best_index]
	ground_items.remove_at(best_index)
	player.pick_up(picked["item"])
	Bus.toast.emit("Picked up %s." % String(picked["item"].get("name", "item")))


func _on_weather_changed(weather: Dictionary) -> void:
	if player == null or phase == "creation":
		return
	Bus.toast.emit("The weather turns: %s." % String(weather.get("kind", "clear")).capitalize())


func _boss_entry_of(boss: Node) -> Dictionary:
	if boss == null:
		return {}
	var value: Variant = boss.get("boss_entry")
	return value if typeof(value) == TYPE_DICTIONARY else {}


## A spirit beast leaves a core wherever it fell. The ordinary loot roll still
## happens through `enemy_died`; this is the part that is particular to beasts.
func _on_beast_slain(at: Vector2, species_id: String, ilvl: int) -> void:
	var entry: Dictionary = DB.spirit_beast(species_id)
	if entry.is_empty() or player == null:
		return
	var species := Beasts.profile(entry)
	var core := Beasts.core_item(species, ilvl, ground_items.size())
	ground_items.append({"x": at.x - 18.0, "y": at.y + 10.0, "item": core})
	Bus.item_dropped.emit(core, at)
	Bus.toast.emit("The %s leaves a %s." % [String(species.get("name", "beast")), String(core.get("name", "core"))])


## A phase change is announced by the body. The scene answers with the phase's
## adds, spawned through the realm so leaving the tomb frees them too.
func _on_boss_phase_changed(boss: Node, index: int, phase_name: String) -> void:
	if realm_instance == null or not is_instance_valid(realm_instance) or boss == null:
		return
	var entry := _boss_entry_of(boss)
	if entry.is_empty():
		return
	Bus.toast.emit("%s: %s." % [String(boss.get("display_name")), phase_name])
	var ids: Array = Boss.adds(entry, index)
	if ids.is_empty():
		return
	var anchor := (boss as Node2D).global_position
	for i in ids.size():
		var angle := TAU * float(i) / float(ids.size())
		var at := anchor + Vector2(cos(angle), sin(angle)) * 120.0
		realm_instance.spawn_beast(String(ids[i]), at, 2)


## Authored relics are one per save. The boss and the altar ask for their
## source's relic, and an id already worn or bagged is never granted twice.
func _grant_unique(source: String) -> void:
	if player == null:
		return
	for entry in DB.uniques:
		if String(entry.get("source", "")) == source:
			_grant_unique_item(String(entry.get("id", "")))
			return


## Grants one authored relic by id. Ownership is checked across worn and bagged
## copies, so a relic can never be duplicated by a second altar.
func _grant_unique_item(unique_id: String) -> void:
	if player == null or unique_id == "":
		return
	var owned := Uniques.owned_ids(player.equipment, player.inventory)
	if owned.has(unique_id):
		return
	var relic := Uniques.new(DB).make(unique_id)
	if relic.is_empty():
		return
	player.pick_up(relic)
	Bus.toast.emit("Relic — %s. %s" % [String(relic.get("name", "?")), String(relic.get("lore", ""))])


## Paid once per stable boss id. The reward is the boss' own, not the ordinary
## loot roll: stones and one guaranteed piece at the declared rarity.
func _on_boss_defeated(id: String, _at: Vector2) -> void:
	bosses_slain[id] = true
	# The hall counts a fallen enemy of the sect as service, paid in contribution
	# rather than stones: the player spends it at the quartermaster.
	Game.sect_contribution = SectEconomy.award_contribution(Game.sect_contribution, SectEconomy.boss_award())
	if SectEconomy.boss_award() > 0:
		Bus.toast.emit("The sect records the deed: +%d contribution." % SectEconomy.boss_award())
	# A boss can belong to a faction. Killing its warden costs that faction face
	# and, through the rival ripple, warms the houses that oppose it.
	var owner := Factions.for_boss(id)
	if owner != "":
		Game.faction_standing = Factions.award(Game.faction_standing, owner, -Factions.boss_penalty())
		Bus.toast.emit("Word of the fall reaches the sects: %s" % Factions.describe(
			owner, Game.faction_standing, Game.notoriety))
	var entry: Dictionary = Boss.profile(DB.boss(id))
	if entry.is_empty() or player == null:
		return
	var reward: Dictionary = Boss.reward(entry)
	var name := String(entry.get("name", id))
	Game.spirit_stones += int(reward.get("stones", 0))
	# The boss table is two assured pieces at spirit or better; the boss entry's
	# own ilvl bonus still decides how high they roll.
	var spoils := Loot.new(DB, Rng).roll(
		"kill.boss",
		maxi(1, player.cultivation.realm + int(entry.get("ilvl_bonus", 0))),
		Game.kills + 7000,
		ground_items.size())
	var items: Array = spoils.get("items", [])
	for item in items:
		player.pick_up(item as Dictionary)
	if items.is_empty():
		Bus.toast.emit("%s falls. The altar is open." % name)
	else:
		Bus.toast.emit("%s falls. You take the %s." % [name, String((items[0] as Dictionary).get("name", "spoils"))])
	# Boss ids are already stable `boss.*` keys, matching the relic's source.
	_grant_unique(id)
	Bus.player_stats_changed.emit()


## Bookkeeping every kill shares, whatever table then pays for it.
func _after_kill(ilvl: int) -> void:
	if player != null:
		player.on_kill(ilvl)
	var before := quests.step_index
	quests.track("kill", "beast", 1)
	if quests.step_index != before:
		_toast_new_objective()
	_check_story_hunts()


## Rolls one table and lays its pieces on the ground. The counter advances by
## what is laid down, so two kills in one frame cannot share an item id.
func _drop_loot(source: String, at: Vector2, ilvl: int, key: int, offset: float = 0.0) -> Dictionary:
	var result := Loot.new(DB, Rng).roll(source, maxi(1, ilvl), key, ground_items.size())
	var items: Array = result.get("items", [])
	for i in items.size():
		var item: Dictionary = items[i]
		ground_items.append({
			"x": at.x + offset + float(i) * 9.0,
			"y": at.y + 10.0,
			"item": item,
		})
		Bus.item_dropped.emit(item, at)
	var stones := int(result.get("stones", 0))
	if stones > 0:
		Game.spirit_stones += stones
		Bus.player_stats_changed.emit()
		Bus.toast.emit("%d spirit stones among the spoils." % stones)
	return result


func _on_enemy_died(at: Vector2, ilvl: int) -> void:
	_after_kill(ilvl)
	_drop_loot("kill.wild", at, ilvl + player.cultivation.realm, Game.kills + 1000, 18.0)


## An elite body reports here instead of `enemy_died`, so its table never rolls
## on top of the wild one. The rank itself was applied at spawn.
func _on_elite_died(at: Vector2, ilvl: int) -> void:
	_after_kill(ilvl)
	_drop_loot("kill.elite", at, ilvl + player.cultivation.realm, Game.kills + 2000, 18.0)
	Bus.toast.emit("An elite falls.")


# ----------------------------------------------------------- save/load ----

func _save(slot: int) -> void:
	if String(phase) == "ended":
		Bus.toast.emit("The story has ended; there is nothing to save.")
		return
	if phase == "realm":
		Bus.toast.emit("You cannot anchor a save inside a hidden realm.")
		return
	if tribulation_arena != null:
		Bus.toast.emit("The heavens do not pause for a save.")
		return
	var data := {
		"version": "0.2.0",
		"clock": Clock.to_dict(),
		"game": Game.to_dict(),
		"player": player.to_dict(),
		"ground_items": ground_items,
		"quests": quests.to_dict(),
		"used_interactables": used_interactables.duplicate(),
		"chunk_deltas": world_delta.to_dict(),
		"shop": merchant.to_dict(),
		"storage": storage.to_dict(),
		"travel_sites": travel_sites.duplicate(true),
		"waypoint": {"name": waypoint_name, "x": waypoint_position.x, "y": waypoint_position.y},
		"realm_seed": realm_seed,
		"realm_cleared": realm_cleared,
		"inheritance_taken": inheritance_taken,
		"inheritances_taken": inheritances_taken.duplicate(),
		"bosses_slain": bosses_slain.duplicate(),
	}
	if Save.save_game(slot, data):
		Log.info("scene", "saved slot %d" % slot)
		Bus.toast.emit("Saved to slot %d." % slot)
	else:
		Log.error("scene", "save failed for slot %d" % slot)
		Bus.toast.emit("Save failed.")


## F2 toggles combat sound. Decided here rather than in a settings file because
## the run rebuilds every node and the choice is per sitting.
func _toggle_audio() -> void:
	if combat_audio == null:
		return
	combat_audio.set_muted(not combat_audio.is_muted())
	Bus.toast.emit("Combat sound %s." % ("off" if combat_audio.is_muted() else "on"))


func _load_game(slot: int) -> void:
	Game.hitstop.clear()
	var data: Dictionary = Save.load_game(slot)
	if data.is_empty():
		Bus.toast.emit("No usable save in slot %d." % slot)
		return
	# An encounter is not in the save: loading abandons it rather than leaving a
	# half-finished circle standing in a restored world.
	if tribulation_arena != null:
		tribulation_arena.queue_free()
		tribulation_arena = null
		Bus.toast.emit("The tribulation is left unfinished.")
	if realm_instance != null:
		_clear_inheritance_trial()
		realm_instance.cleanup()
		realm_instance.queue_free()
		realm_instance = null
		_set_overworld_active(true)

	_close_bars()
	_close_captives()
	_close_chronicle()
	_close_factions()
	_close_sects()
	_close_hierarchy()
	_close_sect_ledger()
	_close_council()
	_close_player_sect()
	Game.from_dict(data.get("game", {}))
	Clock.from_dict(data.get("clock", {}))
	# Offers expire against the saved day, not the day the load happened to run.
	Game.story_offers = Stories.expire_offers(Game.story_offers, Clock.day)
	# A load is not a night: the yard is settled from the saved day forward, so
	# restoring a save cannot be farmed for a day of labour.
	_captive_day = Clock.day
	player.from_dict(data.get("player", {}))
	_run_ended = false
	player.set_physics_process(true)
	player.set_process(true)
	ground_items = data.get("ground_items", []).duplicate(true)
	quests.from_dict(data.get("quests", {}))
	used_interactables = data.get("used_interactables", []).duplicate()
	realm_seed = int(data.get("realm_seed", 0))
	realm_cleared = bool(data.get("realm_cleared", false))
	inheritance_taken = bool(data.get("inheritance_taken", false))
	inheritances_taken.clear()
	var taken_value: Variant = data.get("inheritances_taken", {})
	if typeof(taken_value) == TYPE_DICTIONARY:
		for key in (taken_value as Dictionary).keys():
			var site_id := String(key)
			if not RealmAccess.site(site_id).is_empty():
				inheritances_taken[site_id] = true
	# A pre-M65 save only has the tomb's boolean. It still means the tomb altar
	# was claimed, so the per-site ledger adopts it on load.
	if inheritance_taken:
		inheritances_taken[RealmAccess.default_id()] = true
	# A pre-M63 save never recorded discovery, but a nonzero seed or any realm
	# progress proves the player had already found the rift.
	var legacy_site := _realm_site()
	if not legacy_site.is_empty() and not realm_known() \
			and (realm_seed != 0 or realm_cleared or inheritance_taken):
		Game.discovered[String(legacy_site.get("id", ""))] = true
	var slain: Variant = data.get("bosses_slain", {})
	bosses_slain = (slain as Dictionary).duplicate() if typeof(slain) == TYPE_DICTIONARY else {}
	world_delta = WorldDelta.from_dict(data.get("chunk_deltas", {}))
	chunks.delta = world_delta
	merchant.from_dict(data.get("shop", {}))
	storage.from_dict(data.get("storage", {}))
	travel_sites = data.get("travel_sites", {}).duplicate(true)
	_realm_access_day = -1
	_realm_rumor_day = -1
	var waypoint: Dictionary = data.get("waypoint", {})
	waypoint_name = String(waypoint.get("name", ""))
	waypoint_position = Vector2(float(waypoint.get("x", 0.0)), float(waypoint.get("y", 0.0)))
	for node in interactables:
		if used_interactables.has(node.id):
			node.used = true
	# Rebuild the province so loaded deltas decide which resources exist.
	chunks.today = Clock.day
	chunks.resync(player.global_position)
	_sync_party()
	# Progression is derived from the saved day, so a loaded town is exactly as
	# strong as the seed says it should be on that day.
	_progress_day = Clock.day
	_refresh_npc_progress_all()
	_story_day = Clock.day
	phase = "play"
	_sync_realm_portal()
	if Game.dead:
		_end_run()
	Log.info("scene", "loaded slot %d" % slot)
	Bus.toast.emit("Loaded slot %d." % slot)


func _draw() -> void:
	# The province chunks draw the ground; this only marks the settlement gate
	# so the market is findable from the road.
	if settlement != null:
		draw_string(ThemeDB.fallback_font, settlement.position_for("gate") + Vector2(-70, -34),
			"AZURE CLOUD MARKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c8d4da"))
