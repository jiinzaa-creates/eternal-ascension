extends Node
## Run-level state that is not owned by a node: world seed, kills, karma,
## play time, discovered content. Systems that need it read it from here.

var player: Node = null
## Impact freeze shared by both sides of a fight. Ticked here in real time, so
## a freeze pauses combat without touching the engine clock.
var hitstop := Hitstop.new()

var world_seed: int = 8814237719
var kills: int = 0
var karma: int = 0
## Ambient Qi density of the biome the player stands in. Derived from the world
## each frame, never saved.
var biome_density: float = 1.0
## The biome the player stands in, by id. Derived alongside biome_density,
## never saved.
var current_biome: String = ""
## Slot the title screen asked the run to resume. Consumed once on boot; never
## saved, because it is a hand-off between scenes rather than run state.
var pending_load_slot: int = 0
var spirit_stones: int = 0
var discovered: Dictionary = {}
## Continent regions the player has entered, by lattice index.
var visited_regions: Array = []
## Origin chosen at creation. Applied once, at the start of a run; loading a save
## never re-applies it, because the effects are already in the save.
var origin_id: String = ""
var play_time: float = 0.0
var running: bool = false
## World day the body was born. Age is derived from it and the clock, never
## stored twice, so a save can never drift out of step with the calendar.
var born_day: int = 1
var dead: bool = false
## Highest aging stage already announced this run, so each warning fires once.
var age_warning_stage: int = 0
## Years of life bought with pills and peaches (M29). Permanent; the
## player's stat pipeline reads it as a lifespan mod so every lifespan
## figure in the game agrees.
var lifespan_years_bonus: int = 0
var cauldron_tier: int = 1
var discovered_recipes: Array = []
## Death, counted (M29). Combat deaths leave wounds: each wound is -5%
## max HP and Qi until a week of living closes it. Wounds cap so a bad
## season cannot make the game unplayable.
const MAX_DEATH_WOUNDS := 5
var deaths: int = 0
var death_wounds: int = 0
var death_wound_day: int = 0
## The rite of years (M29): the last day years were burned at a shrine,
## and whether the boon still waits for a breakthrough.
var sacrifice_day: int = -1
var sacrifice_boon: bool = false
## NPC mortality (M29): seeded birth days and recorded deaths for the
## persistent population (sect seats, towns), and who currently holds
## each sect's offices after successions.
var npc_born_days: Dictionary = {}
var npc_deaths: Dictionary = {}
var sect_leadership: Dictionary = {}


## Records a combat death: the count, a fresh wound, and a tenth of the
## stones the body was carrying, scattered where it fell.
func note_death() -> Dictionary:
	deaths += 1
	death_wounds = mini(MAX_DEATH_WOUNDS, death_wounds + 1)
	death_wound_day = Clock.day
	var lost := int(float(spirit_stones) * 0.1)
	spirit_stones -= lost
	return {"deaths": deaths, "wounds": death_wounds, "stones_lost": lost}


## A week survived closes the oldest wound. Returns how many closed.
func fade_death_wounds() -> int:
	var faded := 0
	while death_wounds > 0 and Clock.day >= death_wound_day + 7:
		death_wounds -= 1
		death_wound_day += 7
		faded += 1
	return faded
