extends Node
## Run-level state that is not owned by a node: world seed, kills, karma,
## play time, discovered content. Systems that need it read it from here.

var player: Node = null

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


func _process(delta: float) -> void:
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


func _fresh_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())


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
