class_name Beasts
extends RefCounted
## Spirit beasts: the wild's own cultivators.
##
## A beast is a species from `data/spirit_beasts.json` laid over the same enemy
## body and behaviour archetypes a humanoid uses: the species supplies where it
## lives, how hard it fights, its colour, the status its bite carries and the
## core it leaves behind, while `EnemyAI` still decides how it moves. Nothing
## here touches a node, so every rule is testable headlessly.
##
## A species' `biomes` map is its whole habitat: a biome not listed never spawns
## it, and the weight in the map is the species' share of that biome's beasts.

const ARCHETYPES: Array[String] = ["brawler", "skirmisher", "sentinel", "archer"]

const DEFAULTS := {
	"id": "beast.unknown",
	"name": "Spirit Beast",
	"archetype": "brawler",
	"biomes": {},
	"ilvl_bonus": 0,
	"hp_mult": 1.0,
	"damage_mult": 1.0,
	"speed": 62.0,
	"color": "#7f9e8a",
	"status": {},
	"core": {"name": "Spirit Core", "value": 20},
	"pack": false,
	"desc": "",
}


static func defaults() -> Dictionary:
	return (DEFAULTS as Dictionary).duplicate(true)


## A complete, clamped species. Missing fields fall back instead of leaving a
## body without numbers, exactly like `EnemyAI.profile()`.
static func profile(entry: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	for key in out.keys():
		if entry.has(key):
			out[key] = entry[key]
	out["id"] = String(out.get("id", "beast.unknown"))
	out["name"] = String(out.get("name", "Spirit Beast"))
	var archetype := String(out.get("archetype", "brawler"))
	out["archetype"] = archetype if ARCHETYPES.has(archetype) else "brawler"
	out["biomes"] = _biomes(out.get("biomes", {}))
	out["ilvl_bonus"] = clampi(int(out.get("ilvl_bonus", 0)), 0, 8)
	out["hp_mult"] = clampf(float(out.get("hp_mult", 1.0)), 0.2, 6.0)
	out["damage_mult"] = clampf(float(out.get("damage_mult", 1.0)), 0.2, 5.0)
	out["speed"] = clampf(float(out.get("speed", 62.0)), 10.0, 320.0)
	out["color"] = String(out.get("color", "#7f9e8a"))
	out["status"] = out.get("status", {}) if typeof(out.get("status", {})) == TYPE_DICTIONARY else {}
	out["core"] = _core(out.get("core", {}))
	out["pack"] = bool(out.get("pack", false))
	out["desc"] = String(out.get("desc", ""))
	return out


static func _biomes(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	var data: Dictionary = value
	for key in data.keys():
		var weight := int(data[key])
		if weight > 0:
			out[String(key)] = weight
	return out


static func _core(value: Variant) -> Dictionary:
	var out := {"name": "Spirit Core", "value": 20}
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		out["name"] = String(data.get("name", out["name"]))
		out["value"] = maxi(1, int(data.get("value", out["value"])))
	return out


## Every species in a table, normalized, in table order.
static func all(table: Array) -> Array:
	var out: Array = []
	for entry in table:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out.append(profile(entry))
	return out


## The species at home in a biome, with that biome's weight. An empty result
## means no beast lives there and the caller should spawn a humanoid instead.
static func residents(table: Array, biome_id: String) -> Array:
	var out: Array = []
	for species in all(table):
		var biomes: Dictionary = species["biomes"]
		if biomes.has(biome_id):
			out.append({"species": species, "weight": int(biomes[biome_id])})
	return out


## One beast for a biome, weighted by each species' share of that habitat.
## The single `pick_weighted` call keeps it deterministic for a given stream.
static func roll(table: Array, biome_id: String, r: RandomNumberGenerator) -> Dictionary:
	var pool := residents(table, biome_id)
	if pool.is_empty():
		return {}
	var weights: Array = []
	for entry in pool:
		weights.append(int((entry as Dictionary)["weight"]))
	var index := Rng.pick_weighted(weights, r)
	if index < 0 or index >= pool.size():
		return {}
	return (pool[index] as Dictionary)["species"]


## The shape `Dummy.apply_biome_enemy()` expects, so a beast and a humanoid take
## exactly the same stat path.
static func enemy_entry(species: Dictionary) -> Dictionary:
	return {
		"id": String(species.get("id", "beast.unknown")),
		"name": String(species.get("name", "Spirit Beast")),
		"archetype": String(species.get("archetype", "brawler")),
		"ilvl_bonus": int(species.get("ilvl_bonus", 0)),
		"hp_mult": float(species.get("hp_mult", 1.0)),
		"damage_mult": float(species.get("damage_mult", 1.0)),
		"speed": float(species.get("speed", 62.0)),
		"color": String(species.get("color", "#7f9e8a")),
	}


## The material a beast leaves behind. A core is not equipment: it rolls no
## affixes and carries no slot, it is simply a valuable the market will buy.
static func core_item(species: Dictionary, ilvl: int, counter: int) -> Dictionary:
	var core: Dictionary = species.get("core", {})
	var species_id := String(species.get("id", "beast.unknown"))
	var name := String(core.get("name", "Spirit Core"))
	return {
		"id": "item.core.%s.%d" % [species_id, counter],
		"name": name,
		"base_name": name,
		"slot": "material",
		"ilvl": maxi(1, ilvl),
		"rarity": 2,
		"rarity_name": ItemGen.RARITY_NAMES[2],
		"implicit": "Spirit beast core",
		"base_damage": 0.0,
		"armor": 0.0,
		"mods": [],
		"value": maxi(1, int(core.get("value", 20))),
	}


static func is_valid_id(table: Array, id: String) -> bool:
	for entry in table:
		if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("id", "")) == id:
			return true
	return false


static func count(table: Array) -> int:
	return all(table).size()