## Crafting attempts this run. Every attempt advances it, failures included, so
## a retry rolls a new item instead of repeating the failed stream.
var crafts_made: int = 0
## Practice earned in each profession, by id: `{profession.smith: {xp: n}}`.
## The rank itself is derived, so only practice is ever stored.
var professions: Dictionary = {}
## What people remember of the player, by stable NPC id. The sheet regenerates
## from the seed; this is the only part of a person a save has to carry.
var npc_memory: Dictionary = {}
## The travelling party, as stable NPC ids in formation order. Membership is
## the only party state a save carries: builds, health and positions regenerate
## with the people.
var party_ids: Array = []
## People held against their will. Unlike a bond, loyalty is the player's doing,
## so the roster is saved whole; `Captivity.sanitize()` cleans it on load.
var captives: Array = []
var tamed_beast: Dictionary = {}
## The terms the whole holding yard is kept under (fair or harsh).
var captive_policy := "captivity.fair"
## Advanced once per binding, so two people taken on one day cannot share an id.
var captive_seq := 0
## The market's legal memory of the player's dealings in bound labour, 0..100.
var notoriety := 0
## What the market has been saying, oldest first. Bounded by the story rules;
## entries are generated, so this is a record of what the player heard rather
## than the source of the simulation.
var chronicle: Array = []
## Requests the player has been told about and can still answer, with progress
## for the hunt work. Expired offers are dropped on the day they lapse.
var story_offers: Array = []
## Standing with each faction, −100..100. Raw actions are kept here; lawful
## factions subtract their memory of the player's notoriety when they read it.
var faction_standing: Dictionary = {}
## Sect contribution points: earned by service and donations, spent at the
## quartermaster. Bounded by the economy data's cap.
var sect_contribution := 0
## The established sect whose seal the player holds ("" = none), and the
## standing earned inside each house. Azure Cloud keeps its older ledgers
## (contribution, faction standing); this is the membership every house
## shares.
var player_sect_id := ""
var sect_standing: Dictionary = {}
## The living world of the twelve houses: strength, treasury, membership
## and feuds, settled day by day; each house's council lobby; and the
## houses whose master's seat a won vote has opened.
var sect_world: Dictionary = {}
var sect_lobbies: Dictionary = {}
var sect_seat_won: Dictionary = {}
## Last world day the sect stipend was claimed; −1 means never.
var sect_stipend_day := SectEconomy.DEFAULT_STIPEND_DAY
## How many quartermaster purchases this run, so every issued item gets a new
## stable id and two pills never share one.
var sect_purchases := 0
## Contribution invested in each council bloc, by bloc id. The support itself
## is derived, so only the investment has to be saved.
var sect_lobby: Dictionary = {}
## Set once the council has opened the master's seat. It stays open for the rest
## of the run; the top rung's own standing and realm gates still apply.
var sect_seat_open := false
## The player's own hall: empty until founded, then name, doctrine, treasury and
## member ids. Member realms and ranks are derived, never stored.
var player_sect: Dictionary = {}


func _process(delta: float) -> void:
	hitstop.tick(delta)
	if running:
		play_time += delta


func new_run(seed_value: int = 0) -> void:
	world_seed = seed_value if seed_value != 0 else _fresh_seed()
	Rng.set_world_seed(world_seed)
	kills = 0
	karma = 0
	spirit_stones = 0
	discovered.clear()
	origin_id = "origin.sect_orphan"
	play_time = 0.0
	running = true
	born_day = Clock.day
	dead = false
	age_warning_stage = 0
	lifespan_years_bonus = 0
	cauldron_tier = 1
	discovered_recipes = []
	deaths = 0
	death_wounds = 0
	death_wound_day = 0
	sacrifice_day = -1
	sacrifice_boon = false
	npc_born_days = {}
	npc_deaths = {}
	sect_leadership = {}
	crafts_made = 0
	professions.clear()
	npc_memory.clear()
	party_ids.clear()
	captives.clear()
	captive_policy = Captivity.default_policy_id()
	captive_seq = 0
	notoriety = 0
	chronicle.clear()
	story_offers.clear()
	faction_standing = Factions.sanitize({})
	sect_contribution = 0
	player_sect_id = ""
	sect_standing = {}
	sect_world = {}
	sect_lobbies = {}
	sect_seat_won = {}
	sect_stipend_day = SectEconomy.DEFAULT_STIPEND_DAY
	sect_purchases = 0
	sect_lobby.clear()
	sect_seat_open = false
	player_sect.clear()
	hitstop.clear()


