class_name Towns
extends RefCounted
## Settlements beyond the capital, derived from the continent.
##
## Every land region except the capital gets one settlement, placed and
## shaped as a pure function of (continent, world seed): the same world
## always grows the same towns, so nothing about them needs saving.
## Size follows distance from the capital — near regions raise villages,
## the far rim raises cities — and each town carries the full schedule
## location graph so resident NPC routines resolve exactly as they do
## at the Azure Cloud Market; only the buildings and services differ.

const SIZES := {
	"village": {"scale": 0.72, "buildings": ["tavern", "market", "dorms"],
		"services": ["merchant"],
		"residents": [["farmer", 2], ["merchant", 1], ["guard", 1]]},
	"town": {"scale": 0.88, "buildings": ["tavern", "market", "dorms", "forge", "fields"],
		"services": ["merchant", "forge"],
		"residents": [["farmer", 2], ["merchant", 1], ["guard", 2], ["outer_disciple", 1]]},
	"city": {"scale": 1.0, "buildings": ["sect_hall", "tavern", "market", "dorms", "fields", "forge"],
		"services": ["merchant", "forge", "shrine"],
		"residents": [["farmer", 2], ["merchant", 2], ["guard", 2], ["elder", 1], ["outer_disciple", 2]]},
}


static func specs(continent: Dictionary, seed_value: int) -> Array:
	var out: Array = []
	for region in continent.get("regions", []):
		if bool(region.get("capital", false)):
			continue
		out.append(spec_for(region, seed_value))
	return out


static func spec_for(region: Dictionary, seed_value: int) -> Dictionary:
	var index := int(region["index"])
	var coord: Vector2i = region["coord"]
	var r := Rng.stream_from(seed_value, "town", index)
	var tier := int(region.get("tier", 1))
	var score := tier + r.randi_range(0, 3)
	var size := "village"
	if score >= 6:
		size = "city"
	elif score >= 4:
		size = "town"
	var size_def: Dictionary = SIZES[size]
	var scale := float(size_def["scale"])

	var origin := Continent.chunk_origin(coord)
	var local := Vector2i(6 + r.randi_range(-2, 2), 6 + r.randi_range(-2, 2))
	# A town never rises in a river or lake: step to the nearest dry
	# anchor chunk (deterministic order) when the rolled one is wet.
	var tries: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
		Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	for step in tries:
		var candidate := origin + local + step
		var centre_tile := Vector2i(
			int((float(candidate.x) * Continent.CHUNK_PX + 512.0) / 32.0),
			int((float(candidate.y) * Continent.CHUNK_PX + 512.0) / 32.0))
		if not ChunkGen.ground_water_at_tile(centre_tile, seed_value):
			local += step
			break
	var centre := Vector2(origin + local) * Continent.CHUNK_PX + Vector2(512, 512)

	var locations: Dictionary = {}
	for key in Settlement.LOCATIONS.keys():
		var base: Vector2 = Settlement.LOCATIONS[key]
		var jitter := Vector2(r.randf_range(-26.0, 26.0), r.randf_range(-26.0, 26.0))
		locations[key] = base * scale + (jitter if key != "plaza" else Vector2.ZERO)

	var buildings: Array = []
	for building in Settlement.BUILDINGS:
		if not (size_def["buildings"] as Array).has(String(building["location"])):
			continue
		var copy: Dictionary = building.duplicate()
		copy["size"] = (building["size"] as Vector2) * scale
		buildings.append(copy)

	# Lawless country keeps a second market: marsh and desert
	# towns, and any town on the far rim, run a black stall
	# beside the honest one.
	var services: Array = (size_def["services"] as Array).duplicate()
	var terrain := String(region.get("terrain", ""))
	if (terrain == "marsh" or terrain == "desert" or int(region.get("tier", 1)) >= 4) \
			and not services.has("black_market"):
		services.append("black_market")
	return {
		"region_index": index,
		"region_name": String(region.get("name", "")),
		"name": "%s %s" % [String(region.get("name", "Nameless")), size.capitalize()],
		"size": size,
		"centre": centre,
		"locations": locations,
		"buildings": buildings,
		"services": services,
		"residents": (size_def["residents"] as Array).duplicate(),
	}
