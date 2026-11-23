extends Node
## Deterministic random number generation.
##
## Every procedurally generated thing in the game is a pure function of
## (world_seed, domain, key, counter). Generation order therefore cannot change
## results, which is what makes "regenerate the world from a seed" safe and
## keeps save files small.

var world_seed: int = 8814237719


func set_world_seed(value: int) -> void:
	world_seed = value


## Mixes two integers into a well-distributed 64-bit value (splitmix-style).
## Static so worker threads can use it without touching autoload state.
static func mix_values(a: int, b: int) -> int:
	var h: int = a ^ (b + 0x9E3779B1)
	h = (h ^ (h >> 30)) * -4658895280553007687
	h = (h ^ (h >> 27)) * -7723592293110705685
	h = h ^ (h >> 31)
	return h


func mix(a: int, b: int) -> int:
	return mix_values(a, b)


## Returns an independent RNG stream for an explicit seed. Same arguments always
## produce the same sequence; thread-safe because it reads no shared state.
static func stream_from(seed_value: int, domain: String, key: int = 0, counter: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = mix_values(seed_value, mix_values(hash(domain), mix_values(key, counter)))
	return r


## Returns an independent RNG stream for the current world seed.
func stream(domain: String, key: int = 0, counter: int = 0) -> RandomNumberGenerator:
	return stream_from(world_seed, domain, key, counter)


## Convenience: roll one float in [0, 1) from a named stream.
func roll_float(domain: String, key: int = 0, counter: int = 0) -> float:
	var r := stream(domain, key, counter)
	return r.randf()


## Picks an index from integer weights. Returns -1 for an empty table.
func pick_weighted(weights: Array, r: RandomNumberGenerator) -> int:
	var total := 0
	for w in weights:
		total += maxi(0, int(w))
	if total <= 0:
		return -1
	var roll := r.randi_range(1, total)
	var acc := 0
	for i in weights.size():
		acc += maxi(0, int(weights[i]))
		if roll <= acc:
			return i
	return weights.size() - 1
