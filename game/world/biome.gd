class_name Biome
extends RefCounted
## Which biome a chunk belongs to, as a pure function of (seed, coordinate).
##
## The definitions themselves live in `data/biomes.json`; this class only decides
## identity and picks from a definition's tables. That split keeps chunk
## generation thread-safe: `for_chunk` reads no files and no autoload state, and
## the definitions arrive as a plain dictionary snapshot.

## The market's surroundings are the designed starting biome, so the settlement
## never opens onto ash flats.
const HOME_CHUNK := Vector2i(5, 5)
const HOME_RADIUS := 1
## Chunks per noise cell: larger means bigger, smoother biomes.
const SCALE := 7.0
const BANDS := ["biome.verdant", "biome.marsh", "biome.ashen", "biome.frost"]


static func for_chunk(coord: Vector2i, seed_value: int) -> String:
	if absi(coord.x - HOME_CHUNK.x) <= HOME_RADIUS and absi(coord.y - HOME_CHUNK.y) <= HOME_RADIUS:
		return String(BANDS[0])
	var value := _noise(seed_value, float(coord.x) / SCALE, float(coord.y) / SCALE)
	var index := clampi(int(value * float(BANDS.size())), 0, BANDS.size() - 1)
	return String(BANDS[index])


## Value noise with smoothstep interpolation: neighbouring chunks land in the
## same biome far more often than with a raw hash.
static func _noise(seed_value: int, fx: float, fy: float) -> float:
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var top := lerpf(_corner(seed_value, x0, y0), _corner(seed_value, x0 + 1, y0), sx)
	var bottom := lerpf(_corner(seed_value, x0, y0 + 1), _corner(seed_value, x0 + 1, y0 + 1), sx)
	return clampf(lerpf(top, bottom, sy), 0.0, 0.999)


static func _corner(seed_value: int, x: int, y: int) -> float:
	return Rng.stream_from(seed_value, "biome", x * 73856093 + y * 19349663, 0).randf()


## Picks a resource (herb) definition from a biome's table.
static func pick_resource(biome: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	return _pick(biome.get("resources", []), r)


## Picks an enemy definition from a biome's table.
static func pick_enemy(biome: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	return _pick(biome.get("enemies", []), r)


static func _pick(pool: Array, r: RandomNumberGenerator) -> Dictionary:
	if pool.is_empty():
		return {}
	var weights: Array = []
	for entry in pool:
		weights.append(maxi(1, int(entry.get("weight", 1))))
	var index := Rng.pick_weighted(weights, r)
	if index < 0 or index >= pool.size():
		return {}
	return pool[index]