func _fresh_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())


## Current age in years, from the calendar and the recorded birth day.
func age_years() -> float:
	return Aging.age_for(born_day, Clock.day)


func discover(id: String) -> bool:
	if discovered.has(id):
		return false
	discovered[id] = true
	return true


## Records a first entry into a continent region (lattice index).
## Returns true when the region is newly visited.
func visit_region(index: int) -> bool:
	if index < 0 or visited_regions.has(index):
		return false
	visited_regions.append(index)
	return true


func register_kill() -> void:
	kills += 1


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"kills": kills,
		"karma": karma,
		"spirit_stones": spirit_stones,
		"discovered": discovered.duplicate(),
		"visited_regions": visited_regions.duplicate(),
		"origin": origin_id,
		"play_time": play_time,
		"born_day": born_day,
		"dead": dead,
		"age_warning_stage": age_warning_stage,
		"lifespan_years_bonus": lifespan_years_bonus,
		"cauldron_tier": cauldron_tier,
		"discovered_recipes": discovered_recipes.duplicate(),
		"deaths": deaths,
		"death_wounds": death_wounds,
		"death_wound_day": death_wound_day,
		"sacrifice_day": sacrifice_day,
		"sacrifice_boon": sacrifice_boon,
		"npc_born_days": npc_born_days,
		"npc_deaths": npc_deaths,
		"sect_leadership": sect_leadership,
		"crafts_made": crafts_made,
		"professions": professions.duplicate(true),
		"npc_memory": npc_memory.duplicate(true),
		"party": party_ids.duplicate(),
		"captives": captives.duplicate(true),
		"tamed_beast": tamed_beast.duplicate(true),
		"captive_policy": captive_policy,
		"captive_seq": captive_seq,
		"notoriety": notoriety,
		"chronicle": chronicle.duplicate(true),
		"story_offers": story_offers.duplicate(true),
		"faction_standing": faction_standing.duplicate(true),
		"sect_contribution": sect_contribution,
		"player_sect_id": player_sect_id,
		"sect_standing": sect_standing.duplicate(true),
		"sect_world": sect_world.duplicate(true),
		"sect_lobbies": sect_lobbies.duplicate(true),
		"sect_seat_won": sect_seat_won.duplicate(true),
		"sect_stipend_day": sect_stipend_day,
		"sect_purchases": sect_purchases,
		"sect_lobby": sect_lobby.duplicate(true),
		"sect_seat_open": sect_seat_open,
		"player_sect": player_sect.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	Rng.set_world_seed(world_seed)
	kills = int(data.get("kills", 0))
	karma = int(data.get("karma", 0))
	spirit_stones = int(data.get("spirit_stones", 0))
	discovered = data.get("discovered", {}).duplicate()
	visited_regions.clear()
	for entry in data.get("visited_regions", []):
		var region_index := int(entry)
		if region_index >= 0 and region_index < 20 and not visited_regions.has(region_index):
			visited_regions.append(region_index)
	origin_id = String(data.get("origin", ""))
	play_time = float(data.get("play_time", 0.0))
	# Legacy saves have no birth day: they start their life now, at the age a
	# new body begins.
	born_day = int(data.get("born_day", Clock.day))
	dead = bool(data.get("dead", false))
	age_warning_stage = int(data.get("age_warning_stage", 0))
	lifespan_years_bonus = maxi(0, int(data.get("lifespan_years_bonus", 0)))
	cauldron_tier = clampi(int(data.get("cauldron_tier", 1)), 1, 3)
	discovered_recipes = []
	var saved_recipes: Variant = data.get("discovered_recipes", [])
	if typeof(saved_recipes) == TYPE_ARRAY:
		for entry in (saved_recipes as Array):
			discovered_recipes.append(String(entry))
	deaths = maxi(0, int(data.get("deaths", 0)))
	death_wounds = clampi(int(data.get("death_wounds", 0)), 0, MAX_DEATH_WOUNDS)
	death_wound_day = maxi(0, int(data.get("death_wound_day", 0)))
	sacrifice_day = int(data.get("sacrifice_day", -1))
	sacrifice_boon = bool(data.get("sacrifice_boon", false))
	npc_born_days = _int_dict(data.get("npc_born_days", {}))
	npc_deaths = _int_dict(data.get("npc_deaths", {}))
	sect_leadership = _leadership_dict(data.get("sect_leadership", {}))
	crafts_made = int(data.get("crafts_made", 0))
	professions = Professions.sanitize(data.get("professions", {}))
	npc_memory = NpcDb.sanitize_memory(data.get("npc_memory", {}))
	party_ids = Party.sanitize(data.get("party", []))
	captives = Captivity.sanitize(data.get("captives", []))
	var saved_beast: Variant = data.get("tamed_beast", {})
	tamed_beast = (saved_beast as Dictionary).duplicate(true) if typeof(saved_beast) == TYPE_DICTIONARY else {}
	captive_policy = Captivity.policy_id_or_default(String(data.get("captive_policy", "")))
	captive_seq = maxi(0, int(data.get("captive_seq", 0)))
	notoriety = clampi(int(data.get("notoriety", 0)), 0, Captivity.notoriety_cap())
	chronicle = Stories.sanitize_chronicle(data.get("chronicle", []))
	story_offers = Stories.sanitize_offers(data.get("story_offers", []), Clock.day)
	faction_standing = Factions.sanitize(data.get("faction_standing", {}))
	sect_contribution = clampi(int(data.get("sect_contribution", 0)), 0, SectEconomy.cap())
	player_sect_id = String(data.get("player_sect_id", ""))
	if player_sect_id != "" and Sects.sect(player_sect_id).is_empty():
		player_sect_id = ""
	sect_standing = {}
	var raw_standing: Dictionary = data.get("sect_standing", {})
	for key in raw_standing.keys():
		if not Sects.sect(String(key)).is_empty():
			sect_standing[String(key)] = clampi(int(raw_standing[key]), -100, 100)
	sect_world = SectWorld.sanitize(data.get("sect_world", {}), Clock.day)
	sect_lobbies = {}
	var raw_lobbies: Dictionary = data.get("sect_lobbies", {})
	for key in raw_lobbies.keys():
		if not Sects.sect(String(key)).is_empty():
			sect_lobbies[String(key)] = SectPolitics.sanitize_lobby(raw_lobbies[key])
	sect_seat_won = {}
	var raw_won: Dictionary = data.get("sect_seat_won", {})
	for key in raw_won.keys():
		if not Sects.sect(String(key)).is_empty() and bool(raw_won[key]):
			sect_seat_won[String(key)] = true
	sect_stipend_day = int(data.get("sect_stipend_day", SectEconomy.DEFAULT_STIPEND_DAY))
	sect_purchases = maxi(0, int(data.get("sect_purchases", 0)))
	sect_lobby = SectPolitics.sanitize_lobby(data.get("sect_lobby", {}))
	sect_seat_open = bool(data.get("sect_seat_open", false))
	player_sect = PlayerSect.sanitize(data.get("player_sect", {}))


## Saved id -> day maps: string keys, integer values, nothing else.
func _int_dict(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in (value as Dictionary).keys():
		out[String(key)] = int((value as Dictionary)[key])
	return out


## Saved sect leadership: real sects only, id and name strings only.
func _leadership_dict(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in (value as Dictionary).keys():
		var sect_id := String(key)
		if Sects.sect(sect_id).is_empty():
			continue
		var entry: Dictionary = (value as Dictionary)[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var clean: Dictionary = {}
		for field in ["master_id", "deputy_id", "elder_id", "master_name", "deputy_name"]:
			clean[field] = String(entry.get(field, ""))
		out[sect_id] = clean
	return out
