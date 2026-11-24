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
var spirit_stones: int = 0
var discovered: Dictionary = {}
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
## Crafting attempts this run. Every attempt advances it, failures included, so
## a retry rolls a new item instead of repeating the failed stream.
var crafts_made: int = 0
## Practice earned in each profession, by id: `{profession.smith: {xp: n}}`.
## The rank itself is derived, so only practice is ever stored.
var professions: Dictionary = {}


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
	crafts_made = 0
	professions.clear()
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


func register_kill() -> void:
	kills += 1


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"kills": kills,
		"karma": karma,
		"spirit_stones": spirit_stones,
		"discovered": discovered.duplicate(),
		"origin": origin_id,
		"play_time": play_time,
		"born_day": born_day,
		"dead": dead,
		"age_warning_stage": age_warning_stage,
		"crafts_made": crafts_made,
		"professions": professions.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	Rng.set_world_seed(world_seed)
	kills = int(data.get("kills", 0))
	karma = int(data.get("karma", 0))
	spirit_stones = int(data.get("spirit_stones", 0))
	discovered = data.get("discovered", {}).duplicate()
	origin_id = String(data.get("origin", ""))
	play_time = float(data.get("play_time", 0.0))
	# Legacy saves have no birth day: they start their life now, at the age a
	# new body begins.
	born_day = int(data.get("born_day", Clock.day))
	dead = bool(data.get("dead", false))
	age_warning_stage = int(data.get("age_warning_stage", 0))
	crafts_made = int(data.get("crafts_made", 0))
	professions = Professions.sanitize(data.get("professions", {}))
