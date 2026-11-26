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
const BANDS := ["biome.verdant", "biome.marsh", "biome.ashen", "biome.frost",
	"biome.forest", "biome.snow", "biome.desert", "biome.valley",
	"biome.volcanic", "biome.sacred", "biome.corrupted", "biome.forbidden"]
## Water cells of the continent are not a cultivation biome at all.
const OCEAN := "biome.ocean"
## Each continent terrain carries a trio of biomes: its base, a common
## variation, and a rarer third face. The noise field walks the trio, so
## a region reads as one land with moods rather than a patchwork.
const TRIOS := {
	"plains": ["biome.verdant", "biome.valley", "biome.forest"],
	"forest": ["biome.forest", "biome.verdant", "biome.valley"],
	"mountains": ["biome.snow", "biome.frost", "biome.ashen"],
	"marsh": ["biome.marsh", "biome.corrupted", "biome.verdant"],
	"desert": ["biome.desert", "biome.ashen", "biome.volcanic"],
	"coast": ["biome.valley", "biome.verdant", "biome.sacred"],
}
## Sparse pockets that can surface in any land region far from home.
const POCKETS := ["biome.volcanic", "biome.sacred", "biome.corrupted", "biome.forbidden"]


## Continent data is a pure function of the seed, so it is computed
## once per seed and shared. The cache is written ONLY through prime()
## on the main thread before streaming starts: chunk payloads are built
## on worker threads, and a Dictionary written mid-flight can be read
## torn. After priming, every lookup is a read of a settled value.
static var _continents := {}


## Computes and caches a seed's continent. Main thread only.
static func prime(seed_value: int) -> void:
	if _continents.has(seed_value):
		return
	if _continents.size() > 4:
		_continents.clear()
	_continents[seed_value] = Continent.generate(seed_value)


static func _continent(seed_value: int) -> Dictionary:
	if _continents.has(seed_value):
		return _continents[seed_value]
	# Unprimed seeds happen only in single-threaded contexts (unit
	# tests calling payload generation directly): compute pure.
	return Continent.generate(seed_value)


static func for_chunk(coord: Vector2i, seed_value: int) -> String:
	if absi(coord.x - HOME_CHUNK.x) <= HOME_RADIUS and absi(coord.y - HOME_CHUNK.y) <= HOME_RADIUS:
		return String(BANDS[0])
	var continent := _continent(seed_value)
	var cell := Continent.cell_for_chunk(coord)
	if not Continent.is_land(continent, cell):
		return OCEAN
	# Special pockets first: a coarse second field, kept away from home.
	var pocket := _noise(seed_value, float(coord.x) / (SCALE * 2.6) + 40.0, float(coord.y) / (SCALE * 2.6) - 17.0)
	if pocket > 0.90 and absi(coord.x - HOME_CHUNK.x) + absi(coord.y - HOME_CHUNK.y) > 8:
		var pick := Rng.stream_from(seed_value, "biome_pocket", coord.x * 31 + coord.y, 0)
		return String(POCKETS[pick.randi_range(0, POCKETS.size() - 1)])
	var terrain := Continent.terrain_for_cell(continent, cell)
	var trio: Array = TRIOS.get(terrain, TRIOS["plains"])
	var value := _noise(seed_value, float(coord.x) / SCALE, float(coord.y) / SCALE)
	if value < 0.55:
		return String(trio[0])
	if value < 0.85:
		return String(trio[1])
	return String(trio[2])


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


## Regional Qi density: how rich the ambient Qi is here. Defaults to 1.0 so a
## definition without the field is neutral rather than broken.
static func qi_density(biome: Dictionary) -> float:
	return maxf(0.0, float(biome.get("qi_density", 1.0)))


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
